extends Node
## CombatManager - Centralized damage calculation and combo tracking system
## Singleton that manages all combat-related calculations and combo mechanics

# ============ COMBO CONFIGURATION ============
@export var combo_timeout: float = 1.5  # Time in seconds before combo breaks
@export var combo_multiplier_per_hit: float = 0.05  # 5% damage increase per hit
@export var max_combo_multiplier: float = 1.8  # Maximum 1.8× damage (16 hits)

# ============ HITSTOP CONFIGURATION ============
@export var hitstop_duration_normal: float = 0.05  # Normal hit freeze
@export var hitstop_duration_heavy: float = 0.12  # Heavy hit freeze
@export var hitstop_combo_threshold: int = 10  # Combo count for heavy hitstop

# ============ FINISHER CONFIGURATION ============
const FINISHER_HITSTOP_DURATION: float = 0.15  # 3× normal hitstop
const FINISHER_KNOCKBACK_FORCE: float = 300.0  # Pixels
const FINISHER_KNOCKBACK_DURATION: float = 0.3  # Seconds
const FINISHER_CAMERA_TRAUMA: float = 0.35  # vs normal 0.15
const FINISHER_VFX_SCALE: float = 1.8  # Bigger particles
const FINISHER_SFX_PITCH: float = 0.85  # Lower pitch = heavier

# ============ COMBO STATE ============
var combo_count: int = 0
var combo_timer: float = 0.0
var is_combo_active: bool = false

# ============ COMBAT STATE ============
var active_enemies: Array[Node] = []
var time_since_last_combat_action: float = 0.0
const COMBAT_TIMEOUT: float = 3.0

# ============ SIGNALS ============
signal combo_increased(new_count: int, multiplier: float)
signal combo_broken(final_count: int)
signal damage_calculated(final_damage: int, had_combo: bool)
signal hitstop_triggered(duration: float)

# ============ CONSTANTS ============
const COMBO_MULTIPLIER_PER_HIT: float = 0.05
const MAX_COMBO_MULTIPLIER: float = 1.8


func _ready() -> void:
	print("[CombatManager] Initialized - Combo system active")

	# Connect to EventBus signals
	if EventBus:
		EventBus.hit_registered.connect(_on_hit_registered)
		EventBus.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_update_combo_timer(delta)
	_update_combat_state(delta)


# ============ DAMAGE CALCULATION ============
func calculate_damage(base_damage: int, attacker: Node, target: Node) -> int:
	"""
	Calculates final damage with combo multiplier applied.

	Args:
		base_damage: The base damage value before multipliers
		attacker: The attacking entity (used to check if player)
		target: The target entity

	Returns:
		Final damage as integer (rounded)
	"""
	var final_damage: float = base_damage
	var had_combo: bool = false

	# Apply combo multiplier only for player attacks
	if attacker and attacker.is_in_group("player"):
		if combo_count > 0:
			var combo_multiplier: float = get_combo_multiplier()
			final_damage *= combo_multiplier
			had_combo = true

			# Check for finisher
			var combo_tracker = attacker.get_node_or_null("CombatSystem/ComboTracker")
			if combo_tracker and combo_tracker.is_finisher_hit():
				var finisher_mult = combo_tracker.get_finisher_multiplier()
				final_damage *= finisher_mult

				# Apply finisher knockback to target
				_apply_finisher_knockback(attacker, target)

				# Enhanced effects
				_play_finisher_effects(attacker, target)

				# Execute finisher
				combo_tracker.execute_finisher(int(round(final_damage)))

				print("[CombatManager] FINISHER! Damage: %d × %.2f × %.2f = %.1f (Combo: %d)" % [
					base_damage,
					combo_multiplier,
					finisher_mult,
					final_damage,
					combo_count
				])
			else:
				print("[CombatManager] Damage: %d × %.2f = %.1f (Combo: %d)" % [
					base_damage,
					combo_multiplier,
					final_damage,
					combo_count
				])

		# Apply resonance mode damage bonus
		var resonance = attacker.get_node_or_null("CombatSystem/ResonanceSystem")
		if resonance and resonance.is_mode_active():
			final_damage *= resonance.DAMAGE_BONUS
			print("[CombatManager] Resonance Mode: %.1f × %.2f = %.1f" % [
				final_damage / resonance.DAMAGE_BONUS,
				resonance.DAMAGE_BONUS,
				final_damage
			])

	# Round to integer
	final_damage = round(final_damage)

	# Emit signal
	damage_calculated.emit(int(final_damage), had_combo)

	return int(final_damage)


func get_combo_multiplier() -> float:
	"""
	Returns the current combo damage multiplier.
	Formula: 1.0 + (combo_count × 0.05), capped at 1.8×

	Returns:
		Multiplier value between 1.0 and 1.8
	"""
	if combo_count <= 0:
		return 1.0

	var multiplier: float = 1.0 + (combo_count * COMBO_MULTIPLIER_PER_HIT)
	return min(multiplier, MAX_COMBO_MULTIPLIER)


# ============ COMBO MANAGEMENT ============
func increase_combo() -> void:
	"""Increases the combo counter and resets the timeout timer."""
	combo_count += 1
	combo_timer = combo_timeout
	is_combo_active = true

	var multiplier: float = get_combo_multiplier()

	# Emit signal
	combo_increased.emit(combo_count, multiplier)
	EventBus.combo_increased.emit(combo_count, multiplier)

	print("[CombatManager] Combo: %d (×%.2f)" % [combo_count, multiplier])


