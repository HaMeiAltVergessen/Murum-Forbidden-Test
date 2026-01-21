extends StaticBody2D
class_name MasterPuzzleDoor

## Door that opens when all connected puzzles are solved
## Godot 4.4 compatible

# ============================================================================
# EXPORTS
# ============================================================================

@export var puzzle_controllers: Array[NodePath] = []  ## Paths to PuzzleControllers to track
@export var require_all: bool = true  ## If true, all puzzles must be solved. If false, any puzzle unlocks
@export var visual_feedback: bool = true
@export var door_move_distance: Vector2 = Vector2(0, -128)  ## How far the door moves when open
@export var open_duration: float = 1.0  ## Animation duration

@export_group("Teleport")
@export var enable_teleport: bool = false  ## Enable teleportation when door opens
@export_file("*.tscn") var target_scene: String = ""  ## Scene to load when player enters door

# ============================================================================
# STATE
# ============================================================================

var controllers: Array[PuzzleController] = []
var solved_puzzles: Dictionary = {}  ## controller -> is_solved
var is_open: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: ColorRect = $DoorSprite if has_node("DoorSprite") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var progress_label: Label = $ProgressLabel if has_node("ProgressLabel") else null

var teleport_area: Area2D = null
var original_position: Vector2
var open_position: Vector2

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Store original position
	original_position = global_position
	open_position = original_position + door_move_distance

	# Create sprite if not present
	if not sprite:
		_create_door_sprite()

	# Create teleport area if teleport enabled
	if enable_teleport:
		_create_teleport_area()

	await get_tree().process_frame
	_connect_controllers()

	# Update door visual
	_update_door_visual()

	add_to_group("master_puzzle_doors")

	print("[MasterPuzzleDoor] %s initialized (tracking %d puzzles, teleport: %s)" % [name, controllers.size(), enable_teleport])

func _create_door_sprite() -> void:
	"""Creates a simple door sprite"""
	sprite = ColorRect.new()
	sprite.name = "DoorSprite"
	sprite.custom_minimum_size = Vector2(128, 128)
	sprite.size = Vector2(128, 128)
	sprite.position = -Vector2(64, 64)  # Center
	sprite.color = Color(0.6, 0.3, 0.1, 1.0)  # Brown
	add_child(sprite)

func _create_teleport_area() -> void:
	"""Creates the teleport trigger area"""
	teleport_area = Area2D.new()
	teleport_area.name = "TeleportArea"

	# Collision setup - only detect players
	teleport_area.collision_layer = 0
	teleport_area.collision_mask = 0
	teleport_area.set_collision_mask_value(2, true)  # Player layer

	# Monitoring disabled until door opens
	teleport_area.monitoring = false
	teleport_area.monitorable = false

	# Create collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(128, 128)

	var collision = CollisionShape2D.new()
	collision.shape = shape
	collision.name = "TeleportCollision"

	teleport_area.add_child(collision)
	add_child(teleport_area)

	# Connect signal
	teleport_area.body_entered.connect(_on_teleport_area_entered)

	print("[MasterPuzzleDoor] Teleport area created (target: %s)" % target_scene)

# ============================================================================
# CONTROLLER CONNECTION
# ============================================================================

func _connect_controllers() -> void:
	"""Connects to all puzzle controllers"""
	for controller_path in puzzle_controllers:
		if controller_path.is_empty():
			continue

		var controller = get_node_or_null(controller_path)

		if not controller:
			push_warning("[MasterPuzzleDoor] Could not find controller at path: %s" % controller_path)
			continue

		if not controller is PuzzleController:
			push_warning("[MasterPuzzleDoor] Node is not a PuzzleController: %s" % controller_path)
			continue

		controllers.append(controller)
		solved_puzzles[controller] = false

		# Connect to solved signal
		controller.puzzle_solved.connect(_on_puzzle_solved.bind(controller))

		print("[MasterPuzzleDoor] Connected to controller: %s" % controller.name)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_puzzle_solved(controller: PuzzleController) -> void:
	"""Handles a puzzle being solved"""
	if controller not in solved_puzzles:
		return

	solved_puzzles[controller] = true

	print("[MasterPuzzleDoor] Puzzle solved: %s (%d/%d)" % [controller.puzzle_name, _count_solved(), controllers.size()])

	# Update door visual
	_update_door_visual()

	# Check if door should open
	if _should_open():
		_open_door()

# ============================================================================
# DOOR LOGIC
# ============================================================================

func _should_open() -> bool:
	"""Checks if door should open"""
	if is_open:
		return false

	if require_all:
		# All puzzles must be solved
		return _count_solved() >= controllers.size()
	else:
		# Any puzzle solved
		return _count_solved() > 0

func _count_solved() -> int:
	"""Counts number of solved puzzles"""
	var count = 0
	for is_solved in solved_puzzles.values():
		if is_solved:
			count += 1
	return count

func _open_door() -> void:
	"""Opens the door"""
	if is_open:
		return

	is_open = true

	print("[MasterPuzzleDoor] Opening door! All puzzles solved (%d/%d)" % [_count_solved(), controllers.size()])

	# Disable collision
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.disabled = true

	# Animate door opening
	var tween = create_tween()
	tween.set_parallel(true)

	# Move door up
	tween.tween_property(self, "global_position", open_position, open_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade out
	if sprite:
		tween.tween_property(sprite, "modulate:a", 0.3, open_duration)

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/door_open")

	# Enable teleport area if teleport enabled
	if enable_teleport and teleport_area:
		teleport_area.monitoring = true
		print("[MasterPuzzleDoor] Teleport area activated!")

# ============================================================================
# TELEPORT
# ============================================================================

func _on_teleport_area_entered(body: Node2D) -> void:
	"""Handles player entering teleport area"""
	# Check if it's a player
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Check if door is open
	if not is_open:
		return

	# Check if target scene is set
	if target_scene == "" or not ResourceLoader.exists(target_scene):
		push_warning("[MasterPuzzleDoor] Invalid target scene: %s" % target_scene)
		return

	print("[MasterPuzzleDoor] Player %s entering teleport to %s" % [body.name, target_scene])

	# Load new scene
	_teleport_to_scene(target_scene)

func _teleport_to_scene(scene_path: String) -> void:
	"""Teleports to target scene"""
	# Use SceneManager if available, otherwise direct load
	if has_node("/root/SceneManager"):
		var scene_manager = get_node("/root/SceneManager")
		if scene_manager.has_method("change_scene"):
			scene_manager.change_scene(scene_path)
			return

	# Fallback: Direct scene change
	get_tree().change_scene_to_file(scene_path)

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _update_door_visual() -> void:
	"""Updates door visual based on progress"""
	var solved_count = _count_solved()
	var total_count = controllers.size()

	if total_count == 0:
		return

	# Update progress label
	if progress_label:
		progress_label.text = "%d/%d" % [solved_count, total_count]

	if not sprite or not visual_feedback:
		return

	# Color changes from brown to green as puzzles are solved
	var progress = float(solved_count) / float(total_count)

	var start_color = Color(0.6, 0.3, 0.1, 1.0)  # Brown (locked)
	var end_color = Color(0.3, 0.8, 0.3, 1.0)  # Green (unlocked)

	sprite.color = start_color.lerp(end_color, progress)

	print("[MasterPuzzleDoor] Progress: %d/%d (%.0f%%)" % [solved_count, total_count, progress * 100])
