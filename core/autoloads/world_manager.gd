extends Node

## Central World and Room Management System (Simplified)
## Handles scene transitions and room state

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_PATH: String = "res://levels/%s.tscn"

# ============================================================================
# STATE
# ============================================================================

var current_world: String = "world_1_ruins"
var current_room: String = "test_room"
var previous_room: String = ""

var last_checkpoint: String = ""
var last_checkpoint_position: Vector2 = Vector2.ZERO

# Room State Tracking
var cleared_rooms: Dictionary = {}  # room_id: bool
var visited_rooms: Array[String] = []
var unlocked_doors: Array[String] = []

# World Progression
var bosses_defeated: Array[String] = []
var worlds_unlocked: Array[String] = ["world_1_ruins"]

# Player Data (for restoration after save load)
var pending_player_data: Dictionary = {}
var pending_spawn_point: String = ""

# Transition State
var is_transitioning: bool = false
var fade_overlay: ColorRect

# ============================================================================
# SIGNALS
# ============================================================================

signal world_changed(world_id: String)
signal room_changed(room_id: String)
signal room_cleared(room_id: String)
signal door_unlocked(door_id: String)
signal transition_started
signal transition_completed

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create fade overlay for transitions
	_create_fade_overlay()

	print("[WorldManager] Initialized")
	print("[WorldManager] Current: %s/%s" % [current_world, current_room])

func _create_fade_overlay() -> void:
	"""Creates fullscreen fade overlay"""
	# Create CanvasLayer for overlay
	var canvas = CanvasLayer.new()
	canvas.name = "TransitionOverlay"
	canvas.layer = 100
	add_child(canvas)

	# Create ColorRect for fade
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = Vector2(1920, 1080)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_overlay)

	print("[WorldManager] Fade overlay created")

# ============================================================================
# ROOM TRANSITION
# ============================================================================

func transition_to_room(room_id: String, spawn_point: String = "default") -> void:
	"""Transitions to a new room with fade effect"""

	if is_transitioning:
		push_warning("[WorldManager] Already transitioning, ignoring request")
		return

	print("[WorldManager] Transitioning to %s (spawn: %s)" % [room_id, spawn_point])

	is_transitioning = true
	transition_started.emit()

	# Store previous room
	previous_room = current_room

	# Store spawn point for after load
	pending_spawn_point = spawn_point

	# Start transition sequence
	await _execute_transition(room_id)

	is_transitioning = false
	transition_completed.emit()

func _execute_transition(room_id: String) -> void:
	"""Executes room transition sequence"""

	# 1. Fade out
	await _fade_out(0.5)

	# 2. Save player and UI elements before unloading
	var player = get_tree().get_first_node_in_group("player")
	var hud = get_tree().get_first_node_in_group("hud")
	var death_screen = get_tree().get_first_node_in_group("death_screen")

	var preserved_nodes = []

	if player:
		var player_parent = player.get_parent()
		player_parent.remove_child(player)
		add_child(player)
		preserved_nodes.append(player)
		print("[WorldManager] Player preserved for transition")

	if hud:
		var hud_parent = hud.get_parent()
		hud_parent.remove_child(hud)
		add_child(hud)
		preserved_nodes.append(hud)
		print("[WorldManager] HUD preserved for transition")

	if death_screen:
		var death_screen_parent = death_screen.get_parent()
		death_screen_parent.remove_child(death_screen)
		add_child(death_screen)
		preserved_nodes.append(death_screen)
		print("[WorldManager] DeathScreen preserved for transition")

	# 3. Unload current scene
	_unload_current_scene()

	# 4. Load new scene
	var scene_path = _get_room_path(room_id)
	await _load_scene(scene_path)

	# 4. Update state
	previous_room = current_room
	current_room = room_id

	# Add to visited
	var full_room_id = "%s/%s" % [current_world, room_id]
	if full_room_id not in visited_rooms:
		visited_rooms.append(full_room_id)

	# 5. Spawn player
	await _spawn_player_at_point(pending_spawn_point)

	# 6. Restore player data (if loading save)
	if not pending_player_data.is_empty():
		_restore_player_data()
		pending_player_data.clear()

	# 7. Fade in
	await _fade_in(0.5)

	# 8. Emit signals
	room_changed.emit(room_id)

	print("[WorldManager] Transition completed: %s" % room_id)

func _unload_current_scene() -> void:
	"""Unloads current game scene"""
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)

	if current_scene and current_scene != self:
		current_scene.queue_free()
		await current_scene.tree_exited

	# Wait a frame for cleanup
	await get_tree().process_frame

