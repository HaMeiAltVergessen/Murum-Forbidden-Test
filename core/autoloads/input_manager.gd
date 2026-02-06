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
var controller_count: int = 0

# ============ RT-MODIFIER TRACKING (COMMIT 022.5) ============
# Track RT trigger state for combo modifiers
var p1_rt_held: bool = false  # P1's RT (R key or Axis 7)
var p2_rt_held: bool = false  # P2's RT (Axis 7)
const RT_THRESHOLD: float = 0.5  # Trigger must be > 50% pressed
const RT_RELEASE_THRESHOLD: float = 0.2  # Hysteresis for release

# ============ P1 INPUT STATE TRACKING ============
# Track button/key states for P1 (keyboard/mouse only when P2 active, keyboard+controller when solo)
var p1_button_states: Dictionary = {}  # action_name -> bool (pressed this frame?)
var p1_button_just_pressed: Dictionary = {}  # action_name -> bool (just pressed this frame?)
var p1_button_just_pressed_time: Dictionary = {}  # action_name -> float (time when pressed in ms)
var p1_input_vector: Vector2 = Vector2.ZERO  # Movement input

# ============ P2 INPUT STATE TRACKING ============
# Track button states for P2's specific controller to prevent keyboard/P1 controller interference
var p2_button_states: Dictionary = {}  # action_name -> bool (pressed this frame?)
var p2_button_just_pressed: Dictionary = {}  # action_name -> bool (just pressed this frame?)
var p2_button_just_pressed_time: Dictionary = {}  # action_name -> float (time when pressed in ms)

# ============ INPUT CLEANUP SETTINGS ============
const INPUT_STATE_LIFETIME_MS: float = 100.0  # States live for 100ms (enough for multiple physics ticks)

func _ready() -> void:
	print("[InputManager] Initialized - Hybrid Input (KB+M + Controller)")

	# CRITICAL: Set process priority high so we run late
	# This helps ensure other nodes can read just_pressed states
	# Note: Godot 4.x doesn't have physics_process_priority, only process_priority
	process_priority = 1000  # Higher number = runs later

	# Detect all available controllers
	detect_controllers()

	# Connect to controller hotplug signals
	Input.joy_connection_changed.connect(_on_controller_connection_changed)

func _process(_delta: float) -> void:
	"""Update input vectors and clean up old just_pressed states"""
	# Update P1 input vector every frame (critical for co-op mode keyboard-only filtering)
	_update_p1_input_vector()

	# CRITICAL: Time-based cleanup of just_pressed states
	# States live for 100ms (enough to survive multiple physics ticks)
	# This is MORE RELIABLE than frame-based cleanup because it doesn't depend on execution order
	var current_time_ms = Time.get_ticks_msec()

	# P1 just_pressed cleanup - clear if older than 100ms
	for action in p1_button_just_pressed.keys():
		if p1_button_just_pressed[action]:
			var time_set = p1_button_just_pressed_time.get(action, 0.0)
			if (current_time_ms - time_set) > INPUT_STATE_LIFETIME_MS:
				p1_button_just_pressed[action] = false

	# P2 just_pressed cleanup - clear if older than 100ms
	for action in p2_button_just_pressed.keys():
		if p2_button_just_pressed[action]:
			var time_set = p2_button_just_pressed_time.get(action, 0.0)
			if (current_time_ms - time_set) > INPUT_STATE_LIFETIME_MS:
				p2_button_just_pressed[action] = false

func detect_controllers() -> void:
	"""Detect all connected controllers (COMMIT 022.5: Track count)"""
	detected_controllers.clear()

	# Get all connected joypads
	var joypads = Input.get_connected_joypads()

	for device_id in joypads:
		detected_controllers.append(device_id)
		var controller_name = Input.get_joy_name(device_id)
		print("[InputManager] Controller detected: Device %d - %s" % [device_id, controller_name])

	controller_count = detected_controllers.size()

	if controller_count == 0:
		print("[InputManager] No controllers detected")
	elif controller_count == 1:
		print("[InputManager] 1 controller detected - P1 uses Keyboard, P2 uses Controller")
	else:
		print("[InputManager] %d controllers detected - P1 can use Keyboard + Device 0 (if P2 doesn't use Device 0)" % controller_count)

