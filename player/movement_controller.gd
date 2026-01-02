extends Node
## MovementController handles player movement, jumping, and dashing
class_name MovementController

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var mana_component: ManaComponent = player.get_node_or_null("ManaComponent")

# ============ INPUT CONFIGURATION ============
@export var input_prefix: String = "p1_"  # P1 by default, P2 uses "p2_"
@export var controller_device_id: int = -1  # -1 = keyboard (P1), 0+ = specific controller (P2)
# ============ SFX ============
@onready var jump_sfx: AudioStreamPlayer = null
@onready var dash_sfx: AudioStreamPlayer = null

# ============ MOVEMENT CONFIGURATION ============
@export var move_speed: float = 300.0
@export var jump_velocity: float = -800.0  # Powerful but grounded jump
@export var gravity: float = 1800.0  # High gravity for snappy, impactful feel

# ============ JUMP CONFIGURATION ============
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15
@export var max_jumps: int = 2  # Allows double jump

# ============ EDGE CLIMB CONFIGURATION ============
@export var edge_climb_detection_distance: float = 60.0  # How far to check for edges (increased for better detection)
@export var edge_climb_max_height: float = 120.0  # Maximum height difference for edge climb
@export var edge_climb_min_height: float = -40.0  # Minimum height difference (can be below player when falling)

# ============ DASH CONFIGURATION ============
@export var dash_distance: float = 1350.0  # Doubled from 675.0 (originally 375.0)
@export var dash_duration: float = 0.2
@export var dash_mana_cost: int = 20
@export var dash_cooldown: float = 1.0

# ============ STATE ============
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jumps_used: int = 0  # Track number of jumps used
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# ============ FACING DIRECTION ============
var facing_right: bool = true

# ============ CROUCH STATE ============
var is_crouching: bool = false
var normal_collision_height: float = 48.0
var crouch_collision_height: float = 24.0
var crouch_speed_multiplier: float = 0.5

# ============ HOVER STATE (for Ende der Schwerkraft) ============
var is_hovering: bool = false  # When true, gravity is disabled


func _ready() -> void:
	if not player:
		push_error("[MovementController] Parent must be CharacterBody2D")
		return

	# Store original collision shape height
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		normal_collision_height = capsule.height

	# CRITICAL: For P2, get controller device from InputManager
	if input_prefix == "p2_" and InputManager:
		await get_tree().create_timer(0.1).timeout  # Wait for P2 to be spawned
		controller_device_id = InputManager.p2_controller_device
		print("[MovementController P2] Controller device set to: ", controller_device_id)

# ============ DEVICE-FILTERED INPUT ============

func _is_action_pressed(action: String) -> bool:
	"""Check if action is pressed, with device filtering for P2"""
	if controller_device_id >= 0:
		# P2: Check specific controller device only
		# We can't filter by device directly in Input.is_action_pressed
		# So we check if the input event comes from the right device in _input
		return InputManager.is_p2_action_pressed(action.replace(input_prefix, "")) if InputManager else false
	else:
		# P1: Normal keyboard/mouse input
		return Input.is_action_pressed(action)

func _is_action_just_pressed(action: String) -> bool:
	"""Check if action was just pressed, with device filtering for P2"""
	if controller_device_id >= 0:
		# P2: Use InputManager
		return InputManager.is_p2_action_just_pressed(action.replace(input_prefix, "")) if InputManager else false
	else:
		# P1: Normal keyboard/mouse input
		return Input.is_action_just_pressed(action)

func _get_input_axis(negative: String, positive: String) -> float:
	"""Get input axis, with device filtering for P2"""
	if controller_device_id >= 0:
		# P2: Use InputManager's vector input
		var vec = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
		if "left" in negative or "right" in positive:
			return vec.x
		elif "up" in negative or "down" in positive:
			return vec.y
		return 0.0
	else:
		# P1: Normal keyboard/mouse input
		return Input.get_axis(negative, positive)
	# Setup SFX
	_setup_sfx()


