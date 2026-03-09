extends Node2D
## Generic room for Run-Map nodes
## Dynamically configures itself based on node type (combat, treasure, rest, event, boss)
## Spawns ArenaController for combat nodes, shows item selection for treasure, etc.
class_name RunNodeRoom

# ============ ROOM CONFIG ============
const ROOM_WIDTH: float = 1920.0
const ROOM_HEIGHT: float = 1080.0
const GROUND_Y: float = 800.0
const SPAWN_MARGIN: float = 200.0

var node_type: RunMapData.NodeType = RunMapData.NodeType.COMBAT_PUZZLE
var world_id: RunMapData.WorldId = RunMapData.WorldId.NIEMANDSLAND
var node_data: RunMapData.MapNode = null

# ============ ROOM NODES ============
var spawn_point: Marker2D
var arena_controller: ArenaController = null
var completion_label: Label = null
var room_built: bool = false


func _ready() -> void:
	print("[RunNodeRoom] Initialized (type: %s)" % RunMapData.NodeType.keys()[node_type])
	call_deferred("_activate")


func _activate() -> void:
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	_build_room()
	_setup_player()

	match node_type:
		RunMapData.NodeType.COMBAT_PUZZLE, RunMapData.NodeType.ELITE_PUZZLE:
			_setup_combat()
		RunMapData.NodeType.TREASURE:
			_setup_treasure()
		RunMapData.NodeType.REST:
			_setup_rest()
		RunMapData.NodeType.EVENT:
			_setup_event()
		RunMapData.NodeType.BOSS:
			_setup_boss()


# ============ ROOM BUILDING ============
func _build_room() -> void:
	"""Build minimal room geometry"""
	if room_built:
		return
	room_built = true

	# Ground collision (StaticBody2D)
	var ground = StaticBody2D.new()
	ground.name = "Ground"
	var ground_col = CollisionShape2D.new()
	var ground_shape = RectangleShape2D.new()
	ground_shape.size = Vector2(ROOM_WIDTH, 40)
	ground_col.shape = ground_shape
	ground.add_child(ground_col)
	ground.position = Vector2(ROOM_WIDTH / 2.0, GROUND_Y + 20)
	add_child(ground)

	# Walls (left + right)
	_add_wall(Vector2(-20, ROOM_HEIGHT / 2.0), Vector2(40, ROOM_HEIGHT))
	_add_wall(Vector2(ROOM_WIDTH + 20, ROOM_HEIGHT / 2.0), Vector2(40, ROOM_HEIGHT))

	# Ceiling
	_add_wall(Vector2(ROOM_WIDTH / 2.0, -20), Vector2(ROOM_WIDTH, 40))

	# Spawn point
	spawn_point = Marker2D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = Vector2(ROOM_WIDTH / 2.0, GROUND_Y - 40)
	add_child(spawn_point)

	# Visual ground (ColorRect)
	var ground_visual = ColorRect.new()
	ground_visual.color = _get_ground_color()
	ground_visual.position = Vector2(0, GROUND_Y)
	ground_visual.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT - GROUND_Y)
	add_child(ground_visual)

	# Background
	var bg = ColorRect.new()
	bg.color = _get_bg_color()
	bg.position = Vector2.ZERO
	bg.size = Vector2(ROOM_WIDTH, GROUND_Y)
	bg.z_index = -10
	add_child(bg)

	# Room type label (top)
	var type_label = Label.new()
	type_label.text = _get_room_title()
	type_label.add_theme_font_size_override("font_size", 24)
	type_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.8))
	type_label.position = Vector2(40, 20)
	add_child(type_label)


func _add_wall(pos: Vector2, wall_size: Vector2) -> void:
	var wall = StaticBody2D.new()
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = wall_size
	col.shape = shape
	wall.add_child(col)
	wall.position = pos
	add_child(wall)


# ============ PLAYER SETUP ============
func _setup_player() -> void:
	if not GameManager.player or not is_instance_valid(GameManager.player):
		_spawn_new_player()
		return

	var player = GameManager.player
	if player.get_parent() != self:
		if player.get_parent():
			player.get_parent().remove_child(player)
		add_child(player)

	player.global_position = spawn_point.global_position
	player.z_index = 100
	player.z_as_relative = false
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	print("[RunNodeRoom] Player repositioned")


func _spawn_new_player() -> void:
	var player_scene = preload("res://player/murum.tscn")
	var player = player_scene.instantiate()
	player.global_position = spawn_point.global_position
	add_child(player)
	if GameManager:
		GameManager.set_player(player)
	print("[RunNodeRoom] Player spawned")


