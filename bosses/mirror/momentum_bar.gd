extends CanvasLayer
## MomentumBar — HUD element showing momentum value and state
## Positioned at top of screen, replaces traditional boss HP bar
class_name MomentumBar

# ============ COLORS ============
const COLOR_RUECKSTAND := Color(0.8, 0.2, 0.2)      # Red
const COLOR_GLEICHAUF := Color(0.8, 0.8, 0.2)        # Yellow
const COLOR_UEBERHOLEN := Color(0.2, 0.8, 0.4)       # Green
const COLOR_MAX := Color(1.0, 1.0, 1.0)              # White (pulsing)
const COLOR_BG := Color(0.1, 0.1, 0.1, 0.8)
const COLOR_BORDER := Color(0.5, 0.5, 0.5, 0.6)

# ============ LAYOUT ============
const BAR_WIDTH: float = 600.0
const BAR_HEIGHT: float = 20.0
const BAR_Y: float = 40.0

# ============ STATE ============
var momentum_system: MomentumSystem = null
var controller: Node = null  # MirrorController for finisher count
var _bar_container: Control = null
var _bar_bg: ColorRect = null
var _bar_fill: ColorRect = null
var _label: Label = null
var _finisher_label: Label = null
var _finisher_counter: Label = null
var _countdown_label: Label = null
var _section_label: Label = null
var _pulse_tween: Tween = null


func _ready() -> void:
	_create_ui()

	# Connect to momentum system
	if momentum_system:
		momentum_system.momentum_changed.connect(_on_momentum_changed)
		momentum_system.finisher_window_opened.connect(_on_finisher_window_opened)
		momentum_system.finisher_window_closed.connect(_on_finisher_window_closed)


func _create_ui() -> void:
	_bar_container = Control.new()
	_bar_container.name = "MomentumBarContainer"
	add_child(_bar_container)

	# Background
	_bar_bg = ColorRect.new()
	_bar_bg.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, BAR_Y)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.color = COLOR_BG
	_bar_container.add_child(_bar_bg)

	# Fill bar
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, BAR_Y)
	_bar_fill.size = Vector2(0, BAR_HEIGHT)
	_bar_fill.color = COLOR_RUECKSTAND
	_bar_container.add_child(_bar_fill)

	# State label
	_label = Label.new()
	_label.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, BAR_Y - 24.0)
	_label.size = Vector2(BAR_WIDTH, 24.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = "Momentum"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_bar_container.add_child(_label)

	# Finisher prompt (hidden by default)
	_finisher_label = Label.new()
	_finisher_label.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, BAR_Y + BAR_HEIGHT + 8.0)
	_finisher_label.size = Vector2(BAR_WIDTH, 30.0)
	_finisher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finisher_label.text = "FINISHER! Combo Finisher oder Machtbruch!"
	_finisher_label.add_theme_font_size_override("font_size", 20)
	_finisher_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_finisher_label.visible = false
	_bar_container.add_child(_finisher_label)

	# Finisher counter (top-right of bar)
	_finisher_counter = Label.new()
	_finisher_counter.position = Vector2((1920.0 + BAR_WIDTH) * 0.5 + 16.0, BAR_Y - 4.0)
	_finisher_counter.size = Vector2(120.0, 24.0)
	_finisher_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_finisher_counter.text = "0/4"
	_finisher_counter.add_theme_font_size_override("font_size", 18)
	_finisher_counter.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_bar_container.add_child(_finisher_counter)

	# Countdown timer (shown during finisher window)
	_countdown_label = Label.new()
	_countdown_label.position = Vector2((1920.0 - BAR_WIDTH) * 0.5 - 80.0, BAR_Y - 4.0)
	_countdown_label.size = Vector2(70.0, 24.0)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown_label.add_theme_font_size_override("font_size", 18)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_countdown_label.visible = false
	_bar_container.add_child(_countdown_label)

	# Section indicator (bottom-right)
	_section_label = Label.new()
	_section_label.position = Vector2((1920.0 + BAR_WIDTH) * 0.5 + 16.0, BAR_Y + BAR_HEIGHT + 4.0)
	_section_label.size = Vector2(200.0, 20.0)
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_section_label.text = "Abschnitt 1/4"
	_section_label.add_theme_font_size_override("font_size", 14)
	_section_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_bar_container.add_child(_section_label)


func _process(_delta: float) -> void:
	# Update finisher counter
	if controller and _finisher_counter:
		_finisher_counter.text = "%d/%d" % [controller.finisher_count, controller.finishers_required]

	# Update section label
	if controller and _section_label:
		var section_names: Array[String] = ["Der Fall", "Spiegelkampf", "Abgrund", "Finale"]
		var idx: int = clampi(controller.current_section, 0, 3)
		var speed: float = controller.get_scroll_speed()
		_section_label.text = "%s (%d/%d) | %.0f px/s" % [section_names[idx], idx + 1, 4, speed]

	# Update countdown during finisher window
	if momentum_system and momentum_system.is_finisher_window_open() and _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "%.1fs" % momentum_system._finisher_window_timer
	elif _countdown_label:
		_countdown_label.visible = false


func _on_momentum_changed(value: float, state: int) -> void:
	# Update fill width
	var fill_ratio: float = value / 100.0
	_bar_fill.size.x = BAR_WIDTH * fill_ratio

	# Update color based on state
	match state:
		MomentumSystem.State.RUECKSTAND:
			_bar_fill.color = COLOR_RUECKSTAND
			_label.text = "Rueckstand"
		MomentumSystem.State.GLEICHAUF:
			_bar_fill.color = COLOR_GLEICHAUF
			_label.text = "Gleichauf"
		MomentumSystem.State.UEBERHOLEN:
			_bar_fill.color = COLOR_UEBERHOLEN
			_label.text = "Ueberholen!"
		MomentumSystem.State.MAX:
			_bar_fill.color = COLOR_MAX
			_label.text = "MAX!"


func _on_finisher_window_opened() -> void:
	_finisher_label.visible = true
	# Pulse the bar
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_bar_fill, "color", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	_pulse_tween.tween_property(_bar_fill, "color", Color(0.8, 0.6, 1.0, 1.0), 0.3)


func _on_finisher_window_closed() -> void:
	_finisher_label.visible = false
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
