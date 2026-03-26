extends Node2D
## Controller script for Run-Map room nodes
## Attached to handcrafted .tscn room scenes at runtime
## Handles: player setup, combat spawning, node-type logic, Hades-style exit doors
class_name RunNodeRoom

# ============ DOOR COLORS ============
# ============ BACKGROUND POOLS (per world, keyed by usage) ============
const BG_BASE := "res://Assets/AIPlaceholder/AlbtraumWelten/"

const BG_POOL_W1: Dictionary = {
	"combat": [
		BG_BASE + "Welt1_Niemandsland/Dark_fantasy_battlefield_backg_GPT_Image_15_55624.jpg",
		BG_BASE + "Welt1_Niemandsland/Dark_fantasy_battlefield_backg_GPT_Image_15_65828.jpg",
		BG_BASE + "Welt1_Niemandsland/Dark_fantasy_battlefield_backg_GPT_Image_15_73838.jpg",
		BG_BASE + "Welt1_Niemandsland/Dark_fantasy_battlefield_backg_GPT_Image_15_91400.jpg",
		BG_BASE + "Welt1_Niemandsland/Dark_fantasy_battlefield_backg_GPT_Image_15_98539.jpg",
	],
}

const BG_POOL_W2: Dictionary = {
	"combat": [
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_slum_en_GPT_Image_15_18921.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_slum_en_GPT_Image_15_35710.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_slum_en_GPT_Image_15_56628.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_slum_en_GPT_Image_15_69591.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_battlefiel_GPT_Image_15_36535.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_battlefiel_GPT_Image_15_42145.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_battlefiel_GPT_Image_15_64619.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_battlefiel_GPT_Image_15_87409.jpg",
	],
	"calm": [
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_quiet_orbital_mai_GPT_Image_15_08434.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_quiet_orbital_mai_GPT_Image_15_16362.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_quiet_orbital_mai_GPT_Image_15_35464.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_background_GPT_Image_15_13943.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_background_GPT_Image_15_34442.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_background_GPT_Image_15_64929.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_background_GPT_Image_15_90257.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_background_GPT_Image_15_90607.jpg",
	],
	"shop": [
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_market__GPT_Image_15_52087.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_market__GPT_Image_15_59630.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_market__GPT_Image_15_64088.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cyberpunk_market__GPT_Image_15_73948.jpg",
	],
	"event": [
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cosmic_transition_GPT_Image_15_13643.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cosmic_transition_GPT_Image_15_56631.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cosmic_transition_GPT_Image_15_76179.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_cosmic_transition_GPT_Image_15_95897.jpg",
	],
	"boss": [
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_massive_sci-fi_bo_GPT_Image_15_83056.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_orbital_do_GPT_Image_15_34768.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_orbital_do_GPT_Image_15_41097.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_orbital_do_GPT_Image_15_57277.jpg",
		BG_BASE + "Welt2_Kollektiv/2D_pixel_art_sci-fi_orbital_do_GPT_Image_15_61592.jpg",
	],
}

const BG_POOL_W3: Dictionary = {
	"combat": [
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_29025.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_45960.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_72404.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_79074.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_env_GPT_Image_15_03661.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_env_GPT_Image_15_09903.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_env_GPT_Image_15_35905.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_env_GPT_Image_15_84370.jpg",
	],
	"calm": [
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_minimal_cosmic_ho_GPT_Image_15_44077.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_minimal_cosmic_ho_GPT_Image_15_87340.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_minimal_cosmic_ho_GPT_Image_15_88414.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_minimal_cosmic_ho_GPT_Image_15_89422.jpg",
	],
	"event": [
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_surreal_void_cham_GPT_Image_15_25602.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_surreal_void_cham_GPT_Image_15_89156.jpg",
	],
	"elite": [
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_massive_spiral_ab_GPT_Image_15_07174.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_massive_spiral_ab_GPT_Image_15_20807.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_massive_spiral_ab_GPT_Image_15_37001.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_massive_spiral_ab_GPT_Image_15_70264.jpg",
	],
	"boss": [
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bos_GPT_Image_15_12927.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bos_GPT_Image_15_15505.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bos_GPT_Image_15_44765.jpg",
		BG_BASE + "Welt3_Abgrund/2D_pixel_art_cosmic_horror_bos_GPT_Image_15_93186.jpg",
	],
}

const DOOR_TEXTURE: Texture2D = preload("res://Assets/AIAssets/AIStuff/Interact_Dialog.png")

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

# ============ DEATH ZONE ============
const DEATH_ZONE_MARGIN: float = 500.0  # How far outside the room walls before killing


func _is_any_player(body: Node) -> bool:
	"""Returns true if body is P1 (Murum) or P2 (Lythrun)"""
	return body is Murum or body is Lythrun


func _ready() -> void:
	print("[RunNodeRoom] Initialized (type: %s)" % RunMapData.NodeType.keys()[node_type])
	call_deferred("_activate")


func _activate() -> void:
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	_setup_background()
	_setup_death_zone()
	_setup_player()
	_spawn_exit_doors()

	# Reset per-room boon state (kill counters, death save, etc.)
	if BoonManager:
		BoonManager.reset_room_state()

	# Musik passend zum Raumtyp + Welt starten
	if MusicScenePlayer:
		MusicScenePlayer.play_for_run_room(world_id, node_type)

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


