extends Node
class_name EndeSchwerkraft
## Ende der Schwerkraft - Upward launcher
## W + Attack launches both player and enemy into air

# ============================================================================
# CONSTANTS
# ============================================================================

const COOLDOWN: float = 2.0
const LAUNCH_DAMAGE: int = 12
const LAUNCH_VELOCITY: float = -400.0
const LAUNCH_HEIGHT: float = 150.0
const ANIMATION_DURATION: float = 0.25
const DETECTION_RANGE: float = 80.0
const HOVER_DURATION: float = 1.5
const HOVER_GRAVITY_SCALE: float = 0.0

# ============================================================================
# STATE
# ============================================================================

var cooldown_timer: float = 0.0
var is_executing: bool = false
var hover_active: bool = false

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


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta


func _input(event: InputEvent) -> void:
	print("[EndeSchwerkraft DEBUG] _input called, event: %s" % event)

	if event.is_action_pressed("light_attack"):
		print("[EndeSchwerkraft DEBUG] light_attack pressed")

		# Check if W key is physically pressed (KEY_W = 87)
		if Input.is_physical_key_pressed(KEY_W):
			print("[EndeSchwerkraft DEBUG] W key is also pressed - attempting execute")
			_try_execute()

			# Consume the event to prevent combat system from processing it
			get_viewport().set_input_as_handled()
		else:
			print("[EndeSchwerkraft DEBUG] W key NOT pressed")

# ============================================================================
# EXECUTION
# ============================================================================

func _try_execute() -> void:
	"""Attempts to execute Ende der Schwerkraft"""

	print("[EndeSchwerkraft DEBUG] _try_execute called")

	if is_executing:
		print("[EndeSchwerkraft DEBUG] Already executing - abort")
		return

	if cooldown_timer > 0.0:
		print("[EndeSchwerkraft DEBUG] On cooldown (%.2fs remaining) - abort" % cooldown_timer)
		return

	if not player.is_on_floor():
		print("[EndeSchwerkraft DEBUG] Not on floor - abort")
		return

	var target = _find_target()
	if not target:
		print("[EndeSchwerkraft DEBUG] No target found - abort")
		return

	print("[EndeSchwerkraft DEBUG] All conditions met - executing!")
	_execute(target)


func _find_target() -> Node:
	"""Finds enemy in front of player"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[EndeSchwerkraft DEBUG] Found %d enemies in scene" % enemies.size())

	var sprite = player.get_node_or_null("Sprite2D")
	var facing = 1

	# Determine facing direction
	if sprite:
		facing = -1 if sprite.flip_h else 1

	print("[EndeSchwerkraft DEBUG] Player facing: %s" % ("left" if facing == -1 else "right"))

	var best_enemy = null
	var best_distance = DETECTION_RANGE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - player.global_position
		var dist = to_enemy.length()

		print("[EndeSchwerkraft DEBUG] Enemy %s: distance=%.1f, direction=%s" % [
			enemy.name,
			dist,
			"left" if to_enemy.x < 0 else "right"
		])

		if dist > DETECTION_RANGE:
			print("[EndeSchwerkraft DEBUG]   -> Too far (>%.1f)" % DETECTION_RANGE)
			continue

		# Check if in front
		if to_enemy.x * facing > 0:
			if dist < best_distance:
				best_distance = dist
				best_enemy = enemy
				print("[EndeSchwerkraft DEBUG]   -> New best target!")
		else:
			print("[EndeSchwerkraft DEBUG]   -> Behind player")

	if best_enemy:
		print("[EndeSchwerkraft DEBUG] Selected target: %s (%.1fpx)" % [best_enemy.name, best_distance])
	else:
		print("[EndeSchwerkraft DEBUG] No valid target found")

	return best_enemy

# ============================================================================
# LAUNCHER
# ============================================================================

func _execute(enemy: Node) -> void:
	"""Executes upward launcher"""

	print("[EndeSchwerkraft] Launching enemy: %s" % enemy.name)

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

	# Apply launch
	_launch_both(enemy)

	# Complete
	await get_tree().create_timer(ANIMATION_DURATION - 0.15).timeout
	is_executing = false


func _launch_both(enemy: Node) -> void:
	"""Launches both player and enemy upward"""

	# Launch enemy
	if enemy is CharacterBody2D:
		enemy.velocity.y = LAUNCH_VELOCITY

	# Set juggled state (if from Commit 012)
	if enemy.has_method("set_juggled_state"):
		enemy.set_juggled_state(true)

	# Damage enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(LAUNCH_DAMAGE, player)
	elif enemy.has_node("HealthComponent"):
		var health = enemy.get_node("HealthComponent")
		if health.has_method("take_damage"):
			health.take_damage(LAUNCH_DAMAGE)

	# Launch player
	player.velocity.y = LAUNCH_VELOCITY

	# VFX
	_spawn_launch_effect(enemy.global_position)

	# Camera shake
	if player.has_node("PlayerCamera"):
		var camera = player.get_node("PlayerCamera")
		if camera.has_method("add_trauma"):
			camera.add_trauma(0.2)

	# Hitstop
	if GlobalTimeEffects and GlobalTimeEffects.has_method("hit_stop"):
		GlobalTimeEffects.hit_stop(0.08)

	# Start hover phase
	_start_hover_phase(enemy)

	# Emit signal
	ende_schwerkraft_executed.emit(enemy)
	if EventBus:
		EventBus.ende_schwerkraft_executed.emit(enemy)

	print("[EndeSchwerkraft] Both launched upward, hover phase started")

# ============================================================================
# HOVER PHASE
# ============================================================================

func _start_hover_phase(enemy: Node) -> void:
	"""Both hover for 1.5s after launch"""

	hover_active = true

	# Store original gravity scales
	var player_gravity_scale = player.get("gravity_scale") if player.get("gravity_scale") != null else 1.0
	var enemy_gravity_scale = 1.0
	if enemy.get("gravity_scale") != null:
		enemy_gravity_scale = enemy.gravity_scale

	# Suspend gravity
	if player.get("gravity_scale") != null:
		player.set("gravity_scale", HOVER_GRAVITY_SCALE)

	if enemy.get("gravity_scale") != null:
		enemy.gravity_scale = HOVER_GRAVITY_SCALE

	# Visual: slight glow
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.5)

	# Wait hover duration
	await get_tree().create_timer(HOVER_DURATION).timeout

	# Check if player still exists
	if not is_instance_valid(player):
		return

	# Restore gravity
	if player.get("gravity_scale") != null:
		player.set("gravity_scale", player_gravity_scale)

	if is_instance_valid(enemy) and enemy.get("gravity_scale") != null:
		enemy.gravity_scale = enemy_gravity_scale

	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color.WHITE

	hover_active = false

	print("[EndeSchwerkraft] Hover ended")

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
