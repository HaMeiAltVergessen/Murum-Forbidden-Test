extends Node

## InputRemappingManager - Verwaltet anpassbare Tastenbelegungen
## Separate Bindings für P1 (Keyboard+Controller) und P2 (Controller only)
## Persistente Speicherung in user://input_config.cfg

# ============================================================================
# CONSTANTS
# ============================================================================

const CONFIG_FILE = "user://input_config.cfg"

# Reserved keys that cannot be remapped
const RESERVED_KEYS: Array[int] = [
	KEY_ESCAPE,       # Menu
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
	KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
	KEY_PRINT,        # Screenshot
	KEY_PAUSE,        # System pause
	KEY_INSERT,       # System
	KEY_DELETE,       # System
	KEY_HOME, KEY_END,
	KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK,
]

# Reserved gamepad buttons (navigation)
const RESERVED_GAMEPAD_BUTTONS: Array[int] = [
	JOY_BUTTON_GUIDE,   # Xbox button / PS button
	JOY_BUTTON_MISC1,   # Share/Capture button
	JOY_BUTTON_START,   # Reserved for pause menu
]

# ============================================================================
# SIGNALS
# ============================================================================

signal binding_changed(action_name: String, device_type: String)
signal listening_started(action_name: String)
signal listening_stopped()
signal conflict_detected(action_name: String, conflicting_action: String, input_display: String)
signal changes_applied()
signal changes_reverted()

# ============================================================================
# ENUMS
# ============================================================================

enum Category {
	MOVEMENT,
	ACTION,
	COMBAT,
	ABILITIES
}

enum DeviceType {
	KEYBOARD,
	MOUSE,
	GAMEPAD
}

# ============================================================================
# DATA STRUCTURES
# ============================================================================

## Structure for each remappable action
class ActionData:
	var display_name: String
	var display_name_de: String  # German display name
	var category: int  # Category enum
	var player: int  # 1 or 2
	var keyboard_events: Array[InputEvent] = []
	var mouse_events: Array[InputEvent] = []
	var gamepad_events: Array[InputEvent] = []
	var default_keyboard: Array[InputEvent] = []
	var default_mouse: Array[InputEvent] = []
	var default_gamepad: Array[InputEvent] = []

	func _init(p_display_name: String, p_display_name_de: String, p_category: int, p_player: int):
		display_name = p_display_name
		display_name_de = p_display_name_de
		category = p_category
		player = p_player

# ============================================================================
# STATE
# ============================================================================

## All remappable actions
var remappable_actions: Dictionary = {}  # action_name -> ActionData

## Currently listening for input
var is_listening: bool = false
var listening_action: String = ""
var listening_device_type: int = DeviceType.KEYBOARD

## Pending changes (not yet applied)
var pending_changes: Dictionary = {}  # action_name -> {device_type: events}

## Has unsaved changes
var has_unsaved_changes: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Ensure we receive input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Define all remappable actions
	_define_remappable_actions()

	# Load defaults from current InputMap
	_load_defaults_from_inputmap()

	# Load custom bindings from config file
	load_bindings()

	print("[InputRemappingManager] Initialized with %d remappable actions" % remappable_actions.size())

