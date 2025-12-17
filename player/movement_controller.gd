extends Node
## MovementController handles player movement, jumping, and dashing
class_name MovementController

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var mana_component: ManaComponent = player.get_node_or_null("ManaComponent")

# ============ MOVEMENT CONFIGURATION ============
@export var move_speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0

# ============ JUMP CONFIGURATION ============
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15

# ============ DASH CONFIGURATION ============
@export var dash_distance: float = 250.0
@export var dash_duration: float = 0.2
@export var dash_mana_cost: int = 20
@export var dash_cooldown: float = 1.0

# ============ STATE ============
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
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


func _ready() -> void:
	if not player:
		push_error("[MovementController] Parent must be CharacterBody2D")
		return

	# Store original collision shape height
	var collision_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		normal_collision_height = capsule.height


func _physics_process(delta: float) -> void:
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


# ============ CROUCH ============
func _process_crouch() -> void:
	"""Handles crouching state"""
	var wants_to_crouch: bool = Input.is_action_pressed("crouch") and player.is_on_floor()

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
	var input_direction: float = Input.get_axis("move_left", "move_right")

	# Apply crouch speed modifier
	var current_speed: float = move_speed
	if is_crouching:
		current_speed *= crouch_speed_multiplier

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
	if not player.is_on_floor():
		player.velocity.y += gravity * delta


# ============ JUMP SYSTEM ============
func _process_jump() -> void:
	"""Handles jump input with coyote time and jump buffering"""
	# Can't jump while crouching
	if is_crouching:
		return

	# Check for jump input
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	# Attempt jump if conditions are met
	if jump_buffer_timer > 0 and (player.is_on_floor() or coyote_timer > 0):
		_perform_jump()


func _perform_jump() -> void:
	"""Executes the jump"""
	player.velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	# AudioManager.play_sfx("jump")  # Uncomment when audio added


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


# ============ DASH SYSTEM ============
func _process_dash_input() -> void:
	"""Checks for dash input"""
	if Input.is_action_just_pressed("dash"):
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
		Input.get_axis("move_left", "move_right"),
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
		return

	# Calculate dash speed
	var dash_speed: float = dash_distance / dash_duration
	player.velocity = dash_direction * dash_speed

	# No gravity during dash
	player.move_and_slide()


# ============ GETTERS ============
func is_moving() -> bool:
	"""Returns true if player is moving horizontally"""
	return abs(player.velocity.x) > 10.0


func get_facing_direction() -> int:
	"""Returns 1 for right, -1 for left"""
	return 1 if facing_right else -1
