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

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Configure door (lever connection happens automatically in door script)
	if door_to_room_02:
		door_to_room_02.door_id = "room_01_door_to_room_02"
		door_to_room_02.is_transition_door = true
		door_to_room_02.target_room = "worlds/world_1_ruins/rooms/room_02_corridor"
		door_to_room_02.spawn_point = "FromRoom01"
		door_to_room_02.unlock_on_room_clear = false
		# Door will connect to lever via required_levers export

	print("[Room01] Initialized")
