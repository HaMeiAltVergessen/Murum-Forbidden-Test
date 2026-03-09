extends Node
## RunManager handles roguelike run state, lives, and run currency (Magicka)
## Manages the loop: Limbus → Run → Death/Victory → Limbus
## Holds the current Run-Map (Hades-style node network)
## Doors in-room handle node selection (no separate map UI)

# ============ RUN STATE ============
enum RunState {
	IDLE,       # In Limbus hub, no run active
	MAP_VIEW,   # Between nodes (doors spawned in room, choosing next)
	IN_NODE,    # Inside a node (combat, treasure, event, etc.)
	ENDED       # Run just ended (transitioning back to Limbus)
}

var current_state: RunState = RunState.IDLE

# ============ LIVES ============
const BASE_LIVES: int = 1
const MAX_LIVES: int = 3

var current_lives: int = BASE_LIVES
var max_lives: int = BASE_LIVES  # Increased by perma upgrades

# ============ MAGICKA (PERSISTENT CURRENCY) ============
var magicka: int = 0

# ============ RUN DATA ============
var run_rooms_completed: int = 0
var run_enemies_killed: int = 0

# ============ RUN MAP ============
var current_map: RunMapData.Map = null       # Generated map for current run
var current_world: RunMapData.WorldId = RunMapData.WorldId.NIEMANDSLAND
var current_node: RunMapData.MapNode = null  # Currently active node

# ============ SIGNALS ============
signal run_started()
signal run_ended(victory: bool)
signal lives_changed(current: int, maximum: int)
signal magicka_changed(new_amount: int)
signal player_run_death()  # Player died during run, loses a life
signal map_updated()       # Map state changed (node completed, etc.)
signal node_selected(node: RefCounted)  # Player selected a node


func _ready() -> void:
	print("[RunManager] Initialized")
	EventBus.player_died.connect(_on_player_died_in_run)


# ============ RUN LIFECYCLE ============
func start_run(world_id: RunMapData.WorldId = RunMapData.WorldId.NIEMANDSLAND) -> void:
	if current_state == RunState.MAP_VIEW or current_state == RunState.IN_NODE:
		push_warning("[RunManager] Run already active!")
		return

	current_world = world_id
	current_lives = max_lives
	run_rooms_completed = 0
	run_enemies_killed = 0
	current_node = null

	# Generate the map
	current_map = RunMapGenerator.generate_map(world_id)
	RunMapGenerator.print_map(current_map)

	current_state = RunState.MAP_VIEW
	lives_changed.emit(current_lives, max_lives)
	run_started.emit()

	print("[RunManager] Run started in '%s' with %d lives" % [
		_get_world_name(world_id), current_lives
	])

	# Load the first room directly (doors for row 0 choices)
	_load_first_room()


func _load_first_room() -> void:
	"""Load the entry room .tscn and attach RunNodeRoom controller"""
	_preserve_player()

	var scene_path = RunRoomPool.get_entry_room_path(current_world)
	if scene_path.is_empty():
		push_error("[RunManager] No entry room for world %d" % current_world)
		return

	var room = _load_room_scene(scene_path)
	if not room:
		return

	room.name = "RunEntryRoom"
	room.node_type = RunMapData.NodeType.REST
	room.world_id = current_world
	room.node_data = null

	_replace_current_scene(room)
	print("[RunManager] Entry room loaded: %s" % scene_path)


func select_map_node(node_id: int) -> void:
	"""Player selected a node (via door interaction in room)"""
	if current_state != RunState.MAP_VIEW or not current_map:
		return

	var node: RunMapData.MapNode = current_map.select_node(node_id)
	if not node:
		push_warning("[RunManager] Invalid node ID: %d" % node_id)
		return

	current_node = node
	current_state = RunState.IN_NODE
	node_selected.emit(node)
	print("[RunManager] Node selected: %d (%s)" % [node.id, node.get_type_name()])

	# Load the room for this node
	_load_node_room(node)


func _load_node_room(node: RunMapData.MapNode) -> void:
	"""Loads a handcrafted .tscn room and attaches RunNodeRoom controller"""
	_preserve_player()

	var scene_path = RunRoomPool.get_room_scene_path(current_world, node.type)
	if scene_path.is_empty():
		push_error("[RunManager] No room scene for node type %d" % node.type)
		return

	var room = _load_room_scene(scene_path)
	if not room:
		return

	room.name = "RunNodeRoom_%d" % node.id
	room.node_type = node.type
	room.world_id = current_world
	room.node_data = node

	_replace_current_scene(room)
	print("[RunManager] Loaded room for node %d (%s): %s" % [node.id, node.get_type_name(), scene_path])


func _preserve_player() -> void:
	"""Reparent player to root so it survives scene transitions"""
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player
		if player.get_parent():
			player.get_parent().remove_child(player)
		get_tree().root.add_child(player)


func _load_room_scene(scene_path: String) -> RunNodeRoom:
	"""Load a .tscn room scene and attach the RunNodeRoom script"""
	if not ResourceLoader.exists(scene_path):
		push_error("[RunManager] Room scene not found: %s" % scene_path)
		return null

	var packed_scene: PackedScene = load(scene_path)
	var room_instance: Node2D = packed_scene.instantiate()

	# Attach the RunNodeRoom controller script
	var script = preload("res://worlds/run_rooms/run_node_room.gd")
	room_instance.set_script(script)

	return room_instance as RunNodeRoom