func _physics_process(delta: float) -> void:
	# CRITICAL: Check for NaN position at start of every frame
	if is_nan(player.global_position.x) or is_nan(player.global_position.y):
		print("[MovementController] CRITICAL ERROR: NaN position detected at frame start!")
		print("[MovementController] This indicates position corruption from previous frame.")
		print("[MovementController] Resetting to safe position...")
		player.global_position = Vector2(0, 300)  # Safe fallback position
		player.velocity = Vector2.ZERO
		return

	if is_dashing:
		_process_dash(delta)
		return

	_process_gravity(delta)
	_process_coyote_time(delta)
	_process_jump_buffer(delta)
	_process_crouch()
	_process_horizontal_movement()
	_process_jump()
	_process_dash_input()

	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	player.move_and_slide()

	# CRITICAL: Check for NaN after move_and_slide
	if is_nan(player.global_position.x) or is_nan(player.global_position.y):
		print("[MovementController] CRITICAL ERROR: NaN position after move_and_slide!")
		print("[MovementController] Velocity was: ", player.velocity)
		player.global_position = Vector2(0, 300)  # Safe fallback
		player.velocity = Vector2.ZERO


# ============ CROUCH ============
func _process_crouch() -> void:
	"""Handles crouching state"""
	var crouch_action = input_prefix + "crouch" if InputMap.has_action(input_prefix + "crouch") else "crouch"
	var wants_to_crouch: bool = _is_action_pressed(crouch_action) and player.is_on_floor()

	if wants_to_crouch and not is_crouching:
		_start_crouch()
	elif not wants_to_crouch and is_crouching:
		_end_crouch()


func _start_crouch() -> void:
	"""Starts crouching"""
	is_crouching = true

	# Reduce collision shape height
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		capsule.height = crouch_collision_height

		# Adjust position to keep player on ground
		collision_shape.position.y = (normal_collision_height - crouch_collision_height) / 2

	# Scale sprite to 50% height (crouch visual)
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale = Vector2(1.0, 0.5)

	print("[Movement] Started crouching")


func _end_crouch() -> void:
	"""Ends crouching"""
	# Check if there's room to stand up
	if not _can_stand_up():
		return

	is_crouching = false

	# Restore collision shape height
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		capsule.height = normal_collision_height
		collision_shape.position.y = 0

	# Restore sprite to normal scale
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale = Vector2(1.0, 1.0)

	print("[Movement] Stopped crouching")


func _can_stand_up() -> bool:
	"""Checks if player can stand up from crouch"""
	# Simple check: test if there's space above
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()

	# Create a shape for the standing collision
	var test_shape: CapsuleShape2D = CapsuleShape2D.new()
	test_shape.radius = 16.0
	test_shape.height = normal_collision_height

	query.shape = test_shape
	query.transform = player.global_transform
	query.collision_mask = 1  # World layer

	var result: Array = space_state.intersect_shape(query, 1)
	return result.is_empty()


# ============ MOVEMENT ============
func _process_horizontal_movement() -> void:
	"""Handles horizontal WASD movement"""
	var move_left_action = input_prefix + "move_left"
	var move_right_action = input_prefix + "move_right"
	var input_direction: float = _get_input_axis(move_left_action, move_right_action)

	# Apply crouch speed modifier
	var current_speed: float = move_speed
	if is_crouching:
		current_speed *= crouch_speed_multiplier

	# Apply combat speed reduction (attacking or blocking reduces speed to 20%)
	var combat_system = player.get_node_or_null("CombatSystem")
	if combat_system and combat_system.is_attacking:
		current_speed *= 0.2

	var parry_block = player.get_node_or_null("CombatSystem/ParryBlockSystem")
	if parry_block and parry_block.has_method("is_blocking") and parry_block.is_blocking():
		current_speed *= 0.2

	# Apply resonance mode speed bonus
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.is_mode_active():
		current_speed *= resonance.SPEED_BONUS

	if input_direction != 0:
		player.velocity.x = input_direction * current_speed
		# Update facing direction
		if input_direction > 0:
			facing_right = true
		else:
			facing_right = false
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)


# ============ GRAVITY ============
func _process_gravity(delta: float) -> void:
	"""Applies gravity to player"""
	# Skip gravity if hovering (Ende der Schwerkraft / Luftgott)
	if is_hovering:
		# Keep player suspended at current height (stop vertical movement)
		player.velocity.y = 0.0
		return

	if not player.is_on_floor():
		player.velocity.y += gravity * delta


