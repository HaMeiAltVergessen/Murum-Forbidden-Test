extends Node2D
## TestRoom - First playable level for vertical slice
class_name TestRoom

# ============ REFERENCES ============
@onready var player_spawn: Marker2D = $SpawnPoints/PlayerSpawn
@onready var lever: Node = $Environment/Lever  # Generic Node instead of Lever type
@onready var door: Node = $Environment/Door    # Generic Node instead of Door type
@onready var player: Murum = $Murum

# ============ ROOM BOUNDS ============
@export var room_size: Vector2 = Vector2(1920, 1080)


func _ready() -> void:
	# CRITICAL: Remove duplicate player if transitioning from another scene
	# If GameManager already has a player (from door transition), use that one
	if GameManager.player and is_instance_valid(GameManager.player):
		# Scene has its own player instance from .tscn file
		if player and is_instance_valid(player) and player != GameManager.player:
			print("[TestRoom] Removing duplicate player from scene (using GameManager.player)")
			if player.get_parent():
				player.get_parent().remove_child(player)
			player.queue_free()

			# Use the GameManager's player instead
			player = GameManager.player

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
		# Safe spawn: reset velocity first
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.global_position = player_spawn.global_position
		GameManager.register_player(player, player_spawn.global_position)

	# Setup camera bounds (COMMIT 021: Co-op Camera)
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("clear_room_bounds"):
		camera.clear_room_bounds()
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
