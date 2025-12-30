extends Node
class_name Machtstoss

## Machtstoß (Knockback Wave)
## Press Key 1 to release a directional knockback wave
## Pure CC ability - no damage, only knockback
## Only affects enemies in facing direction
## Costs 20 mana, 3s cooldown

# ============================================================================
# CONSTANTS
# ============================================================================

# Ability Parameters
const KNOCKBACK_RADIUS: float = 180.0  # Detection radius
const KNOCKBACK_FORCE: float = 450.0   # Knockback force applied
const KNOCKBACK_DURATION: float = 0.6  # How long enemies are pushed

# Resource Costs
const MANA_COST: int = 20
const COOLDOWN_DURATION: float = 3.0  # Reduced from 8.0

# VFX
const WAVE_EXPANSION_TIME: float = 0.4  # Wave visual expansion
const SHOCKWAVE_HITSTOP: float = 0.08   # Brief hitstop on activation

# ============================================================================
# STATE
# ============================================================================

var is_on_cooldown: bool = false
var cooldown_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var mana_component: Node = null
var movement_controller: Node = null

# ============================================================================
# SIGNALS
# ============================================================================

signal machtstoss_activated(position: Vector2)
signal machtstoss_hit_enemy(enemy: Node)
signal machtstoss_cooldown_started(duration: float)
signal machtstoss_cooldown_finished()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D

	# Fallback
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[Machtstoß] ERROR: Could not find player reference!")
		return

	# Get movement controller for facing direction
	movement_controller = player.get_node_or_null("MovementController")

	# Get mana component
	mana_component = player.get_node_or_null("ManaComponent")
	if not mana_component:
		print("[Machtstoß] WARNING: ManaComponent not found!")

	print("[Machtstoß] Initialized (Knockback Wave)")

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Activate on Key 1 press OR RT + B (gamepad)
	if event.is_action_pressed("ability_1"):
		attempt_activation()
	# Gamepad: RT + B (check both button and analog trigger)
	elif event.is_action_pressed("dodge"):
		if _is_rt_pressed():
			attempt_activation()

func _is_rt_pressed() -> bool:
	"""Check if RT is pressed (either as button or analog trigger)"""
	# Button 7 (some controllers)
	if Input.is_action_pressed("gamepad_modifier"):
		return true
	# Axis 5 (analog trigger on Xbox/PS controllers)
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		return true
	return false

# ============================================================================
# COOLDOWN
# ============================================================================

func _process(delta: float) -> void:
	# Update cooldown timer
	if is_on_cooldown:
		cooldown_timer -= delta

		if cooldown_timer <= 0.0:
			_finish_cooldown()

func _start_cooldown() -> void:
	"""Starts the cooldown timer"""
	is_on_cooldown = true
	cooldown_timer = COOLDOWN_DURATION

	print("[Machtstoß] Cooldown started (%.1fs)" % COOLDOWN_DURATION)

	# Emit signals
	machtstoss_cooldown_started.emit(COOLDOWN_DURATION)
	EventBus.machtstoss_cooldown_started.emit(COOLDOWN_DURATION)

func _finish_cooldown() -> void:
	"""Finishes the cooldown"""
	is_on_cooldown = false
	cooldown_timer = 0.0

	print("[Machtstoß] Cooldown finished - Ready!")

	# Emit signals
	machtstoss_cooldown_finished.emit()
	EventBus.machtstoss_cooldown_finished.emit()

# ============================================================================
# ACTIVATION
# ============================================================================

func attempt_activation() -> bool:
	"""Attempts to activate Machtstoß. Returns true if successful."""

	# Check cooldown
	if is_on_cooldown:
		print("[Machtstoß] On cooldown (%.1fs remaining)" % cooldown_timer)
		return false

	# Check mana
	if not mana_component:
		print("[Machtstoß] ERROR: ManaComponent not available!")
		return false

	if not mana_component.has_mana(MANA_COST):
		print("[Machtstoß] Not enough mana (%d required, %d available)" % [MANA_COST, mana_component.current_mana])
		return false

	# All checks passed - activate!
	_activate()
	return true

func _activate() -> void:
	"""Activates the Machtstoß knockback wave"""
	print("[Machtstoß] ===== ACTIVATED =====")

	# Consume mana
	if not mana_component.use_mana(MANA_COST):
		print("[Machtstoß] ERROR: Failed to consume mana!")
		return

	print("[Machtstoß] Consumed %d mana" % MANA_COST)

	# Execute knockback wave
	_execute_knockback_wave()

	# VFX
	_spawn_wave_vfx()

	# Audio
	AudioManager.play_sfx("player_machtstoss_activate", 0.1)

	# No camera shake - player should feel no knockback at all
	# Only enemies are affected by the knockback wave

	# Hitstop
	GlobalTimeEffects.hit_stop(SHOCKWAVE_HITSTOP)

	# Start cooldown
	_start_cooldown()

	# Emit signal
	machtstoss_activated.emit(player.global_position)
	EventBus.machtstoss_activated.emit(player.global_position)