# ============ JUMP SYSTEM ============
func _process_jump() -> void:
	"""Handles jump input with coyote time and jump buffering"""
	# Reset jumps when on floor
	if player.is_on_floor():
		jumps_used = 0

	# Can't jump while crouching
	if is_crouching:
		return

	# Check for jump input
	var jump_action = input_prefix + "jump"
	if _is_action_just_pressed(jump_action):
		# IMPORTANT: Edge climb is checked FIRST, before jump count validation
		# This allows edge climb to work as a "3rd jump" after double jump is used
		if _attempt_edge_climb():
			print("[Movement] Edge climb successful (jumps_used: %d)" % jumps_used)
			return

		# First jump: use coyote time and jump buffer
		if jumps_used == 0:
			jump_buffer_timer = jump_buffer_time
			# Attempt jump if conditions are met
			if player.is_on_floor() or coyote_timer > 0:
				_perform_jump()
		# Double jump: can jump in air if jumps remaining
		elif jumps_used < max_jumps:
			_perform_jump()


func _perform_jump() -> void:
	"""Executes the jump"""
	player.velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	jumps_used += 1

	# Play jump SFX
	if jump_sfx:
		jump_sfx.play()

	if jumps_used == 2:
		print("[Movement] Double jump!")


func _process_coyote_time(delta: float) -> void:
	"""Manages coyote time (grace period after leaving platform)"""
	if player.is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0:
		coyote_timer -= delta


func _process_jump_buffer(delta: float) -> void:
	"""Manages jump buffer (allows early jump input)"""
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta


# ============ EDGE CLIMB SYSTEM ============
func _attempt_edge_climb() -> bool:
	"""Attempts to perform an edge climb. Returns true if successful.
	Works independently of jump count - acts as a 3rd jump option."""
	print("[EdgeClimb] Attempting edge climb - jumps_used: %d, velocity.y: %.1f, is_falling: %s" % [jumps_used, player.velocity.y, player.velocity.y > 0])

	# Check both left and right directions
	var edge_position: Vector2 = Vector2.ZERO
	var found_edge: bool = false

	# Try right side first (facing direction has priority)
	if facing_right:
		print("[EdgeClimb] Checking RIGHT direction (facing right)")
		edge_position = _detect_edge(Vector2.RIGHT)
		if edge_position != Vector2.ZERO:
			found_edge = true
			print("[EdgeClimb] Found edge on RIGHT at position: ", edge_position)
		else:
			# Try left side if right fails
			print("[EdgeClimb] No edge on RIGHT, trying LEFT")
			edge_position = _detect_edge(Vector2.LEFT)
			if edge_position != Vector2.ZERO:
				found_edge = true
				print("[EdgeClimb] Found edge on LEFT at position: ", edge_position)
	else:
		print("[EdgeClimb] Checking LEFT direction (facing left)")
		edge_position = _detect_edge(Vector2.LEFT)
		if edge_position != Vector2.ZERO:
			found_edge = true
			print("[EdgeClimb] Found edge on LEFT at position: ", edge_position)
		else:
			# Try right side if left fails
			print("[EdgeClimb] No edge on LEFT, trying RIGHT")
			edge_position = _detect_edge(Vector2.RIGHT)
			if edge_position != Vector2.ZERO:
				found_edge = true
				print("[EdgeClimb] Found edge on RIGHT at position: ", edge_position)

	if found_edge:
		_perform_edge_climb(edge_position)
		return true

	print("[EdgeClimb] No edge found in any direction")
	return false


