extends Camera2D
## RunnerCamera — Auto-scrolling camera for the mirror boss fight
## Supports horizontal (Phase 1) and vertical (Phase 2+3) scrolling
class_name RunnerCamera

# ============ CONFIG ============
@export var scroll_speed: float = 200.0
@export var y_smoothing: float = 3.0  # How quickly camera follows player Y (horizontal mode)
@export var x_smoothing: float = 3.0  # How quickly camera follows player X (vertical mode)
@export var y_offset: float = -100.0  # Camera sits slightly above player
@export var viewport_size: Vector2 = Vector2(1920, 1080)

# ============ STATE ============
var is_scrolling: bool = true
var vertical_mode: bool = false
var _start_x: float = 0.0
var _start_y: float = 0.0
var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0


func _ready() -> void:
	zoom = Vector2(1.0, 1.0)
	position_smoothing_enabled = false
	_start_x = global_position.x
	_start_y = global_position.y


func _process(delta: float) -> void:
	if not is_scrolling:
		_apply_shake(delta)
		return

	if vertical_mode:
		_process_vertical(delta)
	else:
		_process_horizontal(delta)

	_apply_shake(delta)


func _process_horizontal(delta: float) -> void:
	# Auto-scroll X: minimum speed is scroll_speed, but also track the player
	var min_x: float = global_position.x + scroll_speed * delta

	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		var player_target_x: float = player.global_position.x + viewport_size.x * 0.1
		global_position.x = maxf(min_x, lerpf(global_position.x, player_target_x, 4.0 * delta))
	else:
		global_position.x = min_x

	# Track player Y loosely
	if player and is_instance_valid(player):
		var target_y: float = player.global_position.y + y_offset
		global_position.y = lerpf(global_position.y, target_y, y_smoothing * delta)


func _process_vertical(delta: float) -> void:
	# Auto-scroll Y: minimum speed is scroll_speed, but also track the player
	# so the camera never falls too far behind a fast-falling player
	var min_y: float = global_position.y + scroll_speed * delta

	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		# Player should be in the upper ~40% of the screen
		# so camera center = player.y + 10% of viewport (player slightly above center)
		var player_target_y: float = player.global_position.y + viewport_size.y * 0.1
		# Use the larger of scroll-based and player-based position
		# Camera always scrolls at minimum speed, but if player falls faster, camera follows
		global_position.y = maxf(min_y, lerpf(global_position.y, player_target_y, 4.0 * delta))
	else:
		global_position.y = min_y

	# Track player X loosely (keep player centered horizontally)
	if player and is_instance_valid(player):
		var target_x: float = player.global_position.x
		global_position.x = lerpf(global_position.x, target_x, x_smoothing * delta)


func _apply_shake(delta: float) -> void:
	if _shake_intensity > 0.01:
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = lerpf(_shake_intensity, 0.0, _shake_decay * delta)
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


# ============ CONTROL ============
func pause_scrolling() -> void:
	is_scrolling = false


func resume_scrolling() -> void:
	is_scrolling = true


func switch_to_vertical() -> void:
	"""Switch camera to vertical scrolling mode (Phase 2+3)"""
	vertical_mode = true
	_start_y = global_position.y
	print("[RunnerCamera] Switched to vertical mode at Y=%.0f" % _start_y)


# ============ EDGE QUERIES ============
func get_left_edge() -> float:
	return global_position.x - viewport_size.x * 0.5


func get_right_edge() -> float:
	return global_position.x + viewport_size.x * 0.5


func get_top_edge() -> float:
	return global_position.y - viewport_size.y * 0.5


func get_bottom_edge() -> float:
	return global_position.y + viewport_size.y * 0.5


func get_scroll_distance() -> float:
	"""Total distance scrolled since fight/mode start"""
	if vertical_mode:
		return global_position.y - _start_y
	return global_position.x - _start_x


func shake(intensity: float = 8.0, decay: float = 5.0) -> void:
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_decay = decay