func _on_controller_connection_changed(device: int, connected: bool) -> void:
	"""Handle controller hotplug events (COMMIT 022.5: P1 fallback on Device 0 disconnect)"""
	if connected:
		print("[InputManager] Controller connected: Device %d - %s" % [device, Input.get_joy_name(device)])
		detected_controllers.append(device)
		controller_count = detected_controllers.size()

		# Notify if P1 can now use controller (2+ controllers available)
		if controller_count >= 2 and not p2_active:
			print("[InputManager] P1 can now use Controller Device 0 + Keyboard")
	else:
		print("[InputManager] Controller disconnected: Device %d" % device)
		detected_controllers.erase(device)
		controller_count = detected_controllers.size()

		# If P2's controller disconnected, trigger P2 leave
		if device == p2_controller_device:
			print("[InputManager] P2's controller disconnected - triggering P2 leave")
			p2_leave_requested.emit()

		# If Device 0 disconnected and P1 was using it, P1 falls back to keyboard
		elif device == 0 and not p2_active:
			print("[InputManager] Controller Device 0 disconnected - P1 falls back to Keyboard only")
			# No explicit action needed - P1 will automatically use keyboard when controller is unavailable

func _input(event: InputEvent) -> void:
	# CRITICAL DEBUG: Log ALL joypad button events to see if they arrive at InputManager
	if event is InputEventJoypadButton and event.is_pressed():
		print("[InputManager _input] JoypadButton RECEIVED: Device=%d Button=%d p2_active=%s p2_device=%d" % [event.device, event.button_index, p2_active, p2_controller_device])

	# ============ RT-MODIFIER TRACKING (COMMIT 022.5) ============
	# Track P1 RT (Axis 7 on Device 0 OR R key)
	if not p2_active or controller_count >= 2:  # P1 can use controller
		# P1 Controller RT (Axis 7 on Device 0)
		if event is InputEventJoypadMotion and event.device == 0 and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var was_held = p1_rt_held
			p1_rt_held = event.axis_value > RT_THRESHOLD
			if not was_held and p1_rt_held:
				print("[InputManager] P1 RT pressed (Controller, %.2f)" % event.axis_value)
			elif was_held and event.axis_value < RT_RELEASE_THRESHOLD:
				p1_rt_held = false
				print("[InputManager] P1 RT released")
		# P1 Keyboard RT (R key)
		elif event is InputEventKey and event.physical_keycode == KEY_R:
			p1_rt_held = event.is_pressed()
			if p1_rt_held:
				print("[InputManager] P1 RT pressed (Keyboard)")
			else:
				print("[InputManager] P1 RT released (Keyboard)")

	# Track P2 RT (Axis 7 on P2's controller)
	if p2_active and p2_controller_device >= 0:
		if event is InputEventJoypadMotion and event.device == p2_controller_device and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var was_held = p2_rt_held
			p2_rt_held = event.axis_value > RT_THRESHOLD
			if not was_held and p2_rt_held:
				print("[InputManager] P2 RT pressed (%.2f)" % event.axis_value)
			elif was_held and event.axis_value < RT_RELEASE_THRESHOLD:
				p2_rt_held = false
				print("[InputManager] P2 RT released")

	# ============ P1 INPUT TRACKING (COMMIT 022.5: Hybrid-Input) ============
	# P1 Input Logic:
	# - Solo (P2 not active): Keyboard + Controller Device 0
	# - Coop with 1 Controller: Keyboard ONLY (controller reserved for P2)
	# - Coop with 2+ Controllers: Keyboard + Controller Device 0 (ONLY if P2 uses different device!)
	# CRITICAL: P1 can NEVER use Device 0 if P2 is using Device 0 (prevents cross-talk)

	var is_keyboard_mouse = (event is InputEventKey or event is InputEventMouse or event is InputEventMouseButton)
	var is_controller = (event is InputEventJoypadButton or event is InputEventJoypadMotion)
	var is_p1_controller = is_controller and ((event is InputEventJoypadButton and event.device == 0) or (event is InputEventJoypadMotion and event.device == 0))

	# P1 can use Controller Device 0 ONLY if P2 is not using it
	var p1_can_use_device_0 = not p2_active or (p2_active and p2_controller_device != 0)
	var p1_should_accept = is_keyboard_mouse or (is_p1_controller and p1_can_use_device_0)

	if p1_should_accept:
		# DEBUG: Log ALL P1 controller button presses
		if event is InputEventJoypadButton and event.device == 0:
			print("[InputManager P1 BUTTON] Device=%d Button=%d Pressed=%s" % [event.device, event.button_index, event.is_pressed()])

		# Track P1 actions (COMMIT 022.5: ALL actions now have p1_ prefix!)
		# Actions: jump, attack, dash, block, dodge, staff_throw, urgathon, wolkenbruch, crouch, interact, inventory, machtstoss
		var p1_actions = ["jump", "attack", "dash", "block", "dodge", "staff_throw", "urgathon", "wolkenbruch", "crouch", "interact", "inventory", "machtstoss"]
		for action_name in p1_actions:
			var full_action = "p1_" + action_name
			if InputMap.has_action(full_action) and event.is_action(full_action):
				p1_button_states[action_name] = event.is_pressed()
				if event.is_pressed() and not p1_button_just_pressed.get(action_name, false):
					p1_button_just_pressed[action_name] = true
					p1_button_just_pressed_time[action_name] = Time.get_ticks_msec()  # Track time
					print("[InputManager DEBUG] P1 action pressed: %s (time=%d)" % [action_name, Time.get_ticks_msec()])
				elif not event.is_pressed():
					p1_button_just_pressed[action_name] = false

		# Track P1 movement vector (WASD or analog stick)
		# Update movement vector based on current input states
		_update_p1_input_vector()

	# ============ P2 INPUT TRACKING ============
	# CRITICAL: Track P2 button states ONLY from P2's specific controller device
	if p2_active and p2_controller_device >= 0:
		# Process BUTTONS from P2's controller (COMMIT 022.5)
		if event is InputEventJoypadButton and event.device == p2_controller_device:
			# FINAL CORRECTED MAPPING - Xbox Controller (RB = Button 10):
			var button_to_action = {
				0: "jump",           # A button
				1: "dodge",          # B button
				2: "attack",         # X button (Void Strike)
				3: "shadow_scythe",  # Y button (base action, RT+Y for combo)
				4: "inventory",      # Back/Select button
				9: "dash",           # LB button (base action, RT+LB for Phase Shift combo)
				10: "void_orbs",     # RB button (Right Bumper) - Ultimate (CORRECTED!)
				12: "crouch",        # D-Pad Down - Crouch (Durchgangsboeden)
				# Button 6 (Start) currently unused - reserved for pause menu
				# Note: LT = Void Parry (Axis 6), RT = Combo Modifier (Axis 7)
				# Note: Phase Shift = RT+LB combo (handled in lythrun_player.gd)
				# Note: Void Rift = Attack+Down combo (handled in lythrun_player.gd)
			}

			# DEBUG: Log ALL button presses (even unmapped ones)
			print("[InputManager P2 BUTTON] Device=%d Button=%d Pressed=%s" % [event.device, event.button_index, event.is_pressed()])

			# Check if this button has a mapped action
			if event.button_index in button_to_action:
				var action_name = button_to_action[event.button_index]

				# Update pressed state
				p2_button_states[action_name] = event.is_pressed()

				# Track just_pressed (transition from not pressed to pressed)
				if event.is_pressed() and not p2_button_just_pressed.get(action_name, false):
					p2_button_just_pressed[action_name] = true
					p2_button_just_pressed_time[action_name] = Time.get_ticks_msec()  # Track time
					print("[InputManager DEBUG] P2 action pressed: %s (button=%d, time=%d)" % [action_name, event.button_index, Time.get_ticks_msec()])
				elif not event.is_pressed():
					p2_button_just_pressed[action_name] = false
			else:
				# Log unmapped buttons
				if event.is_pressed():
					print("[InputManager P2 UNMAPPED] Button %d pressed (not mapped to any action)" % event.button_index)

		# Process TRIGGERS (LT/RT are axes, not buttons!)
		if event is InputEventJoypadMotion and event.device == p2_controller_device:
			const TRIGGER_THRESHOLD = 0.5  # Trigger must be pressed > 50%

			# LT = Left Trigger = Axis 6 = Void Parry
			if event.axis == JOY_AXIS_TRIGGER_LEFT:
				var was_pressed = p2_button_states.get("void_parry", false)
				var is_pressed = event.axis_value > TRIGGER_THRESHOLD

				p2_button_states["void_parry"] = is_pressed

				# Track just_pressed
				if is_pressed and not was_pressed:
					p2_button_just_pressed["void_parry"] = true
					p2_button_just_pressed_time["void_parry"] = Time.get_ticks_msec()
					print("[InputManager DEBUG] P2 LT (void_parry) pressed: %.2f" % event.axis_value)
				elif not is_pressed and was_pressed:
					p2_button_just_pressed["void_parry"] = false

			# RT = Right Trigger = Axis 7 = Void Orbs (Ultimate)
			elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
				var was_pressed = p2_button_states.get("ultimate", false)
				var is_pressed = event.axis_value > TRIGGER_THRESHOLD

				p2_button_states["ultimate"] = is_pressed

				# Track just_pressed
				if is_pressed and not was_pressed:
					p2_button_just_pressed["ultimate"] = true
					p2_button_just_pressed_time["ultimate"] = Time.get_ticks_msec()
					print("[InputManager DEBUG] P2 RT (ultimate) pressed: %.2f" % event.axis_value)
				elif not is_pressed and was_pressed:
					p2_button_just_pressed["ultimate"] = false

	# P2 Join-Request (Button 6 = Start on Xbox One For Windows)
	if not p2_active and event is InputEventJoypadButton:
		if event.is_pressed() and event.button_index == 6:  # Start button
			# Store which controller is P2
			p2_controller_device = event.device

			if can_p2_join():
				print("[InputManager] P2 join requested from Controller Device %d" % p2_controller_device)
				p2_join_requested.emit()
			else:
				print("[InputManager] P2 join blocked")
				p2_controller_device = -1  # Reset

