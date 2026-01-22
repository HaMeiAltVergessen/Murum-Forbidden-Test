extends Node2D

## Room 02 - Corridor with mixed enemies and puzzle

# ============================================================================
# PROPERTIES
# ============================================================================

const ROOM_ID: String = "room_02_corridor"
const WORLD_ID: String = "world_1_ruins"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var enemies_node: Node2D = $Enemies
@onready var door_to_room_01: Node = $Doors/DoorToRoom01
@onready var door_to_room_03: Node = $Doors/DoorToRoom03
@onready var lever: Node = $Environment/Lever

# ============================================================================
# STATE
# ============================================================================

var initial_enemy_count: int = 0
var is_cleared: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Configure doors
	_setup_doors()

	# Count initial enemies
	initial_enemy_count = _get_enemy_count()

	# Check if room already cleared
	var full_room_id = "%s/%s" % [WORLD_ID, ROOM_ID]
	is_cleared = WorldManager.is_room_cleared(full_room_id)

	if is_cleared:
		_on_room_already_cleared()
	else:
		_setup_room()

	print("[Room02_Corridor] Initialized (enemies: %d, cleared: %s)" % [
		initial_enemy_count,
		is_cleared
	])

	# Activate room (setup player if transitioning from another scene)
	call_deferred("_activate")

func _setup_doors() -> void:
	"""Configures door properties"""
	# Doors are configured directly in scene files via target_scene export
	pass

func _setup_room() -> void:
	"""Sets up room for first playthrough"""
	# Door locking handled by lever connections in scene files

	# Connect enemy signals
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _on_room_already_cleared() -> void:
	"""Called if room was already cleared"""

	# Remove enemies
	if enemies_node:
		for enemy in enemies_node.get_children():
			enemy.queue_free()

	# Unlock door
	if door_to_room_03:
		door_to_room_03.unlock()

	# Activate lever
	if lever:
		lever.is_active = true
		lever._update_visual()

# ============================================================================
# ROOM CLEAR DETECTION
# ============================================================================

func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	"""Called when enemy is killed"""

	# Check if enemy was in this room
	if not enemy.get_parent() == enemies_node:
		return

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Check remaining enemies
	var remaining = _get_enemy_count()

	print("[Room02_Corridor] Enemy killed, remaining: %d" % remaining)

	if remaining <= 0:
		_on_room_cleared()

func _get_enemy_count() -> int:
	"""Returns current enemy count"""
	if not enemies_node:
		return 0

	var count = 0
	for child in enemies_node.get_children():
		if child.is_in_group("enemies"):
			count += 1

	return count

func _on_room_cleared() -> void:
	"""Called when all enemies defeated"""

	if is_cleared:
		return

	is_cleared = true

	print("[Room02_Corridor] Room cleared!")

	# Mark cleared in WorldManager
	var full_room_id = "%s/%s" % [WORLD_ID, ROOM_ID]
	WorldManager.mark_room_cleared(full_room_id)

	# Visual feedback
	_play_clear_effect()

	# Notification
	EventBus.show_notification.emit("Area Cleared", 2.0)

func _play_clear_effect() -> void:
	"""Visual effect for room clear"""
	# Screen flash
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").flash(Color(1.0, 1.0, 0.8, 0.5), 0.3)

	# Audio
	if AudioManager:
		AudioManager.play_sfx("ui/room_clear", 0.0)

# ============================================================================
# ROOM ACTIVATION
# ============================================================================

func _activate() -> void:
	"""Activates the room and sets up player if transitioning from another scene"""
	# Register room with GameManager
	if GameManager.has_method("register_room"):
		GameManager.register_room(self)

	# Set current room in WorldManager (COMMIT 018)
	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID

	# If player was transferred from another scene, ensure proper setup
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player

		# Move player from root to this scene (if coming from door transition)
		if player.get_parent() == get_tree().root:
			get_tree().root.remove_child(player)
			add_child(player)
			print("[Room02_Corridor] Player moved from root to scene")

			# Position player at door spawn position (COMMIT 018: Fix door spawning)
			if GameManager.player_spawn_position != Vector2.ZERO:
				player.global_position = GameManager.player_spawn_position
				print("[Room02_Corridor] Player spawned at door position: ", GameManager.player_spawn_position)
				# Reset spawn position
				GameManager.player_spawn_position = Vector2.ZERO

		# Ensure player is in this scene
		if player.get_parent() == self:
			print("[Room02_Corridor] Player setup in scene")
			player.z_index = 100
			player.z_as_relative = false

			# Ensure player is on ground (not floating or falling through)
			if player is CharacterBody2D:
				player.velocity = Vector2.ZERO

			# Clear camera bounds for free following
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera.has_method("clear_room_bounds"):
				player_camera.clear_room_bounds()
				print("[Room02_Corridor] Camera limits cleared")