func _define_remappable_actions() -> void:
	"""Defines all actions that can be remapped"""

	# ============ PLAYER 1 ============

	# Movement category
	remappable_actions["p1_dash"] = ActionData.new(
		"Dash", "Dash",
		Category.MOVEMENT, 1
	)
	remappable_actions["p1_dodge"] = ActionData.new(
		"Dodge Roll", "Ausweichrolle",
		Category.MOVEMENT, 1
	)

	# Action category
	remappable_actions["p1_interact"] = ActionData.new(
		"Interact", "Interagieren",
		Category.ACTION, 1
	)
	remappable_actions["p1_inventory"] = ActionData.new(
		"Inventory", "Inventar",
		Category.ACTION, 1
	)
	remappable_actions["p1_crouch"] = ActionData.new(
		"Crouch", "Ducken",
		Category.ACTION, 1
	)

	# Combat category
	remappable_actions["p1_staff_throw"] = ActionData.new(
		"Staff Attack", "Stabwurf",
		Category.COMBAT, 1
	)

	# Abilities category
	remappable_actions["p1_urgathon"] = ActionData.new(
		"Urgathon's Will", "Urgathons Wille",
		Category.ABILITIES, 1
	)
	remappable_actions["p1_urteil_der_zerstoerung"] = ActionData.new(
		"Judgment of Destruction", "Urteil der Zerstörung",
		Category.ABILITIES, 1
	)
	remappable_actions["p1_machtstoss"] = ActionData.new(
		"Power Strike", "Machtstoß",
		Category.ABILITIES, 1
	)

	# ============ PLAYER 2 ============

	# Movement category
	remappable_actions["p2_dash"] = ActionData.new(
		"Dash", "Dash",
		Category.MOVEMENT, 2
	)
	remappable_actions["p2_dodge"] = ActionData.new(
		"Dodge Roll", "Ausweichrolle",
		Category.MOVEMENT, 2
	)

	# Action category
	remappable_actions["p2_interact"] = ActionData.new(
		"Interact", "Interagieren",
		Category.ACTION, 2
	)
	remappable_actions["p2_inventory"] = ActionData.new(
		"Inventory", "Inventar",
		Category.ACTION, 2
	)

	remappable_actions["p2_crouch"] = ActionData.new(
		"Crouch", "Ducken",
		Category.ACTION, 2
	)

	# Combat category
	remappable_actions["p2_shadow_scythe"] = ActionData.new(
		"Shadow Scythe", "Schattensensnse",
		Category.COMBAT, 2
	)

	# Abilities category
	remappable_actions["p2_void_parry"] = ActionData.new(
		"Void Parry", "Leerenparade",
		Category.ABILITIES, 2
	)
	remappable_actions["p2_phase_shift"] = ActionData.new(
		"Phase Shift", "Phasenverschiebung",
		Category.ABILITIES, 2
	)
	remappable_actions["p2_void_orbs"] = ActionData.new(
		"Void Orbs", "Leerenkugeln",
		Category.ABILITIES, 2
	)

func _load_defaults_from_inputmap() -> void:
	"""Loads current InputMap settings as defaults"""
	for action_name in remappable_actions:
		if not InputMap.has_action(action_name):
			push_warning("[InputRemappingManager] Action not found in InputMap: %s" % action_name)
			continue

		var action_data: ActionData = remappable_actions[action_name]
		var events = InputMap.action_get_events(action_name)

		for event in events:
			if event is InputEventKey:
				action_data.keyboard_events.append(event.duplicate())
				action_data.default_keyboard.append(event.duplicate())
			elif event is InputEventMouseButton:
				action_data.mouse_events.append(event.duplicate())
				action_data.default_mouse.append(event.duplicate())
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				action_data.gamepad_events.append(event.duplicate())
				action_data.default_gamepad.append(event.duplicate())

# ============================================================================
# INPUT HANDLING (for listening mode)
# ============================================================================

func _input(event: InputEvent) -> void:
	if not is_listening:
		return

	# Cancel listening with Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		stop_listening()
		get_viewport().set_input_as_handled()
		return

	# Handle keyboard input
	if listening_device_type == DeviceType.KEYBOARD and event is InputEventKey and event.pressed:
		if _is_key_valid(event.keycode):
			_propose_new_binding(event)
			get_viewport().set_input_as_handled()
		return

	# Handle mouse input
	if listening_device_type == DeviceType.MOUSE and event is InputEventMouseButton and event.pressed:
		if _is_mouse_button_valid(event.button_index):
			_propose_new_binding(event)
			get_viewport().set_input_as_handled()
		return

	# Handle gamepad input
	if listening_device_type == DeviceType.GAMEPAD:
		if event is InputEventJoypadButton and event.pressed:
			if _is_gamepad_button_valid(event.button_index):
				# Create a new event without device-specific info
				var new_event = InputEventJoypadButton.new()
				new_event.button_index = event.button_index
				_propose_new_binding(new_event)
				get_viewport().set_input_as_handled()
			return
		elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
			# Only accept trigger axes (LT/RT) - axes 4,5,6,7
			if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
				var new_event = InputEventJoypadMotion.new()
				new_event.axis = event.axis
				new_event.axis_value = sign(event.axis_value)
				_propose_new_binding(new_event)
				get_viewport().set_input_as_handled()
			return

# ============================================================================
# LISTENING MODE
# ============================================================================

func start_listening(action_name: String, device_type: int) -> void:
	"""Starts listening for new input binding"""
	if not remappable_actions.has(action_name):
		push_error("[InputRemappingManager] Unknown action: %s" % action_name)
		return

	# Release GUI focus so gamepad/keyboard input is not intercepted by UI
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

	is_listening = true
	listening_action = action_name
	listening_device_type = device_type

	print("[InputRemappingManager] Listening for input: %s (device: %d)" % [action_name, device_type])
	listening_started.emit(action_name)