func _replace_current_scene(room: Node) -> void:
	"""Replace the current scene with a new room"""
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.queue_free()

	get_tree().root.add_child(room)
	get_tree().current_scene = room


func end_run(victory: bool) -> void:
	if current_state == RunState.IDLE or current_state == RunState.ENDED:
		return

	current_state = RunState.ENDED
	run_ended.emit(victory)
	print("[RunManager] Run ended. Victory: %s | Rooms: %d | Kills: %d" % [
		victory, run_rooms_completed, run_enemies_killed
	])

	# End challenge run if active
	if ChallengeRunManager and ChallengeRunManager.is_challenge_run_active:
		if victory:
			ChallengeRunManager.complete_challenge_run()
		else:
			ChallengeRunManager.end_challenge_run()

	# Return to Limbus
	_return_to_limbus()


func _return_to_limbus() -> void:
	current_state = RunState.IDLE
	current_map = null
	current_node = null

	# Reset run-volatile data (Gold, Consumables)
	if GameManager:
		GameManager.coins_collected = 0
		EventBus.coins_changed.emit(0)
	if InventoryManager:
		InventoryManager.inventory["consumables"].clear()
		InventoryManager.inventory_changed.emit()

	# Load Limbus scene
	get_tree().change_scene_to_file("res://worlds/limbus/limbus.tscn")
	print("[RunManager] Returned to Limbus")


# ============ LIVES ============
func lose_life() -> bool:
	"""Removes one life. Returns true if lives remain, false if run over."""
	current_lives -= 1
	lives_changed.emit(current_lives, max_lives)
	print("[RunManager] Life lost. Remaining: %d/%d" % [current_lives, max_lives])

	if current_lives <= 0:
		end_run(false)
		return false
	return true


func get_lives() -> int:
	return current_lives


func set_max_lives(new_max: int) -> void:
	max_lives = clampi(new_max, BASE_LIVES, MAX_LIVES)
	print("[RunManager] Max lives set to %d" % max_lives)


# ============ MAGICKA ============
func add_magicka(amount: int) -> void:
	magicka += amount
	magicka_changed.emit(magicka)
	print("[RunManager] Magicka gained: +%d. Total: %d" % [amount, magicka])


func spend_magicka(amount: int) -> bool:
	"""Spends Magicka. Returns false if not enough."""
	if magicka < amount:
		return false
	magicka -= amount
	magicka_changed.emit(magicka)
	print("[RunManager] Magicka spent: -%d. Total: %d" % [amount, magicka])
	return true


func get_magicka() -> int:
	return magicka


# ============ RUN TRACKING ============
func on_room_completed() -> void:
	if is_run_active():
		run_rooms_completed += 1
		print("[RunManager] Room completed. Total: %d" % run_rooms_completed)


func on_enemy_killed() -> void:
	if is_run_active():
		run_enemies_killed += 1


# ============ DEATH HANDLING ============
func _on_player_died_in_run() -> void:
	if not is_run_active():
		return

	print("[RunManager] Player died during run")
	player_run_death.emit()

	# Use a life
	var lives_remain = lose_life()
	if lives_remain:
		# Respawn in same room
		call_deferred("_respawn_in_room")


func _respawn_in_room() -> void:
	"""Respawns player in current room after losing a life"""
	if GameManager and GameManager.player:
		GameManager.respawn_player()
		GameManager.current_state = GameManager.GameState.PLAYING
		print("[RunManager] Player respawned (lives remaining: %d)" % current_lives)


# ============ SAVE/LOAD (Magicka is persistent, map state for mid-run saves) ============
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"magicka": magicka,
		"max_lives": max_lives
	}
	if current_map and is_run_active():
		data["current_map"] = current_map.to_dict()
		data["current_world"] = current_world
		data["current_lives"] = current_lives
		data["run_rooms_completed"] = run_rooms_completed
		data["run_enemies_killed"] = run_enemies_killed
		data["run_state"] = current_state
	return data


func load_from_save(data: Dictionary) -> void:
	magicka = data.get("magicka", 0)
	max_lives = data.get("max_lives", BASE_LIVES)
	magicka_changed.emit(magicka)

	if data.has("current_map"):
		current_map = RunMapData.Map.from_dict(data["current_map"])
		current_world = data.get("current_world", RunMapData.WorldId.NIEMANDSLAND)
		current_lives = data.get("current_lives", max_lives)
		run_rooms_completed = data.get("run_rooms_completed", 0)
		run_enemies_killed = data.get("run_enemies_killed", 0)
		current_state = data.get("run_state", RunState.MAP_VIEW)
		lives_changed.emit(current_lives, max_lives)
		print("[RunManager] Loaded mid-run save: World=%d, Lives=%d" % [current_world, current_lives])
	else:
		print("[RunManager] Loaded: Magicka=%d, MaxLives=%d" % [magicka, max_lives])


func is_run_active() -> bool:
	return current_state == RunState.MAP_VIEW or current_state == RunState.IN_NODE


func get_current_map() -> RunMapData.Map:
	return current_map


func get_accessible_nodes() -> Array:
	"""Returns nodes the player can select next"""
	if not current_map:
		return []
	return current_map.get_accessible_nodes()


# ============ HELPERS ============
func _get_world_name(world_id: RunMapData.WorldId) -> String:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND: return "Das Niemandsland"
		RunMapData.WorldId.KOLLEKTIV: return "Das Kollektiv"
		RunMapData.WorldId.ABGRUND: return "Der Abgrund"
	return "Unbekannt"
