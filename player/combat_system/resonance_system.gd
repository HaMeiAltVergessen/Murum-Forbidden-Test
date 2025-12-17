extends Node
## ResonanceSystem - Manages player resonance buildup and decay
## Resonance builds through combat and enables special abilities
class_name ResonanceSystem

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var max_resonance: float = 100.0
@export var gain_per_hit: float = 6.25  # +6.25 per enemy hit
@export var loss_on_damage: float = 15.0  # -15.0 when player takes damage
@export var decay_rate_idle: float = 4.0  # 4.0 per second when out of combat
@export var decay_rate_combat: float = 1.0  # 1.0 per second when in combat
@export var combat_timeout: float = 3.0  # Time before considered out of combat

# ============ STATE ============
var current_resonance: float = 0.0
var is_in_combat: bool = false
var last_combat_time: float = 0.0

# ============ SIGNALS ============
signal resonance_changed(current: float, maximum: float, percentage: float)
signal resonance_full()
signal resonance_depleted()
signal resonance_threshold_reached(threshold: int)  # 25, 50, 75, 100

# ============ THRESHOLDS ============
const THRESHOLDS: Array[int] = [25, 50, 75, 100]
var threshold_flags: Dictionary = {
	25: false,
	50: false,
	75: false,
	100: false
}


func _ready() -> void:
	if not enabled:
		return

	# Connect to EventBus signals
	if EventBus:
		EventBus.hit_registered.connect(_on_hit_registered)
		EventBus.player_damaged.connect(_on_player_damaged)
		EventBus.combat_started.connect(_on_combat_started)
		EventBus.combat_ended.connect(_on_combat_ended)

	print("[ResonanceSystem] Initialized - Max: %.1f" % max_resonance)


func _process(delta: float) -> void:
	if not enabled:
		return

	# Apply decay
	_apply_decay(delta)

	# Update combat state
	_update_combat_state(delta)


# ============ RESONANCE MANAGEMENT ============
func add_resonance(amount: float) -> void:
	"""Adds resonance and clamps to max."""
	if not enabled:
		return

	var old_value: float = current_resonance
	current_resonance = min(current_resonance + amount, max_resonance)

	# Check thresholds
	_check_thresholds(old_value, current_resonance)

	# Emit signals
	_emit_resonance_changed()

	# Check if full
	if current_resonance >= max_resonance and old_value < max_resonance:
		resonance_full.emit()
		print("[ResonanceSystem] RESONANCE FULL!")

	print("[ResonanceSystem] +%.2f resonance (%.1f/%.1f)" % [amount, current_resonance, max_resonance])


func remove_resonance(amount: float) -> void:
	"""Removes resonance and clamps to 0."""
	if not enabled:
		return

	var old_value: float = current_resonance
	current_resonance = max(current_resonance - amount, 0.0)

	# Reset threshold flags if we dropped below them
	_reset_thresholds_below(current_resonance)

	# Emit signals
	_emit_resonance_changed()

	# Check if depleted
	if current_resonance <= 0.0 and old_value > 0.0:
		resonance_depleted.emit()
		print("[ResonanceSystem] Resonance depleted")

	print("[ResonanceSystem] -%.2f resonance (%.1f/%.1f)" % [amount, current_resonance, max_resonance])


func set_resonance(amount: float) -> void:
	"""Sets resonance to a specific value."""
	var old_value: float = current_resonance
	current_resonance = clamp(amount, 0.0, max_resonance)

	# Check thresholds
	_check_thresholds(old_value, current_resonance)

	# Emit signals
	_emit_resonance_changed()


func reset_resonance() -> void:
	"""Resets resonance to 0."""
	current_resonance = 0.0
	_reset_all_thresholds()
	_emit_resonance_changed()
	print("[ResonanceSystem] Resonance reset")


# ============ DECAY SYSTEM ============
func _apply_decay(delta: float) -> void:
	"""Applies resonance decay based on combat state."""
	if current_resonance <= 0.0:
		return

	var decay_amount: float = 0.0

	if is_in_combat:
		decay_amount = decay_rate_combat * delta
	else:
		decay_amount = decay_rate_idle * delta

	if decay_amount > 0.0:
		remove_resonance(decay_amount)


