extends Node
class_name PuzzleController

## Base class for all puzzle controllers (Logik-Manager)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal puzzle_solved()
signal puzzle_failed()
signal puzzle_reset()

# ============================================================================
# EXPORTS
# ============================================================================

@export var puzzle_name: String = "Unnamed Puzzle"
@export var auto_solve: bool = true  ## Automatically emit puzzle_solved when check_solution returns true
@export var allow_reset: bool = true  ## Can this puzzle be reset after failure?

# ============================================================================
# STATE
# ============================================================================

var is_solved: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("puzzle_controllers")
	print("[PuzzleController] %s initialized" % puzzle_name)

# ============================================================================
# CORE LOGIC (Override in child classes)
# ============================================================================

func check_solution() -> bool:
	"""Override this in child classes to implement puzzle logic"""
	push_warning("[PuzzleController] check_solution() not implemented in %s" % puzzle_name)
	return false

func reset_puzzle() -> void:
	"""Override this in child classes to reset puzzle state"""
	is_solved = false
	puzzle_reset.emit()
	print("[PuzzleController] %s reset" % puzzle_name)

# ============================================================================
# SOLUTION HANDLING
# ============================================================================

func solve() -> void:
	"""Marks puzzle as solved and emits signal"""
	if is_solved:
		return

	is_solved = true
	puzzle_solved.emit()

	# Play success sound
	if AudioManager:
		AudioManager.play_sfx("puzzle/puzzle_solved")

	print("[PuzzleController] %s SOLVED!" % puzzle_name)

func fail() -> void:
	"""Marks puzzle as failed and emits signal"""
	puzzle_failed.emit()

	# Play fail sound
	if AudioManager:
		AudioManager.play_sfx("puzzle/puzzle_failed")

	print("[PuzzleController] %s FAILED" % puzzle_name)

	# Auto-reset if allowed
	if allow_reset:
		await get_tree().create_timer(0.5).timeout
		reset_puzzle()
