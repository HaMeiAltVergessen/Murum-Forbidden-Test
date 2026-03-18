extends Node
## Controls camera behavior during boss fights
class_name BossCameraController

@export var boss: CharacterBody2D
@export var zoom_level: float = 1.2
@export var focus_lerp_speed: float = 3.0
@export var enable_dynamic_focus: bool = true  # Follow midpoint between boss and player

# Maximum distance the camera midpoint can deviate from the player
# Prevents camera jumping to nowhere when boss teleports far away
const MAX_MIDPOINT_OFFSET: float = 400.0

var camera: Camera2D
var original_zoom: Vector2
var original_position_smoothing: bool
var is_active: bool = false
var player: CharacterBody2D


func _ready() -> void:
	await get_tree().process_frame
	find_camera()
	find_player()


func find_camera() -> void:
	"""Finds the active camera in the scene"""
	camera = get_viewport().get_camera_2d()
	if camera:
		original_zoom = camera.zoom
		original_position_smoothing = camera.position_smoothing_enabled


func find_player() -> void:
	"""Finds the player node"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func activate() -> void:
	"""Activates boss camera mode"""
	if not camera:
		find_camera()

	# Re-find player on activation (may not have been in group during _ready)
	if not player or not is_instance_valid(player):
		find_player()

	is_active = true

	# Smooth zoom to boss fight level
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", Vector2(zoom_level, zoom_level), 1.0).set_trans(Tween.TRANS_CUBIC)

	print("[BossCameraController] Activated (player: %s, camera: %s)" % [
		player.name if player else "NULL",
		camera.name if camera else "NULL"
	])


func deactivate() -> void:
	"""Deactivates boss camera mode and restores original settings"""
	is_active = false

	if camera:
		# Restore original zoom
		var tween = create_tween()
		tween.tween_property(camera, "zoom", original_zoom, 1.0).set_trans(Tween.TRANS_CUBIC)

	print("[BossCameraController] Deactivated")


func _process(delta: float) -> void:
	if not is_active or not camera or not enable_dynamic_focus:
		return

	# Re-find player if reference lost
	if not player or not is_instance_valid(player):
		find_player()
		if not player:
			return

	if not boss or not is_instance_valid(boss):
		return

	var boss_pos: Vector2 = boss.global_position
	var player_pos: Vector2 = player.global_position

	# Validate positions — skip if NaN or clearly corrupt
	if is_nan(boss_pos.x) or is_nan(boss_pos.y) or is_nan(player_pos.x) or is_nan(player_pos.y):
		return

	# Calculate midpoint between boss and player
	var midpoint: Vector2 = (boss_pos + player_pos) / 2.0

	# Clamp midpoint: never move camera further than MAX_MIDPOINT_OFFSET from player
	# This prevents camera jumping when boss teleports far away
	var offset: Vector2 = midpoint - player_pos
	if offset.length() > MAX_MIDPOINT_OFFSET:
		midpoint = player_pos + offset.normalized() * MAX_MIDPOINT_OFFSET

	# Smooth lerp to target
	var target_pos: Vector2 = camera.global_position.lerp(midpoint, focus_lerp_speed * delta)

	# Final NaN guard
	if is_nan(target_pos.x) or is_nan(target_pos.y):
		return

	camera.global_position = target_pos


func focus_on_boss(duration: float = 0.5) -> void:
	"""Focuses camera on boss position"""
	if not camera or not boss:
		return

	var tween = create_tween()
	tween.tween_property(camera, "global_position", boss.global_position, duration).set_trans(Tween.TRANS_CUBIC)


func shake(intensity: float = 5.0, duration: float = 0.3) -> void:
	"""Shakes the camera"""
	if not camera:
		return

	var original_offset = camera.offset
	var shake_count = int(duration * 60)  # 60 FPS

	var tween = create_tween()

	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", shake_offset, 0.016)

	tween.tween_property(camera, "offset", original_offset, 0.1)
