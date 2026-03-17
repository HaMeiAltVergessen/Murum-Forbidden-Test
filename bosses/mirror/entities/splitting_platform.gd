extends StaticBody2D
## SplittingPlatform — Platform that the MirrorBoss can split in two
## 2-second warning (color change) before splitting apart
class_name SplittingPlatform

# ============ CONFIG ============
@export var platform_width: float = 200.0
@export var platform_height: float = 16.0
@export var split_delay: float = 2.0
@export var split_speed: float = 150.0  # How fast halves fall apart
@export var fall_speed: float = 300.0  # How fast halves fall down

# ============ STATE ============
var is_splitting: bool = false
var is_split: bool = false
var _split_timer: float = 0.0

# ============ VISUAL ============
const COLOR_NORMAL := Color(0.25, 0.15, 0.35)
const COLOR_WARNING := Color(0.8, 0.2, 0.2, 0.9)
const COLOR_SPLIT := Color(0.5, 0.1, 0.1, 0.6)

var _visual: ColorRect = null
var _left_half: Node2D = null
var _right_half: Node2D = null


func _ready() -> void:
	# Create visual if needed
	if not has_node("Visual"):
		_visual = ColorRect.new()
		_visual.name = "Visual"
		_visual.size = Vector2(platform_width, platform_height)
		_visual.position = Vector2(-platform_width * 0.5, -platform_height * 0.5)
		_visual.color = COLOR_NORMAL
		add_child(_visual)
	else:
		_visual = $Visual

	# Create collision if needed
	if not has_node("CollisionShape2D"):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(platform_width, platform_height)
		shape.shape = rect
		add_child(shape)


func _process(delta: float) -> void:
	if is_splitting and not is_split:
		_split_timer += delta

		# Warning pulse
		var pulse: float = abs(sin(_split_timer * 6.0))
		if _visual:
			_visual.color = COLOR_NORMAL.lerp(COLOR_WARNING, pulse)

		if _split_timer >= split_delay:
			_execute_split()

	# Animate split halves falling
	if is_split:
		if _left_half:
			_left_half.position.x -= split_speed * delta
			_left_half.position.y += fall_speed * delta
			_left_half.rotation -= 1.5 * delta
		if _right_half:
			_right_half.position.x += split_speed * delta
			_right_half.position.y += fall_speed * delta
			_right_half.rotation += 1.5 * delta

		# Cleanup after falling off screen
		if _left_half and _left_half.position.y > 800:
			queue_free()


# ============ SPLIT ============
func start_split() -> void:
	"""Begin the split countdown (2s warning)"""
	if is_splitting or is_split:
		return
	is_splitting = true
	_split_timer = 0.0


func _execute_split() -> void:
	"""Actually split the platform"""
	is_split = true

	# Disable collision
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	# Hide original visual
	if _visual:
		_visual.visible = false

	# Create two halves
	var half_width: float = platform_width * 0.5

	_left_half = Node2D.new()
	var left_rect := ColorRect.new()
	left_rect.size = Vector2(half_width, platform_height)
	left_rect.position = Vector2(-half_width, -platform_height * 0.5)
	left_rect.color = COLOR_SPLIT
	_left_half.add_child(left_rect)
	add_child(_left_half)

	_right_half = Node2D.new()
	var right_rect := ColorRect.new()
	right_rect.size = Vector2(half_width, platform_height)
	right_rect.position = Vector2(0, -platform_height * 0.5)
	right_rect.color = COLOR_SPLIT
	_right_half.add_child(right_rect)
	add_child(_right_half)

	# Notify momentum system
	if get_tree().get_nodes_in_group("player").size() > 0:
		var player: Node = get_tree().get_nodes_in_group("player")[0]
		# Check if player was standing on this platform (rough check)
		var player_pos: Vector2 = player.global_position if player is Node2D else Vector2.ZERO
		var plat_pos: Vector2 = global_position
		if abs(player_pos.x - plat_pos.x) < platform_width * 0.5 and abs(player_pos.y - plat_pos.y) < 50:
			print("[SplittingPlatform] Player was standing on split platform!")
