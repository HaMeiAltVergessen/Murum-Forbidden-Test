extends Node
## InputManager handles hybrid input for local co-op
## P1: Keyboard + Mouse (always)
## P2: Any Controller (device-agnostic)
class_name InputManager

# ============ SIGNALS ============
signal p2_join_requested
signal p2_leave_requested

# ============ STATE ============
var p2_active: bool = false
var p2_controller_device: int = -1  # Which controller is P2?

# ============ CONTROLLER DETECTION ============
var detected_controllers: Array[int] = []

func _ready() -> void:
	print("[InputManager] Initialized - Hybrid Input (KB+M + Controller)")

	# Detect all available controllers
	detect_controllers()

	# Connect to controller hotplug signals
	Input.joy_connection_changed.connect(_on_controller_connection_changed)

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
		p2_controller_device = -1

	print("[InputManager] P2 active: %s (Device: %d)" % [p2_active, p2_controller_device])

# ============ INPUT GETTERS ============

func get_p1_input_vector() -> Vector2:
	"""Get P1's movement input vector (Keyboard only)"""
	return Input.get_vector("p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down")

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
	"""Check if P1's action is pressed (Keyboard/Mouse)"""
	return Input.is_action_pressed("p1_" + action)

func is_p2_action_pressed(action: String) -> bool:
	"""Check if P2's action is pressed (Controller, device-specific)"""
	if p2_controller_device == -1:
		return false

	# Check if the specific controller has this button pressed
	return Input.is_action_pressed("p2_" + action)

func is_p1_action_just_pressed(action: String) -> bool:
	"""Check if P1's action was just pressed"""
	return Input.is_action_just_pressed("p1_" + action)

func is_p2_action_just_pressed(action: String) -> bool:
	"""Check if P2's action was just pressed"""
	if p2_controller_device == -1:
		return false

	return Input.is_action_just_pressed("p2_" + action)

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
