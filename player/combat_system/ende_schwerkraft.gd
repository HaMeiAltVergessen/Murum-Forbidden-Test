extends Node
class_name EndeSchwerkraft
## Ende der Schwerkraft - Upward launcher
## W + Attack launches both player and enemy into air

# ============================================================================
# CONSTANTS
# ============================================================================

const COOLDOWN: float = 0.0  # No cooldown - always available when on floor
const LAUNCH_DAMAGE: int = 12
const LAUNCH_VELOCITY: float = -400.0  # 2x original height
const LAUNCH_HEIGHT: float = 150.0
const ANIMATION_DURATION: float = 0.25
const DETECTION_RANGE: float = 80.0
const SLOW_FALL_DURATION: float = 2.0  # Duration of slow falling
const SLOW_FALL_GRAVITY_SCALE: float = 0.3  # Reduced gravity for slow descent

# ============================================================================
# STATE
# ============================================================================

var cooldown_timer: float = 0.0
var is_executing: bool = false
var slow_fall_active: bool = false

# Gravity restoration tracking (must be member vars to prevent loss)
var original_player_gravity: float = 0.0
var enemy_gravity_scales: Dictionary = {}

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner

# ============================================================================
# SIGNALS
# ============================================================================

signal ende_schwerkraft_executed(enemy: Node)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[EndeSchwerkraft] Initialized")


func _exit_tree() -> void:
	"""Safety: Restore gravity when node is freed"""
	if slow_fall_active:
		print("[EndeSchwerkraft] Emergency gravity restore on node exit")
		_restore_gravity()


func _process(delta: float) -> void:
	# COMMIT 023.5.1: Null check - safety guard
	if not player:
		return

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Kontinuierliche Prüfung: W + LMB beide gedrückt
	# Funktioniert in beiden Szenarien:
	# 1. W gedrückt halten → LMB drücken
	# 2. LMB gedrückt halten → W drücken
	if not is_executing and cooldown_timer <= 0.0:
		# CRITICAL: Use InputManager to prevent P2 from triggering P1's ability!
		var p1_attack = false
		if InputManager:
			# COMMIT 023: Detect if P2 and use correct action
			var is_p2 = player.is_in_group("player2") or player.name == "Lythrun"
			if is_p2:
				p1_attack = InputManager.is_p2_action_pressed("attack")
			else:
				p1_attack = InputManager.is_p1_action_pressed("attack")

		# Keyboard: W + LMB (P1 only)
		var keyboard_combo = Input.is_physical_key_pressed(KEY_W) and p1_attack
		# Gamepad: Only check if P2 is NOT active (when P2 active, P1 uses keyboard only)
		var gamepad_combo = false
		if not InputManager or not InputManager.p2_active:
			# P1 can use gamepad when playing solo
			var dpad_combo = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) and p1_attack
			var stick_combo = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) < -0.5 and p1_attack
			gamepad_combo = dpad_combo or stick_combo

		if (keyboard_combo or gamepad_combo) and player.is_on_floor():
			_try_execute()


# NOTE: _input() removed - using _process() with InputManager instead for proper filtering

# ============================================================================
# EXECUTION
# ============================================================================

func _try_execute() -> void:
	"""Attempts to execute Ende der Schwerkraft"""

	if is_executing:
		return

	if cooldown_timer > 0.0:
		return

	if not player.is_on_floor():
		return

	var targets = _find_targets()
	if targets.is_empty():
		return

	print("[EndeSchwerkraft] Executing with %d targets" % targets.size())
	_execute(targets)


