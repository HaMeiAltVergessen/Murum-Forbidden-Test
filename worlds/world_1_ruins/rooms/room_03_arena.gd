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
@onready var door_from_room_02: Door = $Doors/DoorFromRoom02
@onready var door_to_room_04: Door = $Doors/DoorToRoom04

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

	print("[Room03] Arena initialized (cleared: %s)" % is_cleared)

func _setup_doors() -> void:
	"""Configures door properties"""

	# Door from Room 02 (entry)
	if door_from_room_02:
		door_from_room_02.door_id = "room_03_door_from_room_02"
		door_from_room_02.is_transition_door = true
		door_from_room_02.target_room = "room_02_corridor"
		door_from_room_02.spawn_point = "from_room_03"
		door_from_room_02.unlock_on_room_clear = false

	# Door to Room 04 (exit)
	if door_to_room_04:
		door_to_room_04.door_id = "room_03_door_to_room_04"
		door_to_room_04.is_transition_door = true
		door_to_room_04.target_room = "room_04_next"
		door_to_room_04.spawn_point = "from_room_03"
		door_to_room_04.unlock_on_room_clear = false

func _setup_arena() -> void:
	"""Sets up arena for first playthrough"""

	# Configure wave spawner
	_configure_waves()

	# Disable checkpoint until clear
	if checkpoint:
		checkpoint.visible = false
		checkpoint.monitoring = false

	# Lock exit door
	if door_to_room_04:
		door_to_room_04.lock()

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

	# Unlock exit door
	if door_to_room_04:
		door_to_room_04.unlock()

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
	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_1.global_position)
	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_2.global_position)
	wave3.add_enemy(UNTOTE_SCENE, wave_spawn_3.global_position)
	wave3.add_enemy(GEIST_SCENE, Vector2(
		(wave_spawn_1.global_position.x + wave_spawn_2.global_position.x) / 2,
		wave_spawn_1.global_position.y
	))
	wave_spawner.add_wave(wave3)

	print("[Room03] Configured 3 waves")

# ============================================================================
# ARENA COMPLETION
# ============================================================================

func _on_all_waves_completed() -> void:
	"""Called when all waves are cleared"""

	print("[Room03] Arena completed!")

	# Mark cleared
	var full_room_id = "%s/%s" % [WORLD_ID, ROOM_ID]
	WorldManager.mark_room_cleared(full_room_id)
	is_cleared = true

	# Enable checkpoint
	if checkpoint:
		await get_tree().create_timer(1.0).timeout
		_activate_checkpoint()

	# Play completion effects
	_play_arena_complete_effects()

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

	# Screen flash
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").flash(Color(1.0, 0.8, 0.5, 0.6), 0.5)

	# Audio
	if AudioManager:
		AudioManager.play_sfx("ui/arena_complete", 0.0)
