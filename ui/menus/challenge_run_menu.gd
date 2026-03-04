extends CanvasLayer
## Challenge Run Menu - Pre-run modifier selection (Hades-inspired)
## Shown from main menu before starting a challenge run

# ============================================================================
# SIGNALS
# ============================================================================

signal challenge_started()
signal back_pressed()

# ============================================================================
# REFERENCES
# ============================================================================

@onready var modifier_container: VBoxContainer = %ModifierContainer
@onready var start_button: Button = %StartChallengeButton
@onready var back_button: Button = %ChallengeBackButton
@onready var heat_label: Label = %HeatLabel
@onready var highest_heat_label: Label = %HighestHeatLabel

# ============================================================================
# STATE
# ============================================================================

## Slider references for reading values
var _modifier_sliders: Dictionary = {}
var _toggle_buttons: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_modifier_ui()
	_update_heat_display()
	print("[ChallengeRunMenu] Initialized")

func _build_modifier_ui() -> void:
	"""Builds modifier selection UI dynamically"""
	# Clear existing
	for child in modifier_container.get_children():
		child.queue_free()

	# Title
	var title = Label.new()
	title.text = "Challenge-Modifikatoren"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier_container.add_child(title)

	var sep = HSeparator.new()
	modifier_container.add_child(sep)

	# Tiered modifiers
	for modifier_id in ChallengeRunManager.TIERED_MODIFIERS:
		var mod_data = ChallengeRunManager.TIERED_MODIFIERS[modifier_id]
		var row = _create_tiered_modifier_row(modifier_id, mod_data)
		modifier_container.add_child(row)

	# Separator before toggle
	var sep2 = HSeparator.new()
	modifier_container.add_child(sep2)

	# Toggle modifiers
	for modifier_id in ChallengeRunManager.TOGGLE_MODIFIERS:
		var mod_data = ChallengeRunManager.TOGGLE_MODIFIERS[modifier_id]
		var row = _create_toggle_modifier_row(modifier_id, mod_data)
		modifier_container.add_child(row)

func _create_tiered_modifier_row(modifier_id: String, mod_data: Dictionary) -> HBoxContainer:
	"""Creates a row for a tiered modifier with label + slider + value"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Name label
	var name_label = Label.new()
	name_label.text = mod_data["name"]
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(name_label)

	# Description label
	var desc_label = Label.new()
	desc_label.text = mod_data["description"]
	desc_label.custom_minimum_size = Vector2(300, 0)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	hbox.add_child(desc_label)

	# Slider
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = mod_data["max_level"]
	slider.step = 1
	slider.value = ChallengeRunManager.get_modifier_level(modifier_id)
	slider.custom_minimum_size = Vector2(150, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	# Value label
	var value_label = Label.new()
	value_label.text = "Stufe %d" % int(slider.value)
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)

	# Connect slider
	slider.value_changed.connect(func(new_value: float):
		ChallengeRunManager.set_modifier_level(modifier_id, int(new_value))
		value_label.text = "Stufe %d" % int(new_value)
		_update_heat_display()
	)

	_modifier_sliders[modifier_id] = slider
	return hbox

func _create_toggle_modifier_row(modifier_id: String, mod_data: Dictionary) -> HBoxContainer:
	"""Creates a row for a toggle modifier with label + checkbox"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Name label
	var name_label = Label.new()
	name_label.text = mod_data["name"]
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 1.0))
	hbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = mod_data["description"]
	desc_label.custom_minimum_size = Vector2(300, 0)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	hbox.add_child(desc_label)

	# CheckButton
	var check = CheckButton.new()
	check.button_pressed = ChallengeRunManager.is_modifier_active(modifier_id)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(check)

	# Connect
	check.toggled.connect(func(pressed: bool):
		ChallengeRunManager.set_modifier_level(modifier_id, 1 if pressed else 0)
		_update_heat_display()
	)

	_toggle_buttons[modifier_id] = check
	return hbox

# ============================================================================
# HEAT DISPLAY
# ============================================================================

func _update_heat_display() -> void:
	"""Updates the heat total label"""
	var current = ChallengeRunManager.get_total_heat()
	var maximum = ChallengeRunManager.get_max_heat()
	heat_label.text = "Heat: %d / %d" % [current, maximum]

	if ChallengeRunManager.are_all_modifiers_maxed():
		heat_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1, 1.0))
	elif current > 0:
		heat_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	else:
		heat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

	if ChallengeRunManager:
		highest_heat_label.text = "Hoechster Heat: %d" % ChallengeRunManager.highest_heat_completed

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_start_pressed() -> void:
	"""Starts the challenge run"""
	ChallengeRunManager.start_challenge_run()
	challenge_started.emit()
	print("[ChallengeRunMenu] Challenge run started with heat %d" % ChallengeRunManager.get_total_heat())

func _on_back_pressed() -> void:
	"""Returns to main menu"""
	# Reset modifiers when going back
	ChallengeRunManager._reset_modifiers()
	back_pressed.emit()
