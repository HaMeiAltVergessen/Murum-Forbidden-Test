extends Node
## ChunkSpawner — Manages procedural level chunk spawning for mirror boss runner
## Spawns handcrafted chunks ahead of camera, despawns behind
class_name ChunkSpawner

# ============ CONFIG ============
const SPAWN_AHEAD_DISTANCE: float = 1500.0  # How far ahead of camera right edge to spawn
const DESPAWN_BEHIND_DISTANCE: float = 300.0  # How far behind camera left edge to despawn
const MAX_ACTIVE_CHUNKS: int = 5  # Allow more active chunks for smoother scrolling
const GROUND_Y: float = 800.0  # Standard ground level

# ============ CHUNK POOLS (paths to .tscn files) ============
# Will be populated as chunks are created
var chunk_pools: Dictionary = {
	"fall": [],
	"spiegel": [],
	"abgrund": [],
	"finale": [],
}

# ============ STATE ============
var controller: Node = null  # MirrorController reference
var active_chunks: Array[Node2D] = []
var current_pool: String = "fall"
var _next_spawn_x: float = 0.0
var _is_spawning: bool = false
var _pool_index: int = 0  # Sequential cycling through pool


func _ready() -> void:
	_load_chunk_pools()


func _process(delta: float) -> void:
	if not _is_spawning or not controller:
		return

	var camera: Camera2D = controller.runner_camera
	if not camera:
		return

	# Spawn new chunks ahead of camera
	var spawn_threshold: float = camera.get_right_edge() + SPAWN_AHEAD_DISTANCE
	while _next_spawn_x < spawn_threshold:
		if active_chunks.size() >= MAX_ACTIVE_CHUNKS:
			break
		_spawn_next_chunk()

	# Despawn chunks behind camera
	var despawn_x: float = camera.get_left_edge() - DESPAWN_BEHIND_DISTANCE
	var to_remove: Array[Node2D] = []
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			to_remove.append(chunk)
			continue
		# Check if chunk's right edge is behind despawn line
		var chunk_width: float = chunk.get_meta("chunk_width", 800.0)
		if chunk.global_position.x + chunk_width < despawn_x:
			to_remove.append(chunk)

	for chunk in to_remove:
		active_chunks.erase(chunk)
		if is_instance_valid(chunk):
			chunk.queue_free()


# ============ SPAWNING ============
func start_spawning(pool_name: String) -> void:
	current_pool = pool_name
	_pool_index = 0
	_is_spawning = true

	# Set initial spawn position: start chunks after the boss room's starting ground
	# Boss room has ground from 0 to ~1200px, so chunks start at 1200
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		# Start chunks slightly ahead of where the player is
		_next_spawn_x = player.global_position.x + 800.0
	else:
		_next_spawn_x = 1200.0

	print("[ChunkSpawner] Starting at X=%.0f, pool='%s'" % [_next_spawn_x, pool_name])

	# Spawn enough initial chunks to fill the visible area + buffer ahead
	var target_x: float = _next_spawn_x + 4000.0  # Fill well ahead
	while _next_spawn_x < target_x and active_chunks.size() < MAX_ACTIVE_CHUNKS:
		_spawn_next_chunk()

	print("[ChunkSpawner] Spawned %d initial chunks, next at X=%.0f" % [active_chunks.size(), _next_spawn_x])


func switch_pool(pool_name: String) -> void:
	"""Switch to a different chunk pool (on section change)"""
	print("[ChunkSpawner] Switching pool: %s → %s" % [current_pool, pool_name])
	current_pool = pool_name
	_pool_index = 0


func stop_spawning() -> void:
	_is_spawning = false


func _spawn_next_chunk() -> void:
	var pool: Array = chunk_pools.get(current_pool, [])
	var chunk: Node2D = null

	if pool.is_empty():
		# No handcrafted chunks — create procedural placeholder
		chunk = _create_placeholder_chunk()
	else:
		# Cycle through pool sequentially
		var scene_path: String = pool[_pool_index % pool.size()]
		_pool_index += 1

		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			chunk = scene.instantiate()
		else:
			push_warning("[ChunkSpawner] Chunk scene not found: %s" % scene_path)
			chunk = _create_placeholder_chunk()

	# Position chunk
	chunk.global_position = Vector2(_next_spawn_x, 0)
	var chunk_width: float = chunk.get_meta("chunk_width", 800.0)
	_next_spawn_x += chunk_width

	# Add to scene
	if controller:
		controller.get_parent().add_child(chunk)
	else:
		get_parent().add_child(chunk)

	active_chunks.append(chunk)


