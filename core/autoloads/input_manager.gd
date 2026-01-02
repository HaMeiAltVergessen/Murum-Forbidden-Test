extends Node
## InputManager handles hybrid input for local co-op
## P1: Keyboard + Mouse (always)
## P2: Any Controller (device-agnostic)

# ============ SIGNALS ============
signal p2_join_requested
signal p2_leave_requested

# ============ STATE ============
var p2_active: bool = false
var p2_controller_device: int = -1  # Which controller is P2?

# ============ CONTROLLER DETECTION ============
var detected_controllers: Array[int] = []

# ============ P1 INPUT STATE TRACKING ============
# Track button/key states for P1 (keyboard/mouse only when P2 active, keyboard+controller when solo)
var p1_button_states: Dictionary = {}  # action_name -> bool (pressed this frame?)
var p1_button_just_pressed: Dictionary = {}  # action_name -> bool (just pressed this frame?)
var p1_input_vector: Vector2 = Vector2.ZERO  # Movement input

# ============ P2 INPUT STATE TRACKING ============
# Track button states for P2's specific controller to prevent keyboard/P1 controller interference
var p2_button_states: Dictionary = {}  # action_name -> bool (pressed this frame?)
var p2_button_just_pressed: Dictionary = {}  # action_name -> bool (just pressed this frame?)

func _ready() -> void:
	print("[InputManager] Initialized - Hybrid Input (KB+M + Controller)")

	# Detect all available controllers
	detect_controllers()

	# Connect to controller hotplug signals
	Input.joy_connection_changed.connect(_on_controller_connection_changed)

func _process(_delta: float) -> void:
	"""Update input vectors and clear just_pressed states each frame"""
	# Update P1 input vector every frame (critical for co-op mode keyboard-only filtering)
	_update_p1_input_vector()

	# Reset just_pressed states at the end of each frame
	# This ensures just_pressed only returns true for one frame

	# P1 just_pressed cleanup
	for action in p1_button_just_pressed.keys():
		if p1_button_just_pressed[action]:
			p1_button_just_pressed[action] = false

	# P2 just_pressed cleanup
	for action in p2_button_just_pressed.keys():
		if p2_button_just_pressed[action]:
			# Mark as consumed for next frame
			p2_button_just_pressed[action] = false

func detect_controllers() -> void:
	"""Detect all connected controllers"""
	detected_controllers.clear()

	# Get all connected joypads
	var joypads = Input.get_connected_joypads()

	for device_id in joypads:
		detected_controllers.append(device_id)
		var controller_name = Input.get_joy_name(device_id)
		print("[InputManager] Controller detected: Device %d - %s" % [device_id, controller_name])

	if detected_controllers.size() == 0:
		print("[InputManager] No controllers detected")

func _on_controller_connection_changed(device: int, connected: bool) -> void:
	"""Handle controller hotplug events"""
	if connected:
		print("[InputManager] Controller connected: Device %d - %s" % [device, Input.get_joy_name(device)])
		detected_controllers.append(device)
	else:
		print("[InputManager] Controller disconnected: Device %d" % device)
		detected_controllers.erase(device)

		# If P2's controller disconnected, trigger P2 leave
		if device == p2_controller_device:
			print("[InputManager] P2's controller disconnected - triggering P2 leave")
			p2_leave_requested.emit()