func _load_scene(scene_path: String) -> void:
	"""Loads scene synchronously"""

	if not ResourceLoader.exists(scene_path):
		push_error("[WorldManager] Scene not found: %s" % scene_path)
		return

	var scene = load(scene_path)
	if not scene:
		push_error("[WorldManager] Failed to load scene: %s" % scene_path)
		return

	var instance = scene.instantiate()
	get_tree().root.add_child(instance)

	# Wait for scene to be ready
	await get_tree().process_frame

func _get_room_path(room_id: String) -> String:
	"""Returns scene path for room"""
	# If room_id already contains path separators, it's a full path
	if "/" in room_id:
		return "res://%s.tscn" % room_id
	else:
		return ROOM_PATH % room_id

# ============================================================================
# PLAYER SPAWNING
# ============================================================================

func _spawn_player_at_point(spawn_point_name: String) -> void:
	"""Spawns player at named spawn point or default position"""

	# Wait for scene to be ready
	await get_tree().process_frame

	# Get current scene
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)

	# Get preserved nodes (might be children of WorldManager after transition)
	var player = get_tree().get_first_node_in_group("player")
	var hud = get_tree().get_first_node_in_group("hud")
	var death_screen = get_tree().get_first_node_in_group("death_screen")

	if not player:
		push_warning("[WorldManager] Player not found in scene!")
		return

	# Remove duplicate cameras from the new scene (player has its own camera)
	var scene_cameras = current_scene.find_children("*", "Camera2D", true, false)
	for cam in scene_cameras:
		if cam.get_parent() != player:  # Don't remove player's camera
			print("[WorldManager] Removing duplicate camera: %s" % cam.name)
			cam.queue_free()

	# Move preserved nodes from WorldManager to new scene
	if player.get_parent() == self and current_scene:
		remove_child(player)
		current_scene.add_child(player)

	if hud and hud.get_parent() == self and current_scene:
		remove_child(hud)
		current_scene.add_child(hud)
		print("[WorldManager] HUD restored to scene")

	if death_screen and death_screen.get_parent() == self and current_scene:
		remove_child(death_screen)
		current_scene.add_child(death_screen)
		print("[WorldManager] DeathScreen restored to scene")

	# Ensure player's camera is active
	var player_camera = player.get_node_or_null("PlayerCamera")
	if player_camera:
		player_camera.enabled = true
		player_camera.make_current()
		print("[WorldManager] Player camera activated")

	# Find spawn point in the new scene
	var spawn_points = current_scene.find_children("*", "Node2D", true, false)
	var spawn_position = Vector2(200, 600)  # Default position

	for node in spawn_points:
		if node.name == spawn_point_name or (spawn_point_name == "default" and node.name == "Default"):
			spawn_position = node.global_position
			print("[WorldManager] Found spawn point: %s at %v" % [node.name, spawn_position])
			break

	# Position player at spawn point
	player.global_position = spawn_position

	# If we have pending player data with position, use that instead
	if not pending_player_data.is_empty() and pending_player_data.has("position"):
		var pos = pending_player_data["position"]
		player.global_position = Vector2(pos["x"], pos["y"])
		print("[WorldManager] Player spawned at saved position: %v" % player.global_position)
	else:
		print("[WorldManager] Player spawned at spawn point: %v" % player.global_position)

func _restore_player_data() -> void:
	"""Restores player state from pending data (after save load)"""

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get pending data from SaveManager
	var player_data = {}
	if SaveManager and not SaveManager.pending_player_data.is_empty():
		player_data = SaveManager.pending_player_data
	elif not pending_player_data.is_empty():
		player_data = pending_player_data

	if player_data.is_empty():
		return

	# Restore HP
	if player_data.has("current_hp"):
		player.current_hp = player_data["current_hp"]
		if player.has("MAX_HP"):
			EventBus.player_hp_changed.emit(player.current_hp, player.MAX_HP)

	# Restore Mana
	if player_data.has("current_mana"):
		player.current_mana = player_data["current_mana"]
		if player.has("MAX_MANA"):
			EventBus.player_mana_changed.emit(player.current_mana, player.MAX_MANA)

	print("[WorldManager] Player data restored")

	# Clear pending data
	if SaveManager:
		SaveManager.pending_player_data = {}
	pending_player_data = {}

# ============================================================================
# FADE TRANSITIONS
# ============================================================================

func _fade_out(duration: float) -> void:
	"""Fades to black"""
	if not fade_overlay:
		return

	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), duration)
	await tween.finished

