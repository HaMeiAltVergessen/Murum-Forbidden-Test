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

	# Spawn additional enemies for Rebound testing (Commit 018)
	_spawn_additional_enemies()

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


func _spawn_additional_enemies() -> void:
	"""Spawns additional enemies for Rebound testing (Commit 018)"""
	# Original: 4 Untote
	# Target: 12 Untote (3x)
	# Need to spawn: 8 more

	var untote_scene = preload("res://enemies/untote.tscn")

	# Spawn positions (spread across the arena)
	var spawn_positions = [
		Vector2(400, 800),
		Vector2(600, 800),
		Vector2(800, 800),
		Vector2(1000, 800),
		Vector2(1200, 800),
		Vector2(1400, 800),
		Vector2(1600, 800),
		Vector2(900, 600),  # One on platform
	]

	for pos in spawn_positions:
		var enemy = untote_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)

	print("[TestRoom] Spawned 8 additional Untote for Rebound testing (Total: 12)")