# ============ COMBAT SETUP ============
func _setup_combat() -> void:
	"""Configure ArenaController with waves from RunRoomPool"""
	var wave_configs = RunRoomPool.build_wave_configs(world_id, node_type)
	if wave_configs.is_empty():
		push_warning("[RunNodeRoom] No wave configs generated!")
		_complete_node()
		return

	# Create spawn points for enemies
	var enemy_spawn_points: Array[Marker2D] = []
	var spawn_positions = [
		Vector2(SPAWN_MARGIN, GROUND_Y - 40),
		Vector2(ROOM_WIDTH / 2.0, GROUND_Y - 40),
		Vector2(ROOM_WIDTH - SPAWN_MARGIN, GROUND_Y - 40),
		Vector2(ROOM_WIDTH * 0.3, GROUND_Y - 40),
		Vector2(ROOM_WIDTH * 0.7, GROUND_Y - 40),
	]

	var spawn_container = Node2D.new()
	spawn_container.name = "EnemySpawnPoints"
	add_child(spawn_container)

	for i in range(spawn_positions.size()):
		var marker = Marker2D.new()
		marker.name = "Spawn_%d" % i
		marker.position = spawn_positions[i]
		spawn_container.add_child(marker)
		enemy_spawn_points.append(marker)

	# Create ArenaController
	arena_controller = ArenaController.new()
	arena_controller.name = "ArenaController"
	arena_controller.arena_id = "run_node_%d" % (node_data.id if node_data else 0)
	arena_controller.wave_configs = wave_configs
	arena_controller.start_mode = ArenaController.StartMode.MANUAL
	arena_controller.lock_doors_during_waves = false
	arena_controller.spawn_coins_on_clear = true
	arena_controller.coins_per_wave = 10

	# Set spawn point paths (will be resolved after adding to tree)
	add_child(arena_controller)

	# Set spawn points via NodePaths
	for marker in enemy_spawn_points:
		arena_controller.spawn_points.append(arena_controller.get_path_to(marker))

	# Connect completion
	arena_controller.arena_completed.connect(_on_arena_completed)

	# Start arena after a short delay
	get_tree().create_timer(1.5).timeout.connect(func():
		if arena_controller and not arena_controller.is_cleared:
			arena_controller.start_arena()
			print("[RunNodeRoom] Combat started!")
	)

	print("[RunNodeRoom] Combat configured with %d waves" % wave_configs.size())


func _on_arena_completed() -> void:
	print("[RunNodeRoom] Arena completed!")
	_show_completion_ui("Raum abgeschlossen!")
	# Auto-complete after delay
	get_tree().create_timer(2.0).timeout.connect(_complete_node)


# ============ TREASURE SETUP ============
func _setup_treasure() -> void:
	"""Show 3 item choices"""
	print("[RunNodeRoom] Treasure room — showing item selection")

	var container = VBoxContainer.new()
	container.position = Vector2(ROOM_WIDTH / 2.0 - 300, 200)
	container.custom_minimum_size = Vector2(600, 400)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	var title = Label.new()
	title.text = "Schatz! Waehle ein Item:"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 40)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(button_container)

	# 3 placeholder item buttons
	var item_names = ["Heilkraut", "Schattenstein", "Mana-Elixier"]
	var item_descriptions = [
		"Heilt 30 HP",
		"+5% Schaden fuer diesen Run",
		"Stellt 20 Mana wieder her"
	]

	for i in range(RunRoomPool.TREASURE_ITEM_COUNT):
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(160, 120)
		item_btn.text = "%s\n\n%s" % [item_names[i], item_descriptions[i]]
		item_btn.add_theme_font_size_override("font_size", 14)
		item_btn.pressed.connect(_on_treasure_selected.bind(i, item_names[i]))
		button_container.add_child(item_btn)


func _on_treasure_selected(index: int, item_name: String) -> void:
	print("[RunNodeRoom] Treasure selected: %s (index %d)" % [item_name, index])
	EventBus.show_notification.emit("Du erhaeltst: %s" % item_name, 3.0)
	_show_completion_ui("Item eingesammelt!")
	get_tree().create_timer(1.5).timeout.connect(_complete_node)


# ============ REST SETUP ============
func _setup_rest() -> void:
	"""Full heal + NPC placeholder"""
	print("[RunNodeRoom] Rest room — healing player")

	# Heal player fully
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player
		if player.has_node("HealthComponent"):
			player.get_node("HealthComponent").reset_health()
		if player.has_node("ManaComponent"):
			player.get_node("ManaComponent").reset_mana()

	var container = VBoxContainer.new()
	container.position = Vector2(ROOM_WIDTH / 2.0 - 250, 200)
	container.custom_minimum_size = Vector2(500, 300)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	var title = Label.new()
	title.text = "Zuflucht der Verlorenen"
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

	var continue_btn = Button.new()
	continue_btn.text = "Weiter"
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.pressed.connect(_complete_node)
	container.add_child(continue_btn)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	EventBus.show_notification.emit("Volle Heilung!", 3.0)


