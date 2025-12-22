extends Node
## ComboTracker - Tracks player combo state locally
## Works in conjunction with CombatManager for combo mechanics
class_name ComboTracker

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var max_combo_display: int = 999  # Maximum combo to display

# ============ FINISHER CONFIGURATION ============
const FINISHER_HIT_INDEX: int = 3  # Every 3rd hit
const FINISHER_DAMAGE_MULTIPLIER: float = 1.5  # ×1.5 base damage
const FINISHER_COMBO_BONUS: float = 1.2  # Extra combo multiplier

# ============ LEAP ENDER CONFIGURATION ============
const LEAP_INPUT_WINDOW: float = 0.5  # Window after 3rd hit to input leap ender
const LEAP_DAMAGE_MULTIPLIER: float = 1.3  # ×1.3 base damage (less than normal finisher)
const DIRECTION_HOLD_THRESHOLD: float = 0.1  # Min direction magnitude

# ============ STATE ============
var current_combo: int = 0
var combo_multiplier: float = 1.0
var time_remaining: float = 0.0
var is_active: bool = false

# ============ LEAP ENDER STATE ============
var leap_input_timer: float = 0.0
var is_leap_available: bool = false
var held_direction: Vector2 = Vector2.ZERO

# ============ VISUAL FEEDBACK ============
var combo_color: Color = Color.WHITE
var shake_intensity: float = 0.0

# ============ SIGNALS ============
signal combo_updated(count: int, multiplier: float, time_remaining: float)
signal combo_started(count: int)
signal combo_ended(final_count: int)
signal combo_milestone_reached(count: int)  # For special combo milestones
signal combo_finisher_ready  # Next hit will be finisher
signal combo_finisher_executed(damage: int)  # Finisher was executed
signal leap_ender_available  # After 3rd hit, leap ender can be triggered
signal leap_ender_triggered(direction: Vector2)  # Leap ender was triggered

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

	# Update leap ender window timer
	if is_leap_available:
		leap_input_timer -= delta

		if leap_input_timer <= 0.0:
			is_leap_available = false
			print("[ComboTracker] Leap Ender window expired")


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

	# Check if next hit will be finisher
	if (new_count + 1) % FINISHER_HIT_INDEX == 0:
		combo_finisher_ready.emit()
		EventBus.combo_finisher_ready.emit()
		print("[ComboTracker] Next hit is FINISHER!")

	# Check if this hit WAS a finisher (3rd hit landed) - enable leap ender window
	if new_count % FINISHER_HIT_INDEX == 0:
		_enable_leap_ender_window()

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


# ============ FINISHER DETECTION ============
func is_finisher_hit() -> bool:
	"""Returns true if current hit is a finisher"""
	return current_combo > 0 and current_combo % FINISHER_HIT_INDEX == 0

func get_finisher_multiplier() -> float:
	"""Returns damage multiplier for finisher"""
	if is_finisher_hit():
		return FINISHER_DAMAGE_MULTIPLIER * FINISHER_COMBO_BONUS
	return 1.0

func execute_finisher(damage: int) -> void:
	"""Called when finisher is executed"""
	print("[ComboTracker] Finisher executed at combo %d (damage: %d)" % [current_combo, damage])

	# Emit signals
	combo_finisher_executed.emit(damage)
	EventBus.combo_finisher_executed.emit(current_combo)


# ============ LEAP ENDER DETECTION ============
func _enable_leap_ender_window() -> void:
	"""Opens window for leap ender input after 3rd hit"""
	is_leap_available = true
	leap_input_timer = LEAP_INPUT_WINDOW

	leap_ender_available.emit()
	EventBus.leap_ender_available.emit()
	print("[ComboTracker] Leap Ender available! (hold direction + attack)")


func check_leap_ender_input() -> bool:
	"""Checks if leap ender input is valid (returns true if can execute)"""

	if not is_leap_available:
		return false

	# Check if direction held
	held_direction = _get_held_direction()

	if held_direction.length() < DIRECTION_HOLD_THRESHOLD:
		return false  # No direction held

	return true


func _get_held_direction() -> Vector2:
	"""Returns currently held direction input"""
	# Only use horizontal direction for leap ender (left/right)
	var direction = Vector2(
		Input.get_axis("move_left", "move_right"),
		0.0  # Vertical movement not used for leap
	).normalized()

	return direction


func consume_leap_ender() -> Vector2:
	"""Consumes leap ender opportunity, returns held direction"""
	is_leap_available = false

	var direction = held_direction
	leap_ender_triggered.emit(direction)
	EventBus.leap_ender_triggered.emit(direction)

	print("[ComboTracker] Leap Ender consumed! Direction: %v" % direction)

	return direction


func get_leap_damage_multiplier() -> float:
	"""Returns damage multiplier for leap ender"""
	return LEAP_DAMAGE_MULTIPLIER

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
