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
	EventBus.enemy_died.connect(_on_enemy_died_in_run)


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

	# ARENA rooms use their own script — load directly without RunNodeRoom override
	if node.type == RunMapData.NodeType.ARENA:
		_load_arena_room(node)
		return

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


func _load_arena_room(node: RunMapData.MapNode) -> void:
	"""Loads the existing Urgathon boss arena with its own script intact"""
	var scene_path = "res://worlds/world_1_ruins/section_4_tempel/room_15_boss_urgathon.tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("[RunManager] Arena scene not found: %s" % scene_path)
		return

	var packed_scene: PackedScene = load(scene_path)
	var room: Node2D = packed_scene.instantiate()
	room.name = "ArenaRoom_%d" % node.id

	_replace_current_scene(room)
	print("[RunManager] Loaded arena room (Urgathon) for node %d" % node.id)

	# Monitor for boss defeat — then mark node complete and offer next doors
	_monitor_arena_completion(room, node)


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


func _monitor_arena_completion(room: Node2D, node: RunMapData.MapNode) -> void:
	"""Polls the arena room for fight_ended flag, then handles run-map completion"""
	# Wait for arena script to be ready
	await get_tree().create_timer(1.0).timeout

	# Poll fight_ended on the arena room script
	while is_instance_valid(room) and room.is_inside_tree():
		if room.get("fight_ended") == true:
			print("[RunManager] Arena fight ended — completing node")
			# Mark node as completed in the map
			if current_map:
				current_map.complete_current_node()
				run_rooms_completed += 1
				map_updated.emit()

			# Get next accessible nodes (should be BOSS)
			var next_nodes = current_map.get_accessible_nodes()
			if next_nodes.is_empty():
				end_run(true)
				return

			# Spawn exit doors on the arena room
			_spawn_arena_exit_doors(room, next_nodes)
			return

		await get_tree().create_timer(0.5).timeout


func _spawn_arena_exit_doors(room: Node2D, next_nodes: Array) -> void:
	"""Spawns simple exit doors on the existing arena room after fight is done"""
	var door_x_start: float = 400.0
	var door_spacing: float = 300.0

	for i in range(next_nodes.size()):
		var node: RunMapData.MapNode = next_nodes[i]
		var pos := Vector2(door_x_start + i * door_spacing, 300)

		var door = Node2D.new()
		door.name = "ExitDoor_%d" % i
		door.global_position = pos
		room.add_child(door)

		var door_color: Color = Color(0.9, 0.1, 0.1) if node.type == RunMapData.NodeType.BOSS else Color.WHITE
		var rect = ColorRect.new()
		rect.color = door_color
		rect.size = Vector2(80, 120)
		rect.position = Vector2(-40, -120)
		door.add_child(rect)

		var label = Label.new()
		label.text = node.get_type_name()
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(80, 30)
		label.position = Vector2(-40, -75)
		door.add_child(label)

		var prompt = Label.new()
		prompt.name = "PromptLabel"
		prompt.text = "E - %s" % node.get_type_name()
		prompt.add_theme_font_size_override("font_size", 14)
		prompt.add_theme_color_override("font_color", Color.WHITE)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.size = Vector2(140, 20)
		prompt.position = Vector2(-70, 10)
		prompt.visible = false
		door.add_child(prompt)

		var area = Area2D.new()
		area.name = "DoorArea"
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(100, 140)
		col.shape = shape
		col.position = Vector2(0, -60)
		area.add_child(col)
		area.collision_layer = 0
		area.collision_mask = 0
		area.set_collision_mask_value(2, true)
		area.monitoring = true
		door.add_child(area)

		var node_id = node.id
		area.body_entered.connect(func(body):
			if body is Murum or body.name == "Murum":
				prompt.visible = true
				door.set_meta("player_inside", true)
		)
		area.body_exited.connect(func(body):
			if body is Murum or body.name == "Murum":
				prompt.visible = false
				door.set_meta("player_inside", false)
		)

		door.set_meta("node_id", node_id)
		door.add_to_group("run_doors")

	# Process E key for these doors
	_start_arena_door_listener()


func _start_arena_door_listener() -> void:
	"""Listens for E key presses to enter doors in arena room"""
	while true:
		await get_tree().process_frame
		var interact_pressed = false
		if InputManager:
			interact_pressed = InputManager.is_p1_action_just_pressed("interact")
		else:
			interact_pressed = Input.is_action_just_pressed("interact")

		if not interact_pressed:
			continue

		for door in get_tree().get_nodes_in_group("run_doors"):
			if door.has_meta("player_inside") and door.get_meta("player_inside"):
				var node_id: int = door.get_meta("node_id")
				print("[RunManager] Arena exit -> node %d" % node_id)
				current_state = RunState.MAP_VIEW
				select_map_node(node_id)
				return


func transition_to_next_world(next_world_id: RunMapData.WorldId) -> void:
	"""Transition to the next world after beating a boss (W1->W2, W2->W3)"""
	print("[RunManager] Transitioning from '%s' to '%s'" % [
		_get_world_name(current_world), _get_world_name(next_world_id)
	])

	current_world = next_world_id
	current_node = null

	# Generate new map for the next world
	current_map = RunMapGenerator.generate_map(next_world_id)
	RunMapGenerator.print_map(current_map)

	current_state = RunState.MAP_VIEW
	map_updated.emit()

	# Load entry room for the new world
	_load_first_room()


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

	# Show run end screen
	_show_run_end_screen(victory)


func _show_run_end_screen(victory: bool) -> void:
	var screen_scene = load("res://ui/run_end_screen.tscn")
	if screen_scene:
		var screen = screen_scene.instantiate()
		get_tree().root.add_child(screen)
		screen.show_summary(victory, run_rooms_completed, run_enemies_killed)
	else:
		push_warning("[RunManager] run_end_screen.tscn not found, returning to Limbus")
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


func _on_enemy_died_in_run(_enemy: Node, _position: Vector2) -> void:
	on_enemy_killed()


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
