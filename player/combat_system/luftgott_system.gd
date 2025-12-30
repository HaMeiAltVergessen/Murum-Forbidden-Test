extends Node
## LuftgottSystem - Extended Air Combat with Air Reset mechanic
## After Air-Combo ends, grants 1s window for Air Reset
## Enables hover state for player + enemy with bonus damage
class_name LuftgottSystem

# ============================================================================
# CONSTANTS - Air Reset Parameters
# ============================================================================

const AIR_RESET_WINDOW: float = 1.0  # Fenster nach Air-Combo-Ende
const AIR_RESET_COMBO_LIMIT: int = 3  # Max 3 zusätzliche Hits

const AIR_RESET_DAMAGE_BOOST: float = 1.2  # ×1.2 auf Air-Hit Damage
const AIR_RESET_HIT_DAMAGE: int = 10  # Base (vs 8 normal air hit)

# Hover Physics
const HOVER_GRAVITY_SCALE: float = 0.0  # Komplette Gravity-Suspension
const HOVER_DRIFT_SPEED: float = 20.0  # Leichtes Driften erlaubt

# Accuracy Decay (Hitbox Scaling)
const HITBOX_SCALE_PER_HIT: float = 0.8  # 80% pro Hit
# Hit 1: 100% hitbox
# Hit 2: 80% hitbox
# Hit 3: 64% hitbox

# Visual
const HOVER_AURA_INTENSITY: float = 1.5  # Glow während hover

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, RESET_WINDOW, AIR_RESET_ACTIVE }

var current_state: State = State.IDLE
var reset_window_timer: float = 0.0
var reset_combo_count: int = 0
var current_hitbox_scale: float = 1.0

# Targets
var reset_enemy: Node = null
var last_air_combo_count: int = 0

# Visual Sphere
var hover_sphere: Node3D = null

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var air_combo_system: Node = null
var movement_controller: Node = null

# ============================================================================
# SIGNALS
# ============================================================================

signal air_reset_window_started()
signal air_reset_activated(enemy: Node)
signal air_reset_hit(count: int, damage: int)
signal air_reset_ended(total_hits: int)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Get references
	player = owner as CharacterBody2D
	if not player:
		push_error("[LuftgottSystem] Owner must be player CharacterBody2D")
		return

	air_combo_system = player.get_node_or_null("AirComboSystem")
	if not air_combo_system:
		push_warning("[LuftgottSystem] AirComboSystem not found")
		return

	movement_controller = player.get_node_or_null("MovementController")
	if not movement_controller:
		push_warning("[LuftgottSystem] MovementController not found")

	# Connect to Air-Combo events
	if air_combo_system.has_signal("air_combo_ended"):
		air_combo_system.air_combo_ended.connect(_on_air_combo_ended)

	print("[LuftgottSystem] Initialized")


func _process(delta: float) -> void:
	match current_state:
		State.RESET_WINDOW:
			_process_reset_window(delta)
		State.AIR_RESET_ACTIVE:
			_process_air_reset()

# ============================================================================
# RESET WINDOW (after Air-Combo ends)
# ============================================================================

func _on_air_combo_ended(final_count: int) -> void:
	"""Called when Air-Combo ends - opens reset window"""

	# Only open window if:
	# 1. Player performed at least 1 air hit
	# 2. Player is still airborne
	if final_count < 1:
		print("[LuftgottSystem] Air-Combo too short (< 1 hit) - no reset window")
		return

	if player.is_on_floor():
		print("[LuftgottSystem] Player on floor - no reset window")
		return

	# Get the last juggled enemy
	if air_combo_system.has_method("get_juggled_enemy"):
		reset_enemy = air_combo_system.get_juggled_enemy()

	# Open reset window
	current_state = State.RESET_WINDOW
	reset_window_timer = AIR_RESET_WINDOW
	last_air_combo_count = final_count

	print("[LuftgottSystem] Air Reset Window OPEN (%.1fs)" % AIR_RESET_WINDOW)

	air_reset_window_started.emit()
	if EventBus:
		EventBus.emit_signal("air_reset_window_started")


func _process_reset_window(delta: float) -> void:
	"""Processes reset window countdown"""

	reset_window_timer -= delta

	# Check for attack input during window
	if Input.is_action_just_pressed("light_attack"):
		# Must still be airborne
		if not player.is_on_floor():
			_activate_air_reset()
			return

	# Window expired
	if reset_window_timer <= 0.0:
		_close_reset_window()


func _close_reset_window() -> void:
	"""Closes reset window without activating"""

	print("[LuftgottSystem] Reset window closed (no activation)")

	current_state = State.IDLE
	reset_enemy = null
	reset_window_timer = 0.0

# ============================================================================
# AIR RESET ACTIVATION
# ============================================================================