func _find_targets() -> Array:
	"""Finds ALL enemies within detection range around player"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var targets = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# CRITICAL: Bosses are too heavy to launch - skip them
		if enemy.is_in_group("boss"):
			print("[EndeSchwerkraft] Skipping boss %s (too heavy to launch)" % enemy.name)
			continue

		# CRITICAL: Don't launch yourself! (COMMIT 023.9.1)
		if enemy == player:
			continue

		var to_enemy = enemy.global_position - player.global_position
		var dist = to_enemy.length()

		if dist > DETECTION_RANGE:
			continue

		# Add to targets list (all enemies in range, regardless of direction)
		targets.append(enemy)

	return targets

# ============================================================================
# LAUNCHER
# ============================================================================

func _execute(enemies: Array) -> void:
	"""Executes upward launcher on all targets"""

	print("[EndeSchwerkraft] Launching %d enemies" % enemies.size())

	is_executing = true
	cooldown_timer = COOLDOWN

	# Play animation (if exists)
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite and sprite.has_method("play"):
		# Fallback to idle if ende_schwerkraft animation doesn't exist
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("ende_schwerkraft"):
			sprite.play("ende_schwerkraft")

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("player/ende_schwerkraft", player.global_position, 0.15)

	# Wait for hit frame
	await get_tree().create_timer(0.15).timeout

	# Apply launch to ALL enemies at once
	_launch_all(enemies)

	# Complete
	await get_tree().create_timer(ANIMATION_DURATION - 0.15).timeout
	is_executing = false


func _launch_all(enemies: Array) -> void:
	"""Launches player and ALL enemies upward simultaneously"""

	print("[EndeSchwerkraft] Launching player + %d enemies" % enemies.size())

	# Launch ALL enemies FIRST (before player)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Launch enemy with exact same velocity as player
		if enemy is CharacterBody2D:
			enemy.velocity.y = LAUNCH_VELOCITY

		# Set juggled state
		if enemy.has_method("set_juggled_state"):
			enemy.set_juggled_state(true)

		# Damage enemy
		if enemy.has_node("HealthComponent"):
			var health = enemy.get_node("HealthComponent")
			if health.has_method("take_damage"):
				health.take_damage(LAUNCH_DAMAGE)
		elif enemy.has_method("take_damage"):
			# Try direct method (for BaseEnemy) - check parameter count
			var method_list = enemy.get_method_list()
			var take_damage_params = 0
			for method in method_list:
				if method.name == "take_damage":
					take_damage_params = method.args.size()
					break

			if take_damage_params == 1:
				enemy.take_damage(LAUNCH_DAMAGE)

		# VFX for each enemy
		_spawn_launch_effect(enemy.global_position)

		print("[EndeSchwerkraft]   -> Launched %s" % enemy.name)

	# Launch player with EXACT SAME VELOCITY
	player.velocity.y = LAUNCH_VELOCITY

	# Camera shake (reduced from 0.3 to 0.15)
	if player.has_node("PlayerCamera"):
		var camera = player.get_node("PlayerCamera")
		if camera.has_method("add_trauma"):
			camera.add_trauma(0.15)

	# Hitstop
	if GlobalTimeEffects and GlobalTimeEffects.has_method("hit_stop"):
		GlobalTimeEffects.hit_stop(0.08)

	# Start slow fall phase for ALL enemies
	_start_slow_fall_phase(enemies)

	# Emit signal for first enemy only (for air combo targeting)
	if enemies.size() > 0:
		var primary_target = enemies[0]
		ende_schwerkraft_executed.emit(primary_target)
		if EventBus:
			EventBus.ende_schwerkraft_executed.emit(primary_target)

	print("[EndeSchwerkraft] All launched upward, slow fall phase started")

# ============================================================================
# SLOW FALL PHASE
# ============================================================================

func _start_slow_fall_phase(enemies: Array) -> void:
	"""All enemies + player fall slowly for duration after launch"""

	# CRITICAL: Prevent overlapping executions from corrupting gravity
	if slow_fall_active:
		print("[EndeSchwerkraft] WARNING: Slow fall already active, skipping gravity manipulation")
		return

	slow_fall_active = true

	# Get player movement controller
	var movement_controller = player.get_node_or_null("MovementController")

	# Clear previous gravity scales (in case of overlapping executions)
	enemy_gravity_scales.clear()

	# Reduce player gravity for slow fall (NOT hovering, just slower)
	if movement_controller and movement_controller.get("gravity") != null:
		# CRITICAL: Only store original gravity if not already stored
		# This prevents exponential reduction from overlapping executions
		if original_player_gravity == 0.0:
			original_player_gravity = movement_controller.gravity
			print("[EndeSchwerkraft] Stored original gravity: %.1f" % original_player_gravity)
		else:
			print("[EndeSchwerkraft] Original gravity already stored: %.1f (current: %.1f)" % [original_player_gravity, movement_controller.gravity])

		# Reduce gravity to 30% for slow fall
		movement_controller.gravity = original_player_gravity * SLOW_FALL_GRAVITY_SCALE
		print("[EndeSchwerkraft] Player gravity reduced to %.1f%% for slow fall" % (SLOW_FALL_GRAVITY_SCALE * 100))

	# Reduce enemy gravity for slow fall
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.get("gravity_scale") != null:
			# Store as member variable to prevent loss
			enemy_gravity_scales[enemy] = enemy.gravity_scale
			enemy.gravity_scale = SLOW_FALL_GRAVITY_SCALE
			print("[EndeSchwerkraft]   -> %s gravity reduced to %.1f%%" % [enemy.name, SLOW_FALL_GRAVITY_SCALE * 100])

	# Visual: slight glow during slow fall
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.5)

	print("[EndeSchwerkraft] Slow fall phase started for player + %d enemies (%.1fs)" % [enemies.size(), SLOW_FALL_DURATION])

	# Wait for slow fall duration
	await get_tree().create_timer(SLOW_FALL_DURATION).timeout

	# Restore gravity using helper function (handles edge cases safely)
	_restore_gravity()

	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

	slow_fall_active = false

	print("[EndeSchwerkraft] Slow fall ended")


func _restore_gravity() -> void:
	"""Safely restores gravity for player and all affected enemies"""

	# Check if player still exists
	if not is_instance_valid(player):
		return

	var movement_controller = player.get_node_or_null("MovementController")

	# Restore player gravity if it was stored
	if movement_controller and is_instance_valid(movement_controller):
		if original_player_gravity > 0.0:  # Only restore if we have a valid stored value
			movement_controller.gravity = original_player_gravity
			print("[EndeSchwerkraft] Player gravity restored to %.1f" % original_player_gravity)
			original_player_gravity = 0.0  # Clear stored value

	# Restore all enemies' gravity
	for enemy in enemy_gravity_scales:
		if is_instance_valid(enemy) and enemy.get("gravity_scale") != null:
			enemy.gravity_scale = enemy_gravity_scales[enemy]
			print("[EndeSchwerkraft]   -> %s gravity restored" % enemy.name)

	# Clear the dictionary
	enemy_gravity_scales.clear()

# ============================================================================
# COOLDOWN
# ============================================================================

func is_on_cooldown() -> bool:
	"""Returns true if on cooldown"""
	return cooldown_timer > 0.0


func can_execute() -> bool:
	"""Returns true if can execute"""
	return not is_executing and cooldown_timer <= 0.0 and player.is_on_floor()


func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return max(0.0, cooldown_timer)

# ============================================================================
# EFFECTS
# ============================================================================

func _spawn_launch_effect(position: Vector2) -> void:
	"""Spawns upward launch VFX"""

	# Check if VFX scene exists
	var vfx_path = "res://vfx/particles/ende_schwerkraft_launch.tscn"
	if not ResourceLoader.exists(vfx_path):
		print("[EndeSchwerkraft] VFX not found: %s" % vfx_path)
		return

	var vfx_scene = load(vfx_path)
	if not vfx_scene:
		return

	var vfx = vfx_scene.instantiate()

	get_tree().root.add_child(vfx)
	vfx.global_position = position

	if vfx.has_method("emit"):
		vfx.emit()
	elif vfx.get("emitting") != null:
		vfx.emitting = true
