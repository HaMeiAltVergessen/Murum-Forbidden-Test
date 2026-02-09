extends StaticBody2D
class_name PuzzleBlock

## Visual feedback block that changes from black to white when puzzle is solved
## Godot 4.4 compatible

# ============================================================================
# EXPORTS
# ============================================================================

@export var block_size: Vector2 = Vector2(64, 64)
@export var puzzle_controller: NodePath  ## Path to the PuzzleController this block tracks
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============================================================================
# STATE
# ============================================================================

var is_solved: bool = false
var controller: PuzzleController = null

# ============================================================================
# REFERENCES
# ============================================================================

@onready var color_rect: ColorRect = $ColorRect if has_node("ColorRect") else null
@onready var particles: GPUParticles2D = $SolveParticles if has_node("SolveParticles") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create ColorRect if not present
	if not color_rect:
		_create_color_rect()

	# Set initial color (black)
	_set_color(Color.BLACK)

	# Connect to puzzle controller
	await get_tree().process_frame
	_connect_controller()

	add_to_group("puzzle_blocks")

	print("[PuzzleBlock] %s initialized" % name)

# ============================================================================
# SETUP
# ============================================================================

func _create_color_rect() -> void:
	"""Creates the ColorRect for visual representation"""
	color_rect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.custom_minimum_size = block_size
	color_rect.size = block_size
	color_rect.position = -block_size / 2  # Center the rect
	add_child(color_rect)

func _connect_controller() -> void:
	"""Connects to the puzzle controller"""
	if puzzle_controller.is_empty():
		push_warning("[PuzzleBlock] No puzzle controller assigned!")
		return

	controller = get_node_or_null(puzzle_controller)

	if not controller:
		push_warning("[PuzzleBlock] Could not find controller at path: %s" % puzzle_controller)
		return

	if not controller is PuzzleController:
		push_warning("[PuzzleBlock] Node at path is not a PuzzleController: %s" % puzzle_controller)
		return

	# Connect to puzzle_solved signal
	controller.puzzle_solved.connect(_on_puzzle_solved)

	print("[PuzzleBlock] Connected to controller: %s" % controller.name)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_puzzle_solved() -> void:
	if is_solved:
		return

	is_solved = true
	_animate_solve()
	_start_dissolve()  # Neu

	print("[PuzzleBlock] %s solved - turning white!" % name)

# ============================================================================
# VISUAL EFFECTS
# ============================================================================
func _start_dissolve() -> void:
	# Node optisch ausblenden
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)  # Alpha von 1 -> 0 in 0.5s
	tween.tween_callback(_on_dissolve_finished)

func _on_dissolve_finished() -> void:
	# Kollision ausschalten
	if collision_shape:
		collision_shape.disabled = true  # StaticBody2D kollidiert nicht mehr[web:19]

	# Entweder komplett entfernen:
	queue_free()

	# Oder nur unsichtbar lassen:
	# visible = false
func _set_color(color: Color) -> void:
	"""Sets the block color"""
	if color_rect:
		color_rect.color = color

func _animate_solve() -> void:
	"""Animates the solve effect"""
	if not color_rect:
		return

	# Create dramatic solve animation
	var tween = create_tween()
	tween.set_parallel(true)

	# Color transition: black -> white
	tween.tween_property(color_rect, "color", Color.WHITE, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Scale pulse
	tween.tween_property(color_rect, "scale", Vector2(1.2, 1.2), 0.3)
	tween.chain().tween_property(color_rect, "scale", Vector2(1.0, 1.0), 0.3)

	# Play particles
	if particles:
		particles.restart()
		particles.emitting = true

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("puzzle/block_solved")

# ============================================================================
# MANUAL CONTROL
# ============================================================================

func solve_manually() -> void:
	"""Manually solves the block (for testing)"""
	_on_puzzle_solved()

func reset_block() -> void:
	"""Resets the block to unsolved state"""
	is_solved = false
	_set_color(Color.BLACK)

	if particles:
		particles.emitting = false

	print("[PuzzleBlock] %s reset to black" % name)
