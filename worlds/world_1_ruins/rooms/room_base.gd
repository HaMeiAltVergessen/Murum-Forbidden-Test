extends Node2D
## RoomBase - Base script for all rooms with camera bounds support
## Extend this script for specific rooms and override room_bounds
class_name RoomBase

# ============ ROOM SETTINGS ============
@export var room_bounds: Rect2 = Rect2(0, 0, 1920, 1080)
@export var auto_set_bounds: bool = true

# ============ SCHWELLENSICHT ============
var _schwellensicht_atmosphere: ColorRect = null

func _ready() -> void:
	if auto_set_bounds:
		_set_camera_bounds()

	_setup_schwellensicht_atmosphere()

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


# ============ SCHWELLENSICHT ATMOSPHERE ============
func _setup_schwellensicht_atmosphere() -> void:
	"""Creates cosmic nebula overlay for Schwellensicht (placeholder ColorRect)"""
	_schwellensicht_atmosphere = ColorRect.new()
	_schwellensicht_atmosphere.color = Color(0.1, 0.0, 0.15, 0.2)
	_schwellensicht_atmosphere.size = Vector2(room_bounds.size.x, room_bounds.size.y)
	_schwellensicht_atmosphere.position = Vector2(room_bounds.position.x, room_bounds.position.y)
	_schwellensicht_atmosphere.visible = false
	_schwellensicht_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schwellensicht_atmosphere.z_index = -1
	add_child(_schwellensicht_atmosphere)

	if EventBus:
		EventBus.schwellensicht_changed.connect(_on_schwellensicht_changed)

	# Check initial state
	if ChallengeRunManager and ChallengeRunManager.is_schwellensicht_active:
		_on_schwellensicht_changed(true)

func _on_schwellensicht_changed(active: bool) -> void:
	"""Toggles cosmic atmosphere overlay"""
	if _schwellensicht_atmosphere:
		_schwellensicht_atmosphere.visible = active
