extends Node2D

## Room 01 - Entry/Tutorial Room

# ============================================================================
# PROPERTIES
# ============================================================================

const ROOM_ID: String = "room_01_entry"
const WORLD_ID: String = "world_1_ruins"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var door_to_room_02: Node = $Doors/DoorToRoom02
@onready var spawn_points: Node2D = $SpawnPoints

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Door is configured directly in the scene file via target_scene export
	print("[Room01] Initialized")

	# Activate room (register with GameManager, setup player)
	call_deferred("_activate")


func _activate() -> void:
	"""Activates the room and sets up player if transitioning from another scene"""
	# Register room with GameManager
	if GameManager.has_method("register_room"):
		GameManager.register_room(self)

	# Check if player exists, if not spawn a new one (e.g., from main menu)
	if not GameManager.player or not is_instance_valid(GameManager.player):
		print("[Room01] No player found, spawning new player")
		_spawn_new_player()
		return

	# If player was transferred from another scene, ensure proper setup
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player

		# Ensure player is in this scene
		if player.get_parent() == self:
			print("[Room01] Player found in scene, ensuring correct z_index and position")
			player.z_index = 100
			player.z_as_relative = false

			# Ensure player is on ground (not floating or falling through)
			if player is CharacterBody2D:
				player.velocity = Vector2.ZERO

			# Clear camera bounds for free following
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera.has_method("clear_room_bounds"):
				player_camera.clear_room_bounds()
				print("[Room01] Camera limits cleared")


func _spawn_new_player() -> void:
	"""Spawns a new player at the default spawn point or loaded position"""
	# Load player scene
	var player_scene = preload("res://player/murum.tscn")
	if not player_scene:
		print("[Room01] ERROR: Could not load player scene")
		return

	# Instantiate player
	var player = player_scene.instantiate()

	# Check if we have pending player data from save load (COMMIT 016)
	var has_save_data = SaveManager.pending_player_data and not SaveManager.pending_player_data.is_empty()

	# Get spawn position
	var spawn_pos = Vector2(50, 360)

	if has_save_data:
		# Use saved position
		var pos_data = SaveManager.pending_player_data.get("position", {})
		spawn_pos = Vector2(pos_data.get("x", 50), pos_data.get("y", 360))
		print("[Room01] Using saved position: ", spawn_pos)
	else:
		# Use default spawn point if it exists
		var default_spawn = spawn_points.get_node_or_null("Default")
		if default_spawn:
			spawn_pos = default_spawn.global_position
			print("[Room01] Using default spawn point at: ", spawn_pos)
		else:
			print("[Room01] Using fallback spawn position: ", spawn_pos)

	# Set player position
	player.global_position = spawn_pos

	# Add player to scene
	add_child(player)

	# Apply saved stats if available (COMMIT 016)
	if has_save_data:
		_apply_saved_player_data(player, SaveManager.pending_player_data)

		# Clear pending data after applying
		SaveManager.pending_player_data = {}
		print("[Room01] Saved player data applied and cleared")

	# Register with GameManager
	if GameManager.has_method("set_player"):
		GameManager.set_player(player)

	print("[Room01] Player spawned successfully at ", spawn_pos)


func _apply_saved_player_data(player: Node, player_data: Dictionary) -> void:
	"""Applies saved player stats from loaded game (COMMIT 016)"""
	print("[Room01] Applying saved player data...")

	# Apply HP
	if player.has("current_hp"):
		player.current_hp = player_data.get("current_hp", player.MAX_HP if player.has("MAX_HP") else 100)
		print("[Room01] Set HP to: %d" % player.current_hp)

	# Apply Mana
	if player.has("current_mana"):
		player.current_mana = player_data.get("current_mana", player.MAX_MANA if player.has("MAX_MANA") else 100)
		print("[Room01] Set Mana to: %d" % player.current_mana)

	# Apply facing direction
	if player.has("facing_direction"):
		player.facing_direction = player_data.get("facing_direction", 1)

	print("[Room01] Player data applied successfully")