func stop_listening() -> void:
	"""Stops listening for input"""
	is_listening = false
	listening_action = ""
	listening_stopped.emit()
	print("[InputRemappingManager] Stopped listening")

func _propose_new_binding(event: InputEvent) -> void:
	"""Proposes a new binding and checks for conflicts"""
	var action_data: ActionData = remappable_actions[listening_action]
	var device_type_str = _get_device_type_string(listening_device_type)

	# Check for conflicts with other actions of same player
	var conflict = _check_conflict(listening_action, event)
	if conflict != "":
		var input_display = get_event_display_name(event)
		conflict_detected.emit(listening_action, conflict, input_display)
		# Still apply the binding, the UI will handle showing the conflict

	# Store the new binding
	match listening_device_type:
		DeviceType.KEYBOARD:
			action_data.keyboard_events.clear()
			action_data.keyboard_events.append(event)
		DeviceType.MOUSE:
			action_data.mouse_events.clear()
			action_data.mouse_events.append(event)
		DeviceType.GAMEPAD:
			action_data.gamepad_events.clear()
			action_data.gamepad_events.append(event)

	has_unsaved_changes = true
	stop_listening()
	binding_changed.emit(listening_action, device_type_str)

# ============================================================================
# CONFLICT DETECTION
# ============================================================================

func _check_conflict(action_name: String, event: InputEvent) -> String:
	"""Checks if the input is already used by another action"""
	var action_data: ActionData = remappable_actions[action_name]
	var player = action_data.player

	for other_action in remappable_actions:
		if other_action == action_name:
			continue

		var other_data: ActionData = remappable_actions[other_action]

		# Only check conflicts within same player
		if other_data.player != player:
			continue

		var events_to_check: Array[InputEvent] = []

		if event is InputEventKey:
			events_to_check = other_data.keyboard_events
		elif event is InputEventMouseButton:
			events_to_check = other_data.mouse_events
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			events_to_check = other_data.gamepad_events

		for other_event in events_to_check:
			if _events_match(event, other_event):
				return other_action

	return ""

func _events_match(event1: InputEvent, event2: InputEvent) -> bool:
	"""Checks if two events are the same input"""
	if event1 is InputEventKey and event2 is InputEventKey:
		return event1.physical_keycode == event2.physical_keycode or event1.keycode == event2.keycode
	elif event1 is InputEventMouseButton and event2 is InputEventMouseButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadButton and event2 is InputEventJoypadButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadMotion and event2 is InputEventJoypadMotion:
		return event1.axis == event2.axis and sign(event1.axis_value) == sign(event2.axis_value)
	return false

# ============================================================================
# VALIDATION
# ============================================================================

func _is_key_valid(keycode: int) -> bool:
	"""Checks if a key is valid for remapping"""
	return keycode not in RESERVED_KEYS

func _is_mouse_button_valid(button: int) -> bool:
	"""Checks if a mouse button is valid for remapping"""
	# Allow left, right, middle, and extra buttons
	return button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
					  MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

func _is_gamepad_button_valid(button: int) -> bool:
	"""Checks if a gamepad button is valid for remapping"""
	return button not in RESERVED_GAMEPAD_BUTTONS

# ============================================================================
# APPLY & REVERT CHANGES
# ============================================================================

func apply_changes() -> void:
	"""Applies all current bindings to the InputMap"""
	for action_name in remappable_actions:
		if not InputMap.has_action(action_name):
			continue

		var action_data: ActionData = remappable_actions[action_name]

		# Clear current events
		InputMap.action_erase_events(action_name)

		# Add keyboard events
		for event in action_data.keyboard_events:
			InputMap.action_add_event(action_name, event)

		# Add mouse events
		for event in action_data.mouse_events:
			InputMap.action_add_event(action_name, event)

		# Add gamepad events
		for event in action_data.gamepad_events:
			InputMap.action_add_event(action_name, event)

	has_unsaved_changes = false
	changes_applied.emit()
	print("[InputRemappingManager] Changes applied to InputMap")

func revert_changes() -> void:
	"""Reverts all bindings to the last saved state"""
	# Reload from config file
	load_bindings()
	has_unsaved_changes = false
	changes_reverted.emit()
	print("[InputRemappingManager] Changes reverted")

