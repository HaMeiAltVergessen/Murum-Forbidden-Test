extends Node
## GameManager handles game state, player lifecycle, and level management

# ============ GAME STATE ============
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.MENU

# ============ PLAYER REFERENCES ============
var player: CharacterBody2D = null
var player_spawn_position: Vector2 = Vector2.ZERO
var current_room: Node2D = null

# ============ STATISTICS ============
var enemies_killed: int = 0
var deaths: int = 0
var coins_collected: int = 0

# ============ WORLD PROGRESSION ============
var world1_arena_cleared: bool = false

# ============ FLAGS SYSTEM ============
# Generic flag system for boss defeats, unlocks, etc.
var flags: Dictionary = {}

# ============ CO-OP DATA (P2) ============
# P2's data is NOT saved, only exists during active session
var p2_gold: int = 0
var p2_consumables: Array[String] = []

# ============ SIGNALS ============
signal arena_cleared
signal flag_changed(flag_name: String, value: bool)
signal p2_gold_changed(new_amount: int)


func _ready() -> void:
	print("[GameManager] Initialized")

	# Connect to EventBus signals
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)

	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)

	# Initialize co-op data
	_initialize_coop_data()


func _input(event: InputEvent) -> void:
	# Pause/Unpause with ESC
	if event.is_action_pressed("ui_cancel") and current_state == GameState.PLAYING:
		toggle_pause()


# ============ GAME STATE MANAGEMENT ============
func start_new_game() -> void:
	"""Starts a new game session with intro cutscene"""
	print("[GameManager] start_new_game() called")
	current_state = GameState.PLAYING
	enemies_killed = 0
	deaths = 0
	coins_collected = 0

	# Spiele Intro-Cutscene ab, dann lade Level
	print("[GameManager] Checking CutsceneManager: ", CutsceneManager)
	if CutsceneManager:
		print("[GameManager] CutsceneManager exists, checking for intro cutscene...")
		var has_intro = CutsceneManager.has_cutscene("intro")
		print("[GameManager] has_cutscene('intro'): ", has_intro)
		if has_intro:
			print("[GameManager] Playing intro cutscene...")
			CutsceneManager.play_cutscene("intro", _on_intro_cutscene_finished)
			return

	print("[GameManager] No cutscene, loading level directly")
	_load_game_level()


func _on_intro_cutscene_finished(_cutscene_id: String, _was_skipped: bool) -> void:
	"""Callback nach Intro-Cutscene"""
	_load_game_level()


func _load_game_level() -> void:
	"""Lädt das Spiel-Level"""
	print("[GameManager] _load_game_level() called")

	# Lade World 1 Entry Level (oder test_room als Fallback)
	var level_path = "res://worlds/world_1_ruins/section_1_entrance/room_01_entry.tscn"
	var level_scene: PackedScene = load(level_path)

	if not level_scene:
		print("[GameManager] Warning: Could not load ", level_path, " - trying test_room")
		level_scene = load("res://levels/test_room.tscn")

	if level_scene:
		get_tree().change_scene_to_packed(level_scene)
		print("[GameManager] Level loaded: ", level_path)
	else:
		push_error("[GameManager] Failed to load any level!")

	EventBus.game_started.emit()
	print("[GameManager] New game started")


func toggle_pause() -> void:
	"""Toggles game pause state"""
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		EventBus.game_paused.emit()
		print("[GameManager] Game paused")
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		EventBus.game_unpaused.emit()
		print("[GameManager] Game unpaused")


func set_game_over() -> void:
	"""Sets game to game over state"""
	current_state = GameState.GAME_OVER
	print("[GameManager] Game Over")


# ============ PLAYER MANAGEMENT ============
func register_player(player_node: CharacterBody2D, spawn_pos: Vector2) -> void:
	"""Registers the player character and spawn position"""
	player = player_node
	player_spawn_position = spawn_pos
	print("[GameManager] Player registered at position: ", spawn_pos)

	# Register with CoopManager
	if CoopManager:
		CoopManager.set_p1_reference(player_node)


func set_player(player_node: CharacterBody2D) -> void:
	"""Sets the player reference (simpler version without spawn position)"""
	player = player_node
	print("[GameManager] Player set: ", player_node)

	# Register with CoopManager
	if CoopManager:
		CoopManager.set_p1_reference(player_node)


