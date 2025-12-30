extends Node
class_name Machtstoss

## Machtstoß (Charge-based Knockback Wave)
## Hold Key 1 to charge (3 stages)
## Release to unleash directional knockback wave + damage
## Only affects enemies in facing direction
## Auto-releases at max charge (6s)

# ============================================================================
# CONSTANTS
# ============================================================================

# Charge Stages (hold duration in seconds)
const STAGE_1_TIME: float = 0.0   # 0-2s
const STAGE_2_TIME: float = 2.0   # 2-4s
const STAGE_3_TIME: float = 4.0   # 4-6s
const MAX_CHARGE_TIME: float = 6.0  # Auto-release

# Stage 1 Parameters (0-2s)
const STAGE_1_RANGE: float = 200.0
const STAGE_1_DAMAGE: int = 20
const STAGE_1_MANA: int = 2

# Stage 2 Parameters (2-4s)
const STAGE_2_RANGE: float = 600.0
const STAGE_2_DAMAGE: int = 60
const STAGE_2_MANA: int = 6

# Stage 3 Parameters (4-6s)
const STAGE_3_RANGE: float = 800.0
const STAGE_3_DAMAGE: int = 80
const STAGE_3_MANA: int = 8

# Shared Parameters
const KNOCKBACK_FORCE: float = 450.0   # Knockback force applied
const KNOCKBACK_DURATION: float = 0.6  # How long enemies are pushed
const STAFF_RAISE_DURATION: float = 0.3  # How long staff is raised

# Cooldown
const COOLDOWN_DURATION: float = 3.0

# VFX
const WAVE_EXPANSION_TIME: float = 0.4  # Wave visual expansion
const SHOCKWAVE_HITSTOP: float = 0.08   # Brief hitstop on activation

# ============================================================================
# STATE
# ============================================================================

var is_on_cooldown: bool = false
var cooldown_timer: float = 0.0

# Charging state
var is_charging: bool = false
var charge_time: float = 0.0
var current_stage: int = 1  # 1, 2, or 3
var last_stage: int = 0  # Track stage changes for visual feedback

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
	# Start charging on Key 1 press OR RT + B (gamepad)
	if event.is_action_pressed("ability_1"):
		_start_charging()
	# Release charge on Key 1 release
	elif event.is_action_released("ability_1"):
		_release_charge()
	# Gamepad: RT + B
	elif event.is_action_pressed("dodge"):
		if _is_rt_pressed():
			_start_charging()
	elif event.is_action_released("dodge"):
		if is_charging:
			_release_charge()

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
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	# Update cooldown timer
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			_finish_cooldown()

	# Update charging
	if is_charging:
		charge_time += delta

		# Update stage based on charge time
		_update_charge_stage()

		# Auto-release at max charge (6 seconds)
		if charge_time >= MAX_CHARGE_TIME:
			print("[Machtstoß] Max charge reached (6s), auto-releasing!")
			_release_charge()

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
# CHARGING SYSTEM
# ============================================================================

func _start_charging() -> void:
	"""Starts charging Machtstoß"""

	# Check cooldown
	if is_on_cooldown:
		print("[Machtstoß] On cooldown (%.1fs remaining)" % cooldown_timer)
		return

	# Check mana (minimum mana for stage 1)
	if not mana_component:
		print("[Machtstoß] ERROR: ManaComponent not available!")
		return

	if not mana_component.has_mana(STAGE_1_MANA):
		print("[Machtstoß] Not enough mana (%d required, %d available)" % [STAGE_1_MANA, mana_component.current_mana])
		return

	# Start charging
	is_charging = true
	charge_time = 0.0
	current_stage = 1
	last_stage = 0

	print("[Machtstoß] ===== CHARGING STARTED =====")

func _update_charge_stage() -> void:
	"""Updates the current charge stage based on charge_time"""

	var new_stage = current_stage

	# Determine stage based on charge time
	if charge_time >= STAGE_3_TIME:
		new_stage = 3
	elif charge_time >= STAGE_2_TIME:
		new_stage = 2
	else:
		new_stage = 1

	# If stage changed, trigger visual feedback
	if new_stage != current_stage:
		current_stage = new_stage
		_on_stage_reached(current_stage)

func _on_stage_reached(stage: int) -> void:
	"""Called when a new charge stage is reached"""

	print("[Machtstoß] STAGE %d REACHED (%.1fs)" % [stage, charge_time])

	# Visual feedback: Flash player sprite
	_flash_player()

	# Get stage parameters for display
	var stage_params = _get_stage_parameters(stage)
	print("[Machtstoß]   -> Range: %.0fpx, Damage: %d, Mana: %d" % [
		stage_params.range,
		stage_params.damage,
		stage_params.mana
	])

func _release_charge() -> void:
	"""Releases the charged Machtstoß"""

	if not is_charging:
		return

	print("[Machtstoß] ===== RELEASED at Stage %d (%.1fs charge) =====" % [current_stage, charge_time])

	# Stop charging
	is_charging = false

	# Get parameters for current stage
	var stage_params = _get_stage_parameters(current_stage)

	# Check mana for current stage
	if not mana_component.has_mana(stage_params.mana):
		print("[Machtstoß] Not enough mana (%d required, %d available)" % [stage_params.mana, mana_component.current_mana])
		charge_time = 0.0
		return

	# Consume mana
	if not mana_component.use_mana(stage_params.mana):
		print("[Machtstoß] ERROR: Failed to consume mana!")
		charge_time = 0.0
		return

	print("[Machtstoß] Consumed %d mana" % stage_params.mana)

	# Visual: Raise staff in facing direction
	_raise_staff_visual()

	# Execute knockback wave with stage parameters
	_execute_knockback_wave(stage_params)

	# VFX
	_spawn_wave_vfx()

	# Audio
	AudioManager.play_sfx("player_machtstoss_activate", 0.1)

	# No camera shake - player should feel no knockback at all

	# Hitstop
	GlobalTimeEffects.hit_stop(SHOCKWAVE_HITSTOP)

	# Start cooldown
	_start_cooldown()

	# Emit signal
	machtstoss_activated.emit(player.global_position)
	EventBus.machtstoss_activated.emit(player.global_position)

	# Reset charge time
	charge_time = 0.0