func _create_placeholder_chunk() -> Node2D:
	"""Creates a simple flat chunk with ground and some platforms"""
	var chunk := Node2D.new()
	chunk.name = "PlaceholderChunk"

	var width: float = 1200.0
	chunk.set_meta("chunk_width", width)

	# Ground (StaticBody2D)
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(width * 0.5, GROUND_Y)

	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(width, 40.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)

	# Ground visual
	var ground_visual := ColorRect.new()
	ground_visual.size = Vector2(width, 40.0)
	ground_visual.position = Vector2(-width * 0.5, -20.0)
	ground_visual.color = Color(0.15, 0.1, 0.2)
	ground.add_child(ground_visual)

	chunk.add_child(ground)

	# Random platforms (1-3)
	var platform_count: int = randi_range(1, 3)
	for i in range(platform_count):
		var plat := StaticBody2D.new()
		plat.name = "Platform_%d" % i
		var px: float = randf_range(100.0, width - 100.0)
		var py: float = randf_range(GROUND_Y - 350.0, GROUND_Y - 120.0)
		plat.position = Vector2(px, py)

		var plat_shape := CollisionShape2D.new()
		var plat_rect := RectangleShape2D.new()
		var plat_width: float = randf_range(120.0, 250.0)
		plat_rect.size = Vector2(plat_width, 16.0)
		plat_shape.shape = plat_rect
		plat.add_child(plat_shape)

		# Platform visual
		var plat_visual := ColorRect.new()
		plat_visual.size = Vector2(plat_width, 16.0)
		plat_visual.position = Vector2(-plat_width * 0.5, -8.0)
		plat_visual.color = Color(0.25, 0.15, 0.35)
		plat.add_child(plat_visual)

		chunk.add_child(plat)

	# Boss waypoints (Marker2D for boss AI navigation)
	var wp_count: int = 3
	for i in range(wp_count):
		var wp := Marker2D.new()
		wp.name = "BossWaypoint_%d" % i
		var wx: float = (i + 1) * (width / (wp_count + 1))
		var wy: float = randf_range(GROUND_Y - 300.0, GROUND_Y - 50.0)
		wp.position = Vector2(wx, wy)
		wp.add_to_group("boss_waypoints")
		chunk.add_child(wp)

	return chunk


# ============ POOL LOADING ============
func _load_chunk_pools() -> void:
	"""Scan for chunk .tscn files in the chunks directory"""
	var base_path: String = "res://bosses/mirror/chunks/"
	var prefixes: Dictionary = {
		"fall": "chunk_fall_",
		"spiegel": "chunk_spiegel_",
		"abgrund": "chunk_abgrund_",
		"finale": "chunk_finale_",
	}

	for pool_name in prefixes.keys():
		var prefix: String = prefixes[pool_name]
		# Check for files numbered 01-10
		for i in range(1, 11):
			var path: String = base_path + prefix + "%02d.tscn" % i
			if ResourceLoader.exists(path):
				chunk_pools[pool_name].append(path)

	# Log loaded pools
	for pool_name in chunk_pools.keys():
		var count: int = chunk_pools[pool_name].size()
		if count > 0:
			print("[ChunkSpawner] Pool '%s': %d chunks loaded" % [pool_name, count])


# ============ UTILITY ============
func get_active_waypoints() -> Array[Marker2D]:
	"""Returns all boss waypoints from active chunks, sorted by X position"""
	var waypoints: Array[Marker2D] = []
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			continue
		for child in chunk.get_children():
			if child is Marker2D and child.is_in_group("boss_waypoints"):
				waypoints.append(child)

	# Sort by global X
	waypoints.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return waypoints