func update_spawn_position(new_pos: Vector2) -> void:
	"""Updates the spawn position (called when entering a new room)"""
	player_spawn_position = new_pos
	print("[GameManager] Spawn position updated to: ", new_pos)


func respawn_player() -> void:
	"""Respawns the player at the last spawn point"""
	if not player:
		push_error("[GameManager] Cannot respawn: No player registered")
		return

	# Determine spawn position (use checkpoint if available, else initial spawn)
	var spawn_pos: Vector2
	if WorldManager.last_checkpoint_position != Vector2.ZERO:
		spawn_pos = WorldManager.last_checkpoint_position
		print("[GameManager] Respawning at checkpoint: ", spawn_pos)
	else:
		spawn_pos = player_spawn_position
		print("[GameManager] Respawning at initial spawn: ", spawn_pos)

	# Call player's respawn method (handles is_dead flag and controls)
	if player.has_method("respawn"):
		player.respawn(spawn_pos)

	# Reset player health/mana via components
	if player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		health_comp.reset_health()

	if player.has_node("ManaComponent"):
		var mana_comp = player.get_node("ManaComponent")
		mana_comp.reset_mana()

	# Reset game state
	current_state = GameState.PLAYING

	EventBus.player_respawned.emit()
	print("[GameManager] Player respawned")


func register_room(room: Node2D) -> void:
	"""Registers the current room"""
	current_room = room
	print("[GameManager] Room registered: ", room.name)


# ============ EVENT HANDLERS ============
func _on_player_died() -> void:
	"""Handles player death"""
	deaths += 1
	print("[GameManager] Player died. Total deaths: ", deaths)

	# In co-op mode, check if P2 can revive
	if CoopManager and CoopManager.is_p2_alive():
		print("[GameManager] P2 is alive, will attempt revive")
		CoopManager.on_p1_died()
	else:
		# Single player or both dead
		current_state = GameState.GAME_OVER


func _on_enemy_died(enemy: Node, _position: Vector2) -> void:
	"""Handles enemy death"""
	enemies_killed += 1
	print("[GameManager] Enemy killed: ", enemy.name, " Total: ", enemies_killed)


func _on_node_added(node: Node) -> void:
	"""Handles when nodes are added to the scene tree (used for scene transitions)"""
	# Check if this is a new scene being loaded
	if node == get_tree().current_scene and player and is_instance_valid(player):
		# If player is still at root, move to new scene
		if player.get_parent() == get_tree().root:
			call_deferred("_reposition_player_in_scene", node)

		# Also reposition P2 if active (COMMIT 021 - Co-op)
		if CoopManager and CoopManager.is_p2_active:
			var p2 = CoopManager.get_p2_instance()
			if p2 and is_instance_valid(p2) and p2.get_parent() == get_tree().root:
				call_deferred("_reposition_p2_in_scene", node)


func _reposition_player_in_scene(scene: Node) -> void:
	"""Repositions player in the new scene after a transition"""
	if not player or not is_instance_valid(player):
		print("[GameManager] Cannot reposition: Player invalid")
		return

	if not scene or not is_instance_valid(scene):
		print("[GameManager] Cannot reposition: Scene invalid")
		return

	# If player is already a child of the target scene, just reposition
	if player.get_parent() == scene:
		print("[GameManager] Player already in target scene, just repositioning")
		player.global_position = player_spawn_position
		player.z_index = 10
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		return

	print("[GameManager] Repositioning player. Current parent: ", player.get_parent())
	print("[GameManager] Target scene: ", scene.name)
	print("[GameManager] Target spawn position: ", player_spawn_position)

	# Remove from current parent (whether root or another scene)
	var current_parent = player.get_parent()
	if current_parent:
		current_parent.remove_child(player)
		print("[GameManager] Removed player from: ", current_parent.name)

	# Add to new scene as LAST child (renders on top of all existing nodes)
	scene.add_child(player)

	# Force player to absolute end of children list
	scene.move_child(player, scene.get_child_count() - 1)

	# High z_index to ensure rendering above everything
	player.z_index = 100
	player.z_as_relative = false  # Absolute z-ordering

	# Position at spawn point
	player.global_position = player_spawn_position

	# Reset velocity and physics state
	if player.has_method("reset_velocity"):
		player.reset_velocity()
	elif "velocity" in player:
		player.velocity = Vector2.ZERO

	# Force player to be on floor (not falling)
	if player.has_method("apply_floor_snap"):
		player.apply_floor_snap()

	print("[GameManager] Player repositioned in scene: ", scene.name)
	print("[GameManager] Position: ", player.global_position, " | z_index: ", player.z_index)
	print("[GameManager] Child index: ", player.get_index(), " of ", scene.get_child_count())