# ============ DEATH ZONE ============
func _setup_death_zone() -> void:
	"""Creates an Area2D kill zone around the room that kills enemies who fall/glitch out of bounds."""
	# Detect room bounds from existing walls
	var room_rect := _detect_room_bounds()
	if room_rect.size == Vector2.ZERO:
		push_warning("[RunNodeRoom] Could not detect room bounds for death zone")
		return

	# Expand bounds by margin — anything beyond this is out of bounds
	var outer := Rect2(
		room_rect.position - Vector2(DEATH_ZONE_MARGIN, DEATH_ZONE_MARGIN),
		room_rect.size + Vector2(DEATH_ZONE_MARGIN * 2, DEATH_ZONE_MARGIN * 2)
	)

	# Create 4 large Area2D strips around the room (top, bottom, left, right)
	var strip_thickness: float = 2000.0
	var strips: Array[Rect2] = [
		# Bottom
		Rect2(outer.position.x, outer.end.y, outer.size.x, strip_thickness),
		# Top
		Rect2(outer.position.x, outer.position.y - strip_thickness, outer.size.x, strip_thickness),
		# Left
		Rect2(outer.position.x - strip_thickness, outer.position.y - strip_thickness, strip_thickness, outer.size.y + strip_thickness * 2),
		# Right
		Rect2(outer.end.x, outer.position.y - strip_thickness, strip_thickness, outer.size.y + strip_thickness * 2),
	]

	for i in range(strips.size()):
		var strip_rect := strips[i]
		var area := Area2D.new()
		area.name = "DeathZone_%d" % i
		area.collision_layer = 0
		area.collision_mask = 8  # Layer 4 = enemies (adjust if needed)
		area.monitoring = true
		area.monitorable = false

		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = strip_rect.size
		shape.shape = rect_shape
		shape.position = strip_rect.position + strip_rect.size / 2.0

		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(_on_death_zone_body_entered)

	print("[RunNodeRoom] Death zone created (room bounds: %v, margin: %.0f)" % [room_rect.size, DEATH_ZONE_MARGIN])


func _detect_room_bounds() -> Rect2:
	"""Detects room bounds from Background ColorRect or wall positions."""
	# Method 1: Use Background ColorRect dimensions
	var bg: ColorRect = get_node_or_null("Background") as ColorRect
	if bg:
		return Rect2(bg.offset_left, bg.offset_top, bg.offset_right - bg.offset_left, bg.offset_bottom - bg.offset_top)

	# Method 2: Use wall StaticBody2D positions
	var wall_left: StaticBody2D = get_node_or_null("WallLeft") as StaticBody2D
	var wall_right: StaticBody2D = get_node_or_null("WallRight") as StaticBody2D
	var ground: StaticBody2D = get_node_or_null("Ground") as StaticBody2D
	var ceiling: StaticBody2D = get_node_or_null("Ceiling") as StaticBody2D

	if wall_left and wall_right and ground:
		var left_x: float = wall_left.position.x
		var right_x: float = wall_right.position.x
		var top_y: float = ceiling.position.y if ceiling else -100.0
		var bottom_y: float = ground.position.y
		return Rect2(left_x, top_y, right_x - left_x, bottom_y - top_y)

	# Fallback: default 1920x1080 room
	return Rect2(0, 0, 1920, 1080)


func _on_death_zone_body_entered(body: Node) -> void:
	"""Kills enemies that enter the death zone (out of bounds)."""
	if not body.is_in_group("enemies"):
		return

	print("[RunNodeRoom] Enemy '%s' fell out of bounds — killing" % body.name)

	# Try to trigger proper death via die() or take_damage
	if body.has_method("die"):
		if body.get("is_dead") == true:
			# Already dead but still moving — force remove
			body.queue_free()
		else:
			body.die()
	elif body.has_method("take_damage"):
		body.take_damage(99999)
	else:
		# Last resort: emit death signal manually and free
		EventBus.enemy_died.emit(body, body.global_position)
		body.queue_free()


# ============ BACKGROUND SETUP ============
func _setup_background() -> void:
	var bg_key: String = _get_bg_key()
	var pool: Array = _get_bg_pool(bg_key)
	if pool.is_empty():
		return

	var tex_path: String = pool[randi() % pool.size()]
	var tex: Texture2D = load(tex_path) as Texture2D
	if not tex:
		push_warning("[RunNodeRoom] Failed to load background: %s" % tex_path)
		return

	# Find and replace the existing Background ColorRect
	var old_bg: ColorRect = get_node_or_null("Background") as ColorRect
	if old_bg:
		old_bg.queue_free()

	var tex_rect := TextureRect.new()
	tex_rect.name = "BackgroundSprite"
	tex_rect.texture = tex
	tex_rect.z_index = -10
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.size = Vector2(1920, 800)
	tex_rect.position = Vector2.ZERO
	add_child(tex_rect)
	move_child(tex_rect, 0)

	print("[RunNodeRoom] Background: %s" % tex_path.get_file())


func _get_bg_key() -> String:
	match node_type:
		RunMapData.NodeType.COMBAT:
			return "combat"
		RunMapData.NodeType.ELITE:
			return "elite"
		RunMapData.NodeType.TREASURE, RunMapData.NodeType.REST:
			return "calm"
		RunMapData.NodeType.EVENT:
			return "event"
		RunMapData.NodeType.BOSS:
			return "boss"
		RunMapData.NodeType.SHOP:
			return "shop"
	return "combat"


func _get_bg_pool(key: String) -> Array:
	var world_pool: Dictionary = {}
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			world_pool = BG_POOL_W1
		RunMapData.WorldId.KOLLEKTIV:
			world_pool = BG_POOL_W2
		RunMapData.WorldId.ABGRUND:
			world_pool = BG_POOL_W3

	if world_pool.has(key):
		return world_pool[key]
	# Fallback to combat pool
	if world_pool.has("combat"):
		return world_pool["combat"]
	return []


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

	# Also reposition P2 if active
	_setup_p2(spawn_marker)


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