func reset_action_to_default(action_name: String) -> void:
	"""Resets a single action to its default bindings"""
	if not remappable_actions.has(action_name):
		return

	var action_data: ActionData = remappable_actions[action_name]

	action_data.keyboard_events.clear()
	for event in action_data.default_keyboard:
		action_data.keyboard_events.append(event.duplicate())

	action_data.mouse_events.clear()
	for event in action_data.default_mouse:
		action_data.mouse_events.append(event.duplicate())

	action_data.gamepad_events.clear()
	for event in action_data.default_gamepad:
		action_data.gamepad_events.append(event.duplicate())

	has_unsaved_changes = true
	binding_changed.emit(action_name, "all")

func reset_all_to_defaults() -> void:
	"""Resets all actions to their default bindings"""
	for action_name in remappable_actions:
		var action_data: ActionData = remappable_actions[action_name]

		action_data.keyboard_events.clear()
		for event in action_data.default_keyboard:
			action_data.keyboard_events.append(event.duplicate())

		action_data.mouse_events.clear()
		for event in action_data.default_mouse:
			action_data.mouse_events.append(event.duplicate())

		action_data.gamepad_events.clear()
		for event in action_data.default_gamepad:
			action_data.gamepad_events.append(event.duplicate())

	has_unsaved_changes = true
	print("[InputRemappingManager] All bindings reset to defaults")

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save_bindings() -> bool:
	"""Saves current bindings to config file"""
	var config = ConfigFile.new()

	for action_name in remappable_actions:
		var action_data: ActionData = remappable_actions[action_name]

		# Save keyboard bindings
		var keyboard_data: Array = []
		for event in action_data.keyboard_events:
			if event is InputEventKey:
				keyboard_data.append({
					"type": "key",
					"keycode": event.keycode,
					"physical_keycode": event.physical_keycode
				})
		config.set_value(action_name, "keyboard", keyboard_data)

		# Save mouse bindings
		var mouse_data: Array = []
		for event in action_data.mouse_events:
			if event is InputEventMouseButton:
				mouse_data.append({
					"type": "mouse",
					"button_index": event.button_index
				})
		config.set_value(action_name, "mouse", mouse_data)

		# Save gamepad bindings
		var gamepad_data: Array = []
		for event in action_data.gamepad_events:
			if event is InputEventJoypadButton:
				gamepad_data.append({
					"type": "button",
					"button_index": event.button_index
				})
			elif event is InputEventJoypadMotion:
				gamepad_data.append({
					"type": "axis",
					"axis": event.axis,
					"axis_value": event.axis_value
				})
		config.set_value(action_name, "gamepad", gamepad_data)

	var error = config.save(CONFIG_FILE)
	if error != OK:
		push_error("[InputRemappingManager] Failed to save bindings: %d" % error)
		return false

	has_unsaved_changes = false
	print("[InputRemappingManager] Bindings saved to %s" % CONFIG_FILE)
	return true

func load_bindings() -> bool:
	"""Loads bindings from config file"""
	var config = ConfigFile.new()
	var error = config.load(CONFIG_FILE)

	if error != OK:
		print("[InputRemappingManager] No config file found, using defaults")
		# Apply defaults to InputMap
		apply_changes()
		return false

	for action_name in remappable_actions:
		var action_data: ActionData = remappable_actions[action_name]

		# Load keyboard bindings
		var keyboard_data = config.get_value(action_name, "keyboard", [])
		if keyboard_data.size() > 0:
			action_data.keyboard_events.clear()
			for data in keyboard_data:
				if data.get("type") == "key":
					var event = InputEventKey.new()
					event.keycode = data.get("keycode", 0)
					event.physical_keycode = data.get("physical_keycode", 0)
					action_data.keyboard_events.append(event)

		# Load mouse bindings
		var mouse_data = config.get_value(action_name, "mouse", [])
		if mouse_data.size() > 0:
			action_data.mouse_events.clear()
			for data in mouse_data:
				if data.get("type") == "mouse":
					var event = InputEventMouseButton.new()
					event.button_index = data.get("button_index", 0)
					action_data.mouse_events.append(event)

		# Load gamepad bindings
		var gamepad_data = config.get_value(action_name, "gamepad", [])
		if gamepad_data.size() > 0:
			action_data.gamepad_events.clear()
			for data in gamepad_data:
				if data.get("type") == "button":
					var event = InputEventJoypadButton.new()
					event.button_index = data.get("button_index", 0)
					action_data.gamepad_events.append(event)
				elif data.get("type") == "axis":
					var event = InputEventJoypadMotion.new()
					event.axis = data.get("axis", 0)
					event.axis_value = data.get("axis_value", 1.0)
					action_data.gamepad_events.append(event)

	# Apply loaded bindings to InputMap
	apply_changes()
	print("[InputRemappingManager] Bindings loaded from %s" % CONFIG_FILE)
	return true