func _detect_edge(direction: Vector2) -> Vector2:
	"""Detects if there's a climbable edge in the given direction.
	Returns the position to teleport to, or Vector2.ZERO if no edge found."""

	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state

	# Start from player center
	var player_center: Vector2 = player.global_position
	print("[EdgeClimb] Player center: ", player_center, " Direction: ", direction)

	# Step 1: Cast horizontal ray to find wall
	var wall_ray_start: Vector2 = player_center
	var wall_ray_end: Vector2 = player_center + (direction * edge_climb_detection_distance)

	var wall_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		wall_ray_start,
		wall_ray_end
	)
	wall_query.collision_mask = 1  # Only check World layer
	wall_query.exclude = [player]

	var wall_result: Dictionary = space_state.intersect_ray(wall_query)

	if wall_result.is_empty():
		print("[EdgeClimb] No wall found in direction ", direction)
		return Vector2.ZERO  # No wall found

	var wall_position: Vector2 = wall_result.position
	print("[EdgeClimb] Wall found at: ", wall_position)

	# Step 2: Search for the platform edge vertically
	# Search range covers both edges above AND below the player (for falling scenarios)
	var edge_search_bottom: Vector2 = Vector2(wall_position.x, player_center.y - edge_climb_min_height)
	var edge_search_top: Vector2 = Vector2(wall_position.x, player_center.y - edge_climb_max_height)

	print("[EdgeClimb] Searching vertical range: top=", edge_search_top, " bottom=", edge_search_bottom)

	# Cast ray downward from top to bottom to find the surface
	var surface_ray_start: Vector2 = edge_search_top
	var surface_ray_end: Vector2 = edge_search_bottom

	var surface_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		surface_ray_start,
		surface_ray_end
	)
	surface_query.collision_mask = 1  # Only check World layer
	surface_query.exclude = [player]

	var surface_result: Dictionary = space_state.intersect_ray(surface_query)

	if surface_result.is_empty():
		print("[EdgeClimb] No surface found in vertical range")
		return Vector2.ZERO  # No surface found

	var edge_top: Vector2 = surface_result.position
	print("[EdgeClimb] Surface/edge found at: ", edge_top)

	# Step 3: Validate edge height
	var height_difference: float = player_center.y - edge_top.y
	# Positive = edge above player, Negative = edge below player (falling past it)

	# Edge must be within climbable range
	# Allows climbing even when falling past the edge (negative height_difference)
	if height_difference < edge_climb_min_height or height_difference > edge_climb_max_height:
		print("[Movement] Edge too far: height_diff=%.1f (min=%.1f, max=%.1f)" % [height_difference, edge_climb_min_height, edge_climb_max_height])
		return Vector2.ZERO

	# Step 4: Calculate proper landing position
	# Player needs to stand ON the platform, not inside it
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	var player_half_height: float = 24.0  # Default fallback

	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		player_half_height = capsule.height / 2.0
		print("[EdgeClimb] Player half-height: %.1f" % player_half_height)

	# Landing position: player center should be half-height above the platform top
	# This places player's feet on the platform surface
	var landing_position: Vector2 = Vector2(edge_top.x, edge_top.y - player_half_height - 2.0)
	# The -2.0 adds a small buffer to ensure we're fully above the platform

	print("[EdgeClimb] Testing landing position: ", landing_position, " (edge_top: ", edge_top, ")")

	# Check if landing position is clear (should check area ABOVE platform, not inside it)
	if collision_shape and collision_shape.shape:
		var test_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		test_query.shape = collision_shape.shape
		test_query.transform = Transform2D(0, landing_position)
		test_query.collision_mask = 1  # World layer
		test_query.exclude = [player]

		var overlap_result: Array = space_state.intersect_shape(test_query, 1)
		if not overlap_result.is_empty():
			# Check if we're colliding with something OTHER than the platform we're climbing
			var colliding_body = overlap_result[0].get("collider")
			print("[EdgeClimb] Overlap detected with: ", colliding_body)
			# For now, we'll allow collision with the target platform itself
			# but block if there's a ceiling or other obstacle
			# This is a simplified check - a more robust solution would check if collision is only with floor
			pass  # Allow for now, may need refinement

	print("[EdgeClimb] Edge climb valid! Returning landing position: ", landing_position)
	return landing_position


func _perform_edge_climb(target_position: Vector2) -> void:
	"""Performs the edge climb by teleporting player to target position."""
	# Safety: Check for NaN before teleporting
	if is_nan(target_position.x) or is_nan(target_position.y):
		print("[Movement] ERROR: Edge climb target position is NaN! Aborting.")
		return

	player.global_position = target_position
	player.velocity = Vector2.ZERO  # Cancel all velocity
	jumps_used = 0  # Reset jumps (landed on platform)
	coyote_timer = 0.0  # Reset coyote time
	jump_buffer_timer = 0.0  # Reset jump buffer

	print("[Movement] Edge climb to position: ", target_position)
	# AudioManager.play_sfx("edge_climb")  # Uncomment when audio added


# ============ DASH SYSTEM ============
func _process_dash_input() -> void:
	"""Checks for dash input"""
	var dash_action = input_prefix + "dash"
	if _is_action_just_pressed(dash_action):
		_attempt_dash()