func break_combo() -> void:
	"""Breaks the current combo chain."""
	if combo_count <= 0:
		return

	var final_count: int = combo_count

	# Reset state
	combo_count = 0
	combo_timer = 0.0
	is_combo_active = false

	# Emit signal
	combo_broken.emit(final_count)
	EventBus.combo_broken.emit(final_count)

	print("[CombatManager] Combo broken! Final count: %d" % final_count)


func reset_combo() -> void:
	"""Immediately resets combo without triggering break event."""
	combo_count = 0
	combo_timer = 0.0
	is_combo_active = false


func _update_combo_timer(delta: float) -> void:
	"""Updates the combo timeout timer."""
	if not is_combo_active:
		return

	if combo_timer > 0:
		combo_timer -= delta

		if combo_timer <= 0:
			break_combo()


# ============ HITSTOP SYSTEM ============
func trigger_hitstop(duration: float = -1.0) -> void:
	"""
	Triggers hitstop (freeze frame effect) via GlobalTimeEffects.

	Args:
		duration: Custom duration, or -1 to use combo-based duration
	"""
	# Determine duration based on combo if not specified
	var hitstop_duration: float = duration

	if duration < 0:
		if combo_count >= hitstop_combo_threshold:
			hitstop_duration = hitstop_duration_heavy
		else:
			hitstop_duration = hitstop_duration_normal

	# Use GlobalTimeEffects for hitstop (handles priority with slow motion)
	GlobalTimeEffects.hit_stop(hitstop_duration)

	# Emit signal
	hitstop_triggered.emit(hitstop_duration)

	print("[CombatManager] Hitstop: %.3fs" % hitstop_duration)


# ============ FINISHER EFFECTS ============
func _apply_finisher_knockback(attacker: Node, target: Node) -> void:
	"""Applies knockback to target on finisher"""

	# Get knockback component
	var knockback = target.get_node_or_null("KnockbackComponent")
	if not knockback:
		print("[CombatManager] Target has no KnockbackComponent")
		return

	# Calculate knockback direction (away from attacker)
	var direction = (target.global_position - attacker.global_position).normalized()

	# Apply knockback
	knockback.apply_knockback(direction, FINISHER_KNOCKBACK_FORCE, FINISHER_KNOCKBACK_DURATION)

	print("[CombatManager] Finisher knockback applied")

func _play_finisher_effects(attacker: Node, _target: Node) -> void:
	"""Plays enhanced VFX/SFX for finisher"""

	# Enhanced hitstop
	GlobalTimeEffects.hit_stop(FINISHER_HITSTOP_DURATION)

	# Enhanced camera shake
	if attacker.has_node("PlayerCamera"):
		var camera = attacker.get_node("PlayerCamera")
		if camera.has_method("add_trauma"):
			camera.add_trauma(FINISHER_CAMERA_TRAUMA)

	# Enhanced SFX (placeholder - will use proper sound when available)
	# AudioManager.play_sfx("attack_3", ...) - Removed due to crashes

	print("[CombatManager] Finisher effects played")


# ============ COMBAT STATE MANAGEMENT ============
func is_in_combat() -> bool:
	"""Returns true if player is in active combat."""
	if active_enemies.size() > 0:
		return true

	if time_since_last_combat_action < COMBAT_TIMEOUT:
		return true

	return false


func register_enemy(enemy: Node) -> void:
	"""Registers an active enemy in combat."""
	if enemy not in active_enemies:
		active_enemies.append(enemy)
		if active_enemies.size() == 1:
			EventBus.combat_started.emit()
			print("[CombatManager] Combat started")


func unregister_enemy(enemy: Node) -> void:
	"""Removes an enemy from combat tracking."""
	if enemy in active_enemies:
		active_enemies.erase(enemy)
		if active_enemies.size() == 0:
			print("[CombatManager] All enemies defeated")


func register_combat_action() -> void:
	"""Updates last combat action timestamp."""
	time_since_last_combat_action = 0.0


func _update_combat_state(delta: float) -> void:
	"""Updates combat state based on time since last action."""
	time_since_last_combat_action += delta

	# Check if combat should end
	if active_enemies.size() == 0 and time_since_last_combat_action >= COMBAT_TIMEOUT:
		if time_since_last_combat_action - delta < COMBAT_TIMEOUT:
			EventBus.combat_ended.emit()
			print("[CombatManager] Combat ended (timeout)")


# ============ EVENT HANDLERS ============
func _on_hit_registered(attacker: Node, _target: Node, _damage: int) -> void:
	"""Called when any hit is registered via EventBus."""
	# Register combat action
	register_combat_action()

	# Only track combo for player attacks
	if attacker and attacker.is_in_group("player"):
		increase_combo()
		trigger_hitstop()


func _on_player_damaged(_damage: int, _source: Node) -> void:
	"""Called when player takes damage - breaks combo."""
	break_combo()


# ============ GETTERS ============
func get_combo_count() -> int:
	"""Returns the current combo count."""
	return combo_count


func get_combo_time_remaining() -> float:
	"""Returns time remaining before combo breaks."""
	return max(0.0, combo_timer)


func get_combo_progress() -> float:
	"""Returns combo timer progress as 0.0-1.0."""
	if combo_timeout <= 0:
		return 0.0
	return combo_timer / combo_timeout


func is_combo_max() -> bool:
	"""Returns true if combo has reached max multiplier."""
	return get_combo_multiplier() >= MAX_COMBO_MULTIPLIER


# ============ DEBUG ============
func _input(event: InputEvent) -> void:
	# Debug: Press F1 to manually break combo
	if event.is_action_pressed("ui_text_backspace"):
		if combo_count > 0:
			print("[CombatManager] DEBUG: Manual combo break")
			break_combo()