func _setup_p2(spawn_marker: Marker2D) -> void:
	"""Reposition P2 alongside P1 if active"""
	if not CoopManager or not CoopManager.is_p2_active:
		return

	var p2 = CoopManager.get_p2_instance()
	if not p2 or not is_instance_valid(p2):
		return

	if p2.get_parent() != self:
		if p2.get_parent():
			p2.get_parent().remove_child(p2)
		add_child(p2)

	p2.global_position = spawn_marker.global_position + Vector2(50, 0)
	p2.z_index = 100
	p2.z_as_relative = false
	if p2 is CharacterBody2D:
		p2.velocity = Vector2.ZERO

	print("[RunNodeRoom] P2 repositioned at %s" % p2.global_position)


func _heal_all_players() -> void:
	"""Full heal P1 and P2"""
	for p in get_tree().get_nodes_in_group("player"):
		if not p or not is_instance_valid(p):
			continue
		if p.has_node("HealthComponent"):
			p.get_node("HealthComponent").reset_health()
		if p.has_node("ManaComponent"):
			p.get_node("ManaComponent").reset_mana()


# ============ COMBAT SETUP ============
func _setup_combat() -> void:
	"""Spawn enemies using ArenaController. Prefers Inspector-configured waves (CombatWaveHolder),
	falls back to auto-generated single wave from RunRoomPool."""

	# Check for Inspector-configured waves (CombatWaveHolder node in scene)
	var wave_holder: CombatWaveHolder = null
	for child in get_children():
		if child is CombatWaveHolder:
			wave_holder = child
			break

	var wave_configs: Array[ArenaWaveConfig] = []
	if wave_holder:
		wave_configs = wave_holder.get_wave_configs()
		if not wave_configs.is_empty():
			print("[RunNodeRoom] Using Inspector-configured waves (%d waves)" % wave_configs.size())

	# Fallback: auto-generate single wave from RunRoomPool
	if wave_configs.is_empty():
		var fallback_config = RunRoomPool.build_single_wave_config(world_id, node_type)
		if fallback_config and not fallback_config.enemies.is_empty():
			wave_configs.append(fallback_config)
			print("[RunNodeRoom] Using auto-generated fallback wave")
		else:
			push_warning("[RunNodeRoom] No encounter generated (world: %d, type: %d)!" % [world_id, node_type])
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
	arena_controller.wave_configs = wave_configs
	arena_controller.start_mode = ArenaController.StartMode.MANUAL
	arena_controller.lock_doors_during_waves = false
	arena_controller.spawn_coins_on_clear = false
	arena_controller.coins_per_wave = 0
	add_child(arena_controller)

	for marker in enemy_spawn_markers:
		arena_controller.spawn_points.append(arena_controller.get_path_to(marker))

	arena_controller.arena_completed.connect(_on_combat_completed)

	# Puzzle gate: pause waves after wave 1, resume when puzzle is solved
	var puzzle_gate = _find_puzzle_gate()
	if puzzle_gate and puzzle_gate is PuzzleController:
		arena_controller.pause_between_waves = true
		puzzle_gate.puzzle_solved.connect(func():
			if arena_controller:
				arena_controller.resume_waves()
				print("[RunNodeRoom] Puzzle gate solved — resuming waves")
		)
		print("[RunNodeRoom] Puzzle gate detected: %s" % puzzle_gate.name)

	# Start combat after short delay
	get_tree().create_timer(1.5).timeout.connect(func():
		if arena_controller and not arena_controller.is_cleared:
			arena_controller.start_arena()
			print("[RunNodeRoom] Combat started!")
	)

	var total_enemies: int = 0
	for config in wave_configs:
		for entry in config.enemies:
			total_enemies += entry.count
	print("[RunNodeRoom] Combat: %d waves, %d total enemies" % [wave_configs.size(), total_enemies])


func _find_puzzle_gate() -> Node:
	"""Finds a PuzzleController in the 'puzzle_gate' group within this room."""
	for child in get_children():
		if child.is_in_group("puzzle_gate"):
			return child
		for grandchild in child.get_children():
			if grandchild.is_in_group("puzzle_gate"):
				return grandchild
	return null


func _on_combat_completed() -> void:
	print("[RunNodeRoom] Combat completed!")
	var w: int = RewardManager.get_world_id_int(world_id)

	# Grant gold
	var gold: int = RewardManager.get_combat_gold(w)
	GameManager.add_coins(gold)

	if node_type == RunMapData.NodeType.ELITE:
		# Elite: gold + boon selection + guaranteed stat pickup
		_show_completion_ui("Elite besiegt! +%d Gold" % gold)
		EventBus.show_notification.emit("+%d Gold" % gold, 2.0)
		_try_spawn_stat_pickup(1.0)  # Guaranteed drop from elites
		get_tree().create_timer(1.5).timeout.connect(_setup_boon_selection)
		return

	_show_completion_ui("Alle Gegner besiegt! +%d Gold" % gold)

	# 30% chance: drop 1 consumable (combat only, not elite)
	var consumable_id: String = RewardManager.get_combat_consumable_drop(w)
	if consumable_id != "":
		InventoryManager.add_item(consumable_id)
		var item_name: String = RewardManager.get_item_name(consumable_id)
		EventBus.show_notification.emit("Item gefunden: %s" % item_name, 3.0)
		print("[RunNodeRoom] Consumable drop: %s" % consumable_id)

	# 25% chance: spawn stat pickup (HP or Mana)
	_try_spawn_stat_pickup()

	get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)


# ============ TREASURE SETUP ============
var treasure_choice_made: bool = false
var _player_in_treasure: String = ""  # "A", "B", "C" or ""
var _treasure_items: Array = []       # Array of item_id strings