# ============================================================================
# KNOCKBACK WAVE
# ============================================================================

func _execute_knockback_wave() -> void:
	"""Executes the knockback wave - pushes ALL enemies in radius"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	print("[Machtstoß] Searching for enemies in %.0fpx radius (ALL directions)..." % KNOCKBACK_RADIUS)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance > KNOCKBACK_RADIUS:
			continue

		# Apply knockback to ALL enemies in radius (no directional filtering)
		_apply_knockback(enemy, distance)
		hit_count += 1

	print("[Machtstoß] Hit %d enemies with omnidirectional knockback wave" % hit_count)

func _apply_knockback(enemy: Node, distance: float) -> void:
	"""Applies knockback to a single enemy"""

	# Calculate knockback direction (away from player)
	var direction_to_enemy = enemy.global_position - player.global_position

	# CRITICAL: Prevent NaN from normalizing zero vector
	var direction: Vector2
	if direction_to_enemy.length_squared() < 0.01:
		direction = Vector2(1, 0)  # Default to right if at same position
		print("[Machtstoß] WARNING: Enemy at same position, using default direction")
	else:
		direction = direction_to_enemy.normalized()

	print("[Machtstoß] Knocking back %s (dist: %.1f, force: %.0f)" % [enemy.name, distance, KNOCKBACK_FORCE])

	# Check for KnockbackComponent first
	var knockback_component = enemy.get_node_or_null("KnockbackComponent")
	if knockback_component and knockback_component.has_method("apply_knockback"):
		# Use KnockbackComponent (direction, force, duration)
		knockback_component.apply_knockback(direction, KNOCKBACK_FORCE, KNOCKBACK_DURATION)
	elif enemy.has_method("apply_knockback"):
		# Fallback: enemy has its own knockback method
		enemy.apply_knockback(direction, KNOCKBACK_FORCE, KNOCKBACK_DURATION)
	elif enemy is CharacterBody2D:
		# Fallback: directly modify velocity
		var knockback_vector = direction * KNOCKBACK_FORCE
		_apply_knockback_direct(enemy, knockback_vector)
	else:
		print("[Machtstoß] WARNING: Cannot apply knockback to %s" % enemy.name)
		return

	# Spawn hit VFX on enemy
	_spawn_hit_vfx(enemy)

	# Emit signal
	machtstoss_hit_enemy.emit(enemy)
	EventBus.machtstoss_hit_enemy.emit(enemy)

func _apply_knockback_direct(enemy: CharacterBody2D, knockback_vector: Vector2) -> void:
	"""Fallback method to apply knockback by directly modifying velocity"""

	# Create a tween for smooth knockback
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# Apply knockback over duration
	var original_velocity = enemy.velocity if enemy.velocity else Vector2.ZERO

	# Set initial knockback velocity
	enemy.velocity = knockback_vector

	# Gradually reduce to zero
	tween.tween_property(enemy, "velocity", Vector2.ZERO, KNOCKBACK_DURATION)

# ============================================================================
# VFX
# ============================================================================

func _spawn_wave_vfx() -> void:
	"""Spawns the expanding wave visual effect"""

	var vfx_path = "res://vfx/particles/machtstoss_wave.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Machtstoß] Wave VFX not found: %s" % vfx_path)
		return

	var wave_scene = load(vfx_path)
	var wave = wave_scene.instantiate()
	get_tree().root.add_child(wave)
	wave.global_position = player.global_position
	wave.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(2.0).timeout
	if wave:
		wave.queue_free()

func _spawn_hit_vfx(enemy: Node) -> void:
	"""Spawns hit effect on knocked-back enemy"""

	var vfx_path = "res://vfx/particles/machtstoss_hit.tscn"

	if not ResourceLoader.exists(vfx_path):
		# Silently skip if VFX not found
		return

	var hit_scene = load(vfx_path)
	var hit = hit_scene.instantiate()
	get_tree().root.add_child(hit)
	hit.global_position = enemy.global_position
	hit.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if hit:
		hit.queue_free()

# ============================================================================
# UTILITY
# ============================================================================

func is_available() -> bool:
	"""Returns true if Machtstoß can be activated"""
	if is_on_cooldown:
		return false

	if not mana_component:
		return false

	return mana_component.has_mana(MANA_COST)

func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return cooldown_timer if is_on_cooldown else 0.0

func get_cooldown_percentage() -> float:
	"""Returns cooldown as percentage (0.0 = ready, 1.0 = just used)"""
	if not is_on_cooldown:
		return 0.0

	return cooldown_timer / COOLDOWN_DURATION