func _input(event: InputEvent) -> void:
	# ============ P1 INPUT TRACKING ============
	# CRITICAL: When P2 is active, P1 should ONLY accept Keyboard/Mouse (NO controller)
	# When P2 is NOT active, P1 can use both Keyboard and Controller

	var is_keyboard_mouse = (event is InputEventKey or event is InputEventMouse or event is InputEventMouseButton)
	var is_controller = (event is InputEventJoypadButton or event is InputEventJoypadMotion)

	# P1 accepts this input if:
	# - It's keyboard/mouse (always) OR
	# - It's controller AND P2 is NOT active
	var p1_should_accept = is_keyboard_mouse or (is_controller and not p2_active)

	if p1_should_accept:
		# Track P1 actions
		# CRITICAL: Some actions don't have p1_ prefix in InputMap!
		# - With p1_ prefix: jump, attack, dash, block, move_left, move_right
		# - WITHOUT p1_ prefix: staff_throw, dodge, urgathon_charge, crouch

		# Actions WITH p1_ prefix
		var p1_prefixed_actions = ["jump", "attack", "dash", "block"]
		for action_name in p1_prefixed_actions:
			var full_action = "p1_" + action_name
			if InputMap.has_action(full_action) and event.is_action(full_action):
				p1_button_states[action_name] = event.is_pressed()
				if event.is_pressed() and not p1_button_just_pressed.get(action_name, false):
					p1_button_just_pressed[action_name] = true
				elif not event.is_pressed():
					p1_button_just_pressed[action_name] = false

		# Actions WITHOUT p1_ prefix (global actions that P1 uses)
		var p1_global_actions = ["staff_throw", "dodge", "urgathon_charge", "crouch"]
		for action_name in p1_global_actions:
			if InputMap.has_action(action_name) and event.is_action(action_name):
				p1_button_states[action_name] = event.is_pressed()
				if event.is_pressed() and not p1_button_just_pressed.get(action_name, false):
					p1_button_just_pressed[action_name] = true
				elif not event.is_pressed():
					p1_button_just_pressed[action_name] = false

		# Track P1 movement vector (WASD or analog stick)
		# Update movement vector based on current input states
		_update_p1_input_vector()

	# ============ P2 INPUT TRACKING ============
	# CRITICAL: Track P2 button states ONLY from P2's specific controller device
	if p2_active and p2_controller_device >= 0:
		# Only process events from P2's specific controller
		if event is InputEventJoypadButton and event.device == p2_controller_device:
			# Track all P2 shadow abilities (no staff_throw, parry, or urgathon - P2 has different abilities)
			var p2_actions = ["join", "attack", "jump", "dash",
				"shadow_scythe", "void_parry", "void_rift", "ultimate", "move_left", "move_right"]

			for action_name in p2_actions:
				var full_action = "p2_" + action_name
				if event.is_action(full_action):
					# Update pressed state
					p2_button_states[action_name] = event.is_pressed()
					# Track just_pressed (transition from not pressed to pressed)
					if event.is_pressed() and not p2_button_just_pressed.get(action_name, false):
						p2_button_just_pressed[action_name] = true
					elif not event.is_pressed():
						p2_button_just_pressed[action_name] = false

	# P2 Join-Request (any controller START button)
	if not p2_active and event is InputEventJoypadButton:
		if event.is_pressed() and event.button_index == JOY_BUTTON_START:
			# Store which controller is P2
			p2_controller_device = event.device

			if can_p2_join():
				print("[InputManager] P2 join requested from Controller Device %d" % p2_controller_device)
				p2_join_requested.emit()
			else:
				print("[InputManager] P2 join blocked")
				p2_controller_device = -1  # Reset

func _update_p1_input_vector() -> void:
	"""Update P1's movement vector based on current allowed inputs"""
	# CRITICAL: When P2 is active, use ONLY keyboard (not controller)
	# This must be called every frame in _process, not just in _input

	if p2_active:
		# Co-op mode: Keyboard ONLY (no controller for P1)
		# We can't use Input.get_vector() because it includes controller
		# Instead, check keyboard keys directly
		var x = 0.0
		var y = 0.0

		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			y += 1.0

		p1_input_vector = Vector2(x, y).normalized() if (x != 0 or y != 0) else Vector2.ZERO
	else:
		# Solo mode - accept both keyboard and controller
		# CRITICAL: InputMap has p1_move_left/right but NOT p1_move_up/down
		# Use the existing move_left/right/jump/crouch actions
		p1_input_vector = Input.get_vector("p1_move_left", "p1_move_right", "jump", "crouch")

func can_p2_join() -> bool:
	"""Check if P2 can join"""
	# Block join during cutscenes
	if GameManager and GameManager.has_method("is_in_cutscene") and GameManager.is_in_cutscene():
		print("[InputManager] Join blocked: Cutscene active")
		return false

	# Block join during Lythrun boss fight
	if GameManager and GameManager.get_flag("lythrun_boss_fight_active"):
		print("[InputManager] Join blocked: Boss fight active")
		return false

	# Check if at least one controller is available
	if detected_controllers.size() == 0:
		print("[InputManager] Join blocked: No controller detected")
		return false

	return true

