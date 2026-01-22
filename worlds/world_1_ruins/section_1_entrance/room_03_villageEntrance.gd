extends Node2D

## Room 03 - Combat Arena with Wave System

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "room_03_arena"
const WORLD_ID: String = "world_1_ruins"

# Enemy Scenes
const UNTOTE_SCENE = preload("res://enemies/untote.tscn")
const GEIST_SCENE = preload("res://enemies/world_1_ruins/geist.tscn")

# ============================================================================
# REFERENCES
# ============================================================================

@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var checkpoint: Checkpoint = $Checkpoint
@onready var door_from_room_02: Node = $Doors/DoorFromRoom02
@onready var door_to_room_04: Node = $Doors/DoorToRoom04

# Spawn Points
@onready var wave_spawn_1: Marker2D = $SpawnPoints/WaveSpawn1
@onready var wave_spawn_2: Marker2D = $SpawnPoints/WaveSpawn2
@onready var wave_spawn_3: Marker2D = $SpawnPoints/WaveSpawn3

# ============================================================================
# STATE
# ============================================================================

var is_cleared: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Configure doors
	_setup_doors()

	# Check if room already cleared
	var full_room_id = "%s/%s" % [WORLD_ID, ROOM_ID]
	is_cleared = WorldManager.is_room_cleared(full_room_id)

	if is_cleared:
		_on_room_already_cleared()
	else:
		_setup_arena()

	print("[Room03_VillageEntrance] Arena initialized (cleared: %s)" % is_cleared)

	# Activate room (setup player if transitioning from door - COMMIT 018)
	call_deferred("_activate")

func _setup_doors() -> void:
	"""Configures door properties"""
	# Doors are configured directly in scene files via target_scene export
	pass

func _setup_arena() -> void:
	"""Sets up arena for first playthrough"""

	# Configure wave spawner
	_configure_waves()

	# Disable checkpoint until clear
	if checkpoint:
		checkpoint.visible = false
		checkpoint.monitoring = false

	# Hide exit door until arena complete
	if door_to_room_04:
		door_to_room_04.visible = false
		door_to_room_04.monitoring = false
		door_to_room_04.modulate.a = 0.0

	# Connect wave events
	wave_spawner.all_waves_completed.connect(_on_all_waves_completed)

	# Add to group
	wave_spawner.add_to_group("wave_spawners")

func _on_room_already_cleared() -> void:
	"""Called if room was previously cleared"""

	# Disable wave spawner
	if wave_spawner:
		wave_spawner.queue_free()

	# Enable checkpoint
	if checkpoint:
		checkpoint.visible = true
		checkpoint.is_activated = true
		checkpoint._update_visual()

	# Make exit door visible/accessible
	if door_to_room_04:
		door_to_room_04.visible = true
		door_to_room_04.monitoring = true
		door_to_room_04.modulate.a = 1.0

	# Ensure GameManager knows arena is cleared
	GameManager.world1_arena_cleared = true

# ============================================================================
# WAVE CONFIGURATION
# ============================================================================

func _configure_waves() -> void:
	"""Configures all wave compositions"""

	# Wave 1: 2× Untote (Warm-up)
	var wave1 = WaveSpawner.Wave.new()
	wave1.delay_before = 1.0
	wave1.delay_after = 2.0
	wave1.add_enemy(UNTOTE_SCENE, wave_spawn_1.global_position)
	wave1.add_enemy(UNTOTE_SCENE, wave_spawn_2.global_position)
	wave_spawner.add_wave(wave1)

	# Wave 2: 1× Untote + 2× Geist (Mixed)
	var wave2 = WaveSpawner.Wave.new()
	wave2.delay_before = 1.5
	wave2.delay_after = 2.5
	wave2.add_enemy(UNTOTE_SCENE, wave_spawn_1.global_position)
	wave2.add_enemy(GEIST_SCENE, wave_spawn_2.global_position)
	wave2.add_enemy(GEIST_SCENE, wave_spawn_3.global_position)
	wave_spawner.add_wave(wave2)

	# Wave 3: 3× Untote + 1× Geist (Overwhelming)
	var wave3 = WaveSpawner.Wave.new()
	wave3.delay_before = 2.0
	wave3.delay_after = 3.0

	# Calculate center position for Geist
	var geist_pos = Vector2(
		(wave_spawn_1.global_position.x + wave_spawn_2.global_position.x) / 2,
		wave_spawn_1.global_position.y
	)

	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_1.global_position)
	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_2.global_position)
	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_3.global_position)
	wave3.add_enemy(GEIST_SCENE, geist_pos)
	wave_spawner.add_wave(wave3)

	print("[Room03_VillageEntrance] Configured 3 waves")
	print("[Room03_VillageEntrance] Wave 3 positions: ", wave_spawn_1.global_position, ", ", wave_spawn_2.global_position, ", ", wave_spawn_3.global_position, ", Geist: ", geist_pos)

# ============================================================================
# ARENA COMPLETION
# ============================================================================

func _on_all_waves_completed() -> void:
	"""Called when all waves are cleared"""

	print("[Room03_VillageEntrance] Arena completed!")

	# Mark cleared
	var full_room_id = "%s/%s" % [WORLD_ID, ROOM_ID]
	WorldManager.mark_room_cleared(full_room_id)
	is_cleared = true

	# Mark arena cleared in GameManager
	GameManager.world1_arena_cleared = true
	GameManager.arena_cleared.emit()

	# Unlock exit door to hub
	_unlock_exit_door()

	# Enable checkpoint
	if checkpoint:
		await get_tree().create_timer(1.0).timeout
		_activate_checkpoint()

	# Play completion effects
	_play_arena_complete_effects()

func _unlock_exit_door() -> void:
	"""Unlocks exit door to Room 04 (Hub)"""

	if not door_to_room_04:
		push_warning("[Room03_VillageEntrance] Exit door not found!")
		return

	# Make door visible/active (if it was hidden)
	door_to_room_04.visible = true
	door_to_room_04.monitoring = true

	# Visual feedback
	var tween = create_tween()
	tween.tween_property(door_to_room_04, "modulate:a", 1.0, 0.5)

	# Notification
	EventBus.show_notification.emit("Exit to Hub Unlocked!", 3.0)

	# Audio
	if AudioManager:
		AudioManager.play_sfx("ui/door_unlock", 0.0)

	print("[Room03_VillageEntrance] Exit door to hub unlocked")

func _activate_checkpoint() -> void:
	"""Activates checkpoint after arena clear"""

	if not checkpoint:
		return

	# Make visible
	checkpoint.visible = true
	checkpoint.monitoring = true

	# Spawn effect
	var tween = create_tween()
	checkpoint.modulate.a = 0.0
	tween.tween_property(checkpoint, "modulate:a", 1.0, 0.5)

	# Notification
	EventBus.show_notification.emit("Checkpoint Unlocked", 2.0)

func _play_arena_complete_effects() -> void:
	"""Visual/audio effects for arena completion"""

	# Camera shake for arena completion
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.4)

	# Audio
	if AudioManager:
		AudioManager.play_sfx("ui/arena_complete", 0.0)

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
			print("[Room03_VillageEntrance] Player moved from root to scene")

			# Position player at door spawn position
			if GameManager.player_spawn_position != Vector2.ZERO:
				player.global_position = GameManager.player_spawn_position
				print("[Room03_VillageEntrance] Player spawned at door position: ", GameManager.player_spawn_position)
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
