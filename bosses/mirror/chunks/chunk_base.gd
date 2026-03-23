extends Node2D
## ChunkBase — Base class for handcrafted mirror boss chunks
## Supports horizontal (Phase 1) and vertical (Phase 2+3) chunks
class_name MirrorChunkBase

# ============ CONFIG ============
## Width of this chunk in pixels (used for seamless horizontal spawning)
@export var chunk_width: float = 800.0
## Height of this chunk in pixels (used for seamless vertical spawning)
@export var chunk_height: float = 800.0

# ============ GROUND LEVEL ============
const GROUND_Y: float = 800.0


func _ready() -> void:
	set_meta("chunk_width", chunk_width)
	set_meta("chunk_height", chunk_height)
	for child in get_children():
		if child is Marker2D and child.name.begins_with("BossWaypoint"):
			child.add_to_group("boss_waypoints")


# ============ WAYPOINTS ============
func get_waypoints() -> Array[Marker2D]:
	var waypoints: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.is_in_group("boss_waypoints"):
			waypoints.append(child)
	waypoints.sort_custom(func(a, b): return a.position.x < b.position.x)
	return waypoints
