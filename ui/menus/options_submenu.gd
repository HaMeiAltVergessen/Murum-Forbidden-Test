extends Control

## Options Menu - Verwaltung aller Spieleinstellungen
## Godot 4.4 kompatibel
## COMMIT 017: Options Menu Foundation

# ============================================================================
# SIGNALS
# ============================================================================

signal back_pressed()

# ============================================================================
# REFERENCES - Tab Container
# ============================================================================

@onready var tab_container: TabContainer = %TabContainer

# ============================================================================
# REFERENCES - Audio Tab
# ============================================================================

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value_label: Label = %SFXValueLabel

# ============================================================================
# REFERENCES - Video Tab
# ============================================================================

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_value_label: Label = %BrightnessValueLabel
@onready var vsync_checkbox: CheckBox = %VSyncCheckBox

# ============================================================================
# REFERENCES - Input Tab
# ============================================================================

@onready var input_device_option: OptionButton = %InputDeviceOption

# ============================================================================
# REFERENCES - Buttons
# ============================================================================

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup UI
	_setup_audio_tab()
	_setup_video_tab()
	_setup_input_tab()

	# Load current settings
	_load_current_settings()

	# Connect signals
	_connect_signals()

	# Setup input actions for tab navigation
	_setup_tab_navigation()

	print("[OptionsMenu] Initialized")

# ============================================================================
# SETUP
# ============================================================================

func _setup_audio_tab() -> void:
	"""Configures audio sliders"""
	# Master
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01

	# Music
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01

	# SFX
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01

func _setup_video_tab() -> void:
	"""Configures video options"""
	# Resolution options
	resolution_option.clear()
	for i in range(SettingsManager.resolution_options.size()):
		var res = SettingsManager.resolution_options[i]
		resolution_option.add_item("%dx%d" % [res.x, res.y], i)

	# Window mode options
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", 0)
	window_mode_option.add_item("Fullscreen", 1)
	window_mode_option.add_item("Borderless", 2)

	# Brightness slider
	brightness_slider.min_value = 0.5
	brightness_slider.max_value = 1.5
	brightness_slider.step = 0.01

func _setup_input_tab() -> void:
	"""Configures input options"""
	input_device_option.clear()
	input_device_option.add_item("Auto", 0)
	input_device_option.add_item("Keyboard", 1)
	input_device_option.add_item("Gamepad", 2)

func _setup_tab_navigation() -> void:
	"""Sets up input actions for tab navigation"""
	# Check if actions exist, if not create them
	if not InputMap.has_action("tab_switch_left"):
		InputMap.add_action("tab_switch_left")
		var key_tab = InputEventKey.new()
		key_tab.keycode = KEY_TAB
		key_tab.shift_pressed = true
		InputMap.action_add_event("tab_switch_left", key_tab)
		var lb = InputEventJoypadButton.new()
		lb.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("tab_switch_left", lb)

	if not InputMap.has_action("tab_switch_right"):
		InputMap.add_action("tab_switch_right")
		var key_tab = InputEventKey.new()
		key_tab.keycode = KEY_TAB
		InputMap.action_add_event("tab_switch_right", key_tab)
		var rb = InputEventJoypadButton.new()
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("tab_switch_right", rb)

# ============================================================================
# LOAD CURRENT SETTINGS
# ============================================================================

func _load_current_settings() -> void:
	"""Loads current settings from SettingsManager into UI"""
	# Audio
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	_update_audio_labels()

	# Video
	resolution_option.selected = SettingsManager.resolution_index
	window_mode_option.selected = SettingsManager.window_mode
	brightness_slider.value = SettingsManager.brightness
	vsync_checkbox.button_pressed = SettingsManager.vsync_enabled
	_update_brightness_label()

	# Input
	input_device_option.selected = SettingsManager.preferred_input_device

	print("[OptionsMenu] Current settings loaded into UI")

# ============================================================================
# CONNECT SIGNALS
# ============================================================================

func _connect_signals() -> void:
	"""Connects all UI element signals"""
	# Audio
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	# Video
	resolution_option.item_selected.connect(_on_resolution_selected)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	brightness_slider.value_changed.connect(_on_brightness_slider_changed)
	vsync_checkbox.toggled.connect(_on_vsync_toggled)

	# Input
	input_device_option.item_selected.connect(_on_input_device_selected)

	# Buttons
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Tab navigation
	if event.is_action_pressed("tab_switch_right"):
		_switch_tab(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_switch_left"):
		_switch_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _switch_tab(direction: int) -> void:
	"""Switches to next/previous tab"""
	var current_tab = tab_container.current_tab
	var tab_count = tab_container.get_tab_count()
	var new_tab = (current_tab + direction) % tab_count
	if new_tab < 0:
		new_tab = tab_count - 1
	tab_container.current_tab = new_tab

# ============================================================================
# AUDIO SIGNAL HANDLERS
# ============================================================================

func _on_master_slider_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_audio_labels()

func _on_music_slider_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_audio_labels()

func _on_sfx_slider_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)
	_update_audio_labels()
	# Play test sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

func _update_audio_labels() -> void:
	"""Updates audio value labels"""
	master_value_label.text = "%d%%" % (master_slider.value * 100)
	music_value_label.text = "%d%%" % (music_slider.value * 100)
	sfx_value_label.text = "%d%%" % (sfx_slider.value * 100)

# ============================================================================
# VIDEO SIGNAL HANDLERS
# ============================================================================

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(index)

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_brightness_slider_changed(value: float) -> void:
	SettingsManager.set_brightness(value)
	_update_brightness_label()

func _on_vsync_toggled(enabled: bool) -> void:
	SettingsManager.set_vsync(enabled)

func _update_brightness_label() -> void:
	"""Updates brightness value label"""
	brightness_value_label.text = "%d%%" % (brightness_slider.value * 100)

# ============================================================================
# INPUT SIGNAL HANDLERS
# ============================================================================

func _on_input_device_selected(index: int) -> void:
	SettingsManager.set_preferred_input_device(index)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_reset_pressed() -> void:
	"""Resets all settings to defaults"""
	print("[OptionsMenu] Resetting to defaults")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

	# Reset via SettingsManager
	SettingsManager.reset_to_defaults()

	# Reload UI
	_load_current_settings()

func _on_back_pressed() -> void:
	"""Returns to main menu and saves settings"""
	print("[OptionsMenu] Returning to main menu")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_back")

	# Save settings
	SettingsManager.save_settings()

	# Emit signal for main menu
	back_pressed.emit()