# ============================================================================
# GETTERS
# ============================================================================

func get_actions_for_player(player: int) -> Array:
	"""Returns all remappable actions for a specific player"""
	var result: Array = []
	for action_name in remappable_actions:
		var action_data: ActionData = remappable_actions[action_name]
		if action_data.player == player:
			result.append(action_name)
	return result

func get_actions_by_category(player: int, category: int) -> Array:
	"""Returns actions for a player filtered by category"""
	var result: Array = []
	for action_name in remappable_actions:
		var action_data: ActionData = remappable_actions[action_name]
		if action_data.player == player and action_data.category == category:
			result.append(action_name)
	return result

func get_action_display_name(action_name: String, use_german: bool = true) -> String:
	"""Returns the display name for an action"""
	if not remappable_actions.has(action_name):
		return action_name

	var action_data: ActionData = remappable_actions[action_name]
	return action_data.display_name_de if use_german else action_data.display_name

func get_current_binding_display(action_name: String, device_type: int) -> String:
	"""Returns the display string for current binding"""
	if not remappable_actions.has(action_name):
		return "---"

	var action_data: ActionData = remappable_actions[action_name]
	var events: Array[InputEvent] = []

	match device_type:
		DeviceType.KEYBOARD:
			events = action_data.keyboard_events
		DeviceType.MOUSE:
			events = action_data.mouse_events
		DeviceType.GAMEPAD:
			events = action_data.gamepad_events

	if events.is_empty():
		return "---"

	var display_parts: Array[String] = []
	for event in events:
		display_parts.append(get_event_display_name(event))

	return ", ".join(display_parts)

func get_event_display_name(event: InputEvent) -> String:
	"""Returns a human-readable name for an input event"""
	if event is InputEventKey:
		var key_name = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		return key_name if key_name != "" else "Key %d" % event.keycode

	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Linke Maustaste"
			MOUSE_BUTTON_RIGHT:
				return "Rechte Maustaste"
			MOUSE_BUTTON_MIDDLE:
				return "Mittlere Maustaste"
			MOUSE_BUTTON_XBUTTON1:
				return "Maus Taste 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Maus Taste 5"
			MOUSE_BUTTON_WHEEL_UP:
				return "Mausrad hoch"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Mausrad runter"
			_:
				return "Maus Taste %d" % event.button_index

	elif event is InputEventJoypadButton:
		return _get_gamepad_button_name(event.button_index)

	elif event is InputEventJoypadMotion:
		return _get_gamepad_axis_name(event.axis, event.axis_value)

	return "???"

func _get_gamepad_button_name(button: int) -> String:
	"""Returns display name for gamepad button (Xbox style)"""
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Oben"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Unten"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Links"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Rechts"
		_:
			return "Button %d" % button

func _get_gamepad_axis_name(axis: int, value: float) -> String:
	"""Returns display name for gamepad axis"""
	var direction = "+" if value > 0 else "-"
	match axis:
		JOY_AXIS_LEFT_X:
			return "L-Stick " + ("Rechts" if value > 0 else "Links")
		JOY_AXIS_LEFT_Y:
			return "L-Stick " + ("Unten" if value > 0 else "Oben")
		JOY_AXIS_RIGHT_X:
			return "R-Stick " + ("Rechts" if value > 0 else "Links")
		JOY_AXIS_RIGHT_Y:
			return "R-Stick " + ("Unten" if value > 0 else "Oben")
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		_:
			return "Axis %d %s" % [axis, direction]

func _get_device_type_string(device_type: int) -> String:
	"""Converts device type enum to string"""
	match device_type:
		DeviceType.KEYBOARD:
			return "keyboard"
		DeviceType.MOUSE:
			return "mouse"
		DeviceType.GAMEPAD:
			return "gamepad"
	return "unknown"

func get_category_name(category: int, use_german: bool = true) -> String:
	"""Returns display name for category"""
	if use_german:
		match category:
			Category.MOVEMENT:
				return "Bewegung"
			Category.ACTION:
				return "Aktionen"
			Category.COMBAT:
				return "Kampf"
			Category.ABILITIES:
				return "Fähigkeiten"
	else:
		match category:
			Category.MOVEMENT:
				return "Movement"
			Category.ACTION:
				return "Actions"
			Category.COMBAT:
				return "Combat"
			Category.ABILITIES:
				return "Abilities"
	return "Unknown"
