extends PuzzleController
class_name ChainPuzzleController

## R3 - Kristall-Kette Controller
## Requires all crystals to be hit in a single staff throw

# ============================================================================
# EXPORTS
# ============================================================================

@export var required_crystals: int = 4
@export var check_delay: float = 0.2  ## Delay before checking if all crystals destroyed

# ============================================================================
# STATE
# ============================================================================

var connected_crystals: Array[Node] = []
var checking_solution: bool = false  ## Prevents multiple simultaneous checks

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
	"""Handles crystal being destroyed (HP=0)"""
	print("[ChainPuzzle] Crystal %s destroyed by %s" % [crystal.name, projectile_owner.name if projectile_owner else "unknown"])

	# Prevent multiple simultaneous checks
	if checking_solution:
		return

	checking_solution = true

	# Wait for all crystals in current attack to register destruction
	await get_tree().create_timer(check_delay).timeout

	# Check if all crystals are destroyed
	var all_destroyed = _check_all_destroyed()

	if all_destroyed:
		# All crystals HP=0 → Puzzle solved!
		print("[ChainPuzzle] All crystals destroyed! Puzzle solved!")
		solve()
		# Remove all crystals from scene immediately (prevents reset timers from firing)
		_remove_all_crystals()
	else:
		# Some crystals still alive → Reset destroyed crystals (if they can reset)
		print("[ChainPuzzle] Not all crystals destroyed - resetting destroyed ones")
		_reset_destroyed_crystals()

	checking_solution = false

# ============================================================================
# SOLUTION CHECK
# ============================================================================

func check_solution() -> bool:
	"""Checks if all crystals have been destroyed"""
	return _check_all_destroyed()

func _check_all_destroyed() -> bool:
	"""Checks if all connected crystals are destroyed (HP=0)"""
	var destroyed = 0
	for crystal in connected_crystals:
		if not is_instance_valid(crystal):
			# Crystal was removed/freed → counts as destroyed
			destroyed += 1
			continue

		# Check if crystal HP is 0 or is_activated is true
		if ("current_hp" in crystal and crystal.current_hp <= 0) or ("is_activated" in crystal and crystal.is_activated):
			destroyed += 1

	print("[ChainPuzzle] Destroyed crystals: %d/%d" % [destroyed, required_crystals])
	return destroyed >= required_crystals

func _reset_destroyed_crystals() -> void:
	"""Resets destroyed crystals (only if can_reset=true)"""
	for crystal in connected_crystals:
		if not is_instance_valid(crystal):
			continue

		# Only reset if crystal is destroyed AND can reset
		if "is_activated" in crystal and crystal.is_activated:
			if "can_reset" in crystal and crystal.can_reset and crystal.has_method("reset"):
				crystal.reset()
				print("[ChainPuzzle] Reset crystal: %s" % crystal.name)

func _remove_all_crystals() -> void:
	"""Removes all crystals from the scene (called when puzzle is solved)"""
	print("[ChainPuzzle] Removing all crystals from scene")
	for crystal in connected_crystals:
		if is_instance_valid(crystal):
			# Mark crystal for removal (prevents reset timer from firing)
			if "is_being_removed" in crystal:
				crystal.is_being_removed = true
			# Cancel any active monitoring
			if "monitoring" in crystal:
				crystal.monitoring = false
			# Queue for removal
			crystal.queue_free()
			print("[ChainPuzzle] Removed crystal: %s" % crystal.name)

	# Clear the array
	connected_crystals.clear()

# ============================================================================
# LOAD HANDLING
# ============================================================================

func _on_load_solved() -> void:
	"""Called when puzzle is already solved on load - removes all crystals"""
	print("[ChainPuzzle] Already solved, removing crystals")
	_remove_all_crystals()

# ============================================================================
# RESET
# ============================================================================

func reset_puzzle() -> void:
	"""Resets the chain puzzle"""
	super.reset_puzzle()
	checking_solution = false

	# Reset all crystals (only if they still exist and can reset)
	for crystal in connected_crystals:
		if is_instance_valid(crystal) and crystal.has_method("reset") and "can_reset" in crystal and crystal.can_reset:
			crystal.reset()

	print("[ChainPuzzle] Reset - awaiting all crystals to be destroyed")