func _attempt_dash() -> void:
	"""Attempts to perform a dash"""
	# Check cooldown
	if dash_cooldown_timer > 0:
		return

	# Check mana
	if mana_component and not mana_component.use_mana(dash_mana_cost):
		return

	# Determine dash direction
	var input_direction: Vector2 = Vector2(
		_get_input_axis(input_prefix + "move_left", input_prefix + "move_right"),
		0.0  # Horizontal only for now
	)

	# Default to facing direction if no input
	if input_direction.length() == 0:
		input_direction = Vector2.RIGHT if facing_right else Vector2.LEFT

	# Start dash
	dash_direction = input_direction.normalized()
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown

	# Play dash SFX
	if dash_sfx:
		dash_sfx.play()

	# Disable collision with enemies during dash (can pass through)
	# Must change BOTH layer and mask:
	# - Layer: 2 → 32 (enemies don't see player)
	# - Mask: 17 → 1 (player doesn't see enemies, only terrain)
	player.collision_layer = 32
	player.collision_mask = 1

	# Cancel vertical velocity
	player.velocity.y = 0

	AudioManager.play_sfx("player_dash")


func _process_dash(delta: float) -> void:
	"""Handles dash movement"""
	dash_timer -= delta

	if dash_timer <= 0:
		# End dash
		is_dashing = false
		player.velocity.x = 0

		# Dash end explosion (damage + knockback)
		_dash_end_explosion()

		# Re-enable collision with enemies after dash
		# Restore BOTH layer and mask:
		# - Layer: 32 → 2 (normal player layer)
		# - Mask: 1 → 17 (terrain + enemies)
		player.collision_layer = 2
		player.collision_mask = 17

		return

	# Calculate dash speed
	var dash_speed: float = dash_distance / dash_duration

	# Apply resonance mode speed bonus
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance and resonance.is_mode_active():
		dash_speed *= resonance.SPEED_BONUS

	player.velocity = dash_direction * dash_speed

	# No gravity during dash
	player.move_and_slide()


func _dash_end_explosion() -> void:
	"""Creates a powerful AoE explosion at the end of dash"""
	const EXPLOSION_RADIUS: float = 144.0  # Increased by 80% (from 80.0)
	const EXPLOSION_DAMAGE: int = 27  # Increased by 80% (from 15)
	const EXPLOSION_KNOCKBACK: float = 540.0  # Increased by 80% (from 300.0)

	print("[MovementController] Dash end explosion!")

	# Find enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Check distance
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance > EXPLOSION_RADIUS:
			continue

		# Apply damage
		if enemy.has_method("take_damage"):
			enemy.take_damage(EXPLOSION_DAMAGE, player)
			hit_count += 1
		elif enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(EXPLOSION_DAMAGE)
				hit_count += 1

		# Apply knockback
		var direction = (enemy.global_position - player.global_position)
		if direction.length_squared() < 0.01:
			direction = Vector2(1, 0)  # Default direction
		else:
			direction = direction.normalized()

		if enemy.has_node("KnockbackComponent"):
			var knockback = enemy.get_node("KnockbackComponent")
			if knockback.has_method("apply_knockback"):
				knockback.apply_knockback(direction, EXPLOSION_KNOCKBACK, 0.3)

	if hit_count > 0:
		print("[MovementController] Dash explosion hit %d enemies" % hit_count)


# ============ SFX SETUP ============
func _setup_sfx() -> void:
	"""Creates and configures SFX AudioStreamPlayers"""
	# Jump SFX
	jump_sfx = AudioStreamPlayer.new()
	jump_sfx.name = "JumpSFX"
	jump_sfx.stream = load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Gothicvania Church/Stomper Asset Files/fx/jump.wav")
	jump_sfx.volume_db = -15.0
	jump_sfx.pitch_scale = 0.6  # Lower pitch for heavier jump sound
	add_child(jump_sfx)

	# Dash SFX
	dash_sfx = AudioStreamPlayer.new()
	dash_sfx.name = "DashSFX"
	dash_sfx.stream = load("res://Assets/Placeholder/Legacy Collection/Assets/Packs/Gothicvania Church/Stomper Asset Files/fx/stomp.wav")
	dash_sfx.volume_db = -13.0
	dash_sfx.pitch_scale = 0.75  # Match dark fantasy pitch
	add_child(dash_sfx)

	print("[MovementController] SFX initialized")


# ============ GETTERS ============
func is_moving() -> bool:
	"""Returns true if player is moving horizontally"""
	return abs(player.velocity.x) > 10.0


func get_facing_direction() -> int:
	"""Returns 1 for right, -1 for left"""
	return 1 if facing_right else -1
