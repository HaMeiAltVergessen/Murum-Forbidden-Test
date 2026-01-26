@tool
extends HBoxContainer
class_name RemapButton

## RemapButton - Einzelner Eintrag für eine Tastenbelegung
## Zeigt Action-Name, aktuelle Belegung und Change-Button

# ============================================================================
# SIGNALS
# ============================================================================

signal remap_requested(action_name: String)
signal reset_requested(action_name: String)

# ============================================================================
# EXPORTS
# ============================================================================

@export var action_name: String = "" :
	set(value):
		action_name = value
		_update_display()

# ============================================================================
# STATE
# ============================================================================

enum State {
	NORMAL,
	LISTENING,
	CONFLICT
}

var current_state: State = State.NORMAL
var device_type: int = 0  # InputRemappingManager.DeviceType
var conflict_action: String = ""

# ============================================================================
# REFERENCES
# ============================================================================

var action_label: Label
var binding_label: Label
var change_button: Button
var reset_button: Button
var conflict_icon: TextureRect

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_create_ui()

	if not Engine.is_editor_hint():
		# Connect to InputRemappingManager signals
		if InputRemappingManager:
			InputRemappingManager.binding_changed.connect(_on_binding_changed)
			InputRemappingManager.listening_started.connect(_on_listening_started)
			InputRemappingManager.listening_stopped.connect(_on_listening_stopped)
			InputRemappingManager.conflict_detected.connect(_on_conflict_detected)

	_update_display()

func _create_ui() -> void:
	"""Creates the UI structure programmatically"""
	# Set container properties
	custom_minimum_size = Vector2(0, 50)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Action name label
	action_label = Label.new()
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.add_theme_font_size_override("font_size", 20)
	add_child(action_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# Conflict icon (hidden by default)
	conflict_icon = TextureRect.new()
	conflict_icon.custom_minimum_size = Vector2(24, 24)
	conflict_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	conflict_icon.visible = false
	conflict_icon.modulate = Color(1.0, 0.6, 0.0)  # Orange warning color
	add_child(conflict_icon)

	# Binding display label
	binding_label = Label.new()
	binding_label.custom_minimum_size = Vector2(180, 0)
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binding_label.add_theme_font_size_override("font_size", 18)
	add_child(binding_label)

	# Change button
	change_button = Button.new()
	change_button.text = "Ändern"
	change_button.custom_minimum_size = Vector2(100, 40)
	change_button.pressed.connect(_on_change_pressed)
	add_child(change_button)

	# Reset button (small)
	reset_button = Button.new()
	reset_button.text = "↻"
	reset_button.custom_minimum_size = Vector2(40, 40)
	reset_button.tooltip_text = "Auf Standard zurücksetzen"
	reset_button.pressed.connect(_on_reset_pressed)
	add_child(reset_button)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func setup(p_action_name: String, p_device_type: int) -> void:
	"""Sets up the button for a specific action and device type"""
	action_name = p_action_name
	device_type = p_device_type
	_update_display()

func set_state(state: State) -> void:
	"""Sets the visual state of the button"""
	current_state = state
	_update_visual_state()

func set_enabled(enabled: bool) -> void:
	"""Enables or disables the button"""
	if change_button:
		change_button.disabled = not enabled
	if reset_button:
		reset_button.disabled = not enabled

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_display() -> void:
	"""Updates the display based on current action"""
	if Engine.is_editor_hint():
		return

	if not action_label or not binding_label:
		return

	if action_name == "":
		action_label.text = "---"
		binding_label.text = "---"
		return

	if not InputRemappingManager:
		action_label.text = action_name
		binding_label.text = "---"
		return

	# Update action display name
	action_label.text = InputRemappingManager.get_action_display_name(action_name)

	# Update binding display
	binding_label.text = InputRemappingManager.get_current_binding_display(action_name, device_type)

func _update_visual_state() -> void:
	"""Updates visual state based on current state"""
	if not binding_label or not change_button:
		return

	match current_state:
		State.NORMAL:
			binding_label.add_theme_color_override("font_color", Color.WHITE)
			change_button.text = "Ändern"
			change_button.disabled = false
			conflict_icon.visible = false
		State.LISTENING:
			binding_label.text = "Drücke eine Taste..."
			binding_label.add_theme_color_override("font_color", Color.YELLOW)
			change_button.text = "Abbrechen"
			change_button.disabled = false
		State.CONFLICT:
			binding_label.add_theme_color_override("font_color", Color.ORANGE)
			conflict_icon.visible = true

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_change_pressed() -> void:
	"""Called when change button is pressed"""
	if current_state == State.LISTENING:
		# Cancel listening
		if InputRemappingManager:
			InputRemappingManager.stop_listening()
	else:
		# Request remapping
		remap_requested.emit(action_name)

func _on_reset_pressed() -> void:
	"""Called when reset button is pressed"""
	reset_requested.emit(action_name)

func _on_binding_changed(changed_action: String, _device_type_str: String) -> void:
	"""Called when any binding changes"""
	if changed_action == action_name or changed_action == "all":
		_update_display()
		if current_state == State.CONFLICT:
			set_state(State.NORMAL)

func _on_listening_started(listening_action: String) -> void:
	"""Called when listening mode starts"""
	if listening_action == action_name:
		set_state(State.LISTENING)
	else:
		# Disable other buttons during listening
		set_enabled(false)

func _on_listening_stopped() -> void:
	"""Called when listening mode stops"""
	if current_state == State.LISTENING:
		set_state(State.NORMAL)
	set_enabled(true)
	_update_display()

func _on_conflict_detected(target_action: String, conflicting_action: String, _input_display: String) -> void:
	"""Called when a conflict is detected"""
	if target_action == action_name:
		conflict_action = conflicting_action
		# Show conflict briefly then return to normal
		set_state(State.CONFLICT)
		# Auto-clear conflict state after delay
		await get_tree().create_timer(2.0).timeout
		if current_state == State.CONFLICT:
			set_state(State.NORMAL)
