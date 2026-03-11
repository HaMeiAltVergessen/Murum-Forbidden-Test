extends Node2D
## Limbus - Central Hub for Roguelike Runs
## Contains: Run Door, Merchant (later), Seal Altar (later)

const ROOM_ID: String = "limbus"
const WORLD_ID: String = "limbus"

@onready var spawn_point: Marker2D = $SpawnPoints/Default

var has_spawned_content: bool = false


func _ready() -> void:
	print("[Limbus] Initialized")
	call_deferred("_activate")


func _activate() -> void:
	# Register room with GameManager
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	# Ensure RunManager is in IDLE state
	if RunManager:
		RunManager.current_state = RunManager.RunState.IDLE

	# Check if player exists, if not spawn a new one
	if not GameManager.player or not is_instance_valid(GameManager.player):
		print("[Limbus] No player found, spawning new player")
		_spawn_new_player()
		_ensure_staff_visible()
		_auto_save()
		return

	# Player transferred from run (death/victory) — reposition
	var player = GameManager.player
	if player.get_parent() != self:
		if player.get_parent():
			player.get_parent().remove_child(player)
		add_child(player)

	player.global_position = spawn_point.global_position
	player.z_index = 100
	player.z_as_relative = false
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	# Reset player health/mana
	if player.has_node("HealthComponent"):
		player.get_node("HealthComponent").reset_health()
	if player.has_node("ManaComponent"):
		player.get_node("ManaComponent").reset_mana()

	# Reset death state
	if player.has_method("respawn"):
		player.respawn(spawn_point.global_position)

	# Ensure staff is visible (manifested after intro)
	_ensure_staff_visible()

	print("[Limbus] Player repositioned at hub")

	# Auto-save when reaching Limbus
	_auto_save()


func _spawn_new_player() -> void:
	var player_scene = preload("res://player/murum.tscn")
	if not player_scene:
		push_error("[Limbus] Could not load player scene!")
		return

	var player = player_scene.instantiate()
	player.global_position = spawn_point.global_position
	add_child(player)

	if GameManager:
		GameManager.set_player(player)

	# Apply saved data if available
	if SaveManager and SaveManager.pending_player_data and not SaveManager.pending_player_data.is_empty():
		SaveManager.pending_player_data = {}

	print("[Limbus] Player spawned at ", spawn_point.global_position)


func _ensure_staff_visible() -> void:
	"""Ensures staff is visible and controller active (manifested after intro)"""
	var p = GameManager.player if GameManager else null
	if not p or not is_instance_valid(p):
		return

	var staff_sprite = p.get_node_or_null("StaffSprite")
	if staff_sprite:
		staff_sprite.visible = true

	var staff_controller = p.get_node_or_null("StaffController")
	if staff_controller:
		staff_controller.set_process(true)
		staff_controller.set_process_input(true)
		staff_controller.set_physics_process(true)


func _auto_save() -> void:
	"""Auto-saves to the active slot when entering Limbus"""
	if not SaveManager:
		return

	if SaveManager.current_slot < 1:
		print("[Limbus] No active slot, skipping auto-save")
		return

	# Set world/room for save data
	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID

	var success = SaveManager.save_current_game()
	if success:
		print("[Limbus] Auto-saved to slot %d" % SaveManager.current_slot)
	else:
		push_warning("[Limbus] Auto-save failed")
