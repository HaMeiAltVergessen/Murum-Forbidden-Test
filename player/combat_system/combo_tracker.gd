extends Node
## ComboTracker - Tracks player combo state locally
## Works in conjunction with CombatManager for combo mechanics
class_name ComboTracker

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var max_combo_display: int = 999  # Maximum combo to display

# ============ STATE ============
var current_combo: int = 0
var combo_multiplier: float = 1.0
var time_remaining: float = 0.0
var is_active: bool = false

# ============ VISUAL FEEDBACK ============
var combo_color: Color = Color.WHITE
var shake_intensity: float = 0.0

# ============ SIGNALS ============
signal combo_updated(count: int, multiplier: float, time_remaining: float)
signal combo_started(count: int)
signal combo_ended(final_count: int)
signal combo_milestone_reached(count: int)  # For special combo milestones

# ============ COMBO MILESTONES ============
const MILESTONE_THRESHOLDS: Array[int] = [5, 10, 25, 50, 100]


func _ready() -> void:
	if not enabled:
		return

	# Connect to CombatManager signals
	if CombatManager:
		CombatManager.combo_increased.connect(_on_combo_increased)
		CombatManager.combo_broken.connect(_on_combo_broken)
		CombatManager.damage_calculated.connect(_on_damage_calculated)

	print("[ComboTracker] Initialized and connected to CombatManager")


func _process(delta: float) -> void:
	if not enabled or not is_active:
		return

	# Update time remaining display
	if CombatManager:
		time_remaining = CombatManager.get_combo_time_remaining()

		# Update UI
		combo_updated.emit(current_combo, combo_multiplier, time_remaining)

		# Update visual intensity based on combo
		_update_visual_feedback()


# ============ COMBO TRACKING ============
func _on_combo_increased(new_count: int, multiplier: float) -> void:
	"""Called when CombatManager increases combo."""
	var was_inactive: bool = not is_active

	# Update state
	current_combo = new_count
	combo_multiplier = multiplier
	is_active = true

	# Check for milestones
	_check_milestone(new_count)

	# Emit signals
	if was_inactive:
		combo_started.emit(new_count)

	combo_updated.emit(current_combo, combo_multiplier, time_remaining)

	# Update visual feedback
	_update_visual_feedback()


func _on_combo_broken(final_count: int) -> void:
	"""Called when combo chain breaks."""
	if not is_active:
		return

	# Store final count for signal
	var ended_count: int = current_combo

	# Reset state
	current_combo = 0
	combo_multiplier = 1.0
	time_remaining = 0.0
	is_active = false

	# Emit signal
	combo_ended.emit(ended_count)

	print("[ComboTracker] Combo ended at %d hits" % ended_count)


func _on_damage_calculated(final_damage: int, had_combo: bool) -> void:
	"""Called when damage is calculated with combo."""
	# This can be used for additional feedback if needed
	pass


# ============ VISUAL FEEDBACK ============
func _update_visual_feedback() -> void:
	"""Updates visual feedback values based on combo count."""
	# Calculate shake intensity (for screen shake)
	shake_intensity = min(current_combo * 0.02, 1.0)  # 2% per hit, max 1.0

	# Calculate combo color
	combo_color = _get_combo_color()


func _get_combo_color() -> Color:
	"""Returns color based on combo count."""
	if current_combo < 5:
		return Color.WHITE  # 1-4 hits: white
	elif current_combo < 10:
		return Color(1.0, 1.0, 0.0)  # 5-9 hits: yellow
	elif current_combo < 20:
		return Color(1.0, 0.6, 0.0)  # 10-19 hits: orange
	else:
		return Color(1.0, 0.2, 0.2)  # 20+ hits: red


# ============ MILESTONES ============
func _check_milestone(count: int) -> void:
	"""Checks if a combo milestone has been reached."""
	for threshold in MILESTONE_THRESHOLDS:
		if count == threshold:
			combo_milestone_reached.emit(count)
			print("[ComboTracker] Milestone reached: %d hits!" % count)
			break


# ============ GETTERS ============
func get_combo_count() -> int:
	"""Returns current combo count."""
	return current_combo


func get_combo_multiplier() -> float:
	"""Returns current damage multiplier."""
	return combo_multiplier


func get_time_remaining() -> float:
	"""Returns time remaining before combo breaks."""
	return time_remaining


func get_combo_progress() -> float:
	"""Returns combo timer progress as 0.0-1.0."""
	if CombatManager:
		return CombatManager.get_combo_progress()
	return 0.0


func get_combo_color() -> Color:
	"""Returns current combo color for UI."""
	return combo_color


func get_shake_intensity() -> float:
	"""Returns screen shake intensity for camera."""
	return shake_intensity


func is_combo_active() -> bool:
	"""Returns true if combo is currently active."""
	return is_active


func is_max_combo() -> bool:
	"""Returns true if at maximum combo multiplier."""
	if CombatManager:
		return CombatManager.is_combo_max()
	return false


# ============ CONTROL ============
func enable() -> void:
	"""Enables combo tracking."""
	enabled = true
	print("[ComboTracker] Enabled")


func disable() -> void:
	"""Disables combo tracking."""
	enabled = false
	is_active = false
	current_combo = 0
	print("[ComboTracker] Disabled")


func force_break_combo() -> void:
	"""Manually breaks the combo (debug/special cases)."""
	if CombatManager:
		CombatManager.break_combo()


# ============ DEBUG ============
func get_debug_info() -> Dictionary:
	"""Returns debug information about combo state."""
	return {
		"enabled": enabled,
		"active": is_active,
		"count": current_combo,
		"multiplier": combo_multiplier,
		"time_remaining": time_remaining,
		"color": combo_color,
		"shake_intensity": shake_intensity
	}


func print_debug_info() -> void:
	"""Prints debug information to console."""
	var info: Dictionary = get_debug_info()
	print("[ComboTracker] Debug Info:")
	for key in info:
		print("  %s: %s" % [key, str(info[key])])