func _get_stage_parameters(stage: int) -> Dictionary:
	"""Returns parameters for the given stage"""

	match stage:
		1:
			return {
				"range": STAGE_1_RANGE,
				"damage": STAGE_1_DAMAGE,
				"mana": STAGE_1_MANA
			}
		2:
			return {
				"range": STAGE_2_RANGE,
				"damage": STAGE_2_DAMAGE,
				"mana": STAGE_2_MANA
			}
		3:
			return {
				"range": STAGE_3_RANGE,
				"damage": STAGE_3_DAMAGE,
				"mana": STAGE_3_MANA
			}
		_:
			# Fallback to stage 1
			return {
				"range": STAGE_1_RANGE,
				"damage": STAGE_1_DAMAGE,
				"mana": STAGE_1_MANA
			}

func _flash_player() -> void:
	"""Flashes player sprite briefly when stage is reached"""

	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Create flash tween
	var tween = create_tween()

	# Flash white and back
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	print("[Machtstoß] Player flash!")

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

func _execute_knockback_wave(stage_params: Dictionary) -> void:
	"""Executes the knockback wave - pushes enemies on facing side only + deals damage"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	# Get player's facing direction from MovementController (1 = right, -1 = left)
	var player_facing = 1  # Default to right
	if movement_controller and movement_controller.has_method("get_facing_direction"):
		player_facing = movement_controller.get_facing_direction()

	var knockback_range = stage_params.range
	var damage = stage_params.damage

	print("[Machtstoß] Stage %d wave (%.0fpx range, %d damage, facing: %s)" % [
		current_stage,
		knockback_range,
		damage,
		"RIGHT" if player_facing > 0 else "LEFT"
	])

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance > knockback_range:
			continue

		# CRITICAL: Only affect enemies on the facing side
		var direction_to_enemy = enemy.global_position - player.global_position

		# If player faces right (1), enemy must be on right (x > 0)
		# If player faces left (-1), enemy must be on left (x < 0)
		if player_facing > 0 and direction_to_enemy.x < 0:
			continue  # Enemy is on left side, skip
		if player_facing < 0 and direction_to_enemy.x > 0:
			continue  # Enemy is on right side, skip

		# Enemy is on correct side, apply knockback + damage
		_apply_knockback(enemy, distance, damage)
		hit_count += 1

	print("[Machtstoß] Hit %d enemies on %s side" % [hit_count, "RIGHT" if player_facing > 0 else "LEFT"])

func _apply_knockback(enemy: Node, distance: float, damage: int) -> void:
	"""Applies knockback + damage to a single enemy"""

	# Calculate knockback direction (away from player)
	var direction_to_enemy = enemy.global_position - player.global_position

	# CRITICAL: Prevent NaN from normalizing zero vector
	var direction: Vector2
	if direction_to_enemy.length_squared() < 0.01:
		direction = Vector2(1, 0)  # Default to right if at same position
		print("[Machtstoß] WARNING: Enemy at same position, using default direction")
	else:
		direction = direction_to_enemy.normalized()

	print("[Machtstoß] Hitting %s (dist: %.1f, force: %.0f, damage: %d)" % [enemy.name, distance, KNOCKBACK_FORCE, damage])

	# Deal damage first
	_deal_damage_to_enemy(enemy, damage)

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

func _deal_damage_to_enemy(enemy: Node, damage: int) -> void:
	"""Deals damage to an enemy"""

	# Try to damage enemy using its take_damage method
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, player)
		print("[Machtstoß]   -> Damaged %s for %d (direct method)" % [enemy.name, damage])
		return

	# Fallback: Use HealthComponent
	if enemy.has_node("HealthComponent"):
		var health = enemy.get_node("HealthComponent")
		if health and health.has_method("take_damage"):
			health.take_damage(damage)
			print("[Machtstoß]   -> Damaged %s for %d (HealthComponent)" % [enemy.name, damage])
			return

	print("[Machtstoß]   -> WARNING: Could not damage %s (no damage method)" % enemy.name)

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _raise_staff_visual() -> void:
	"""Raises staff in facing direction as visual feedback"""

	# Get player sprite
	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Get facing direction
	var player_facing = 1  # Default to right
	if movement_controller and movement_controller.has_method("get_facing_direction"):
		player_facing = movement_controller.get_facing_direction()

	print("[Machtstoß] Raising staff %s" % ("RIGHT" if player_facing > 0 else "LEFT"))

	# Create tween for staff raise animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# Raise staff to the side (left or right based on facing)
	# Positive X = right, Negative X = left
	var staff_offset_x = 30.0 * player_facing  # 30 pixels to the side
	var staff_offset_y = -40.0  # 40 pixels up

	# Animate: raise staff
	tween.tween_property(sprite, "position", Vector2(staff_offset_x, staff_offset_y), STAFF_RAISE_DURATION * 0.4)
	# Hold briefly
	tween.tween_interval(STAFF_RAISE_DURATION * 0.2)
	# Return to normal
	tween.tween_property(sprite, "position", Vector2.ZERO, STAFF_RAISE_DURATION * 0.4)

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