func _setup_treasure() -> void:
	print("[RunNodeRoom] Treasure room")
	var w: int = RewardManager.get_world_id_int(world_id)
	_treasure_items = RewardManager.get_treasure_choices(w)

	if _treasure_items.is_empty():
		push_warning("[RunNodeRoom] No treasure items available!")
		_on_node_cleared()
		return

	# Look for TreasureChoices node in scene (Area2D zones like EventChoices)
	var choices = get_node_or_null("TreasureChoices")
	if not choices:
		# Fallback: create choice zones dynamically
		choices = Node2D.new()
		choices.name = "TreasureChoices"
		add_child(choices)
		_create_treasure_zones(choices)

	# Connect choice zones
	var zone_keys := ["A", "B", "C"]
	for i in range(mini(_treasure_items.size(), zone_keys.size())):
		var key: String = zone_keys[i]
		var zone: Area2D = choices.get_node_or_null("Choice" + key)
		if not zone:
			continue

		# Add item label to zone
		var item_name: String = RewardManager.get_item_name(_treasure_items[i])
		var item_desc: String = RewardManager.get_item_description(_treasure_items[i])
		var label = Label.new()
		label.text = "%s\n%s" % [item_name, item_desc]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(200, 60)
		label.position = Vector2(-100, -80)
		zone.add_child(label)

		# Connect body signals
		var captured_key := key
		zone.body_entered.connect(func(body):
			if _is_any_player(body):
				_player_in_treasure = captured_key
		)
		zone.body_exited.connect(func(body):
			if _is_any_player(body):
				if _player_in_treasure == captured_key:
					_player_in_treasure = ""
		)

	_show_completion_ui("Waehle einen Schatz!")


func _create_treasure_zones(parent: Node2D) -> void:
	"""Creates 3 choice zones dynamically if TreasureChoices not in scene"""
	var positions := [Vector2(400, 700), Vector2(700, 700), Vector2(1000, 700)]
	var keys := ["A", "B", "C"]

	for i in range(mini(_treasure_items.size(), 3)):
		var zone := Area2D.new()
		zone.name = "Choice" + keys[i]
		zone.global_position = positions[i]
		zone.collision_layer = 0
		zone.collision_mask = 0
		zone.set_collision_mask_value(2, true)
		zone.monitoring = true

		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(120, 120)
		col.shape = shape
		zone.add_child(col)

		# Visual
		var rect := ColorRect.new()
		rect.color = Color(0.2, 0.7, 0.3, 0.6)
		rect.size = Vector2(120, 120)
		rect.position = Vector2(-60, -60)
		zone.add_child(rect)

		# Prompt
		var prompt := Label.new()
		prompt.name = "PromptLabel"
		prompt.text = "E - Nehmen"
		prompt.add_theme_font_size_override("font_size", 14)
		prompt.add_theme_color_override("font_color", Color.WHITE)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.size = Vector2(120, 20)
		prompt.position = Vector2(-60, 65)
		zone.add_child(prompt)

		parent.add_child(zone)


func _confirm_treasure_choice() -> void:
	"""Called when player presses E inside a treasure zone"""
	if treasure_choice_made or _player_in_treasure == "":
		return
	treasure_choice_made = true

	var index: int = ["A", "B", "C"].find(_player_in_treasure)
	if index < 0 or index >= _treasure_items.size():
		return

	var item_id: String = _treasure_items[index]
	InventoryManager.add_item(item_id)
	var item_name: String = RewardManager.get_item_name(item_id)

	# Remove all choice zones
	var choices = get_node_or_null("TreasureChoices")
	if choices:
		for child in choices.get_children():
			child.queue_free()

	_show_completion_ui("Schatz: %s erhalten!" % item_name)
	EventBus.show_notification.emit("Du erhaeltst: %s" % item_name, 3.0)
	print("[RunNodeRoom] Treasure chosen: %s" % item_id)

	_on_node_cleared()


# ============ BOON SELECTION (Elite/Boss rooms — Pachron Altar) ============
var boon_choice_made: bool = false
var _player_in_altar: bool = false
var _pachron_screen: Node = null

func _setup_boon_selection() -> void:
	"""After elite/boss combat: spawn Pachron altar interactable"""
	# Check if any boons are available at all
	var any_available: bool = false
	for path_id in BoonManager.PATH_IDS:
		if BoonManager.get_next_available_tier(path_id) > 0:
			any_available = true
			break
		if not BoonManager.get_upgradeable_boons(path_id).is_empty():
			any_available = true
			break

	if not any_available:
		print("[RunNodeRoom] No boons/upgrades available — skipping selection")
		EventBus.show_notification.emit("Keine Pachron verfuegbar.", 2.0)
		_on_node_cleared()
		return

	print("[RunNodeRoom] Spawning Pachron altar")

	# Spawn altar at center of room
	var altar := Area2D.new()
	altar.name = "PachronAltar"
	altar.global_position = Vector2(800, 800)
	altar.collision_layer = 0
	altar.collision_mask = 0
	altar.set_collision_mask_value(2, true)
	altar.monitoring = true

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 100)
	col.shape = shape
	altar.add_child(col)

	# Altar sprite
	var altar_sprite := Sprite2D.new()
	altar_sprite.texture = preload("res://Assets/AIAssets/AIStuff/pachronaltar01.png")
	altar_sprite.scale = Vector2(0.8, 0.8)
	altar.add_child(altar_sprite)

	# Prompt
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "E - Pachron-Altar"
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(200, 25)
	prompt.position = Vector2(-100, 55)
	prompt.visible = false
	altar.add_child(prompt)

	altar.body_entered.connect(func(body):
		if _is_any_player(body):
			_player_in_altar = true
			prompt.visible = true
	)
	altar.body_exited.connect(func(body):
		if _is_any_player(body):
			_player_in_altar = false
			prompt.visible = false
	)

	add_child(altar)
	_show_completion_ui("Pachron-Altar erschienen!")