# ============ EVENT SETUP ============
func _setup_event() -> void:
	"""Text event with choices (placeholder)"""
	print("[RunNodeRoom] Event room")

	var container = VBoxContainer.new()
	container.position = Vector2(ROOM_WIDTH / 2.0 - 300, 200)
	container.custom_minimum_size = Vector2(600, 400)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	var title = Label.new()
	title.text = "Ereignis"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	var text = Label.new()
	text.text = "Ein geheimnisvoller Wanderer bietet dir etwas an..."
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(text)

	var choice_a = Button.new()
	choice_a.text = "Annehmen (+20 HP, -10 Mana)"
	choice_a.custom_minimum_size = Vector2(400, 40)
	choice_a.add_theme_font_size_override("font_size", 16)
	choice_a.pressed.connect(func():
		EventBus.show_notification.emit("Du akzeptierst das Angebot.", 3.0)
		_complete_node()
	)
	container.add_child(choice_a)

	var choice_b = Button.new()
	choice_b.text = "Ablehnen (weiter ohne Aenderung)"
	choice_b.custom_minimum_size = Vector2(400, 40)
	choice_b.add_theme_font_size_override("font_size", 16)
	choice_b.pressed.connect(func():
		EventBus.show_notification.emit("Du gehst weiter.", 3.0)
		_complete_node()
	)
	container.add_child(choice_b)


# ============ BOSS SETUP ============
func _setup_boss() -> void:
	"""Boss placeholder (Commit 5)"""
	print("[RunNodeRoom] Boss room — placeholder")

	var label = Label.new()
	label.text = "BOSS: Die Schwuere der Vier\n(Noch nicht implementiert)"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(ROOM_WIDTH / 2.0 - 300, 300)
	add_child(label)

	var skip_btn = Button.new()
	skip_btn.text = "Boss ueberspringen (Placeholder)"
	skip_btn.custom_minimum_size = Vector2(300, 50)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.position = Vector2(ROOM_WIDTH / 2.0 - 150, 500)
	skip_btn.pressed.connect(_complete_node)
	add_child(skip_btn)


# ============ COMPLETION ============
func _complete_node() -> void:
	"""Notify RunManager that this node is done"""
	if not RunManager:
		return

	print("[RunNodeRoom] Node completed, returning to map")
	RunManager.complete_current_node()


func _show_completion_ui(message: String) -> void:
	if completion_label and is_instance_valid(completion_label):
		completion_label.queue_free()

	completion_label = Label.new()
	completion_label.text = message
	completion_label.add_theme_font_size_override("font_size", 32)
	completion_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_label.position = Vector2(ROOM_WIDTH / 2.0 - 200, 100)
	completion_label.size = Vector2(400, 50)
	add_child(completion_label)


# ============ VISUAL HELPERS ============
func _get_ground_color() -> Color:
	match node_type:
		RunMapData.NodeType.COMBAT_PUZZLE: return Color(0.15, 0.1, 0.1)
		RunMapData.NodeType.ELITE_PUZZLE: return Color(0.2, 0.12, 0.05)
		RunMapData.NodeType.TREASURE: return Color(0.08, 0.15, 0.1)
		RunMapData.NodeType.REST: return Color(0.08, 0.12, 0.18)
		RunMapData.NodeType.EVENT: return Color(0.12, 0.08, 0.15)
		RunMapData.NodeType.BOSS: return Color(0.2, 0.05, 0.05)
	return Color(0.1, 0.1, 0.1)


func _get_bg_color() -> Color:
	match node_type:
		RunMapData.NodeType.COMBAT_PUZZLE: return Color(0.08, 0.05, 0.05)
		RunMapData.NodeType.ELITE_PUZZLE: return Color(0.1, 0.06, 0.02)
		RunMapData.NodeType.TREASURE: return Color(0.04, 0.08, 0.05)
		RunMapData.NodeType.REST: return Color(0.04, 0.06, 0.1)
		RunMapData.NodeType.EVENT: return Color(0.06, 0.04, 0.08)
		RunMapData.NodeType.BOSS: return Color(0.1, 0.02, 0.02)
	return Color(0.05, 0.05, 0.05)


func _get_room_title() -> String:
	match node_type:
		RunMapData.NodeType.COMBAT_PUZZLE: return "Kampf + Raetsel"
		RunMapData.NodeType.ELITE_PUZZLE: return "Elite-Kampf"
		RunMapData.NodeType.TREASURE: return "Schatzkammer"
		RunMapData.NodeType.REST: return "Rastplatz"
		RunMapData.NodeType.EVENT: return "Ereignis"
		RunMapData.NodeType.BOSS: return "Boss"
	return "Raum"
