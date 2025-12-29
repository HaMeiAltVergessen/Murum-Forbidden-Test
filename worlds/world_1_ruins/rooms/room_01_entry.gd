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
	# Door is configured directly in the scene file via target_scene export
	print("[Room01] Initialized")