func _open_pachron_selection() -> void:
	"""Opens the Pachron selection screen UI"""
	if boon_choice_made or _pachron_screen != null:
		return

	var screen_scene = load("res://ui/pachron/pachron_selection_screen.tscn")
	_pachron_screen = screen_scene.instantiate()

	_pachron_screen.boon_flow_completed.connect(_on_pachron_flow_completed)
	_pachron_screen.selection_cancelled.connect(_on_pachron_cancelled)

	# Add to tree first so _ready() runs and builds UI
	get_tree().root.add_child(_pachron_screen)
	get_tree().paused = true

	# Then setup with offered paths
	var available_paths: Array = BoonManager.PATH_IDS.duplicate()
	available_paths.shuffle()
	var offered: Array = available_paths.slice(0, mini(3, available_paths.size()))
	_pachron_screen.setup(offered)
	print("[RunNodeRoom] Pachron selection screen opened")


func _on_pachron_flow_completed() -> void:
	"""Called when the full Pachron flow is done (dialog + boon choice)"""
	boon_choice_made = true
	_pachron_screen = null
	get_tree().paused = false

	# Remove altar
	var altar = get_node_or_null("PachronAltar")
	if altar:
		altar.queue_free()

	_show_completion_ui("Pachron-Segen erhalten!")
	_on_node_cleared()


func _on_pachron_cancelled() -> void:
	"""Player cancelled the selection — return to altar"""
	if _pachron_screen:
		_pachron_screen.queue_free()
		_pachron_screen = null
	get_tree().paused = false
	print("[RunNodeRoom] Pachron selection cancelled")


# ============ REST SETUP ============
func _setup_rest() -> void:
	print("[RunNodeRoom] Rest room — healing all players")
	_heal_all_players()

	var container = VBoxContainer.new()
	container.position = Vector2(400, 200)
	container.custom_minimum_size = Vector2(500, 300)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	var title = Label.new()
	title.text = node_data.get_display_name() if node_data else _get_rest_name()
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
var _event_npc_in_range: bool = false
var _event_dialog_started: bool = false
var _event_choice_index: int = -1  # 0 = positive, 1 = negative
var _event_npc_visual: Node2D = null
var _event_template: Dictionary = {}  # Cached template for current event

# Event templates per world: {npc_name, intro_text, offer_text, accept_text, reject_text, reward_desc}
const EVENT_TEMPLATES_W1: Array = [
	{
		"npc": "Wanderer", "intro": "Eine verhüllte Gestalt sitzt am Wegesrand...",
		"offer": "Ich trage etwas bei mir, das dir helfen könnte. Doch nichts ist umsonst.",
		"accept": "Nimm es. Möge es dir dienen.", "reject": "Dann war unser Gespräch hier wohl vergebens.",
		"reward_desc": "Annehmen",
	},
	{
		"npc": "Alter Geist", "intro": "Ein schimmernder Geist erscheint vor dir...",
		"offer": "Ich war einst wie du. Lass mich dir etwas hinterlassen.",
		"accept": "Nimm meinen Segen.", "reject": "Du wagst es, mich abzulehnen?!",
		"reward_desc": "Segen annehmen",
	},
]

const EVENT_TEMPLATES_W2: Array = [
	{
		"npc": "Defekter Androide", "intro": "Ein beschädigter Androide flackert in der Ecke...",
		"offer": "Mein Speicher enthält... nützliche Daten. Download möglich.",
		"accept": "Transfer... abgeschlossen.", "reject": "Verbindung... verweigert. Protokoll: Verteidigung.",
		"reward_desc": "Daten akzeptieren",
	},
]

const EVENT_TEMPLATES_W3: Array = [
	{
		"npc": "Verzerrte Stimme", "intro": "Die Luft vibriert. Eine körperlose Stimme flüstert...",
		"offer": "Ich biete Macht. Doch Macht hat ihren Preis.",
		"accept": "Die Macht fließt in dich hinein...", "reject": "Dann... werde ich sie dir NEHMEN.",
		"reward_desc": "Macht annehmen",
	},
]


func _setup_event() -> void:
	print("[RunNodeRoom] Event room")

	# Hide old EventChoices if present in scene
	var old_choices = get_node_or_null("EventChoices")
	if old_choices:
		old_choices.visible = false
		for child in old_choices.get_children():
			if child is Area2D:
				child.monitoring = false

	# Cache template and spawn NPC
	_event_template = _get_event_template()
	_spawn_event_npc()


func _spawn_event_npc() -> void:
	"""Creates an NPC visual with interaction area"""
	_event_npc_visual = Node2D.new()
	_event_npc_visual.name = "EventNPC"
	_event_npc_visual.position = Vector2(700, 720)
	add_child(_event_npc_visual)

	# NPC body visual
	var body_rect := ColorRect.new()
	body_rect.color = Color(0.5, 0.3, 0.7, 0.9)
	body_rect.size = Vector2(40, 80)
	body_rect.position = Vector2(-20, -80)
	_event_npc_visual.add_child(body_rect)

	# NPC head
	var head_rect := ColorRect.new()
	head_rect.color = Color(0.6, 0.4, 0.8, 0.9)
	head_rect.size = Vector2(30, 30)
	head_rect.position = Vector2(-15, -110)
	_event_npc_visual.add_child(head_rect)

	# NPC name label
	var name_label := Label.new()
	name_label.text = _event_template["npc"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(160, 20)
	name_label.position = Vector2(-80, -130)
	_event_npc_visual.add_child(name_label)

	# Prompt label
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	prompt.text = "E - Sprechen"
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(120, 20)
	prompt.position = Vector2(-60, 10)
	prompt.visible = false
	_event_npc_visual.add_child(prompt)

	# Glow
	var glow := PointLight2D.new()
	glow.color = Color(0.6, 0.3, 0.9, 0.6)
	glow.energy = 0.4
	glow.position = Vector2(0, -50)
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.width = 128
	gradient_tex.height = 128
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.5)
	gradient_tex.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient_tex.gradient = gradient
	glow.texture = gradient_tex
	glow.texture_scale = 1.5
	_event_npc_visual.add_child(glow)

	# Interaction area
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(2, true)
	area.monitoring = true
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(140, 100)
	col.shape = shape
	col.position = Vector2(0, -40)
	area.add_child(col)
	_event_npc_visual.add_child(area)

	area.body_entered.connect(func(body):
		if _is_any_player(body):
			_event_npc_in_range = true
			prompt.visible = true
	)
	area.body_exited.connect(func(body):
		if _is_any_player(body):
			_event_npc_in_range = false
			prompt.visible = false
	)


