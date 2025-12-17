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

# ============ COMBO STATE ============
var combo_count: int = 0
var combo_timer: float = 0.0
var is_combo_active: bool = false

# ============ HITSTOP STATE ============
var is_hitstop_active: bool = false
var hitstop_timer: float = 0.0

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
	_update_hitstop(delta)


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

			print("[CombatManager] Damage: %d × %.2f = %.1f (Combo: %d)" % [
				base_damage,
				combo_multiplier,
				final_damage,
				combo_count
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
	Triggers hitstop (freeze frame effect).

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

	# Activate hitstop
	is_hitstop_active = true
	hitstop_timer = hitstop_duration
	Engine.time_scale = 0.0

	# Emit signal
	hitstop_triggered.emit(hitstop_duration)

	print("[CombatManager] Hitstop: %.3fs" % hitstop_duration)


func _update_hitstop(delta: float) -> void:
	"""Updates hitstop timer and restores time scale."""
	if not is_hitstop_active:
		return

	# Use unscaled delta time for hitstop timer
	hitstop_timer -= get_process_delta_time()

	if hitstop_timer <= 0:
		_end_hitstop()


func _end_hitstop() -> void:
	"""Ends hitstop effect and restores normal time."""
	is_hitstop_active = false
	hitstop_timer = 0.0
	Engine.time_scale = 1.0


# ============ EVENT HANDLERS ============
func _on_hit_registered(attacker: Node, target: Node, damage: int) -> void:
	"""Called when any hit is registered via EventBus."""
	# Only track combo for player attacks
	if attacker and attacker.is_in_group("player"):
		increase_combo()
		trigger_hitstop()


func _on_player_damaged(damage: int, source: Node) -> void:
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