func _reposition_p2_in_scene(scene: Node) -> void:
	"""Repositions P2 in the new scene after a transition (COMMIT 021 - Co-op)"""
	if not CoopManager or not CoopManager.is_p2_active:
		return

	var p2 = CoopManager.get_p2_instance()
	if not p2 or not is_instance_valid(p2):
		print("[GameManager] Cannot reposition P2: Invalid")
		return

	if not scene or not is_instance_valid(scene):
		print("[GameManager] Cannot reposition P2: Scene invalid")
		return

	# If P2 is already a child of the target scene, just reposition
	if p2.get_parent() == scene:
		print("[GameManager] P2 already in target scene, just repositioning")
		p2.global_position = player_spawn_position + Vector2(50, 0)  # Spawn next to P1
		p2.z_index = 10
		if "velocity" in p2:
			p2.velocity = Vector2.ZERO
		return

	print("[GameManager] Repositioning P2. Current parent: ", p2.get_parent())
	print("[GameManager] Target scene: ", scene.name)

	# CRITICAL: Hide P2 and disable physics during transition delay
	# This prevents P2 from falling out of bounds while waiting
	p2.visible = false
	p2.set_physics_process(false)
	p2.set_process(false)
	if "velocity" in p2:
		p2.velocity = Vector2.ZERO

	# Wait 1 second before moving P2 to new scene (prevents out-of-bounds death)
	print("[GameManager] Waiting 1 second before moving P2 to new scene...")
	await get_tree().create_timer(1.0).timeout

	# Validate everything is still valid after the wait
	if not is_instance_valid(p2) or not is_instance_valid(scene):
		print("[GameManager] P2 or scene became invalid during wait")
		return

	# Remove from current parent (whether root or another scene)
	var current_parent = p2.get_parent()
	if current_parent:
		current_parent.remove_child(p2)
		print("[GameManager] Removed P2 from: ", current_parent.name)

	# Add to new scene as LAST child (renders on top of all existing nodes)
	scene.add_child(p2)

	# Force P2 to absolute end of children list
	scene.move_child(p2, scene.get_child_count() - 1)

	# High z_index to ensure rendering above everything
	p2.z_index = 100
	p2.z_as_relative = false  # Absolute z-ordering

	# Position at spawn point (offset from P1)
	p2.global_position = player_spawn_position + Vector2(50, 0)

	# Reset velocity and physics state
	if p2.has_method("reset_velocity"):
		p2.reset_velocity()
	elif "velocity" in p2:
		p2.velocity = Vector2.ZERO

	# Force P2 to be on floor (not falling)
	if p2.has_method("apply_floor_snap"):
		p2.apply_floor_snap()

	# Re-enable P2 visibility and physics
	p2.visible = true
	p2.set_physics_process(true)
	p2.set_process(true)

	# CRITICAL: Re-initialize P2's input system after scene transition
	# _ready() is NOT called again when re-adding to tree, so we must manually restore controller references
	_reinitialize_p2_input_system(p2)

	# CRITICAL: Re-setup CoopCamera after level transition
	# The camera from the previous scene is destroyed, so we need to create/activate a new one
	if CoopManager and CoopManager.has_method("_setup_coop_camera"):
		CoopManager._setup_coop_camera()
		print("[GameManager] CoopCamera re-setup after level transition")

	print("[GameManager] P2 repositioned in scene: ", scene.name)
	print("[GameManager] Position: ", p2.global_position, " | z_index: ", p2.z_index)


