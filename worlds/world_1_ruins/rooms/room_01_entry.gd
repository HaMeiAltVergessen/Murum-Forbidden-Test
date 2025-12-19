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

@onready var door_to_room_02: Door = $Doors/DoorToRoom02
@onready var lever: Lever = $Environment/Lever

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Configure door
	if door_to_room_02:
		door_to_room_02.door_id = "room_01_door_to_room_02"
		door_to_room_02.is_transition_door = true
		door_to_room_02.target_room = "worlds/world_1_ruins/rooms/room_02_corridor"
		door_to_room_02.spawn_point = "FromRoom01"
		door_to_room_02.unlock_on_room_clear = false
		# Door starts locked, requires lever activation

	# Connect lever to door
	if lever and door_to_room_02:
		lever.lever_activated.connect(_on_lever_activated)

	print("[Room01] Initialized")

func _on_lever_activated(_lever: Lever) -> void:
	"""Called when lever is activated"""
	if door_to_room_02:
		door_to_room_02.unlock()
		print("[Room01] Door to Room02 unlocked")
