extends PuzzleController
class_name TimedDoorController

## R4 - Zeitfenster-Tür Controller
## Door opens for limited time when switch is activated

# ============================================================================
# EXPORTS
# ============================================================================

@export var door_open_duration: float = 3.0

# ============================================================================
# REFERENCES
# ============================================================================

var timed_switch: Node = null
var timed_door: Node = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	super._ready()
	puzzle_name = "Zeitfenster-Tür"

	# Find switch and door
	await get_tree().process_frame
	_find_components()

# ============================================================================
# COMPONENT SETUP
# ============================================================================

func _find_components() -> void:
	"""Finds TimedSwitch and TimedDoor siblings in parent"""
	var parent_node = get_parent()
	if not parent_node:
		return

	for child in parent_node.get_children():
		if child.has_signal("switch_activated"):
			timed_switch = child
			timed_switch.switch_activated.connect(_on_switch_activated)
			print("[TimedDoorPuzzle] Found switch: %s" % child.name)

		if child.has_method("open"):
			timed_door = child
			print("[TimedDoorPuzzle] Found door: %s" % child.name)

func set_switch(switch: Node) -> void:
	"""Manually sets the switch"""
	timed_switch = switch
	if switch.has_signal("switch_activated"):
		switch.switch_activated.connect(_on_switch_activated)

func set_door(door: Node) -> void:
	"""Manually sets the door"""
	timed_door = door

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_switch_activated(_switch_id: int, _activator: Node2D) -> void:
	"""Handles switch activation - opens door temporarily"""
	if not timed_door or not timed_door.has_method("open_timed"):
		push_warning("[TimedDoorPuzzle] No timed door connected!")
		return

	print("[TimedDoorPuzzle] Switch activated - opening door for %.1fs" % door_open_duration)
	timed_door.open_timed(door_open_duration)

	# First activation counts as solving the puzzle
	if not is_solved:
		solve()

# ============================================================================
# LOAD HANDLING
# ============================================================================

func _on_load_solved() -> void:
	"""Called when puzzle is already solved on load - removes switch and opens door permanently"""
	print("[TimedDoorPuzzle] Already solved, opening door permanently and removing switch")

	# Open door permanently
	if timed_door and is_instance_valid(timed_door):
		if timed_door.has_method("open_permanently"):
			timed_door.open_permanently()
		elif timed_door.has_method("open"):
			timed_door.open()

	# Remove the switch since puzzle is complete
	if timed_switch and is_instance_valid(timed_switch):
		timed_switch.queue_free()
		timed_switch = null

# ============================================================================
# SOLUTION CHECK
# ============================================================================

func check_solution() -> bool:
	"""Timed puzzle doesn't have a permanent solution"""
	return false

# ============================================================================
# RESET
# ============================================================================

func reset_puzzle() -> void:
	"""Resets the timed door puzzle"""
	super.reset_puzzle()

	if timed_switch and timed_switch.has_method("deactivate"):
		timed_switch.deactivate()

	print("[TimedDoorPuzzle] Reset")
