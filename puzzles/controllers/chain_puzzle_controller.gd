extends PuzzleController
class_name ChainPuzzleController

## R3 - Kristall-Kette Controller
## Requires all crystals to be hit in a single staff throw

# ============================================================================
# EXPORTS
# ============================================================================

@export var required_crystals: int = 4

# ============================================================================
# STATE
# ============================================================================

var activated_count: int = 0
var connected_crystals: Array[Node] = []
var last_activation_time: float = 0.0
const CHAIN_TIMEOUT: float = 0.5  # Max time between crystal hits to count as chain

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	super._ready()
	puzzle_name = "Kristall-Kette"

	# Find and connect to all crystals
	await get_tree().process_frame
	_connect_crystals()

# ============================================================================
# CRYSTAL CONNECTION
# ============================================================================

func _connect_crystals() -> void:
	"""Finds and connects to all PuzzleCrystal siblings in parent"""
	var parent_node = get_parent()
	if not parent_node:
		return

	for child in parent_node.get_children():
		if child.has_signal("crystal_hit"):
			connected_crystals.append(child)
			child.crystal_hit.connect(_on_crystal_hit.bind(child))
			print("[ChainPuzzle] Connected to crystal: %s" % child.name)

	required_crystals = connected_crystals.size()
	print("[ChainPuzzle] Total crystals: %d" % required_crystals)

func connect_crystal(crystal: Node) -> void:
	"""Manually connects a crystal"""
	if crystal in connected_crystals:
		return

	connected_crystals.append(crystal)
	crystal.crystal_hit.connect(_on_crystal_hit.bind(crystal))

	required_crystals = connected_crystals.size()
	print("[ChainPuzzle] Manually connected to crystal: %s (Total: %d)" % [crystal.name, required_crystals])

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_crystal_hit(projectile_owner: Node2D, crystal: Node) -> void:
	"""Handles crystal being hit"""
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check if this is part of a chain (within timeout)
	if activated_count > 0 and (current_time - last_activation_time) > CHAIN_TIMEOUT:
		# Chain broken - reset
		print("[ChainPuzzle] Chain timeout - resetting (took %.2fs between hits)" % (current_time - last_activation_time))
		reset_puzzle()
		return

	activated_count += 1
	last_activation_time = current_time

	print("[ChainPuzzle] Crystal %s hit by %s (%d/%d)" % [crystal.name, projectile_owner.name if projectile_owner else "unknown", activated_count, required_crystals])

	# Visual feedback
	if crystal.has_method("set_activated_visual"):
		crystal.set_activated_visual()

	# Check if all crystals activated
	if activated_count >= required_crystals:
		if check_solution():
			solve()

# ============================================================================
# SOLUTION CHECK
# ============================================================================

func check_solution() -> bool:
	"""Checks if all crystals have been activated"""
	return activated_count >= required_crystals

# ============================================================================
# RESET
# ============================================================================

func reset_puzzle() -> void:
	"""Resets the chain puzzle"""
	super.reset_puzzle()
	activated_count = 0
	last_activation_time = 0.0

	# Reset all crystals (only if they still exist and can reset)
	for crystal in connected_crystals:
		if is_instance_valid(crystal) and crystal.has_method("reset") and "can_reset" in crystal and crystal.can_reset:
			crystal.reset()

	print("[ChainPuzzle] Reset - awaiting crystal chain")
