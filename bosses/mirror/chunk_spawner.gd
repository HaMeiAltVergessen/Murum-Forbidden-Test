extends Node
## ChunkSpawner — Manages procedural level chunk spawning for mirror boss runner
## Supports horizontal (Phase 1) and vertical (Phase 2+3) spawning
class_name ChunkSpawner

# ============ CONFIG ============
const SPAWN_AHEAD_DISTANCE: float = 1500.0  # How far ahead of camera edge to spawn
const DESPAWN_BEHIND_DISTANCE: float = 300.0  # How far behind camera edge to despawn
const DESPAWN_WARNING_OFFSET: float = 400.0  # Warning starts when chunk trailing edge is this close to camera edge
const MAX_ACTIVE_CHUNKS: int = 5
const GROUND_Y: float = 800.0

# ============ CHUNK POOLS (paths to .tscn files) ============
var chunk_pools: Dictionary = {
	"fall": [],
	"spiegel": [],
	"abgrund": [],
	"finale": [],
	"fall_vertical": [],
	"finale_vertical": [],
}

# ============ STATE ============
var controller: Node = null
var active_chunks: Array[Node2D] = []
var current_pool: String = "fall"
var vertical_mode: bool = false
var _next_spawn_x: float = 0.0
var _next_spawn_y: float = 0.0
var _is_spawning: bool = false
var _pool_index: int = 0
var _warned_chunks: Dictionary = {}  # chunk instance_id → true


func _ready() -> void:
	_load_chunk_pools()


func _process(delta: float) -> void:
	if not _is_spawning or not controller:
		return

	var camera: RunnerCamera = controller.runner_camera
	if not camera:
		return

	if vertical_mode:
		_process_vertical(camera)
	else:
		_process_horizontal(camera)


func _process_horizontal(camera: RunnerCamera) -> void:
	# Spawn new chunks ahead of camera right edge
	var spawn_threshold: float = camera.get_right_edge() + SPAWN_AHEAD_DISTANCE
	while _next_spawn_x < spawn_threshold:
		if active_chunks.size() >= MAX_ACTIVE_CHUNKS:
			break
		_spawn_next_chunk()

	var left_edge: float = camera.get_left_edge()

	# Warn chunks approaching camera left edge (still partially visible)
	var warning_x: float = left_edge + DESPAWN_WARNING_OFFSET
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			continue
		if _warned_chunks.has(chunk.get_instance_id()):
			continue
		var cw: float = chunk.get_meta("chunk_width", 800.0)
		if chunk.global_position.x + cw < warning_x:
			_start_chunk_warning(chunk)

	# Despawn chunks behind camera left edge
	var despawn_x: float = left_edge - DESPAWN_BEHIND_DISTANCE
	var to_remove: Array[Node2D] = []
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			to_remove.append(chunk)
			continue
		var chunk_width: float = chunk.get_meta("chunk_width", 800.0)
		if chunk.global_position.x + chunk_width < despawn_x:
			to_remove.append(chunk)

	for chunk in to_remove:
		active_chunks.erase(chunk)
		if is_instance_valid(chunk):
			_warned_chunks.erase(chunk.get_instance_id())
			chunk.queue_free()


func _process_vertical(camera: RunnerCamera) -> void:
	# Spawn new chunks below camera bottom edge
	var spawn_threshold: float = camera.get_bottom_edge() + SPAWN_AHEAD_DISTANCE
	while _next_spawn_y < spawn_threshold:
		if active_chunks.size() >= MAX_ACTIVE_CHUNKS:
			break
		_spawn_next_chunk_vertical()

	var top_edge: float = camera.get_top_edge()

	# Warn chunks approaching camera top edge
	var warning_y: float = top_edge + DESPAWN_WARNING_OFFSET
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			continue
		if _warned_chunks.has(chunk.get_instance_id()):
			continue
		var ch: float = chunk.get_meta("chunk_height", 800.0)
		if chunk.global_position.y + ch < warning_y:
			_start_chunk_warning(chunk)

	# Despawn chunks above camera top edge
	var despawn_y: float = top_edge - DESPAWN_BEHIND_DISTANCE
	var to_remove: Array[Node2D] = []
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			to_remove.append(chunk)
			continue
		var chunk_height: float = chunk.get_meta("chunk_height", 800.0)
		if chunk.global_position.y + chunk_height < despawn_y:
			to_remove.append(chunk)

	for chunk in to_remove:
		active_chunks.erase(chunk)
		if is_instance_valid(chunk):
			_warned_chunks.erase(chunk.get_instance_id())
			chunk.queue_free()


