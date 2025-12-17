extends Control
## ComboDisplay - Visual UI for combo counter and multiplier
## Shows combo count, multiplier, and timer with animations

# ============ REFERENCES ============
@onready var container: VBoxContainer = $Container
@onready var combo_label: Label = $Container/ComboLabel
@onready var multiplier_label: Label = $Container/MultiplierLabel
@onready var timer_bar: ProgressBar = $Container/TimerBar

# ============ CONFIGURATION ============
@export var pulse_scale: float = 1.15  # Scale increase during pulse
@export var pulse_duration: float = 0.15  # Duration of pulse animation
@export var fade_duration: float = 0.5  # Duration of fade out
@export var show_threshold: int = 1  # Minimum combo to show UI

# ============ STATE ============
var current_combo: int = 0
var current_multiplier: float = 1.0
var is_visible_now: bool = false

# ============ COLORS ============
var color_white: Color = Color.WHITE
var color_yellow: Color = Color(1.0, 1.0, 0.0)
var color_orange: Color = Color(1.0, 0.6, 0.0)
var color_red: Color = Color(1.0, 0.2, 0.2)

# ============ ANIMATION ============
var pulse_tween: Tween = null


func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	is_visible_now = false

	# Connect to EventBus combo signals
	if EventBus:
		EventBus.combo_increased.connect(_on_combo_increased)
		EventBus.combo_broken.connect(_on_combo_broken)

	print("[ComboDisplay] Initialized")


func _process(_delta: float) -> void:
	# Update timer bar if combo is active
	if current_combo > 0 and CombatManager:
		var progress: float = CombatManager.get_combo_progress()
		timer_bar.value = progress


# ============ COMBO UPDATES ============
func _on_combo_increased(new_count: int, multiplier: float) -> void:
	"""Called when combo increases."""
	current_combo = new_count
	current_multiplier = multiplier

	# Update text
	_update_labels()

	# Update color
	_update_color()

	# Show UI if hidden
	if not is_visible_now:
		_show_ui()

	# Pulse animation
	_play_pulse_animation()


func _on_combo_broken(final_count: int) -> void:
	"""Called when combo breaks."""
	current_combo = 0
	current_multiplier = 1.0

	# Fade out UI
	_hide_ui()


# ============ UI UPDATES ============
func _update_labels() -> void:
	"""Updates the text labels."""
	# Combo count label
	if current_combo == 1:
		combo_label.text = "1 HIT"
	else:
		combo_label.text = "%d HITS" % current_combo

	# Multiplier label
	multiplier_label.text = "×%.2f" % current_multiplier


func _update_color() -> void:
	"""Updates label colors based on combo count."""
	var color: Color = _get_combo_color()

	combo_label.add_theme_color_override("font_color", color)
	multiplier_label.add_theme_color_override("font_color", color)


func _get_combo_color() -> Color:
	"""Returns color based on combo count."""
	if current_combo < 5:
		return color_white  # 1-4 hits: white
	elif current_combo < 10:
		return color_yellow  # 5-9 hits: yellow
	elif current_combo < 20:
		return color_orange  # 10-19 hits: orange
	else:
		return color_red  # 20+ hits: red


# ============ ANIMATIONS ============
func _show_ui() -> void:
	"""Fades in the UI."""
	if is_visible_now:
		return

	is_visible_now = true

	# Create fade in tween
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _hide_ui() -> void:
	"""Fades out the UI."""
	if not is_visible_now:
		return

	is_visible_now = false

	# Create fade out tween
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)


func _play_pulse_animation() -> void:
	"""Plays a pulse animation on the container."""
	# Kill existing pulse tween
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	# Create new pulse tween
	pulse_tween = create_tween()
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.set_trans(Tween.TRANS_ELASTIC)

	# Pulse up
	pulse_tween.tween_property(container, "scale", Vector2(pulse_scale, pulse_scale), pulse_duration * 0.4)
	# Pulse down
	pulse_tween.tween_property(container, "scale", Vector2.ONE, pulse_duration * 0.6)


# ============ MANUAL CONTROL ============
func show_combo(count: int, multiplier: float) -> void:
	"""Manually shows combo with specific values."""
	current_combo = count
	current_multiplier = multiplier

	_update_labels()
	_update_color()
	_show_ui()


func hide_combo() -> void:
	"""Manually hides combo display."""
	_hide_ui()


# ============ GETTERS ============
func is_showing() -> bool:
	"""Returns true if UI is currently visible."""
	return is_visible_now
