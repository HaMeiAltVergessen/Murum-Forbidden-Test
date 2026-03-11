extends Node2D
## Controller script for Run-Map room nodes
## Attached to handcrafted .tscn room scenes at runtime
## Handles: player setup, combat spawning, node-type logic, Hades-style exit doors
class_name RunNodeRoom

# ============ DOOR COLORS ============
const DOOR_COLORS: Dictionary = {
	RunMapData.NodeType.COMBAT: Color(0.8, 0.3, 0.2),
	RunMapData.NodeType.ELITE: Color(0.9, 0.6, 0.1),
	RunMapData.NodeType.TREASURE: Color(0.2, 0.8, 0.4),
	RunMapData.NodeType.REST: Color(0.3, 0.6, 0.9),
	RunMapData.NodeType.EVENT: Color(0.7, 0.4, 0.9),
	RunMapData.NodeType.BOSS: Color(0.9, 0.1, 0.1),
	RunMapData.NodeType.SHOP: Color(1.0, 0.85, 0.2),
	RunMapData.NodeType.ARENA: Color(0.9, 0.2, 0.5),
}

# ============ ROOM CONFIG (set by RunManager before adding to tree) ============
var node_type: RunMapData.NodeType = RunMapData.NodeType.COMBAT
var world_id: RunMapData.WorldId = RunMapData.WorldId.NIEMANDSLAND
var node_data: RunMapData.MapNode = null

# ============ INTERNAL STATE ============
var arena_controller: ArenaController = null
var doors_spawned: bool = false


func _ready() -> void:
	print("[RunNodeRoom] Initialized (type: %s)" % RunMapData.NodeType.keys()[node_type])
	call_deferred("_activate")


func _activate() -> void:
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	_setup_player()
	_spawn_exit_doors()

	match node_type:
		RunMapData.NodeType.COMBAT, RunMapData.NodeType.ELITE:
			_setup_combat()
		RunMapData.NodeType.TREASURE:
			_setup_treasure()
		RunMapData.NodeType.REST:
			_setup_rest()
		RunMapData.NodeType.EVENT:
			_setup_event()
		RunMapData.NodeType.BOSS:
			_setup_boss()
		RunMapData.NodeType.SHOP:
			_setup_shop()
		RunMapData.NodeType.ARENA:
			pass  # Arena rooms use their own script, loaded directly by RunManager


# ============ PLAYER SETUP ============
func _setup_player() -> void:
	var spawn_marker: Marker2D = _find_spawn_point()

	if not GameManager.player or not is_instance_valid(GameManager.player):
		_spawn_new_player(spawn_marker)
		return

	var player = GameManager.player
	if player.get_parent() != self:
		if player.get_parent():
			player.get_parent().remove_child(player)
		add_child(player)

	player.global_position = spawn_marker.global_position
	player.z_index = 100
	player.z_as_relative = false
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	print("[RunNodeRoom] Player repositioned at %s" % spawn_marker.global_position)


func _spawn_new_player(spawn_marker: Marker2D) -> void:
	var player_scene = preload("res://player/murum.tscn")
	var player = player_scene.instantiate()
	player.global_position = spawn_marker.global_position
	add_child(player)
	if GameManager:
		GameManager.set_player(player)
	print("[RunNodeRoom] Player spawned")


func _find_spawn_point() -> Marker2D:
	"""Find the player spawn point in the room (SpawnPoints/Default)"""
	var spawn_points_node = get_node_or_null("SpawnPoints")
	if spawn_points_node:
		var default_spawn = spawn_points_node.get_node_or_null("Default")
		if default_spawn and default_spawn is Marker2D:
			return default_spawn
	# Fallback: search for any SpawnPoint in the scene
	for child in get_children():
		if child is Marker2D and child.name.contains("Spawn"):
			return child
	# Last resort: create a temporary marker
	var fallback = Marker2D.new()
	fallback.position = Vector2(960, 760)
	add_child(fallback)
	return fallback


