extends CanvasLayer
## Ebenen des Deliriums - Murums Albtraum Modifier-Auswahl
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
@onready var delirium_label: Label = %HeatLabel
@onready var deepest_label: Label = %HighestHeatLabel

# ============================================================================
# STATE
# ============================================================================

## Slider references for reading values
var _modifier_sliders: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _schwellensicht_label: Label = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_modifier_ui()
	_update_delirium_display()
	print("[DeliriumMenu] Ebenen des Deliriums initialisiert")

func _build_modifier_ui() -> void:
	"""Builds modifier selection UI dynamically"""
	# Clear existing
	for child in modifier_container.get_children():
		child.queue_free()

	# Title
	var title = Label.new()
	title.text = "Ebenen des Deliriums"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier_container.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Murums Qualen"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.3, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier_container.add_child(subtitle)

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

	# Schwellensicht indicator
	var sep3 = HSeparator.new()
	modifier_container.add_child(sep3)

	_schwellensicht_label = Label.new()
	_schwellensicht_label.text = "Schwellensicht aktiv"
	_schwellensicht_label.add_theme_font_size_override("font_size", 18)
	_schwellensicht_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1.0))
	_schwellensicht_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_schwellensicht_label.visible = false
	modifier_container.add_child(_schwellensicht_label)

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
	desc_label.custom_minimum_size = Vector2(350, 0)
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
	value_label.text = "Qual %d" % int(slider.value)
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(value_label)

	# Connect slider
	slider.value_changed.connect(func(new_value: float):
		ChallengeRunManager.set_modifier_level(modifier_id, int(new_value))
		value_label.text = "Qual %d" % int(new_value)
		_update_delirium_display()
	)

	_modifier_sliders[modifier_id] = slider
	return hbox

func _create_toggle_modifier_row(modifier_id: String, mod_data: Dictionary) -> HBoxContainer:
	"""Creates a row for a toggle modifier with label + checkbox"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Name label - dark purple for Myrkurs Siegel
	var name_label = Label.new()
	name_label.text = mod_data["name"]
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.5, 0.1, 0.6, 1.0))
	hbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = mod_data["description"]
	desc_label.custom_minimum_size = Vector2(350, 0)
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
		_update_delirium_display()
	)

	_toggle_buttons[modifier_id] = check
	return hbox

# ============================================================================
# DELIRIUM DISPLAY
# ============================================================================

func _update_delirium_display() -> void:
	"""Updates the delirium depth label"""
	var current = ChallengeRunManager.get_delirium_depth()
	var maximum = ChallengeRunManager.get_max_delirium()
	delirium_label.text = "Delirium: %d / %d" % [current, maximum]

	if ChallengeRunManager.are_all_modifiers_maxed():
		delirium_label.add_theme_color_override("font_color", Color(0.7, 0.1, 1.0, 1.0))
	elif current > 0:
		delirium_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9, 1.0))
	else:
		delirium_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

	if ChallengeRunManager:
		deepest_label.text = "Tiefster Abstieg: %d" % ChallengeRunManager.deepest_delirium_reached

	# Schwellensicht indicator
	if _schwellensicht_label:
		var threshold = maximum * 0.5
		_schwellensicht_label.visible = current >= threshold

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_start_pressed() -> void:
	"""Starts the challenge run"""
	ChallengeRunManager.start_challenge_run()
	challenge_started.emit()
	print("[DeliriumMenu] Abstieg beginnt! Delirium: %d" % ChallengeRunManager.get_delirium_depth())

func _on_back_pressed() -> void:
	"""Returns to main menu"""
	# Reset modifiers when going back
	ChallengeRunManager._reset_modifiers()
	back_pressed.emit()
