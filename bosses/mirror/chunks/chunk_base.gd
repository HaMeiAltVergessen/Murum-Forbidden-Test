extends Node2D
## ChunkBase — Base class for handcrafted mirror boss chunks
## Each chunk is a horizontal level segment with ground, platforms, and waypoints
class_name MirrorChunkBase

# ============ CONFIG ============
## Width of this chunk in pixels (used for seamless spawning)
@export var chunk_width: float = 800.0

# ============ GROUND LEVEL ============
const GROUND_Y: float = 800.0


func _ready() -> void:
	# Store width as metadata for ChunkSpawner
	set_meta("chunk_width", chunk_width)
	# Auto-add waypoints to group by name pattern
	for child in get_children():
		if child is Marker2D and child.name.begins_with("BossWaypoint"):
			child.add_to_group("boss_waypoints")


# ============ WAYPOINTS ============
func get_waypoints() -> Array[Marker2D]:
	"""Returns all BossWaypoint markers in this chunk"""
	var waypoints: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.is_in_group("boss_waypoints"):
			waypoints.append(child)
	waypoints.sort_custom(func(a, b): return a.position.x < b.position.x)
	return waypoints
