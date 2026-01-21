extends Node
class_name PuzzleReward

## Handles rewards when puzzle is solved (item drops, door opening, events)
## Godot 4.4 compatible

# ============================================================================
# EXPORTS
# ============================================================================

@export var puzzle_controller: NodePath  ## Path to the PuzzleController
@export_group("Item Drops")
@export var drop_items: bool = false  ## Drop items when puzzle solved
@export var item_ids: Array[String] = []  ## IDs of items to drop (e.g., ["health_potion", "mana_potion"])
@export var drop_position_offset: Vector2 = Vector2(0, -50)  ## Offset from puzzle position

@export_group("Door/Gate")
@export var open_door: bool = false  ## Open a door when solved
@export var door_node: NodePath  ## Path to door node

@export_group("Custom Event")
@export var trigger_custom_event: bool = false  ## Trigger custom event
@export var event_name: String = ""  ## Name of event to trigger

# ============================================================================
# STATE
# ============================================================================

var controller: PuzzleController = null
var is_rewarded: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	await get_tree().process_frame
	_connect_controller()

	print("[PuzzleReward] %s initialized" % name)

func _connect_controller() -> void:
	"""Connects to the puzzle controller"""
	if puzzle_controller.is_empty():
		push_warning("[PuzzleReward] No puzzle controller assigned!")
		return

	controller = get_node_or_null(puzzle_controller)

	if not controller:
		push_warning("[PuzzleReward] Could not find controller at path: %s" % puzzle_controller)
		return

	if not controller is PuzzleController:
		push_warning("[PuzzleReward] Node at path is not a PuzzleController: %s" % puzzle_controller)
		return

	# Connect to puzzle_solved signal
	controller.puzzle_solved.connect(_on_puzzle_solved)

	print("[PuzzleReward] Connected to controller: %s" % controller.name)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_puzzle_solved() -> void:
	"""Handles puzzle being solved - give rewards"""
	if is_rewarded:
		return

	is_rewarded = true

	print("[PuzzleReward] Puzzle solved! Giving rewards...")

	# Item drops
	if drop_items and item_ids.size() > 0:
		_spawn_items()

	# Door opening
	if open_door and not door_node.is_empty():
		_open_door()

	# Custom event
	if trigger_custom_event and event_name != "":
		_trigger_event()

# ============================================================================
# REWARDS
# ============================================================================

func _spawn_items() -> void:
	"""Spawns item pickups"""
	var puzzle_position = get_parent().global_position if get_parent() else global_position

	for item_id in item_ids:
		if item_id == "":
			continue

		var spawn_pos = puzzle_position + drop_position_offset

		# Try to load pickup scene
		if not ResourceLoader.exists("res://environment/pickups/pickup_base.tscn"):
			push_warning("[PuzzleReward] Pickup scene not found!")
			continue

		var pickup_scene = load("res://environment/pickups/pickup_base.tscn")
		var pickup = pickup_scene.instantiate()

		# Set item ID
		if "item_id" in pickup:
			pickup.item_id = item_id

		# Add to scene
		get_tree().root.add_child(pickup)
		pickup.global_position = spawn_pos

		print("[PuzzleReward] Spawned item: %s at %v" % [item_id, spawn_pos])

		# Slight offset for multiple items
		drop_position_offset += Vector2(30, 0)

func _open_door() -> void:
	"""Opens a door"""
	var door = get_node_or_null(door_node)

	if not door:
		push_warning("[PuzzleReward] Could not find door at path: %s" % door_node)
		return

	if door.has_method("open"):
		door.open()
		print("[PuzzleReward] Opened door: %s" % door.name)
	else:
		push_warning("[PuzzleReward] Door has no open() method: %s" % door.name)

func _trigger_event() -> void:
	"""Triggers custom event via EventBus"""
	if not EventBus:
		push_warning("[PuzzleReward] EventBus not found!")
		return

	print("[PuzzleReward] Triggering event: %s" % event_name)

	# Emit via EventBus (if it exists)
	if EventBus.has_signal("puzzle_reward_event"):
		EventBus.puzzle_reward_event.emit(event_name)
	else:
		print("[PuzzleReward] Warning: EventBus has no puzzle_reward_event signal")