func _get_event_template() -> Dictionary:
	"""Returns a random event template for the current world"""
	var templates: Array = []
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			templates = EVENT_TEMPLATES_W1
		RunMapData.WorldId.KOLLEKTIV:
			templates = EVENT_TEMPLATES_W2
		RunMapData.WorldId.ABGRUND:
			templates = EVENT_TEMPLATES_W3

	if templates.is_empty():
		templates = EVENT_TEMPLATES_W1
	return templates[randi() % templates.size()]


func _start_event_dialog() -> void:
	"""Creates and plays event dialog programmatically"""
	if _event_dialog_started or event_choice_made:
		return
	if DialogManager and DialogManager.is_active:
		return

	_event_dialog_started = true
	var template: Dictionary = _event_template

	# Build dialog resource
	var dialog := DialogData.new()
	dialog.dialog_id = "run_event_%d" % (node_data.id if node_data else 0)

	# Entry 1: Narration
	var intro := DialogEntry.new()
	intro.text = template["intro"]
	dialog.entries.append(intro)

	# Entry 2: NPC offer with choices
	var offer := DialogEntry.new()
	offer.speaker_name = template["npc"]
	offer.text = template["offer"]

	var choice_accept := DialogChoice.new()
	choice_accept.choice_text = template["reward_desc"]
	choice_accept.response_speaker = template["npc"]
	choice_accept.response_text = template["accept"]

	var choice_reject := DialogChoice.new()
	choice_reject.choice_text = "Ablehnen"
	choice_reject.response_speaker = template["npc"]
	choice_reject.response_text = template["reject"]

	offer.choices = [choice_accept, choice_reject]
	dialog.entries.append(offer)

	# Connect signals
	EventBus.dialog_choice_selected.connect(_on_event_choice_selected)
	EventBus.dialog_finished.connect(_on_event_dialog_finished, CONNECT_ONE_SHOT)

	DialogManager.play_dialog_resource(dialog)


func _on_event_choice_selected(dialog_id: String, choice_index: int) -> void:
	if not dialog_id.begins_with("run_event_"):
		return
	_event_choice_index = choice_index
	# Disconnect after receiving choice
	if EventBus.dialog_choice_selected.is_connected(_on_event_choice_selected):
		EventBus.dialog_choice_selected.disconnect(_on_event_choice_selected)


func _on_event_dialog_finished(_dialog_id: String) -> void:
	event_choice_made = true

	if _event_choice_index == 0:
		# Positive: give consumable
		_event_positive_outcome()
	else:
		# Negative: NPC becomes hostile
		_event_negative_outcome()


func _event_positive_outcome() -> void:
	"""Player accepted — give a random consumable"""
	var w: int = RewardManager.get_world_id_int(world_id)
	var pool: Array = RewardManager.get_treasure_choices(w)
	if not pool.is_empty():
		var item_id: String = pool[0]
		InventoryManager.add_item(item_id)
		var item_name: String = RewardManager.get_item_name(item_id)
		EventBus.show_notification.emit("Erhalten: %s" % item_name, 3.0)
		print("[RunNodeRoom] Event positive: %s" % item_id)

	# Remove NPC
	if _event_npc_visual:
		_event_npc_visual.queue_free()

	_on_node_cleared()


func _event_negative_outcome() -> void:
	"""Player rejected — NPC becomes hostile, start combat"""
	print("[RunNodeRoom] Event negative — NPC fight!")

	# Change NPC color to hostile red
	if _event_npc_visual:
		_event_npc_visual.queue_free()

	# Spawn enemies using combat system
	var wave_config = RunRoomPool.build_single_wave_config(world_id, RunMapData.NodeType.COMBAT)
	if not wave_config:
		# Fallback: just give the consolation reward
		_event_combat_reward()
		return

	var enemy_spawn_markers: Array[Marker2D] = []
	var spawn_container = get_node_or_null("EnemySpawnPoints")
	if spawn_container:
		for child in spawn_container.get_children():
			if child is Marker2D:
				enemy_spawn_markers.append(child)

	if enemy_spawn_markers.is_empty():
		# No spawn points — create a fallback
		var fallback := Marker2D.new()
		fallback.position = Vector2(700, 720)
		add_child(fallback)
		enemy_spawn_markers.append(fallback)

	arena_controller = ArenaController.new()
	arena_controller.name = "EventArenaController"
	arena_controller.arena_id = "event_npc_%d" % (node_data.id if node_data else 0)
	arena_controller.wave_configs = [wave_config]
	arena_controller.start_mode = ArenaController.StartMode.MANUAL
	arena_controller.lock_doors_during_waves = false
	arena_controller.spawn_coins_on_clear = false
	arena_controller.coins_per_wave = 0
	add_child(arena_controller)

	for marker in enemy_spawn_markers:
		arena_controller.spawn_points.append(arena_controller.get_path_to(marker))

	arena_controller.arena_completed.connect(_on_event_combat_completed)

	EventBus.show_notification.emit("Der NPC greift an!", 2.0)

	get_tree().create_timer(1.0).timeout.connect(func():
		if arena_controller and not arena_controller.is_cleared:
			arena_controller.start_arena()
	)


