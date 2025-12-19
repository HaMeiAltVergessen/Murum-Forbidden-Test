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

	# Connect lever to door
	if lever and door:
		lever.lever_activated.connect(_on_lever_activated)
		print("[TestRoom] Lever connected to Door")

	# Setup player spawn
	if player and player_spawn:
		player.global_position = player_spawn.global_position
		GameManager.register_player(player, player_spawn.global_position)

	# Set camera bounds
	if player and player.player_camera:
		var bounds: Rect2 = Rect2(Vector2.ZERO, room_size)
		player.player_camera.set_room_bounds(bounds)
		print("[TestRoom] Camera bounds set to ", bounds)


func deactivate() -> void:
	"""Deactivates the room"""
	print("[TestRoom] Room deactivated")


func _on_lever_activated(_lever: Lever) -> void:
	"""Called when lever is activated"""
	if door:
		door.unlock()
		print("[TestRoom] Door unlocked by lever")
