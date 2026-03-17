extends Camera2D
## RunnerCamera — Auto-scrolling camera for the mirror boss fight
## Scrolls right at configurable speed, tracks player Y loosely
class_name RunnerCamera

# ============ CONFIG ============
@export var scroll_speed: float = 200.0
@export var y_smoothing: float = 3.0  # How quickly camera follows player Y
@export var y_offset: float = -100.0  # Camera sits slightly above player
@export var viewport_size: Vector2 = Vector2(1920, 1080)

# ============ STATE ============
var is_scrolling: bool = true
var _start_x: float = 0.0


func _ready() -> void:
	# Camera settings
	zoom = Vector2(1.0, 1.0)
	position_smoothing_enabled = false  # We handle smoothing manually
	_start_x = global_position.x


func _process(delta: float) -> void:
	if not is_scrolling:
		return

	# Auto-scroll X
	global_position.x += scroll_speed * delta

	# Track player Y loosely
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		var target_y: float = player.global_position.y + y_offset
		global_position.y = lerpf(global_position.y, target_y, y_smoothing * delta)


# ============ CONTROL ============
func pause_scrolling() -> void:
	is_scrolling = false


func resume_scrolling() -> void:
	is_scrolling = true


func get_left_edge() -> float:
	"""Returns the world X position of the left edge of the camera viewport"""
	return global_position.x - viewport_size.x * 0.5


func get_right_edge() -> float:
	"""Returns the world X position of the right edge of the camera viewport"""
	return global_position.x + viewport_size.x * 0.5


func get_scroll_distance() -> float:
	"""Total distance scrolled since fight start"""
	return global_position.x - _start_x
