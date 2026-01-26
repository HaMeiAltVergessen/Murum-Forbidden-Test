extends VBoxContainer

## ControlsSection - UI für die Tastenbelegung im Options-Menü
## Ermöglicht das Remappen von Aktionen für P1 und P2

# ============================================================================
# SIGNALS
# ============================================================================

signal unsaved_changes_status(has_changes: bool)
signal show_confirm_dialog(title: String, message: String, confirm_callback: Callable)

# ============================================================================
# PRELOADS
# ============================================================================

const RemapButtonScene = preload("res://systems/input/remap_button.tscn")

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player_selector: OptionButton = %PlayerSelector
@onready var device_selector: OptionButton = %DeviceSelector
@onready var bindings_container: VBoxContainer = %BindingsContainer
@onready var reset_all_button: Button = %ResetAllButton
@onready var apply_button: Button = %ApplyButton

# ============================================================================
# STATE
# ============================================================================

var current_player: int = 1
var current_device_type: int = 0  # InputRemappingManager.DeviceType.KEYBOARD
var remap_buttons: Dictionary = {}  # action_name -> RemapButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_selectors()
	_connect_signals()
	_rebuild_bindings_list()

	print("[ControlsSection] Initialized")

func _setup_selectors() -> void:
	"""Sets up the player and device selector dropdowns"""
	# Player selector
	player_selector.clear()
	player_selector.add_item("Spieler 1 (Murum)", 1)
	player_selector.add_item("Spieler 2 (Lythrun)", 2)
	player_selector.selected = 0

	# Device selector
	device_selector.clear()
	device_selector.add_item("Tastatur", 0)  # DeviceType.KEYBOARD
	device_selector.add_item("Maus", 1)       # DeviceType.MOUSE
	device_selector.add_item("Controller", 2) # DeviceType.GAMEPAD
	device_selector.selected = 0

func _connect_signals() -> void:
	"""Connects UI signals"""
	player_selector.item_selected.connect(_on_player_selected)
	device_selector.item_selected.connect(_on_device_selected)
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	apply_button.pressed.connect(_on_apply_pressed)

	# Connect to InputRemappingManager
	if InputRemappingManager:
		InputRemappingManager.binding_changed.connect(_on_binding_changed)
		InputRemappingManager.changes_applied.connect(_on_changes_applied)
		InputRemappingManager.changes_reverted.connect(_on_changes_reverted)

# ============================================================================
# BINDINGS LIST
# ============================================================================

func _rebuild_bindings_list() -> void:
	"""Rebuilds the list of remappable actions for current player/device"""
	# Clear existing buttons
	for child in bindings_container.get_children():
		child.queue_free()
	remap_buttons.clear()

	if not InputRemappingManager:
		var label = Label.new()
		label.text = "InputRemappingManager nicht verfügbar"
		bindings_container.add_child(label)
		return

	# Get actions for current player
	var actions = InputRemappingManager.get_actions_for_player(current_player)

	if actions.is_empty():
		var label = Label.new()
		label.text = "Keine anpassbaren Aktionen für diesen Spieler"
		bindings_container.add_child(label)
		return

	# Group actions by category
	var categories = [
		InputRemappingManager.Category.MOVEMENT,
		InputRemappingManager.Category.ACTION,
		InputRemappingManager.Category.COMBAT,
		InputRemappingManager.Category.ABILITIES
	]

	for category in categories:
		var category_actions = InputRemappingManager.get_actions_by_category(current_player, category)

		if category_actions.is_empty():
			continue

		# Category header
		var header = Label.new()
		header.text = InputRemappingManager.get_category_name(category)
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		bindings_container.add_child(header)

		# Separator
		var separator = HSeparator.new()
		bindings_container.add_child(separator)

		# Actions in this category
		for action_name in category_actions:
			var remap_button = _create_remap_button(action_name)
			bindings_container.add_child(remap_button)
			remap_buttons[action_name] = remap_button

		# Spacer between categories
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		bindings_container.add_child(spacer)

	_update_apply_button()