func _reinitialize_p2_input_system(p2: CharacterBody2D) -> void:
	"""Re-initialize P2's input system after scene transition (COMMIT 021 - Co-op Fix)"""
	if not p2 or not is_instance_valid(p2):
		return

	print("[GameManager] Re-initializing P2's input system...")

	# Re-set MovementController's controller_device_id
	if p2.has_node("MovementController"):
		var movement = p2.get_node("MovementController")
		if InputManager and InputManager.p2_controller_device >= 0:
			movement.controller_device_id = InputManager.p2_controller_device
			print("[GameManager] P2 MovementController device restored: ", movement.controller_device_id)

	# Re-set CombatSystem's controller_device_id (if it has one)
	if p2.has_node("CombatSystem"):
		var combat = p2.get_node("CombatSystem")
		if "controller_device_id" in combat and InputManager and InputManager.p2_controller_device >= 0:
			combat.controller_device_id = InputManager.p2_controller_device
			print("[GameManager] P2 CombatSystem device restored: ", combat.controller_device_id)

	print("[GameManager] P2 input system re-initialized successfully")


# ============ STATISTICS ============
func add_coin() -> void:
	"""Increments coin counter by 1"""
	add_coins(1)

func add_coins(amount: int) -> void:
	"""Adds coins to player's total"""
	coins_collected += amount
	EventBus.coins_changed.emit(coins_collected)
	print("[GameManager] Coins added: +%d. Total: %d" % [amount, coins_collected])

func remove_coins(amount: int) -> void:
	"""Removes coins from player's total"""
	coins_collected -= amount
	EventBus.coins_changed.emit(coins_collected)
	print("[GameManager] Coins removed: -%d. Total: %d" % [amount, coins_collected])


func get_statistics() -> Dictionary:
	"""Returns current game statistics"""
	return {
		"enemies_killed": enemies_killed,
		"deaths": deaths,
		"coins_collected": coins_collected
	}


# ============ FLAGS SYSTEM ============
func set_flag(flag_name: String, value: bool) -> void:
	"""Sets a game flag (for boss defeats, unlocks, etc.)"""
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)
	print("[GameManager] Flag set: %s = %s" % [flag_name, value])


func get_flag(flag_name: String, default_value: bool = false) -> bool:
	"""Gets a game flag value"""
	return flags.get(flag_name, default_value)


func has_flag(flag_name: String) -> bool:
	"""Checks if a flag exists"""
	return flags.has(flag_name)


func clear_flags() -> void:
	"""Clears all flags (for new game)"""
	flags.clear()
	print("[GameManager] All flags cleared")


# ============ CO-OP SYSTEM ============
func _initialize_coop_data() -> void:
	"""Initialize co-op data"""
	p2_gold = 0
	p2_consumables.clear()

func add_p2_gold(amount: int) -> void:
	"""Add gold to P2's total"""
	p2_gold += amount
	p2_gold_changed.emit(p2_gold)
	print("[GameManager] P2 Gold added: +%d. Total: %d" % [amount, p2_gold])

func spend_p2_gold(amount: int) -> bool:
	"""Spend P2's gold (returns false if not enough)"""
	if p2_gold >= amount:
		p2_gold -= amount
		p2_gold_changed.emit(p2_gold)
		print("[GameManager] P2 Gold spent: -%d. Total: %d" % [amount, p2_gold])
		return true
	return false

func get_p2_gold() -> int:
	"""Get P2's current gold"""
	return p2_gold

func add_p2_consumable(item_id: String) -> void:
	"""Add consumable to P2's inventory"""
	p2_consumables.append(item_id)
	print("[GameManager] P2 Consumable added: %s" % item_id)

func has_p2_consumable(item_id: String) -> bool:
	"""Check if P2 has a consumable"""
	return item_id in p2_consumables

func use_p2_consumable(item_id: String) -> bool:
	"""Use P2's consumable (returns false if not found)"""
	if has_p2_consumable(item_id):
		p2_consumables.erase(item_id)
		print("[GameManager] P2 Consumable used: %s" % item_id)
		return true
	return false

func reset_p2_data() -> void:
	"""Reset P2's data (called when P2 leaves or on load)"""
	p2_gold = 0
	p2_consumables.clear()
	print("[GameManager] P2 data reset")
