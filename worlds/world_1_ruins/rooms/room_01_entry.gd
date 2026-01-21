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
	"""Spawns a new player at the default spawn point"""
	# Load player scene
	var player_scene = preload("res://player/murum.tscn")
	if not player_scene:
		print("[Room01] ERROR: Could not load player scene")
		return

	# Instantiate player
	var player = player_scene.instantiate()

	# Get spawn position (50 pixels from left edge, centered vertically on platform level)
	var spawn_pos = Vector2(50, 360)

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

	# Register with GameManager
	if GameManager.has_method("set_player"):
		GameManager.set_player(player)

	print("[Room01] Player spawned successfully at ", spawn_pos)