func _activate_air_reset() -> void:
	"""Activates Air Reset mechanic"""

	# Validate enemy still exists
	if not reset_enemy or not is_instance_valid(reset_enemy):
		print("[LuftgottSystem] Reset enemy invalid - cannot activate")
		_close_reset_window()
		return

	# Check if enemy is in range
	const RESET_RANGE: float = 100.0
	var distance: float = player.global_position.distance_to(reset_enemy.global_position)
	if distance > RESET_RANGE:
		print("[LuftgottSystem] Enemy too far (%.1f > %.1f)" % [distance, RESET_RANGE])
		_close_reset_window()
		return

	print("[LuftgottSystem] AIR RESET ACTIVATED!")

	# Enter Air Reset state
	current_state = State.AIR_RESET_ACTIVE
	reset_combo_count = 0
	current_hitbox_scale = 1.0

	# Start hover for player
	_start_player_hover()

	# Start hover for enemy
	_start_enemy_hover(reset_enemy)

	# Spawn visual sphere
	_spawn_hover_sphere()

	# Emit signals
	air_reset_activated.emit(reset_enemy)
	if EventBus:
		EventBus.emit_signal("air_reset_activated", reset_enemy)


func _start_player_hover() -> void:
	"""Enables hover mode for player"""

	if movement_controller:
		movement_controller.is_hovering = true
		print("[LuftgottSystem] Player hover enabled")


func _start_enemy_hover(enemy: Node) -> void:
	"""Enables hover mode for enemy"""

	if not enemy:
		return

	# Suspend enemy gravity
	if enemy.get("gravity_scale") != null:
		enemy.gravity_scale = HOVER_GRAVITY_SCALE
		print("[LuftgottSystem] Enemy %s gravity suspended" % enemy.name)

	# Stop enemy vertical movement
	if enemy is CharacterBody2D:
		enemy.velocity.y = 0.0

# ============================================================================
# AIR RESET COMBO
# ============================================================================

func _process_air_reset() -> void:
	"""Processes Air Reset combo state"""

	# Validate enemy
	if not reset_enemy or not is_instance_valid(reset_enemy):
		print("[LuftgottSystem] Enemy lost - ending air reset")
		_end_air_reset()
		return

	# Check if player touched ground
	if player.is_on_floor():
		print("[LuftgottSystem] Player touched floor - ending air reset")
		_end_air_reset()
		return

	# Check for attack input
	if Input.is_action_just_pressed("light_attack"):
		# Check combo limit
		if reset_combo_count >= AIR_RESET_COMBO_LIMIT:
			print("[LuftgottSystem] Reset combo limit reached (%d)" % AIR_RESET_COMBO_LIMIT)
			_end_air_reset()
			return

		# Check if enemy in range (with accuracy decay)
		if _is_enemy_in_reset_range(reset_enemy):
			_perform_air_reset_hit()
		else:
			print("[LuftgottSystem] Enemy out of range (accuracy decay)")
			_end_air_reset()


func _is_enemy_in_reset_range(enemy: Node) -> bool:
	"""Checks if enemy is in range (with accuracy decay)"""

	const BASE_RANGE: float = 100.0
	var effective_range: float = BASE_RANGE * current_hitbox_scale

	var distance: float = player.global_position.distance_to(enemy.global_position)

	print("[LuftgottSystem] Range check: %.1f / %.1f (scale: %.2f)" % [
		distance,
		effective_range,
		current_hitbox_scale
	])

	return distance <= effective_range


