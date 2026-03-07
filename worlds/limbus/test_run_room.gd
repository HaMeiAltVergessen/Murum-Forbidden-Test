extends Node2D
## Test Run Room - Minimal test room for run loop validation
## Contains: Ground, colored death zone, 1x Magicka pickup

const ROOM_ID: String = "test_run_room"
const WORLD_ID: String = "limbus"

@onready var spawn_point: Marker2D = $SpawnPoints/Default


func _ready() -> void:
	print("[TestRunRoom] Initialized")
	call_deferred("_activate")


func _activate() -> void:
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID

	# Spawn or reposition player
	if not GameManager.player or not is_instance_valid(GameManager.player):
		_spawn_new_player()
		return

	var player = GameManager.player
	if player.get_parent() != self:
		if player.get_parent():
			player.get_parent().remove_child(player)
		add_child(player)

	# Use GameManager spawn position if set (from door transition), else use default
	var pos = spawn_point.global_position
	if GameManager.player_spawn_position != Vector2.ZERO:
		pos = GameManager.player_spawn_position
		GameManager.player_spawn_position = Vector2.ZERO

	player.global_position = pos
	player.z_index = 100
	player.z_as_relative = false
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	print("[TestRunRoom] Player repositioned at ", pos)


func _spawn_new_player() -> void:
	var player_scene = preload("res://player/murum.tscn")
	var player = player_scene.instantiate()
	player.global_position = spawn_point.global_position
	add_child(player)
	if GameManager:
		GameManager.set_player(player)
	print("[TestRunRoom] Player spawned at ", spawn_point.global_position)