func set_p2_active(active: bool) -> void:
	"""Set P2 active state"""
	p2_active = active

	if not active:
		# P2 leaving - clean up P2 state
		p2_controller_device = -1
		p2_button_states.clear()
		p2_button_just_pressed.clear()

		# CRITICAL: Clear P1 tracked states so P1 can use controller again
		p1_button_states.clear()
		p1_button_just_pressed.clear()
		p1_input_vector = Vector2.ZERO

		print("[InputManager] P2 left - P1 can now use controller again")

	print("[InputManager] P2 active: %s (Device: %d)" % [p2_active, p2_controller_device])

# ============ INPUT GETTERS ============

func get_p1_input_vector() -> Vector2:
	"""Get P1's movement input vector (Keyboard when P2 active, Keyboard+Controller when solo)"""
	return p1_input_vector

func get_p2_input_vector() -> Vector2:
	"""Get P2's movement input vector (Controller only, device-specific)"""
	if p2_controller_device == -1:
		return Vector2.ZERO

	# Get controller axes directly
	var x = Input.get_joy_axis(p2_controller_device, JOY_AXIS_LEFT_X)
	var y = Input.get_joy_axis(p2_controller_device, JOY_AXIS_LEFT_Y)

	# Apply deadzone
	if abs(x) < 0.2:
		x = 0.0
	if abs(y) < 0.2:
		y = 0.0

	return Vector2(x, y).normalized()

func is_p1_action_pressed(action: String) -> bool:
	"""Check if P1's action is pressed (Keyboard when P2 active, Keyboard+Controller when solo)"""
	# When P2 is active, use tracked button states (keyboard-only)
	# When P2 is NOT active, use Input.is_action_pressed (keyboard+controller)
	if p2_active:
		return p1_button_states.get(action, false)
	else:
		# Try with p1_ prefix first, then try global action name
		if InputMap.has_action("p1_" + action):
			return Input.is_action_pressed("p1_" + action)
		elif InputMap.has_action(action):
			return Input.is_action_pressed(action)
		else:
			return false

func is_p2_action_pressed(action: String) -> bool:
	"""Check if P2's action is pressed (Controller, device-specific)"""
	if p2_controller_device == -1:
		return false

	# CRITICAL: Use tracked button state from P2's specific controller ONLY
	# This prevents keyboard/mouse and other controllers from controlling P2
	return p2_button_states.get(action, false)

func is_p1_action_just_pressed(action: String) -> bool:
	"""Check if P1's action was just pressed (Keyboard when P2 active, Keyboard+Controller when solo)"""
	# When P2 is active, use tracked just_pressed states (keyboard-only)
	# When P2 is NOT active, use Input.is_action_just_pressed (keyboard+controller)
	if p2_active:
		return p1_button_just_pressed.get(action, false)
	else:
		# Try with p1_ prefix first, then try global action name
		if InputMap.has_action("p1_" + action):
			return Input.is_action_just_pressed("p1_" + action)
		elif InputMap.has_action(action):
			return Input.is_action_just_pressed(action)
		else:
			return false

func is_p2_action_just_pressed(action: String) -> bool:
	"""Check if P2's action was just pressed"""
	if p2_controller_device == -1:
		return false

	# CRITICAL: Use tracked just_pressed state from P2's specific controller ONLY
	# This prevents keyboard/mouse and other controllers from controlling P2
	return p2_button_just_pressed.get(action, false)

func is_p1_action_just_released(action: String) -> bool:
	"""Check if P1's action was just released"""
	return Input.is_action_just_released("p1_" + action)

func is_p2_action_just_released(action: String) -> bool:
	"""Check if P2's action was just released"""
	if p2_controller_device == -1:
		return false

	return Input.is_action_just_released("p2_" + action)

# ============ UTILITY ============

func get_p2_controller_name() -> String:
	"""Get the name of P2's controller"""
	if p2_controller_device >= 0:
		return Input.get_joy_name(p2_controller_device)
	return "None"

func has_controller() -> bool:
	"""Check if any controller is connected"""
	return detected_controllers.size() > 0
