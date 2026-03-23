extends CanvasLayer
## MomentumBar — Phase-adaptive HUD for mirror boss fight
## Phase 1: Momentum bar + finisher counter
## Phase 2+3: Boss HP bar + knockdown meter + knockdown counter
class_name MomentumBar

# ============ COLORS ============
const COLOR_RUECKSTAND := Color(0.8, 0.2, 0.2)
const COLOR_GLEICHAUF := Color(0.8, 0.8, 0.2)
const COLOR_UEBERHOLEN := Color(0.2, 0.8, 0.4)
const COLOR_MAX := Color(1.0, 1.0, 1.0)
const COLOR_BG := Color(0.1, 0.1, 0.1, 0.8)
const COLOR_BORDER := Color(0.5, 0.5, 0.5, 0.6)
const COLOR_HP_BG := Color(0.15, 0.05, 0.05, 0.8)
const COLOR_HP_FILL := Color(0.8, 0.15, 0.15)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.1)
const COLOR_KD_BG := Color(0.1, 0.05, 0.15, 0.8)
const COLOR_KD_FILL := Color(0.6, 0.3, 0.8)
const COLOR_KD_HIGH := Color(1.0, 0.85, 0.3)
const COLOR_KD_MAX := Color(1.0, 1.0, 1.0)

# ============ LAYOUT ============
const BAR_WIDTH: float = 800.0
const BAR_HEIGHT: float = 30.0
const BAR_Y: float = 50.0
const HP_BAR_WIDTH: float = 800.0
const HP_BAR_HEIGHT: float = 24.0
const HP_BAR_Y: float = 40.0
const KD_BAR_WIDTH: float = 600.0
const KD_BAR_HEIGHT: float = 16.0
const KD_BAR_Y: float = 72.0

# ============ STATE ============
var momentum_system: MomentumSystem = null
var controller: Node = null
var _current_hud_phase: int = 1

# Phase 1 elements
var _bar_container: Control = null
var _bar_bg: ColorRect = null
var _bar_fill: ColorRect = null
var _label: Label = null
var _finisher_label: Label = null
var _finisher_counter: Label = null
var _countdown_label: Label = null
var _section_label: Label = null
var _pulse_tween: Tween = null

# Phase 2+3 elements
var _phase2_container: Control = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_label: Label = null
var _kd_bar_bg: ColorRect = null
var _kd_bar_fill: ColorRect = null
var _kd_label: Label = null
var _kd_counter: Label = null
var _vulnerable_label: Label = null
var _kd_pulse_tween: Tween = null


func _ready() -> void:
	_create_phase_1_ui()
	_create_phase_2_ui()

	# Show Phase 1 by default
	_phase2_container.visible = false

	if momentum_system:
		momentum_system.momentum_changed.connect(_on_momentum_changed)
		momentum_system.finisher_window_opened.connect(_on_finisher_window_opened)
		momentum_system.finisher_window_closed.connect(_on_finisher_window_closed)
		momentum_system.knockdown_meter_changed.connect(_on_knockdown_meter_changed)
		momentum_system.knockdown_triggered.connect(_on_knockdown_triggered)
		momentum_system.knockdown_ended.connect(_on_knockdown_ended)

	_on_momentum_changed(0.0, MomentumSystem.State.RUECKSTAND)
	print("[MomentumBar] Initialized - Layer: %d" % layer)


func _create_phase_1_ui() -> void:
	_bar_container = Control.new()
	_bar_container.name = "MomentumBarContainer"
	add_child(_bar_container)

	# Border
	var border = ColorRect.new()
	border.position = Vector2((1920.0 - BAR_WIDTH) * 0.5 - 2.0, BAR_Y - 2.0)
	border.size = Vector2(BAR_WIDTH + 4.0, BAR_HEIGHT + 4.0)
	border.color = COLOR_BORDER
	_bar_container.add_child(border)

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
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_bar_container.add_child(_label)

	# Finisher prompt
	_finisher_label = Label.new()
	_finisher_label.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, BAR_Y + BAR_HEIGHT + 8.0)
	_finisher_label.size = Vector2(BAR_WIDTH, 30.0)
	_finisher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finisher_label.text = "FINISHER! Combo Finisher oder Machtbruch!"
	_finisher_label.add_theme_font_size_override("font_size", 20)
	_finisher_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_finisher_label.visible = false
	_bar_container.add_child(_finisher_label)

	# Finisher counter
	_finisher_counter = Label.new()
	_finisher_counter.position = Vector2((1920.0 + BAR_WIDTH) * 0.5 + 16.0, BAR_Y - 4.0)
	_finisher_counter.size = Vector2(120.0, 24.0)
	_finisher_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_finisher_counter.text = "0/4"
	_finisher_counter.add_theme_font_size_override("font_size", 18)
	_finisher_counter.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_bar_container.add_child(_finisher_counter)

	# Countdown timer
	_countdown_label = Label.new()
	_countdown_label.position = Vector2((1920.0 - BAR_WIDTH) * 0.5 - 80.0, BAR_Y - 4.0)
	_countdown_label.size = Vector2(70.0, 24.0)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown_label.add_theme_font_size_override("font_size", 18)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_countdown_label.visible = false
	_bar_container.add_child(_countdown_label)

	# Section indicator
	_section_label = Label.new()
	_section_label.position = Vector2((1920.0 + BAR_WIDTH) * 0.5 + 16.0, BAR_Y + BAR_HEIGHT + 4.0)
	_section_label.size = Vector2(200.0, 20.0)
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_section_label.text = "Abschnitt 1/4"
	_section_label.add_theme_font_size_override("font_size", 14)
	_section_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_bar_container.add_child(_section_label)


