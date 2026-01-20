extends PuzzleController
class_name SequencePuzzleController

## R1 - Schalter-Sequenz Controller
## Requires switches to be hit in correct order

# ============================================================================
# EXPORTS
# ============================================================================

@export var correct_sequence: Array[int] = [1, 2, 3]

# ============================================================================
# STATE
# ============================================================================

var current_sequence: Array[int] = []
var connected_switches: Array[PuzzleSwitch] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	super._ready()
	puzzle_name = "Schalter-Sequenz"

	# Find and connect to all switches in this puzzle
	await get_tree().process_frame  # Wait for switches to be ready
	_connect_switches()

# ============================================================================
# SWITCH CONNECTION
# ============================================================================

func _connect_switches() -> void:
	"""Finds and connects to all PuzzleSwitch children"""
	for child in get_children():
		if child is PuzzleSwitch:
			connected_switches.append(child)
			child.switch_activated.connect(_on_switch_hit)
			print("[SequencePuzzle] Connected to switch: %s (ID: %d)" % [child.name, child.switch_id])

func connect_switch(switch: PuzzleSwitch) -> void:
	"""Manually connects a switch to this controller"""
	if switch in connected_switches:
		return

	connected_switches.append(switch)
	switch.switch_activated.connect(_on_switch_hit)
	print("[SequencePuzzle] Manually connected to switch: %s (ID: %d)" % [switch.name, switch.switch_id])

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_switch_hit(switch_id: int) -> void:
	"""Handles switch activation"""
	print("[SequencePuzzle] Switch %d hit (Current sequence: %v)" % [switch_id, current_sequence])

	# Add to current sequence
	current_sequence.append(switch_id)

	# Check if sequence matches so far
	var is_correct_so_far = _check_sequence_partial()

	if is_correct_so_far:
		# Set correct visual on switch
		var switch = _get_switch_by_id(switch_id)
		if switch:
			switch.set_correct_visual()

		# Check if complete
		if current_sequence.size() == correct_sequence.size():
			if check_solution():
				solve()
	else:
		# Wrong sequence - reset
		_show_failure_feedback()
		fail()

func _on_switch_hit.call_deferred(switch_id: int) -> void:
	pass  # Required for deferred calls

# ============================================================================
# SOLUTION CHECK
# ============================================================================

func check_solution() -> bool:
	"""Checks if current sequence matches correct sequence"""
	if current_sequence.size() != correct_sequence.size():
		return false

	for i in range(current_sequence.size()):
		if current_sequence[i] != correct_sequence[i]:
			return false

	return true

func _check_sequence_partial() -> bool:
	"""Checks if current sequence is correct so far (prefix match)"""
	if current_sequence.size() > correct_sequence.size():
		return false

	for i in range(current_sequence.size()):
		if current_sequence[i] != correct_sequence[i]:
			return false

	return true

# ============================================================================
# RESET
# ============================================================================

func reset_puzzle() -> void:
	"""Resets the sequence puzzle"""
	super.reset_puzzle()
	current_sequence.clear()

	# Reset all switches
	for switch in connected_switches:
		if switch.can_deactivate:
			switch.deactivate()

	print("[SequencePuzzle] Reset - awaiting new sequence")

# ============================================================================
# FEEDBACK
# ============================================================================

func _show_failure_feedback() -> void:
	"""Shows visual feedback for wrong sequence"""
	# Flash all switches red
	for switch in connected_switches:
		switch.set_incorrect_visual()

# ============================================================================
# HELPERS
# ============================================================================

func _get_switch_by_id(switch_id: int) -> PuzzleSwitch:
	"""Finds switch by ID"""
	for switch in connected_switches:
		if switch.switch_id == switch_id:
			return switch
	return null