func _create_remap_button(action_name: String) -> Control:
	"""Creates a RemapButton for the given action"""
	var button = RemapButtonScene.instantiate()
	button.setup(action_name, current_device_type)
	button.remap_requested.connect(_on_remap_requested)
	button.reset_requested.connect(_on_reset_action_requested)
	return button

# ============================================================================
# UI UPDATES
# ============================================================================

func _update_all_bindings_display() -> void:
	"""Updates the display of all remap buttons"""
	for action_name in remap_buttons:
		var button = remap_buttons[action_name]
		button.setup(action_name, current_device_type)

func _update_apply_button() -> void:
	"""Updates the apply button based on unsaved changes"""
	if InputRemappingManager:
		var has_changes = InputRemappingManager.has_unsaved_changes
		apply_button.disabled = not has_changes
		apply_button.text = "Anwenden" if has_changes else "Gespeichert"
		unsaved_changes_status.emit(has_changes)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func has_unsaved_changes() -> bool:
	"""Returns true if there are unsaved changes"""
	if InputRemappingManager:
		return InputRemappingManager.has_unsaved_changes
	return false

func save_and_apply() -> void:
	"""Saves and applies all changes"""
	if InputRemappingManager:
		InputRemappingManager.apply_changes()
		InputRemappingManager.save_bindings()

func discard_changes() -> void:
	"""Discards all unsaved changes"""
	if InputRemappingManager:
		InputRemappingManager.revert_changes()

# ============================================================================
# SIGNAL HANDLERS - UI
# ============================================================================

func _on_player_selected(index: int) -> void:
	"""Called when player selector changes"""
	current_player = index + 1  # Index 0 = Player 1, Index 1 = Player 2

	# P2 is controller-only, so switch device selector
	if current_player == 2:
		device_selector.selected = 2  # Gamepad
		current_device_type = InputRemappingManager.DeviceType.GAMEPAD
		device_selector.disabled = true  # P2 can only use controller
	else:
		device_selector.disabled = false

	_rebuild_bindings_list()

func _on_device_selected(index: int) -> void:
	"""Called when device selector changes"""
	current_device_type = index
	_update_all_bindings_display()

func _on_reset_all_pressed() -> void:
	"""Called when reset all button is pressed"""
	show_confirm_dialog.emit(
		"Alle Zurücksetzen",
		"Möchten Sie wirklich alle Tastenbelegungen auf die Standardwerte zurücksetzen?\n\nDies kann nicht rückgängig gemacht werden.",
		_do_reset_all
	)

func _do_reset_all() -> void:
	"""Actually performs the reset all operation"""
	if InputRemappingManager:
		InputRemappingManager.reset_all_to_defaults()
		InputRemappingManager.apply_changes()
		InputRemappingManager.save_bindings()
		_update_all_bindings_display()
		_update_apply_button()

func _on_apply_pressed() -> void:
	"""Called when apply button is pressed"""
	save_and_apply()

func _on_remap_requested(action_name: String) -> void:
	"""Called when a remap button requests remapping"""
	if InputRemappingManager:
		InputRemappingManager.start_listening(action_name, current_device_type)

func _on_reset_action_requested(action_name: String) -> void:
	"""Called when a single action reset is requested"""
	if InputRemappingManager:
		InputRemappingManager.reset_action_to_default(action_name)
		_update_apply_button()

# ============================================================================
# SIGNAL HANDLERS - InputRemappingManager
# ============================================================================

func _on_binding_changed(_action_name: String, _device_type_str: String) -> void:
	"""Called when any binding changes"""
	_update_apply_button()

func _on_changes_applied() -> void:
	"""Called when changes are applied"""
	_update_apply_button()

func _on_changes_reverted() -> void:
	"""Called when changes are reverted"""
	_update_all_bindings_display()
	_update_apply_button()