func _fade_in(duration: float) -> void:
	"""Fades from black"""
	if not fade_overlay:
		return

	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0), duration)
	await tween.finished

# ============================================================================
# ROOM STATE
# ============================================================================

func mark_room_cleared(room_id: String = "") -> void:
	"""Marks room as cleared (all enemies defeated)"""

	if room_id.is_empty():
		room_id = "%s/%s" % [current_world, current_room]

	if is_room_cleared(room_id):
		return  # Already cleared

	cleared_rooms[room_id] = true

	print("[WorldManager] Room cleared: %s" % room_id)
	room_cleared.emit(room_id)

	# Unlock associated doors
	_unlock_doors_for_room(room_id)

func is_room_cleared(room_id: String) -> bool:
	"""Returns true if room is cleared"""
	return cleared_rooms.get(room_id, false)

func _unlock_doors_for_room(room_id: String) -> void:
	"""Unlocks all doors associated with room clear"""

	# Find doors in current scene that should unlock
	var doors = get_tree().get_nodes_in_group("doors")

	for door in doors:
		if door.has_method("try_unlock_on_clear"):
			door.try_unlock_on_clear(room_id)

# ============================================================================
# DOOR MANAGEMENT
# ============================================================================

func unlock_door(door_id: String) -> void:
	"""Unlocks a door by ID"""

	if door_id in unlocked_doors:
		return  # Already unlocked

	unlocked_doors.append(door_id)

	print("[WorldManager] Door unlocked: %s" % door_id)
	door_unlocked.emit(door_id)

func is_door_unlocked(door_id: String) -> bool:
	"""Returns true if door is unlocked"""
	return door_id in unlocked_doors

# ============================================================================
# CHECKPOINT SYSTEM
# ============================================================================

func set_last_checkpoint(checkpoint_id: String, position: Vector2) -> void:
	"""Sets last activated checkpoint"""

	last_checkpoint = checkpoint_id
	last_checkpoint_position = position

	print("[WorldManager] Checkpoint set: %s at %v" % [checkpoint_id, position])

func respawn_at_checkpoint() -> void:
	"""Respawns player at last checkpoint"""

	if last_checkpoint.is_empty():
		push_warning("[WorldManager] No checkpoint set, respawning at default")
		# Just reset player position in current room
		var player = get_tree().get_first_node_in_group("player")
		if player and last_checkpoint_position != Vector2.ZERO:
			player.global_position = last_checkpoint_position
		return

	# For now, just reset position - full version would parse checkpoint ID
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = last_checkpoint_position

# ============================================================================
# SAVE/LOAD INTEGRATION
# ============================================================================

func get_progression_data() -> Dictionary:
	"""Returns progression data for saving"""

	return {
		"current_world": current_world,
		"current_room": current_room,
		"last_checkpoint": last_checkpoint,
		"last_checkpoint_position": {
			"x": last_checkpoint_position.x,
			"y": last_checkpoint_position.y
		},
		"worlds_unlocked": worlds_unlocked,
		"rooms_cleared": cleared_rooms,
		"visited_rooms": visited_rooms,
		"unlocked_doors": unlocked_doors,
		"bosses_defeated": bosses_defeated
	}

func load_progression_data(data: Dictionary) -> void:
	"""Loads progression data from save"""

	current_world = data.get("current_world", "world_1_ruins")
	current_room = data.get("current_room", "test_room")
	last_checkpoint = data.get("last_checkpoint", "")

	var checkpoint_pos = data.get("last_checkpoint_position", {})
	last_checkpoint_position = Vector2(
		checkpoint_pos.get("x", 0.0),
		checkpoint_pos.get("y", 0.0)
	)

	worlds_unlocked = data.get("worlds_unlocked", ["world_1_ruins"])
	cleared_rooms = data.get("rooms_cleared", {})
	visited_rooms = data.get("visited_rooms", [])
	unlocked_doors = data.get("unlocked_doors", [])
	bosses_defeated = data.get("bosses_defeated", [])

	print("[WorldManager] Progression data loaded")

# ============================================================================
# UTILITY
# ============================================================================

func get_current_room_full_id() -> String:
	"""Returns full room ID (world/room)"""
	return "%s/%s" % [current_world, current_room]

func get_enemies_in_room() -> Array:
	"""Returns all enemies in current room"""
	return get_tree().get_nodes_in_group("enemies")

func is_room_active_combat() -> bool:
	"""Returns true if room has active enemies"""
	var enemies = get_enemies_in_room()
	return enemies.size() > 0
