extends Node2D
## RoomBase - Base script for all rooms with camera bounds support
## Extend this script for specific rooms and override room_bounds
class_name RoomBase

# ============ ROOM SETTINGS ============
@export var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)
@export var auto_set_bounds: bool = true

func _ready() -> void:
	if auto_set_bounds:
		_set_camera_bounds()

	print("[Room] Initialized: %s | Bounds: %s" % [name, room_bounds])

func _exit_tree() -> void:
	if auto_set_bounds:
		_clear_camera_bounds()

func _set_camera_bounds() -> void:
	"""Set camera bounds for this room"""
	var camera = get_viewport().get_camera_2d()

	if camera and camera.has_method("set_room_bounds"):
		camera.set_room_bounds(room_bounds)
		print("[Room] Camera bounds set for: %s" % name)
	else:
		push_warning("[Room] Camera not found or doesn't support bounds")

func _clear_camera_bounds() -> void:
	"""Clear camera bounds when leaving room"""
	var camera = get_viewport().get_camera_2d()

	if camera and camera.has_method("clear_room_bounds"):
		camera.clear_room_bounds()
		print("[Room] Camera bounds cleared for: %s" % name)