func _create_phase_2_ui() -> void:
	_phase2_container = Control.new()
	_phase2_container.name = "Phase2Container"
	add_child(_phase2_container)

	var hp_x: float = (1920.0 - HP_BAR_WIDTH) * 0.5
	var kd_x: float = (1920.0 - KD_BAR_WIDTH) * 0.5

	# HP bar label
	_hp_label = Label.new()
	_hp_label.position = Vector2(hp_x, HP_BAR_Y - 22.0)
	_hp_label.size = Vector2(HP_BAR_WIDTH, 20.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.text = "Murum (Spiegel)"
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	_phase2_container.add_child(_hp_label)

	# HP bar border
	var hp_border := ColorRect.new()
	hp_border.position = Vector2(hp_x - 2.0, HP_BAR_Y - 2.0)
	hp_border.size = Vector2(HP_BAR_WIDTH + 4.0, HP_BAR_HEIGHT + 4.0)
	hp_border.color = COLOR_BORDER
	_phase2_container.add_child(hp_border)

	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(hp_x, HP_BAR_Y)
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.color = COLOR_HP_BG
	_phase2_container.add_child(_hp_bar_bg)

	# HP bar fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.position = Vector2(hp_x, HP_BAR_Y)
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fill.color = COLOR_HP_FILL
	_phase2_container.add_child(_hp_bar_fill)

	# Knockdown bar label
	_kd_label = Label.new()
	_kd_label.position = Vector2(kd_x, KD_BAR_Y - 2.0)
	_kd_label.size = Vector2(KD_BAR_WIDTH, 16.0)
	_kd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kd_label.text = "Knockdown"
	_kd_label.add_theme_font_size_override("font_size", 14)
	_kd_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	_phase2_container.add_child(_kd_label)

	# Knockdown bar border
	var kd_border := ColorRect.new()
	kd_border.position = Vector2(kd_x - 1.0, KD_BAR_Y + 14.0)
	kd_border.size = Vector2(KD_BAR_WIDTH + 2.0, KD_BAR_HEIGHT + 2.0)
	kd_border.color = COLOR_BORDER
	_phase2_container.add_child(kd_border)

	# Knockdown bar background
	_kd_bar_bg = ColorRect.new()
	_kd_bar_bg.position = Vector2(kd_x, KD_BAR_Y + 15.0)
	_kd_bar_bg.size = Vector2(KD_BAR_WIDTH, KD_BAR_HEIGHT)
	_kd_bar_bg.color = COLOR_KD_BG
	_phase2_container.add_child(_kd_bar_bg)

	# Knockdown bar fill
	_kd_bar_fill = ColorRect.new()
	_kd_bar_fill.position = Vector2(kd_x, KD_BAR_Y + 15.0)
	_kd_bar_fill.size = Vector2(0, KD_BAR_HEIGHT)
	_kd_bar_fill.color = COLOR_KD_FILL
	_phase2_container.add_child(_kd_bar_fill)

	# Knockdown counter
	_kd_counter = Label.new()
	_kd_counter.position = Vector2((1920.0 + KD_BAR_WIDTH) * 0.5 + 16.0, KD_BAR_Y + 12.0)
	_kd_counter.size = Vector2(80.0, 20.0)
	_kd_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kd_counter.text = "0/4"
	_kd_counter.add_theme_font_size_override("font_size", 16)
	_kd_counter.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_phase2_container.add_child(_kd_counter)

	# "VERWUNDBAR!" pulsing label
	_vulnerable_label = Label.new()
	_vulnerable_label.position = Vector2((1920.0 - 400.0) * 0.5, KD_BAR_Y + 36.0)
	_vulnerable_label.size = Vector2(400.0, 30.0)
	_vulnerable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vulnerable_label.text = "VERWUNDBAR!"
	_vulnerable_label.add_theme_font_size_override("font_size", 22)
	_vulnerable_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_vulnerable_label.visible = false
	_phase2_container.add_child(_vulnerable_label)


func _process(_delta: float) -> void:
	if _current_hud_phase == 1:
		_process_phase_1()
	else:
		_process_phase_2_3()


func _process_phase_1() -> void:
	if controller and _finisher_counter:
		_finisher_counter.text = "%d/%d" % [controller.finisher_count, controller.finishers_required]

	if controller and _section_label:
		var section_names: Array[String] = ["Der Fall", "Spiegelkampf", "Abgrund", "Finale"]
		var idx: int = clampi(controller.current_section, 0, 3)
		var speed: float = controller.get_scroll_speed()
		_section_label.text = "%s (%d/%d) | %.0f px/s" % [section_names[idx], idx + 1, 4, speed]

	if _countdown_label:
		_countdown_label.visible = false


func _process_phase_2_3() -> void:
	# Update HP bar
	if controller and controller.mirror_boss and controller.mirror_boss.has_node("HealthComponent"):
		var hc: HealthComponentGeneric = controller.mirror_boss.get_node("HealthComponent")
		var ratio: float = hc.current_hp / hc.max_hp
		_hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
		# Color shifts from green to red as HP drops
		if ratio > 0.5:
			_hp_bar_fill.color = COLOR_HP_FILL
		else:
			_hp_bar_fill.color = COLOR_HP_LOW

	# Update knockdown counter
	if momentum_system and _kd_counter:
		_kd_counter.text = "%d/4" % momentum_system.knockdown_count
		# Hide counter in Phase 3
		_kd_counter.visible = (_current_hud_phase == 2)


# ============ PHASE SWITCHING ============
func switch_to_phase_2_hud() -> void:
	print("[MomentumBar] Switching to Phase 2 HUD")
	_current_hud_phase = 2
	_bar_container.visible = false
	_phase2_container.visible = true
	_kd_counter.visible = true


func switch_to_phase_3_hud() -> void:
	print("[MomentumBar] Switching to Phase 3 HUD")
	_current_hud_phase = 3
	_bar_container.visible = false
	_phase2_container.visible = true
	_kd_counter.visible = false  # No counter in Phase 3


# ============ PHASE 1 CALLBACKS ============
func _on_momentum_changed(value: float, state: int) -> void:
	if _current_hud_phase != 1:
		return

	var fill_ratio: float = value / 100.0
	_bar_fill.size.x = BAR_WIDTH * fill_ratio

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
	if _current_hud_phase != 1:
		return
	_finisher_label.visible = true
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_bar_fill, "color", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	_pulse_tween.tween_property(_bar_fill, "color", Color(0.8, 0.6, 1.0, 1.0), 0.3)


func _on_finisher_window_closed() -> void:
	if _current_hud_phase != 1:
		return
	_finisher_label.visible = false
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null


# ============ PHASE 2+3 CALLBACKS ============
func _on_knockdown_meter_changed(value: float) -> void:
	if _current_hud_phase < 2:
		return

	var fill_ratio: float = value / 100.0
	_kd_bar_fill.size.x = KD_BAR_WIDTH * fill_ratio

	# Color: purple → gold → white
	if value < 50.0:
		_kd_bar_fill.color = COLOR_KD_FILL
	elif value < 90.0:
		_kd_bar_fill.color = COLOR_KD_HIGH
	else:
		_kd_bar_fill.color = COLOR_KD_MAX


func _on_knockdown_triggered(count: int) -> void:
	if _current_hud_phase < 2:
		return

	# Show "VERWUNDBAR!" pulsing
	_vulnerable_label.visible = true
	if _kd_pulse_tween:
		_kd_pulse_tween.kill()
	_kd_pulse_tween = create_tween().set_loops()
	_kd_pulse_tween.tween_property(_vulnerable_label, "modulate:a", 0.3, 0.3)
	_kd_pulse_tween.tween_property(_vulnerable_label, "modulate:a", 1.0, 0.3)

	# Reset knockdown bar fill
	_kd_bar_fill.size.x = KD_BAR_WIDTH  # Full bar during knockdown


func _on_knockdown_ended(count: int) -> void:
	if _current_hud_phase < 2:
		return

	_vulnerable_label.visible = false
	if _kd_pulse_tween:
		_kd_pulse_tween.kill()
		_kd_pulse_tween = null
	_kd_bar_fill.size.x = 0
