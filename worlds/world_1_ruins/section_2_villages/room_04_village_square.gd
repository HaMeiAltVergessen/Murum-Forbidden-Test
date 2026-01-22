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

	print("[Room04_VillageSquare] Hub initialized")

	# Activate room (setup player if transitioning from door - COMMIT 018)
	call_deferred("_activate")

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

	print("[Room04_VillageSquare] Checkpoint configured")

func _on_checkpoint_activated() -> void:
	"""Called when checkpoint is activated"""

	# Checkpoint already saved via WorldManager.set_last_checkpoint()
	# Manual save would require slot_index parameter

	print("[Room04_VillageSquare] Checkpoint activated")

func _setup_merchant() -> void:
	"""Sets up merchant NPC"""

	if not merchant:
		print("[Room04_VillageSquare] No merchant in scene")
		return

	# Check if arena is cleared
	if GameManager.world1_arena_cleared:
		_show_merchant()
	else:
		merchant.visible = false
		print("[Room04_VillageSquare] Merchant hidden (arena not cleared)")

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

	print("[Room04_VillageSquare] Merchant unlocked")

func _on_arena_cleared() -> void:
	"""Called when arena is cleared (during this session)"""

	_show_merchant()
	_unlock_boss_door()  # NEW: Unlock boss door for testing

func _setup_boss_door() -> void:
	"""Sets up boss door (locked for now)"""

	if not door_to_boss:
		print("[Room04_VillageSquare] No boss door in scene")
		return

	# Check if boss door should be unlocked (testing: after arena clear)
	if GameManager.world1_arena_cleared:
		_unlock_boss_door()
	else:
		_lock_boss_door()

func _lock_boss_door() -> void:
	"""Locks the boss door"""

	if not door_to_boss:
		return

	if door_to_boss.has_method("lock_door"):
		door_to_boss.lock_door()
	else:
		# Fallback: disable interaction
		door_to_boss.monitoring = false

	print("[Room04_VillageSquare] Boss door locked")

func _unlock_boss_door() -> void:
	"""Unlocks the boss door (for testing purposes)"""

	if not door_to_boss:
		return

	# Check if already unlocked
	if door_to_boss.has_method("is_locked"):
		if not door_to_boss.is_locked():
			return  # Already unlocked

	# Unlock door
	if door_to_boss.has_method("unlock_door"):
		door_to_boss.unlock_door()
	else:
		# Fallback: enable interaction
		door_to_boss.monitoring = true

	# Spawn unlock VFX
	_spawn_door_unlock_vfx()

	# Notification
	EventBus.show_notification.emit("Boss Arena Unlocked!", 3.0)

	print("[Room04_VillageSquare] Boss door unlocked")

func _spawn_door_unlock_vfx() -> void:
	"""Spawns VFX when door unlocks"""

	if not door_to_boss:
		return

	# Check if VFX scene exists
	var vfx_path = "res://vfx/boss/boss_door_unlock.tscn"
	if not ResourceLoader.exists(vfx_path):
		print("[Room04_VillageSquare] Boss door unlock VFX not found")
		return

	var vfx_scene = load(vfx_path)
	var vfx = vfx_scene.instantiate()
	door_to_boss.add_child(vfx)

	# Start emission if it's a particle system
	if vfx.has_method("emit"):
		vfx.emit()
	elif vfx is GPUParticles2D:
		vfx.emitting = true

# ============================================================================
# ROOM ACTIVATION (COMMIT 018)
# ============================================================================

func _activate() -> void:
	"""Activates the room and sets up player if transitioning from door"""
	# Register room with GameManager
	if GameManager.has_method("register_room"):
		GameManager.register_room(self)

	# Set current room in WorldManager
	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID

	# If player was transferred from door, ensure proper setup
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player

		# Move player from root to this scene (if coming from door transition)
		if player.get_parent() == get_tree().root:
			get_tree().root.remove_child(player)
			add_child(player)
			print("[Room04_VillageSquare] Player moved from root to scene")

			# Position player at door spawn position
			if GameManager.player_spawn_position != Vector2.ZERO:
				player.global_position = GameManager.player_spawn_position
				print("[Room04_VillageSquare] Player spawned at door position: ", GameManager.player_spawn_position)
				# Reset spawn position
				GameManager.player_spawn_position = Vector2.ZERO

		# Ensure player setup
		if player.get_parent() == self:
			player.z_index = 100
			player.z_as_relative = false

			# Ensure player is on ground
			if player is CharacterBody2D:
				player.velocity = Vector2.ZERO

			# Clear camera bounds
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera.has_method("clear_room_bounds"):
				player_camera.clear_room_bounds()
