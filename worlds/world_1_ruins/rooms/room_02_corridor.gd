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
@onready var door_to_room_01: Door = $Doors/DoorToRoom01
@onready var door_to_room_03: Door = $Doors/DoorToRoom03
@onready var lever: Lever = $Environment/Lever

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

	print("[Room02] Initialized (enemies: %d, cleared: %s)" % [
		initial_enemy_count,
		is_cleared
	])

func _setup_doors() -> void:
	"""Configures door properties"""

	# Door to Room 01 (entry)
	if door_to_room_01:
		door_to_room_01.door_id = "room_02_door_to_room_01"
		# Already configured in scene file

	# Door to Room 03 (exit) - locked by lever
	if door_to_room_03:
		door_to_room_03.door_id = "room_02_door_to_room_03"
		# Already configured in scene file with required_levers

func _setup_room() -> void:
	"""Sets up room for first playthrough"""

	# Lock exit door (unlocked by lever)
	if door_to_room_03:
		door_to_room_03.lock()

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

	print("[Room02] Enemy killed, remaining: %d" % remaining)

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

	print("[Room02] Room cleared!")

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