func _update_p1_input_vector() -> void:
	"""Update P1's movement vector based on current allowed inputs (COMMIT 022.5: Hybrid-Input)"""
	# P1 Input Logic:
	# - Solo (P2 not active): Keyboard + Controller Device 0
	# - Coop with P2 using Device 0: Keyboard ONLY (prevent cross-talk!)
	# - Coop with P2 using other device: Keyboard + Controller Device 0

	# Use keyboard-only if P2 is using Device 0 (prevents cross-talk)
	if p2_active and (controller_count < 2 or p2_controller_device == 0):
		# Keyboard ONLY mode (either only 1 controller OR P2 is using Device 0)
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
		# Solo mode OR P2 uses different controller (not Device 0)
		# Use Input.get_vector with p1_move_left/right actions (includes keyboard + Device 0)
		p1_input_vector = Input.get_vector("p1_move_left", "p1_move_right", "p1_jump", "p1_crouch")

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
	else:
		print("[InputManager] *** P2 JOINED *** Device: %d" % p2_controller_device)

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

# ============ RT-MODIFIER GETTERS (COMMIT 022.5) ============

func is_p1_rt_held() -> bool:
	"""Check if P1's RT modifier is held (R key or Axis 7 on Device 0)"""
	return p1_rt_held

func is_p2_rt_held() -> bool:
	"""Check if P2's RT modifier is held (Axis 7 on P2's controller)"""
	return p2_rt_held

func get_controller_count() -> int:
	"""Get number of connected controllers"""
	return controller_count
