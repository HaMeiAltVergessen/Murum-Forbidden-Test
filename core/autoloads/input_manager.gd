extends Node
## InputManager handles dual-controller input for local co-op

# ============ SIGNALS ============
signal p2_join_requested
signal p2_leave_requested

# ============ STATE ============
var p2_active: bool = false

func _ready() -> void:
	print("[InputManager] Initialized")

func _input(event: InputEvent) -> void:
	# P2 Join-Request (only when not active)
	if not p2_active and event.is_action_pressed("p2_join"):
		if can_p2_join():
			print("[InputManager] P2 join requested")
			p2_join_requested.emit()
		else:
			print("[InputManager] P2 join blocked")

func can_p2_join() -> bool:
	"""Check if P2 can join (not blocked by cutscenes or boss fights)"""
	# Check if cutscene is active
	if GameManager.has_method("is_in_cutscene") and GameManager.is_in_cutscene():
		return false

	# Check if Lythrun boss fight is active
	if GameManager.get_flag("lythrun_boss_fight_active"):
		return false

	return true

func set_p2_active(active: bool) -> void:
	"""Set P2 active state"""
	p2_active = active
	print("[InputManager] P2 active: ", p2_active)

# ============ HELPER FUNCTIONS ============

func get_p1_input_vector() -> Vector2:
	"""Get P1's movement input vector"""
	return Input.get_vector("p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down")

func get_p2_input_vector() -> Vector2:
	"""Get P2's movement input vector"""
	return Input.get_vector("p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down")

func is_p1_action_pressed(action: String) -> bool:
	"""Check if P1's action is pressed"""
	return Input.is_action_pressed("p1_" + action)

func is_p2_action_pressed(action: String) -> bool:
	"""Check if P2's action is pressed"""
	return Input.is_action_pressed("p2_" + action)

func is_p1_action_just_pressed(action: String) -> bool:
	"""Check if P1's action was just pressed"""
	return Input.is_action_just_pressed("p1_" + action)

func is_p2_action_just_pressed(action: String) -> bool:
	"""Check if P2's action was just pressed"""
	return Input.is_action_just_pressed("p2_" + action)

func is_p1_action_just_released(action: String) -> bool:
	"""Check if P1's action was just released"""
	return Input.is_action_just_released("p1_" + action)

func is_p2_action_just_released(action: String) -> bool:
	"""Check if P2's action was just released"""
	return Input.is_action_just_released("p2_" + action)
