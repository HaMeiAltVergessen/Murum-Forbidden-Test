extends Node2D

## Room 04 - Hub/Checkpoint Area
## Safe zone with checkpoint and merchant NPC

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "room_04_hub"
const WORLD_ID: String = "world_1_ruins"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var checkpoint: Checkpoint = $Objects/Checkpoint
@onready var merchant: Node2D = $NPCs/Merchant if has_node("NPCs/Merchant") else null
@onready var door_to_arena: Node = $Doors/DoorToArena
@onready var door_to_boss: Node = $Doors/DoorToBoss if has_node("Doors/DoorToBoss") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_checkpoint()
	_setup_merchant()
	_setup_boss_door()

	# Connect to arena cleared signal
	GameManager.arena_cleared.connect(_on_arena_cleared)

	print("[Room04] Hub initialized")

func _setup_checkpoint() -> void:
	"""Sets up checkpoint (bonfire)"""

	if not checkpoint:
		return

	# Connect activation signal
	if checkpoint.has_signal("activated"):
		checkpoint.activated.connect(_on_checkpoint_activated)

	# Check if this is the active checkpoint
	var checkpoint_id = "%s/%s/Checkpoint" % [WORLD_ID, ROOM_ID]
	if WorldManager.last_checkpoint == checkpoint_id:
		checkpoint.is_activated = true
		checkpoint._update_visual()

	print("[Room04] Checkpoint configured")

func _on_checkpoint_activated() -> void:
	"""Called when checkpoint is activated"""

	# Save game
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()

	print("[Room04] Checkpoint activated and game saved")

func _setup_merchant() -> void:
	"""Sets up merchant NPC"""

	if not merchant:
		print("[Room04] No merchant in scene")
		return

	# Check if arena is cleared
	if GameManager.world1_arena_cleared:
		_show_merchant()
	else:
		merchant.visible = false
		print("[Room04] Merchant hidden (arena not cleared)")

func _show_merchant() -> void:
	"""Shows and activates merchant"""

	if not merchant:
		return

	if merchant.visible:
		return  # Already visible

	merchant.visible = true

	# Play appear animation if method exists
	if merchant.has_method("play_appear_animation"):
		merchant.play_appear_animation()

	# Notification
	EventBus.show_notification.emit("Merchant Available!", 3.0)

	print("[Room04] Merchant unlocked")

func _on_arena_cleared() -> void:
	"""Called when arena is cleared (during this session)"""

	_show_merchant()

func _setup_boss_door() -> void:
	"""Sets up boss door (locked for now)"""

	if not door_to_boss:
		return

	# Lock boss door (will be unlocked in later content)
	door_to_boss.monitoring = false

	# Add visual indication (if door has label)
	if door_to_boss.has_node("PromptLabel"):
		var label = door_to_boss.get_node("PromptLabel")
		label.text = "Sealed by ancient magic"

	print("[Room04] Boss door locked")
