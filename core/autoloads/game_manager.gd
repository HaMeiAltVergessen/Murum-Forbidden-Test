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


func _ready() -> void:
	print("[GameManager] Initialized")

	# Connect to EventBus signals
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)

	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	# Pause/Unpause with ESC
	if event.is_action_pressed("ui_cancel") and current_state == GameState.PLAYING:
		toggle_pause()


# ============ GAME STATE MANAGEMENT ============
func start_new_game() -> void:
	"""Starts a new game session"""
	current_state = GameState.PLAYING
	enemies_killed = 0
	deaths = 0
	coins_collected = 0

	# Load test room
	var test_room_scene: PackedScene = load("res://levels/test_room.tscn")
	if test_room_scene:
		get_tree().change_scene_to_packed(test_room_scene)

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
	current_state = GameState.GAME_OVER
	print("[GameManager] Player died. Total deaths: ", deaths)


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


# ============ STATISTICS ============
func add_coin() -> void:
	"""Increments coin counter"""
	coins_collected += 1
	print("[GameManager] Coin collected. Total: ", coins_collected)


func get_statistics() -> Dictionary:
	"""Returns current game statistics"""
	return {
		"enemies_killed": enemies_killed,
		"deaths": deaths,
		"coins_collected": coins_collected
	}