# ============ COMBAT SETUP ============
func _setup_combat() -> void:
	"""Spawn all enemies at once using ArenaController + room's EnemySpawnPoints"""
	var wave_config = RunRoomPool.build_single_wave_config(world_id, node_type)
	if not wave_config:
		push_warning("[RunNodeRoom] No encounter generated!")
		_on_combat_completed()
		return

	# Collect enemy spawn points from the .tscn
	var enemy_spawn_markers: Array[Marker2D] = []
	var spawn_container = get_node_or_null("EnemySpawnPoints")
	if spawn_container:
		for child in spawn_container.get_children():
			if child is Marker2D:
				enemy_spawn_markers.append(child)

	if enemy_spawn_markers.is_empty():
		push_warning("[RunNodeRoom] No EnemySpawnPoints found in room!")
		_on_combat_completed()
		return

	# Create ArenaController
	arena_controller = ArenaController.new()
	arena_controller.name = "ArenaController"
	arena_controller.arena_id = "run_node_%d" % (node_data.id if node_data else 0)
	arena_controller.wave_configs = [wave_config]
	arena_controller.start_mode = ArenaController.StartMode.MANUAL
	arena_controller.lock_doors_during_waves = false
	arena_controller.spawn_coins_on_clear = true
	arena_controller.coins_per_wave = 15
	add_child(arena_controller)

	for marker in enemy_spawn_markers:
		arena_controller.spawn_points.append(arena_controller.get_path_to(marker))

	arena_controller.arena_completed.connect(_on_combat_completed)

	# Start combat after short delay
	get_tree().create_timer(1.5).timeout.connect(func():
		if arena_controller and not arena_controller.is_cleared:
			arena_controller.start_arena()
			print("[RunNodeRoom] Combat started!")
	)

	var total_enemies = 0
	for entry in wave_config.enemies:
		total_enemies += entry.count
	print("[RunNodeRoom] Combat: %d enemies to defeat" % total_enemies)


func _on_combat_completed() -> void:
	print("[RunNodeRoom] Combat completed!")
	_show_completion_ui("Alle Gegner besiegt!")
	get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)


# ============ TREASURE SETUP ============
func _setup_treasure() -> void:
	print("[RunNodeRoom] Treasure room")

	# Heal player as bonus
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player
		if player.has_node("HealthComponent"):
			player.get_node("HealthComponent").reset_health()
		if player.has_node("ManaComponent"):
			player.get_node("ManaComponent").reset_mana()

	var items = [
		{"name": "Heilkraut", "desc": "Heilt 30 HP"},
		{"name": "Schattenstein", "desc": "+5% Schaden fuer diesen Run"},
		{"name": "Mana-Elixier", "desc": "Stellt 20 Mana wieder her"},
	]
	var chosen = items[randi() % items.size()]

	_show_completion_ui("Schatz: %s gefunden!" % chosen["name"])
	EventBus.show_notification.emit("Du erhaeltst: %s — %s" % [chosen["name"], chosen["desc"]], 4.0)
	print("[RunNodeRoom] Treasure auto-collected: %s" % chosen["name"])

	get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)


# ============ REST SETUP ============
func _setup_rest() -> void:
	print("[RunNodeRoom] Rest room — healing player")

	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player
		if player.has_node("HealthComponent"):
			player.get_node("HealthComponent").reset_health()
		if player.has_node("ManaComponent"):
			player.get_node("ManaComponent").reset_mana()

	var container = VBoxContainer.new()
	container.position = Vector2(400, 200)
	container.custom_minimum_size = Vector2(500, 300)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	var title = Label.new()
	title.text = _get_rest_name()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	var heal_label = Label.new()
	heal_label.text = "HP und Mana vollstaendig wiederhergestellt!"
	heal_label.add_theme_font_size_override("font_size", 20)
	heal_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(heal_label)

	EventBus.show_notification.emit("Volle Heilung!", 3.0)
	get_tree().create_timer(1.0).timeout.connect(_on_node_cleared)


# ============ EVENT SETUP ============
var event_choice_made: bool = false
var _player_in_choice: String = ""  # "A" or "B" or ""

