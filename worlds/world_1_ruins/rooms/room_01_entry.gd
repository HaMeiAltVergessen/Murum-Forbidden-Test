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