func _perform_air_reset_hit() -> void:
	"""Performs an air reset hit with bonus damage"""

	reset_combo_count += 1

	# Calculate damage with boost
	var damage: int = int(AIR_RESET_HIT_DAMAGE * AIR_RESET_DAMAGE_BOOST)

	print("[LuftgottSystem] Air Reset Hit %d! Damage: %d" % [reset_combo_count, damage])

	# Apply juggle knockback (slight upward)
	var juggle_direction: Vector2 = Vector2(0, -200.0)
	if reset_enemy.has_node("KnockbackComponent"):
		var knockback: KnockbackComponent = reset_enemy.get_node("KnockbackComponent")
		knockback.apply_knockback(juggle_direction.normalized(), juggle_direction.length(), 0.2)

	# Deal damage
	if reset_enemy.has_node("HealthComponent"):
		var health_comp = reset_enemy.get_node("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage)

	# Play hit effect
	_play_reset_hit_effect()

	# Apply accuracy decay
	current_hitbox_scale *= HITBOX_SCALE_PER_HIT

	# Emit signals
	air_reset_hit.emit(reset_combo_count, damage)
	if EventBus:
		EventBus.emit_signal("air_reset_hit", reset_combo_count, damage)

	# Check if limit reached
	if reset_combo_count >= AIR_RESET_COMBO_LIMIT:
		print("[LuftgottSystem] Max hits reached - ending air reset")
		await get_tree().create_timer(0.1).timeout
		_end_air_reset()


func _play_reset_hit_effect() -> void:
	"""Plays visual/audio effects for air reset hit"""

	# Play sound (higher pitched than normal air hit)
	AudioManager.play_sfx_at_position("combat/air_hit", player.global_position, 0.6)

	# Flash sphere
	if hover_sphere:
		_flash_sphere()

# ============================================================================
# AIR RESET END
# ============================================================================

func _end_air_reset() -> void:
	"""Ends Air Reset and restores gravity"""

	print("[LuftgottSystem] Air Reset ended (%d hits)" % reset_combo_count)

	var final_hits: int = reset_combo_count

	# Restore player gravity
	if movement_controller:
		movement_controller.is_hovering = false
		print("[LuftgottSystem] Player gravity restored")

	# Restore enemy gravity
	if reset_enemy and is_instance_valid(reset_enemy):
		if reset_enemy.get("gravity_scale") != null:
			# Restore original gravity (assuming 1.0)
			reset_enemy.gravity_scale = 1.0
			print("[LuftgottSystem] Enemy gravity restored")

	# Remove visual sphere
	_remove_hover_sphere()

	# Reset state
	current_state = State.IDLE
	reset_enemy = null
	reset_combo_count = 0
	current_hitbox_scale = 1.0

	# Emit signals
	air_reset_ended.emit(final_hits)
	if EventBus:
		EventBus.emit_signal("air_reset_ended", final_hits)

# ============================================================================
# VISUAL SPHERE
# ============================================================================

func _spawn_hover_sphere() -> void:
	"""Spawns violette durchsichtige Sphere um Player"""

	# Create sphere as MeshInstance2D with purple color
	var sphere = MeshInstance2D.new()

	# Create circle mesh
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Generate circle vertices
	var vertices = PackedVector2Array()
	var colors = PackedColorArray()
	const SEGMENTS = 32
	const RADIUS = 60.0

	for i in range(SEGMENTS + 1):
		var angle = (i / float(SEGMENTS)) * TAU
		vertices.append(Vector2(cos(angle), sin(angle)) * RADIUS)
		# Purple color with transparency
		colors.append(Color(0.6, 0.2, 0.8, 0.3))  # Violett, 30% transparent

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	sphere.mesh = mesh

	# Add to player
	player.add_child(sphere)
	sphere.position = Vector2.ZERO
	sphere.z_index = -1  # Behind player

	hover_sphere = sphere

	# Pulsating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sphere, "scale", Vector2(1.1, 1.1), 0.5)
	tween.tween_property(sphere, "scale", Vector2(1.0, 1.0), 0.5)

	print("[LuftgottSystem] Hover sphere spawned (violett)")


func _flash_sphere() -> void:
	"""Flashes sphere on hit"""

	if not hover_sphere:
		return

	var tween = create_tween()
	tween.tween_property(hover_sphere, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	tween.tween_property(hover_sphere, "modulate", Color.WHITE, 0.1)


func _remove_hover_sphere() -> void:
	"""Removes visual sphere"""

	if hover_sphere and is_instance_valid(hover_sphere):
		hover_sphere.queue_free()
		hover_sphere = null
		print("[LuftgottSystem] Hover sphere removed")

# ============================================================================
# GETTERS
# ============================================================================

func is_active() -> bool:
	"""Returns true if Luftgott is in reset window or active"""
	return current_state in [State.RESET_WINDOW, State.AIR_RESET_ACTIVE]


func force_end() -> void:
	"""Forces Luftgott to end immediately (called when Wolkenbruch overrides)"""

	print("[LuftgottSystem] Force ending Luftgott (overridden by Wolkenbruch)")

	if current_state == State.AIR_RESET_ACTIVE:
		# End active air reset
		_end_air_reset()
	elif current_state == State.RESET_WINDOW:
		# Just cancel the window
		current_state = State.IDLE
		reset_window_timer = 0.0
		print("[LuftgottSystem] Reset window cancelled")


func is_in_reset_window() -> bool:
	"""Returns true if in reset window"""
	return current_state == State.RESET_WINDOW


func is_air_reset_active() -> bool:
	"""Returns true if air reset is active"""
	return current_state == State.AIR_RESET_ACTIVE


func get_reset_window_time() -> float:
	"""Returns remaining reset window time"""
	return reset_window_timer


func get_reset_combo_count() -> int:
	"""Returns current reset combo count"""
	return reset_combo_count

# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> Dictionary:
	"""Returns debug information"""
	return {
		"state": State.keys()[current_state],
		"window_time": reset_window_timer,
		"reset_combo": reset_combo_count,
		"hitbox_scale": current_hitbox_scale,
		"reset_enemy": reset_enemy.name if reset_enemy else "None"
	}