func _setup_event() -> void:
	print("[RunNodeRoom] Event room")

	var choices = get_node_or_null("EventChoices")
	if not choices:
		push_warning("[RunNodeRoom] No EventChoices node found in scene!")
		_on_node_cleared()
		return

	var choice_a: Area2D = choices.get_node_or_null("ChoiceA")
	var choice_b: Area2D = choices.get_node_or_null("ChoiceB")

	if choice_a:
		choice_a.body_entered.connect(func(body):
			if body is Murum or body.name == "Murum":
				_player_in_choice = "A"
		)
		choice_a.body_exited.connect(func(body):
			if body is Murum or body.name == "Murum":
				if _player_in_choice == "A":
					_player_in_choice = ""
		)

	if choice_b:
		choice_b.body_entered.connect(func(body):
			if body is Murum or body.name == "Murum":
				_player_in_choice = "B"
		)
		choice_b.body_exited.connect(func(body):
			if body is Murum or body.name == "Murum":
				if _player_in_choice == "B":
					_player_in_choice = ""
		)


func _confirm_event_choice() -> void:
	"""Called when player presses E inside a choice zone"""
	if event_choice_made or _player_in_choice == "":
		return
	event_choice_made = true

	var choices = get_node_or_null("EventChoices")
	if not choices:
		return

	var chosen_key := _player_in_choice  # "A" or "B"
	var other_key := "B" if chosen_key == "A" else "A"

	# Remove the chosen zone
	var chosen_node = choices.get_node_or_null("Choice" + chosen_key)
	if chosen_node:
		chosen_node.queue_free()

	# Grey out the other zone
	var other_node = choices.get_node_or_null("Choice" + other_key)
	if other_node:
		other_node.modulate = Color(0.4, 0.4, 0.4, 0.5)
		# Disable collision
		var area = other_node as Area2D
		if area:
			area.monitoring = false

	if chosen_key == "A":
		EventBus.show_notification.emit("Du akzeptierst das Angebot.", 3.0)
	else:
		EventBus.show_notification.emit("Du gehst weiter.", 3.0)

	_on_node_cleared()


# ============ SHOP SETUP ============
var _player_in_shop_area: bool = false

func _setup_shop() -> void:
	print("[RunNodeRoom] Shop room")

	var merchant_area: Area2D = get_node_or_null("MerchantArea")
	if not merchant_area:
		push_warning("[RunNodeRoom] No MerchantArea in shop room!")
		_on_node_cleared()
		return

	merchant_area.body_entered.connect(func(body):
		if body is Murum or body.name == "Murum":
			_player_in_shop_area = true
	)
	merchant_area.body_exited.connect(func(body):
		if body is Murum or body.name == "Murum":
			_player_in_shop_area = false
	)

	# Show hint
	var hint = Label.new()
	hint.name = "ShopHint"
	hint.text = "E - Einkaufen"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(600, 500)
	hint.size = Vector2(200, 30)
	add_child(hint)


func _open_run_shop() -> void:
	"""Opens the shop for the current world"""
	var shop_file: String = ""
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			shop_file = "res://data/shops/run_shop_w1.json"
		RunMapData.WorldId.KOLLEKTIV:
			shop_file = "res://data/shops/run_shop_w2.json"
		RunMapData.WorldId.ABGRUND:
			shop_file = "res://data/shops/run_shop_w3.json"

	if shop_file == "" or not FileAccess.file_exists(shop_file):
		EventBus.show_notification.emit("Kein Angebot verfuegbar.", 2.0)
		return

	var file = FileAccess.open(shop_file, FileAccess.READ)
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("[RunNodeRoom] Failed to parse shop data: %s" % shop_file)
		return

	var shop_data: Dictionary = json.data
	var merchant_name: String = shop_data.get("merchant_name", "Haendler")
	ShopManager.open_shop(shop_data, merchant_name, "Was darf es sein?")


# ============ BOSS SETUP ============
func _setup_boss() -> void:
	var boss_name: String = _get_boss_name()
	print("[RunNodeRoom] Boss room — %s (placeholder, auto-skip)" % boss_name)

	_show_completion_ui("BOSS: %s (uebersprungen)" % boss_name)
	get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)


func _get_boss_name() -> String:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return "Die Schwuere der Vier"
		RunMapData.WorldId.KOLLEKTIV:
			return "Das Kollektiv der Einen Stimme"
		RunMapData.WorldId.ABGRUND:
			return "Murum (Spiegel)"
	return "Unbekannter Boss"