func _on_event_combat_completed() -> void:
	print("[RunNodeRoom] Event combat completed!")
	_event_combat_reward()


func _event_combat_reward() -> void:
	"""Consolation reward after winning event combat: gold + small heal"""
	var reward: Dictionary = RewardManager.get_event_combat_reward()
	GameManager.add_coins(reward["gold"])

	# Small heal all players
	for p in get_tree().get_nodes_in_group("player"):
		if not p or not is_instance_valid(p):
			continue
		if p.has_node("HealthComponent"):
			var health_comp = p.get_node("HealthComponent")
			var heal_amount: float = health_comp.max_health * reward["heal_percent"]
			health_comp.heal(heal_amount)

	_show_completion_ui("Kampf gewonnen! +%d Gold" % reward["gold"])
	EventBus.show_notification.emit("+%d Gold, kleine Heilung" % reward["gold"], 3.0)
	get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)


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
		if _is_any_player(body):
			_player_in_shop_area = true
	)
	merchant_area.body_exited.connect(func(body):
		if _is_any_player(body):
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
var _boss_controller: Node = null

func _setup_boss() -> void:
	var boss_name: String = _get_boss_name()
	var is_final_boss: bool = _get_next_world() < 0
	print("[RunNodeRoom] Boss room — %s" % boss_name)

	# Try to spawn the actual boss based on world
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			_setup_hero_group_boss(is_final_boss)
		RunMapData.WorldId.KOLLEKTIV:
			_setup_kollektiv_boss(is_final_boss)
		RunMapData.WorldId.ABGRUND:
			_setup_mirror_boss(is_final_boss)
		_:
			# Other worlds: placeholder (auto-skip)
			_setup_boss_placeholder(boss_name, is_final_boss)


func _setup_hero_group_boss(is_final_boss: bool) -> void:
	"""Spawns the hero group boss for Welt 1"""
	var controller_scene: PackedScene = load("res://bosses/hero_group/hero_group_controller.tscn")
	if not controller_scene:
		push_warning("[RunNodeRoom] Hero group controller scene not found!")
		_setup_boss_placeholder("Die Heldengruppe", is_final_boss)
		return

	_boss_controller = controller_scene.instantiate()

	# Position at center of arena
	var boss_spawn: Marker2D = null
	var spawn_container = get_node_or_null("EnemySpawnPoints")
	if spawn_container:
		boss_spawn = spawn_container.get_node_or_null("BossSpawn") as Marker2D
	if boss_spawn:
		_boss_controller.global_position = boss_spawn.global_position
	else:
		_boss_controller.global_position = Vector2(1300, 760)

	add_child(_boss_controller)

	# Connect defeated signal
	_boss_controller.defeated.connect(_on_boss_defeated.bind(is_final_boss))

	# Start fight after delay
	_show_completion_ui("Die Heldengruppe")
	get_tree().create_timer(2.0).timeout.connect(func():
		if _boss_controller and _boss_controller.has_method("start_fight"):
			_boss_controller.start_fight()
	)


func _setup_kollektiv_boss(is_final_boss: bool) -> void:
	"""Spawns the Kollektiv boss for Welt 2"""
	var controller_scene: PackedScene = load("res://bosses/kollektiv/kollektiv_controller.tscn")
	if not controller_scene:
		push_warning("[RunNodeRoom] Kollektiv controller scene not found!")
		_setup_boss_placeholder("Das Kollektiv der Einen Stimme", is_final_boss)
		return

	_boss_controller = controller_scene.instantiate()

	# Position at center of arena
	var boss_spawn: Marker2D = null
	var spawn_container = get_node_or_null("EnemySpawnPoints")
	if spawn_container:
		boss_spawn = spawn_container.get_node_or_null("BossSpawn") as Marker2D
	if boss_spawn:
		_boss_controller.global_position = boss_spawn.global_position
	else:
		_boss_controller.global_position = Vector2(1400, 1400)

	add_child(_boss_controller)

	# Connect defeated signal
	_boss_controller.defeated.connect(_on_boss_defeated.bind(is_final_boss))

	# Start fight after delay
	_show_completion_ui("Das Kollektiv der Einen Stimme")
	get_tree().create_timer(2.0).timeout.connect(func():
		if _boss_controller and _boss_controller.has_method("start_fight"):
			_boss_controller.start_fight()
	)


func _setup_mirror_boss(is_final_boss: bool) -> void:
	"""Spawns the Mirror boss for Welt 3"""
	var controller_scene: PackedScene = load("res://bosses/mirror/mirror_controller.tscn")
	if not controller_scene:
		push_warning("[RunNodeRoom] Mirror controller scene not found!")
		_setup_boss_placeholder("Murum (Spiegel)", is_final_boss)
		return

	_boss_controller = controller_scene.instantiate()

	# Position at player start (runner boss doesn't use BossSpawn)
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		_boss_controller.global_position = player.global_position
	else:
		_boss_controller.global_position = Vector2(300, 760)

	add_child(_boss_controller)

	# Connect defeated signal
	_boss_controller.defeated.connect(_on_boss_defeated.bind(is_final_boss))

	# Start fight after delay
	_show_completion_ui("Murum (Spiegel)")
	get_tree().create_timer(2.0).timeout.connect(func():
		if _boss_controller and _boss_controller.has_method("start_fight"):
			_boss_controller.start_fight()
	)


func _on_boss_defeated(is_final_boss: bool) -> void:
	"""Called when a boss is defeated"""
	print("[RunNodeRoom] Boss defeated!")

	# Full heal all players
	_heal_all_players()

	# Grant boss rewards: Magicka
	var w: int = RewardManager.get_world_id_int(world_id)
	var magicka_amount: int = RewardManager.get_boss_magicka(w)
	RunManager.add_magicka(magicka_amount)

	_show_completion_ui("Boss besiegt! +%d Magicka!" % magicka_amount)
	EventBus.show_notification.emit("+%d Magicka! Volle Heilung!" % magicka_amount, 4.0)

	# Wait for VictorySequence if boss has one, otherwise use fallback timer
	var wait_time: float = 4.0
	if _boss_controller:
		var vs: VictorySequence = _boss_controller.get_node_or_null("Components/VictorySequence")
		if vs and vs._is_running:
			await vs.sequence_completed
			# Small extra pause after sequence
			await get_tree().create_timer(0.5).timeout
			if is_final_boss:
				_on_node_cleared()
			else:
				_setup_boon_selection()
			return

	# Fallback: fixed timer (for bosses without VictorySequence)
	if is_final_boss:
		get_tree().create_timer(wait_time).timeout.connect(_on_node_cleared)
	else:
		get_tree().create_timer(wait_time).timeout.connect(_setup_boon_selection)


func _setup_boss_placeholder(boss_name: String, is_final_boss: bool) -> void:
	"""Placeholder for unimplemented bosses — auto-skip"""
	print("[RunNodeRoom] Boss placeholder — %s (auto-skip)" % boss_name)

	# Full heal all players
	_heal_all_players()

	var w: int = RewardManager.get_world_id_int(world_id)
	var magicka_amount: int = RewardManager.get_boss_magicka(w)
	RunManager.add_magicka(magicka_amount)

	_show_completion_ui("BOSS: %s (uebersprungen)" % boss_name)
	EventBus.show_notification.emit("+%d Magicka! Volle Heilung!" % magicka_amount, 4.0)

	if is_final_boss:
		get_tree().create_timer(2.0).timeout.connect(_on_node_cleared)
	else:
		get_tree().create_timer(2.0).timeout.connect(_setup_boon_selection)


func _get_boss_name() -> String:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return "Die Heldengruppe"
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

	var door_width: float = 800.0
	var door_height: float = 800.0
	var door_color := Color(1.0, 0.85, 0.2)

	# Door sprite
	var door_sprite = Sprite2D.new()
	door_sprite.texture = DOOR_TEXTURE
	door_sprite.position = Vector2(0, -door_height / 2.0)
	door_sprite.scale = Vector2(door_width / 800.0, door_height / 800.0)
	door_sprite.modulate = door_color
	door_container.add_child(door_sprite)

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
		if _is_any_player(body):
			prompt.visible = true
			door_container.set_meta("player_inside", true)
	)
	area.body_exited.connect(func(body):
		if _is_any_player(body):
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

	var door_width: float = 800.0
	var door_height: float = 800.0
	var door_color: Color = DOOR_COLORS.get(node.type, Color.WHITE)

	# Door sprite
	var door_sprite = Sprite2D.new()
	door_sprite.texture = DOOR_TEXTURE
	door_sprite.position = Vector2(0, -door_height / 5.0)
	door_sprite.scale = Vector2(door_width / 400.0, door_height / 400.0)
	door_sprite.modulate = door_color
	door_container.add_child(door_sprite)

	# Node type label
	var type_label = Label.new()
	type_label.text = node.get_display_name()
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
	prompt.text = "E - %s" % node.get_display_name()
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(200, 20)
	prompt.position = Vector2(-100, 10)
	prompt.visible = false
	door_container.add_child(prompt)

	# Connect signals
	var node_id = node.id
	area.body_entered.connect(func(body):
		if _is_any_player(body):
			prompt.visible = true
			door_container.set_meta("player_inside", true)
	)
	area.body_exited.connect(func(body):
		if _is_any_player(body):
			prompt.visible = false
			door_container.set_meta("player_inside", false)
	)

	door_container.set_meta("node_id", node_id)
	door_container.add_to_group("run_doors")


func _process(_delta: float) -> void:
	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact") or InputManager.is_p2_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if not interact_pressed:
		return

	# Treasure choice confirmation
	if node_type == RunMapData.NodeType.TREASURE and not treasure_choice_made:
		_confirm_treasure_choice()
		return

	# Pachron altar interaction (Elite + Boss rooms)
	if node_type in [RunMapData.NodeType.ELITE, RunMapData.NodeType.BOSS] and not boon_choice_made and _player_in_altar:
		_open_pachron_selection()
		return

	# Event NPC interaction
	if node_type == RunMapData.NodeType.EVENT and not event_choice_made and _event_npc_in_range:
		_start_event_dialog()
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
func _try_spawn_stat_pickup(chance: float = 0.25) -> void:
	"""Spawns a random stat pickup (HP or Mana) near the player"""
	if randf() > chance:
		return

	var spawn_pos := Vector2(600, 400)  # Fallback
	if GameManager.player and is_instance_valid(GameManager.player):
		spawn_pos = GameManager.player.global_position + Vector2(randi_range(-80, 80), -40)

	var pickup := StatPickup.new()
	pickup.stat_type = StatPickup.StatType.HP if randf() < 0.5 else StatPickup.StatType.MANA
	pickup.bonus_amount = randi_range(10, 20)
	pickup.global_position = spawn_pos
	add_child(pickup)
	print("[RunNodeRoom] Stat pickup spawned: %s +%d" % [
		"HP" if pickup.stat_type == StatPickup.StatType.HP else "Mana",
		pickup.bonus_amount
	])


func _show_completion_ui(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(400, 100)
	label.size = Vector2(400, 50)
	add_child(label)
