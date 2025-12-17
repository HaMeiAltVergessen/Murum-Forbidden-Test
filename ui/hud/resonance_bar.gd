extends Control
## ResonanceBar - Visual UI for resonance tracking
## Shows resonance level with dynamic color coding and animations
class_name ResonanceBar

# ============ REFERENCES ============
@onready var background: ColorRect = $Background
@onready var fill_container: Control = $FillContainer
@onready var fill: ColorRect = $FillContainer/Fill
@onready var percent_label: Label = $PercentLabel

# ============ STATE ============
var current_value: float = 0.0
var max_value: float = 100.0
var target_width: float = 0.0

# ============ COLORS ============
const COLOR_BASE: Color = Color(0.0, 1.0, 1.0)  # Cyan (#00FFFF)
const COLOR_LOW: Color = Color(0.0, 0.81, 0.82)  # Dark Turquoise (#00CED1)
const COLOR_MID: Color = Color(1.0, 1.0, 0.0)  # Yellow (#FFFF00)
const COLOR_HIGH: Color = Color(1.0, 0.65, 0.0)  # Orange (#FFA500)
const COLOR_FULL: Color = Color(1.0, 0.84, 0.0)  # Gold (#FFD700)

# ============ ANIMATION ============
var pulse_tween: Tween = null
var is_pulsing: bool = false


func _ready() -> void:
	_update_display()
	print("[ResonanceBar] Initialized")


func _process(_delta: float) -> void:
	# Smooth fill animation
	if fill.size.x != target_width:
		fill.size.x = lerp(fill.size.x, target_width, 0.2)


# ============ PUBLIC API ============
func set_resonance(current: float, maximum: float = 100.0) -> void:
	"""Sets the resonance value and updates display."""
	current_value = current
	max_value = maximum
	_update_display()


func animate_gain() -> void:
	"""Visual feedback for resonance gain."""
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(fill, "scale:y", 1.15, 0.1)
	tween.tween_property(fill, "scale:y", 1.0, 0.1)


func animate_loss() -> void:
	"""Visual feedback for resonance loss (damage)."""
	# Flash red
	var original_color: Color = fill.color
	fill.color = Color.RED

	await get_tree().create_timer(0.15).timeout

	fill.color = original_color


# ============ DISPLAY UPDATE ============
func _update_display() -> void:
	"""Updates the visual display of the bar."""
	# Calculate percentage
	var percent: float = current_value / max_value if max_value > 0.0 else 0.0
	percent = clamp(percent, 0.0, 1.0)

	# Update target width for smooth animation
	target_width = background.size.x * percent

	# Update color
	fill.color = _get_resonance_color(percent)

	# Update label
	percent_label.text = "%.0f%%" % (percent * 100.0)

	# Pulse effect if full
	if percent >= 1.0 and not is_pulsing:
		_start_pulse_effect()
	elif percent < 1.0 and is_pulsing:
		_stop_pulse_effect()


func _get_resonance_color(percent: float) -> Color:
	"""Returns color based on resonance percentage with smooth transitions."""
	if percent >= 1.0:
		return COLOR_FULL  # Gold
	elif percent >= 0.75:
		# Lerp between Orange and Gold
		var t: float = (percent - 0.75) / 0.25
		return COLOR_HIGH.lerp(COLOR_FULL, t)
	elif percent >= 0.5:
		# Lerp between Yellow and Orange
		var t: float = (percent - 0.5) / 0.25
		return COLOR_MID.lerp(COLOR_HIGH, t)
	elif percent >= 0.25:
		# Lerp between Dark Turquoise and Yellow
		var t: float = (percent - 0.25) / 0.25
		return COLOR_LOW.lerp(COLOR_MID, t)
	else:
		# Lerp between Cyan and Dark Turquoise
		var t: float = percent / 0.25
		return COLOR_BASE.lerp(COLOR_LOW, t)


# ============ ANIMATIONS ============
func _start_pulse_effect() -> void:
	"""Starts pulsing animation when resonance is full."""
	if is_pulsing:
		return

	is_pulsing = true

	# Kill existing pulse
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	# Create looping pulse
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)

	# Pulse scale
	pulse_tween.tween_property(fill, "scale:y", 1.1, 0.5)
	pulse_tween.tween_property(fill, "scale:y", 1.0, 0.5)


func _stop_pulse_effect() -> void:
	"""Stops pulsing animation."""
	if not is_pulsing:
		return

	is_pulsing = false

	# Kill pulse tween
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	# Reset scale
	fill.scale.y = 1.0


# ============ GETTERS ============
func get_current_value() -> float:
	"""Returns current resonance value."""
	return current_value


func get_percentage() -> float:
	"""Returns resonance as percentage (0-100)."""
	if max_value <= 0.0:
		return 0.0
	return (current_value / max_value) * 100.0


func is_full() -> bool:
	"""Returns true if resonance is at maximum."""
	return current_value >= max_value


# ============ MODE DISPLAY ============
func set_mode_active(active: bool, time_remaining: float = 0.0) -> void:
	"""Sets the mode active state and updates display."""
	if active:
		# Lock bar at 100%
		set_resonance(100.0, 100.0)
		fill.color = COLOR_FULL

		# Change label
		percent_label.text = "RESONANCE MODE"

		# Create countdown label if it doesn't exist
		if not has_node("CountdownLabel"):
			var countdown = Label.new()
			countdown.name = "CountdownLabel"
			countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			countdown.theme_override_font_sizes/font_size = 12
			countdown.position = Vector2(150, 2)
			add_child(countdown)

		var countdown = $CountdownLabel
		countdown.text = "%.0fs" % time_remaining

		# Start pulse animation
		_start_mode_pulse()
	else:
		# Reset to normal state
		percent_label.text = "0%"

		# Remove countdown label
		if has_node("CountdownLabel"):
			$CountdownLabel.queue_free()

		# Stop pulse
		_stop_mode_pulse()


func update_mode_timer(time_remaining: float) -> void:
	"""Updates the mode countdown timer."""
	if has_node("CountdownLabel"):
		$CountdownLabel.text = "%.0fs" % time_remaining


func _start_mode_pulse() -> void:
	"""Starts pulsing animation during mode."""
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)

	pulse_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.5)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)


func _stop_mode_pulse() -> void:
	"""Stops mode pulse animation."""
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	scale = Vector2(1.0, 1.0)