# ============ NODE COMPLETION + HADES-STYLE DOORS ============
func _on_node_cleared() -> void:
	"""Node is cleared — unlock doors for next choices"""
	if not RunManager or not RunManager.current_map:
		return

	if RunManager.current_node:
		RunManager.current_map.complete_current_node()
		RunManager.run_rooms_completed += 1
		RunManager.map_updated.emit()

		if RunManager.current_node.type == RunMapData.NodeType.BOSS:
			# Last boss (Abgrund) ends the run
			if _get_next_world() < 0:
				RunManager.end_run(true)
				return
			# Other bosses: doors to next world (handled below)

	_unlock_doors()


func _spawn_exit_doors() -> void:
	"""Spawn doors immediately — always open for now"""
	if doors_spawned:
		return

	if not RunManager or not RunManager.current_map:
		return

	# Get door position markers from the scene
	var door_positions: Array[Marker2D] = []
	var door_pos_container = get_node_or_null("DoorPositions")
	if door_pos_container:
		for child in door_pos_container.get_children():
			if child is Marker2D:
				door_positions.append(child)

	# Boss rooms (non-final): single door to next world
	if node_type == RunMapData.NodeType.BOSS and _get_next_world() >= 0:
		doors_spawned = true
		var pos: Vector2 = door_positions[1].global_position if door_positions.size() > 1 else Vector2(700, 700)
		_create_world_transition_door(pos)
		print("[RunNodeRoom] Spawned world transition door")
		return

	var next_nodes = RunManager.current_map.get_accessible_nodes()
	if next_nodes.is_empty():
		return

	doors_spawned = true

	var door_count = next_nodes.size()
	for i in range(door_count):
		var node: RunMapData.MapNode = next_nodes[i]
		var pos: Vector2
		if i < door_positions.size():
			pos = door_positions[i].global_position
		else:
			pos = Vector2(400 + i * 300, 700)
		_create_door(node, pos, i)

	print("[RunNodeRoom] Spawned %d exit doors" % door_count)


func _create_world_transition_door(pos: Vector2) -> void:
	"""Create a door that transitions to the next world"""
	var next_world := _get_next_world() as RunMapData.WorldId
	var world_names := {
		RunMapData.WorldId.KOLLEKTIV: "Das Kollektiv",
		RunMapData.WorldId.ABGRUND: "Der Abgrund",
	}
	var door_label: String = world_names.get(next_world, "Naechste Welt")

	var door_container = Node2D.new()
	door_container.name = "WorldDoor"
	door_container.global_position = pos
	add_child(door_container)

	var door_width: float = 100.0
	var door_height: float = 140.0
	var door_color := Color(1.0, 0.85, 0.2)

	# Border
	var border = ColorRect.new()
	border.color = door_color * 0.6
	border.size = Vector2(door_width + 6, door_height + 6)
	border.position = Vector2(-door_width / 2.0 - 3, -door_height - 3)
	border.z_index = -1
	door_container.add_child(border)

	# Door visual
	var door_rect = ColorRect.new()
	door_rect.color = door_color
	door_rect.size = Vector2(door_width, door_height)
	door_rect.position = Vector2(-door_width / 2.0, -door_height)
	door_container.add_child(door_rect)

	# Label
	var type_label = Label.new()
	type_label.text = door_label
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.size = Vector2(door_width + 40, 30)
	type_label.position = Vector2(-door_width / 2.0 - 20, -door_height / 2.0 - 15)
	door_container.add_child(type_label)

	# Interaction area
	var area = Area2D.new()
	area.name = "DoorArea"
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(door_width + 20, door_height + 20)
	col.shape = shape
	col.position = Vector2(0, -door_height / 2.0)
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(2, true)
	area.monitoring = true
	door_container.add_child(area)

	# Prompt
	var prompt = Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "E - %s" % door_label
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(160, 20)
	prompt.position = Vector2(-80, 10)
	prompt.visible = false
	door_container.add_child(prompt)

	# Signals
	area.body_entered.connect(func(body):
		if body is Murum or body.name == "Murum":
			prompt.visible = true
			door_container.set_meta("player_inside", true)
	)
	area.body_exited.connect(func(body):
		if body is Murum or body.name == "Murum":
			prompt.visible = false
			door_container.set_meta("player_inside", false)
	)

	door_container.set_meta("world_transition", next_world)
	door_container.add_to_group("run_doors")


func _unlock_doors() -> void:
	"""Called when node is cleared — doors are already open, just show hint"""
	if not doors_spawned:
		return
	_show_completion_ui("Waehle den naechsten Raum!")


