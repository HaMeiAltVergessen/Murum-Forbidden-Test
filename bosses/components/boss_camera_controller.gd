extends Node
## Controls camera behavior during boss fights
class_name BossCameraController

@export var boss: CharacterBody2D
@export var zoom_level: float = 1.2
@export var focus_lerp_speed: float = 3.0
@export var enable_dynamic_focus: bool = true  # Follow midpoint between boss and player

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

	is_active = true

	# Smooth zoom to boss fight level
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", Vector2(zoom_level, zoom_level), 1.0).set_trans(Tween.TRANS_CUBIC)

	print("[BossCameraController] Activated")


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

	if not boss or not player:
		return

	# Focus camera on midpoint between boss and player
	var midpoint = (boss.global_position + player.global_position) / 2.0
	camera.global_position = camera.global_position.lerp(midpoint, focus_lerp_speed * delta)


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