# ============ SPAWNING ============
func start_spawning(pool_name: String) -> void:
	current_pool = pool_name
	_pool_index = 0
	_is_spawning = true

	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		_next_spawn_x = player.global_position.x - 200.0
	else:
		_next_spawn_x = 0.0

	print("[ChunkSpawner] Starting at X=%.0f, pool='%s'" % [_next_spawn_x, pool_name])

	var target_x: float = _next_spawn_x + 4000.0
	while _next_spawn_x < target_x and active_chunks.size() < MAX_ACTIVE_CHUNKS:
		_spawn_next_chunk()

	print("[ChunkSpawner] Spawned %d initial chunks, next at X=%.0f" % [active_chunks.size(), _next_spawn_x])


func switch_pool(pool_name: String) -> void:
	print("[ChunkSpawner] Switching pool: %s → %s" % [current_pool, pool_name])
	current_pool = pool_name
	_pool_index = 0


func switch_to_vertical() -> void:
	"""Switch to vertical spawning mode — clears all chunks and starts fresh"""
	print("[ChunkSpawner] Switching to vertical mode")
	vertical_mode = true
	clear_all_chunks()
	_pool_index = 0

	# Start spawning below current camera position
	var camera: RunnerCamera = controller.runner_camera if controller else null
	if camera:
		_next_spawn_y = camera.global_position.y
	else:
		_next_spawn_y = 0.0

	# Pre-spawn initial vertical chunks
	var target_y: float = _next_spawn_y + 3000.0
	while _next_spawn_y < target_y and active_chunks.size() < MAX_ACTIVE_CHUNKS:
		_spawn_next_chunk_vertical()

	print("[ChunkSpawner] Vertical: spawned %d initial chunks, next at Y=%.0f" % [active_chunks.size(), _next_spawn_y])


func stop_spawning() -> void:
	_is_spawning = false


func clear_all_chunks() -> void:
	"""Remove all active chunks from the scene"""
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()
	_warned_chunks.clear()


func _start_chunk_warning(chunk: Node2D) -> void:
	"""Start blinking all platform visuals in a chunk to warn of imminent despawn."""
	_warned_chunks[chunk.get_instance_id()] = true
	var rects: Array = _find_visual_rects(chunk)
	for rect in rects:
		if not is_instance_valid(rect):
			continue
		var original: Color = rect.color
		var warning: Color = Color(0.7, 0.12, 0.12, original.a * 0.7)
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(rect, "color", warning, 0.2)
		tween.tween_property(rect, "color", original.lerp(warning, 0.3), 0.2)


func _find_visual_rects(node: Node) -> Array:
	"""Recursively find all ColorRect nodes under a node."""
	var rects: Array = []
	if node is ColorRect:
		rects.append(node)
	for child in node.get_children():
		rects.append_array(_find_visual_rects(child))
	return rects


func _spawn_next_chunk() -> void:
	var pool: Array = chunk_pools.get(current_pool, [])
	var chunk: Node2D = null

	if pool.is_empty():
		chunk = _create_placeholder_chunk()
	else:
		var scene_path: String = pool[_pool_index % pool.size()]
		_pool_index += 1
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			chunk = scene.instantiate()
		else:
			push_warning("[ChunkSpawner] Chunk scene not found: %s" % scene_path)
			chunk = _create_placeholder_chunk()

	chunk.global_position = Vector2(_next_spawn_x, 0)
	var chunk_width: float = chunk.get_meta("chunk_width", 800.0)
	_next_spawn_x += chunk_width

	_add_chunk_to_scene(chunk)


func _spawn_next_chunk_vertical() -> void:
	var pool: Array = chunk_pools.get(current_pool, [])
	var chunk: Node2D = null

	if pool.is_empty():
		chunk = _create_vertical_placeholder_chunk()
	else:
		var scene_path: String = pool[_pool_index % pool.size()]
		_pool_index += 1
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			chunk = scene.instantiate()
		else:
			push_warning("[ChunkSpawner] Vertical chunk not found: %s" % scene_path)
			chunk = _create_vertical_placeholder_chunk()

	chunk.global_position = Vector2(0, _next_spawn_y)
	var chunk_height: float = chunk.get_meta("chunk_height", 800.0)
	_next_spawn_y += chunk_height

	_add_chunk_to_scene(chunk)