# ============ COMBAT STATE ============
func _update_combat_state(delta: float) -> void:
	"""Updates combat state based on time since last action."""
	if not is_in_combat:
		return

	last_combat_time += delta

	if last_combat_time >= combat_timeout:
		_exit_combat()


func _enter_combat() -> void:
	"""Enters combat state."""
	if is_in_combat:
		return

	is_in_combat = true
	last_combat_time = 0.0
	print("[ResonanceSystem] Entered combat")


func _exit_combat() -> void:
	"""Exits combat state."""
	if not is_in_combat:
		return

	is_in_combat = false
	last_combat_time = 0.0
	print("[ResonanceSystem] Exited combat")


func _refresh_combat() -> void:
	"""Refreshes combat timer."""
	last_combat_time = 0.0
	if not is_in_combat:
		_enter_combat()


# ============ THRESHOLDS ============
func _check_thresholds(old_value: float, new_value: float) -> void:
	"""Checks if any thresholds were crossed."""
	for threshold in THRESHOLDS:
		if old_value < threshold and new_value >= threshold:
			if not threshold_flags[threshold]:
				threshold_flags[threshold] = true
				resonance_threshold_reached.emit(threshold)
				print("[ResonanceSystem] Threshold reached: %d%%" % threshold)


func _reset_thresholds_below(value: float) -> void:
	"""Resets threshold flags below the given value."""
	for threshold in THRESHOLDS:
		if value < threshold:
			threshold_flags[threshold] = false


func _reset_all_thresholds() -> void:
	"""Resets all threshold flags."""
	for threshold in THRESHOLDS:
		threshold_flags[threshold] = false


# ============ SIGNAL EMITTERS ============
func _emit_resonance_changed() -> void:
	"""Emits resonance_changed signal."""
	var percentage: float = (current_resonance / max_resonance) * 100.0
	resonance_changed.emit(current_resonance, max_resonance, percentage)


# ============ EVENT HANDLERS ============
func _on_hit_registered(attacker: Node, _target: Node, _damage: int) -> void:
	"""Called when any hit is registered."""
	# Only gain resonance for player attacks
	if attacker and attacker.is_in_group("player"):
		add_resonance(gain_per_hit)
		_refresh_combat()


func _on_player_damaged(_damage: int, _source: Node) -> void:
	"""Called when player takes damage."""
	remove_resonance(loss_on_damage)
	_refresh_combat()


func _on_combat_started() -> void:
	"""Called when combat starts globally."""
	_enter_combat()


func _on_combat_ended() -> void:
	"""Called when combat ends globally."""
	_exit_combat()


# ============ GETTERS ============
func get_current_resonance() -> float:
	"""Returns current resonance value."""
	return current_resonance


func get_max_resonance() -> float:
	"""Returns maximum resonance value."""
	return max_resonance


func get_resonance_percentage() -> float:
	"""Returns resonance as percentage (0-100)."""
	if max_resonance <= 0.0:
		return 0.0
	return (current_resonance / max_resonance) * 100.0


func get_resonance_normalized() -> float:
	"""Returns resonance as normalized value (0.0-1.0)."""
	if max_resonance <= 0.0:
		return 0.0
	return current_resonance / max_resonance


func is_resonance_full() -> bool:
	"""Returns true if resonance is at maximum."""
	return current_resonance >= max_resonance


func is_resonance_empty() -> bool:
	"""Returns true if resonance is at 0."""
	return current_resonance <= 0.0


func is_above_threshold(threshold: int) -> bool:
	"""Returns true if resonance is above the given threshold."""
	return get_resonance_percentage() >= threshold


# ============ CONTROL ============
func enable() -> void:
	"""Enables resonance system."""
	enabled = true
	print("[ResonanceSystem] Enabled")


func disable() -> void:
	"""Disables resonance system."""
	enabled = false
	print("[ResonanceSystem] Disabled")


# ============ DEBUG ============
func get_debug_info() -> Dictionary:
	"""Returns debug information."""
	return {
		"enabled": enabled,
		"current": current_resonance,
		"max": max_resonance,
		"percentage": get_resonance_percentage(),
		"in_combat": is_in_combat,
		"time_since_combat": last_combat_time,
		"thresholds": threshold_flags
	}


func print_debug_info() -> void:
	"""Prints debug information."""
	var info: Dictionary = get_debug_info()
	print("[ResonanceSystem] Debug Info:")
	for key in info:
		print("  %s: %s" % [key, str(info[key])])
