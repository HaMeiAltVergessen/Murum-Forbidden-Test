extends Node2D
## TestRoom - First playable level for vertical slice
class_name TestRoom

# ============ REFERENCES ============
@onready var player_spawn: Marker2D = $SpawnPoints/PlayerSpawn
@onready var lever: Lever = $Environment/Lever
@onready var door: Door = $Environment/Door
@onready var player: Murum = $Murum

# ============ ROOM BOUNDS ============
@export var room_size: Vector2 = Vector2(1920, 1080)


func _ready() -> void:
	# Activate room
	activate()

	print("[TestRoom] Level loaded")


func activate() -> void:
	"""Activates the room and sets up connections"""
	# Register room with GameManager
	GameManager.register_room(self)

	# Lever connects to door automatically via door's required_levers

	# Setup player spawn
	if player and player_spawn:
		player.global_position = player_spawn.global_position
		GameManager.register_player(player, player_spawn.global_position)

	# Clear camera bounds so camera always follows player
	if player:
		var player_camera = player.get_node_or_null("PlayerCamera")
		if player_camera and player_camera.has_method("clear_room_bounds"):
			player_camera.clear_room_bounds()
			print("[TestRoom] Camera limits cleared - free following")


func deactivate() -> void:
	"""Deactivates the room"""
	print("[TestRoom] Room deactivated")