func _add_chunk_to_scene(chunk: Node2D) -> void:
	if controller:
		controller.get_parent().add_child(chunk)
	else:
		get_parent().add_child(chunk)
	active_chunks.append(chunk)


func _create_placeholder_chunk() -> Node2D:
	"""Creates a flat horizontal testing chunk"""
	var chunk := Node2D.new()
	chunk.name = "PlaceholderChunk"

	var width: float = 3000.0
	chunk.set_meta("chunk_width", width)

	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector2(width * 0.5, GROUND_Y)

	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(width + 20.0, 200.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)

	var ground_visual := ColorRect.new()
	ground_visual.size = Vector2(width, 200.0)
	ground_visual.position = Vector2(-width * 0.5, -20.0)
	ground_visual.color = Color(0.12, 0.08, 0.18)
	ground.add_child(ground_visual)

	chunk.add_child(ground)
	return chunk


func _create_vertical_placeholder_chunk() -> Node2D:
	"""Creates a vertical fall chunk with staggered platforms for reliable landing"""
	var chunk := Node2D.new()
	chunk.name = "VerticalPlaceholderChunk"

	var height: float = 800.0
	chunk.set_meta("chunk_height", height)
	chunk.set_meta("chunk_width", 1920.0)

	# 4 platforms per chunk — staggered left/right for reliable landing
	# Each platform is wide enough and alternates sides so the player always has somewhere to land
	var platform_count: int = 4
	var y_step: float = height / (platform_count + 1)

	for i in range(platform_count):
		var plat_width: float = randf_range(400.0, 700.0)
		# Alternate left/right to create a zigzag pattern
		var plat_x: float
		if i % 2 == 0:
			plat_x = randf_range(100.0, 600.0)  # Left side
		else:
			plat_x = randf_range(1920.0 - plat_width - 600.0, 1920.0 - plat_width - 100.0)  # Right side
		var plat_y: float = y_step * (i + 1)

		var platform := StaticBody2D.new()
		platform.name = "Platform_%d" % i
		platform.collision_layer = 1
		platform.collision_mask = 0
		platform.position = Vector2(plat_x + plat_width * 0.5, plat_y)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(plat_width, 32.0)
		shape.shape = rect
		platform.add_child(shape)

		var visual := ColorRect.new()
		visual.size = Vector2(plat_width, 32.0)
		visual.position = Vector2(-plat_width * 0.5, -16.0)
		visual.color = Color(0.15, 0.1, 0.22)
		platform.add_child(visual)

		chunk.add_child(platform)

	# Side walls to keep player in bounds
	for side in [-1, 1]:
		var wall := StaticBody2D.new()
		wall.name = "Wall_%s" % ("Left" if side == -1 else "Right")
		wall.collision_layer = 1
		wall.collision_mask = 0
		var wall_x: float = -32.0 if side == -1 else 1952.0
		wall.position = Vector2(wall_x, height * 0.5)

		var wall_shape := CollisionShape2D.new()
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(64.0, height)
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)

		chunk.add_child(wall)

	return chunk


# ============ POOL LOADING ============
func _load_chunk_pools() -> void:
	var base_path: String = "res://bosses/mirror/chunks/"
	var prefixes: Dictionary = {
		"fall": "chunk_fall_",
		"spiegel": "chunk_spiegel_",
		"abgrund": "chunk_abgrund_",
		"finale": "chunk_finale_",
		"fall_vertical": "chunk_vfall_",
		"finale_vertical": "chunk_vfinale_",
	}

	for pool_name in prefixes.keys():
		var prefix: String = prefixes[pool_name]
		for i in range(1, 11):
			var path: String = base_path + prefix + "%02d.tscn" % i
			if ResourceLoader.exists(path):
				chunk_pools[pool_name].append(path)

	for pool_name in chunk_pools.keys():
		var count: int = chunk_pools[pool_name].size()
		if count > 0:
			print("[ChunkSpawner] Pool '%s': %d chunks loaded" % [pool_name, count])


# ============ UTILITY ============
func get_active_waypoints() -> Array[Marker2D]:
	"""Returns all boss waypoints from active chunks, sorted by position"""
	var waypoints: Array[Marker2D] = []
	for chunk in active_chunks:
		if not is_instance_valid(chunk):
			continue
		for child in chunk.get_children():
			if child is Marker2D and child.is_in_group("boss_waypoints"):
				waypoints.append(child)

	if vertical_mode:
		waypoints.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	else:
		waypoints.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return waypoints
