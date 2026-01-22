extends PuzzleController
class_name DualPlatePuzzleController

## R2 - Druckplatten-Gegner Controller
## Requires both pressure plates to be pressed simultaneously

# ============================================================================
# STATE
# ============================================================================

var connected_plates: Array[Node] = []  # PressurePlate nodes
var plate_states: Dictionary = {}  # plate -> is_pressed

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	super._ready()
	puzzle_name = "Druckplatten-Gegner"

	# Find and connect to all pressure plates
	await get_tree().process_frame
	_connect_plates()

# ============================================================================
# PLATE CONNECTION
# ============================================================================

func _connect_plates() -> void:
	"""Finds and connects to all PressurePlate siblings in parent"""
	var parent_node = get_parent()
	if not parent_node:
		return

	for child in parent_node.get_children():
		if child.has_signal("plate_pressed"):
			connected_plates.append(child)
			plate_states[child] = false

			child.plate_pressed.connect(_on_plate_pressed.bind(child))

			print("[DualPlatePuzzle] Connected to plate: %s" % child.name)

	print("[DualPlatePuzzle] Total plates: %d" % connected_plates.size())

func connect_plate(plate: Node) -> void:
	"""Manually connects a pressure plate"""
	if plate in connected_plates:
		return

	connected_plates.append(plate)
	plate_states[plate] = false

	plate.plate_pressed.connect(_on_plate_pressed.bind(plate))

	print("[DualPlatePuzzle] Manually connected to plate: %s" % plate.name)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_plate_pressed(activator: CharacterBody2D, plate: Node) -> void:
	"""Handles plate being activated (one-time)"""
	plate_states[plate] = true
	print("[DualPlatePuzzle] Plate %s activated by %s" % [plate.name, activator.name if activator else "unknown"])

	# Check if all plates are activated
	if check_solution():
		solve()

# ============================================================================
# SOLUTION CHECK
# ============================================================================

func check_solution() -> bool:
	"""Checks if all plates are pressed"""
	for plate in connected_plates:
		if not plate_states.get(plate, false):
			return false

	return true

# ============================================================================
# LOAD HANDLING
# ============================================================================

func _on_load_solved() -> void:
	"""Called when puzzle is already solved on load - removes all pressure plates"""
	print("[DualPlatePuzzle] Already solved, removing pressure plates")

	# Remove all connected pressure plates
	for plate in connected_plates:
		if is_instance_valid(plate):
			plate.queue_free()

	connected_plates.clear()
	plate_states.clear()

# ============================================================================
# RESET
# ============================================================================

func reset_puzzle() -> void:
	"""Resets the dual plate puzzle"""
	super.reset_puzzle()

	# Reset plate states
	for plate in connected_plates:
		plate_states[plate] = false

	print("[DualPlatePuzzle] Reset - awaiting plate presses")