func _create_door(node: RunMapData.MapNode, pos: Vector2, index: int) -> void:
	"""Create a single Hades-style door — always open"""
	var door_container = Node2D.new()
	door_container.name = "Door_%d" % index
	door_container.global_position = pos
	add_child(door_container)

	var door_width: float = 80.0
	var door_height: float = 120.0
	var door_color: Color = DOOR_COLORS.get(node.type, Color.WHITE)

	# Door border
	var border = ColorRect.new()
	border.color = door_color * 0.6
	border.size = Vector2(door_width + 6, door_height + 6)
	border.position = Vector2(-door_width / 2.0 - 3, -door_height - 3)
	border.z_index = -1
	door_container.add_child(border)

	# Door visual
	var door_rect = ColorRect.new()
	door_rect.color = door_color
	door_rect.size = Vector2(door_width, door_height)
	door_rect.position = Vector2(-door_width / 2.0, -door_height)
	door_container.add_child(door_rect)

	# Node type label
	var type_label = Label.new()
	type_label.text = node.get_type_name()
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.size = Vector2(door_width, 30)
	type_label.position = Vector2(-door_width / 2.0, -door_height / 2.0 - 15)
	door_container.add_child(type_label)

	# Reward label above door
	var reward_label = Label.new()
	reward_label.text = node.reward_type.capitalize()
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.size = Vector2(door_width, 20)
	reward_label.position = Vector2(-door_width / 2.0, -door_height - 25)
	door_container.add_child(reward_label)

	# Interaction area
	var area = Area2D.new()
	area.name = "DoorArea"
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(door_width + 20, door_height + 20)
	col.shape = shape
	col.position = Vector2(0, -door_height / 2.0)
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(2, true)  # Player on Layer 2
	area.monitoring = true
	door_container.add_child(area)

	# Prompt label
	var prompt = Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "E - %s" % node.get_type_name()
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(140, 20)
	prompt.position = Vector2(-70, 10)
	prompt.visible = false
	door_container.add_child(prompt)

	# Connect signals
	var node_id = node.id
	area.body_entered.connect(func(body):
		if body is Murum or body.name == "Murum":
			prompt.visible = true
			door_container.set_meta("player_inside", true)
	)
	area.body_exited.connect(func(body):
		if body is Murum or body.name == "Murum":
			prompt.visible = false
			door_container.set_meta("player_inside", false)
	)

	door_container.set_meta("node_id", node_id)
	door_container.add_to_group("run_doors")


func _process(_delta: float) -> void:
	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if not interact_pressed:
		return

	# Event choice confirmation
	if node_type == RunMapData.NodeType.EVENT and not event_choice_made:
		_confirm_event_choice()
		return

	# Shop interaction
	if node_type == RunMapData.NodeType.SHOP and _player_in_shop_area:
		_open_run_shop()
		return

	# Door interaction
	if not doors_spawned:
		return

	for door in get_tree().get_nodes_in_group("run_doors"):
		if door.has_meta("player_inside") and door.get_meta("player_inside"):
			# World transition door (after boss)
			if door.has_meta("world_transition"):
				var next_world: int = door.get_meta("world_transition")
				RunManager.transition_to_next_world(next_world as RunMapData.WorldId)
				return
			# Normal door
			var node_id: int = door.get_meta("node_id")
			_enter_door(node_id)
			return


func _enter_door(node_id: int) -> void:
	"""Player entered a door — load the next node"""
	print("[RunNodeRoom] Entering door -> node %d" % node_id)
	RunManager.current_state = RunManager.RunState.MAP_VIEW
	RunManager.select_map_node(node_id)


func _get_rest_name() -> String:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return "Zuflucht der Verlorenen"
		RunMapData.WorldId.KOLLEKTIV:
			return "Regenerationsstation"
		RunMapData.WorldId.ABGRUND:
			return "Der Letzte Lichtfunke"
	return "Raststelle"


func _get_next_world() -> int:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return RunMapData.WorldId.KOLLEKTIV
		RunMapData.WorldId.KOLLEKTIV:
			return RunMapData.WorldId.ABGRUND
	return -1


# ============ UI HELPERS ============
func _show_completion_ui(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(400, 100)
	label.size = Vector2(400, 50)
	add_child(label)
