extends Node2D
## Room 05 - Lythrun Boss Arena

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "room_05_boss_arena"
const WORLD_ID: String = "world_1_ruins"
const BOSS_SCENE_PATH: String = "res://bosses/lythrun/lythrun_boss.tscn"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player_spawn: Marker2D = $Spawns/PlayerSpawn
@onready var boss_spawn: Marker2D = $Spawns/BossSpawn
@onready var exit_door: Area2D = $Doors/ExitDoor if has_node("Doors/ExitDoor") else null
@onready var arena_boundary: Node2D = $ArenaBoundary if has_node("ArenaBoundary") else null

# ============================================================================
# STATE
# ============================================================================

var boss_instance: BaseBoss = null
var player: CharacterBody2D = null
var fight_started: bool = false
var fight_ended: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_arena()
	_spawn_player()

	# Intro sequence
	await get_tree().create_timer(1.0).timeout
	_play_intro_cutscene()


func _setup_arena() -> void:
	"""Sets up the arena environment"""

	# Lock exit door
	if exit_door and exit_door.has_method("lock_door"):
		exit_door.lock_door()

	# Set arena boundary visible (semi-transparent)
	if arena_boundary:
		arena_boundary.modulate = Color(1, 1, 1, 0.3)

	print("[Room05] Arena setup complete")


func _spawn_player() -> void:
	"""Spawns the player at the designated spawn point"""

	player = get_tree().get_first_node_in_group("player")

	if not player:
		print("[Room05] No player found in scene tree")
		return

	if player_spawn:
		player.global_position = player_spawn.global_position

	# Disable movement during intro
	if player.has_method("disable_movement"):
		player.disable_movement()

	var spawn_pos = player_spawn.global_position if player_spawn else Vector2.ZERO
	print("[Room05] Player spawned at: ", spawn_pos)


# ============================================================================
# INTRO CUTSCENE
# ============================================================================

func _play_intro_cutscene() -> void:
	"""Plays the boss intro cutscene"""

	print("[Room05] Starting intro cutscene")

	var active_camera = get_viewport().get_camera_2d()

	if active_camera and boss_spawn:
		# Zoom camera to boss spawn altar
		var tween = create_tween()
		tween.tween_property(active_camera, "global_position", boss_spawn.global_position, 1.5).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

	await get_tree().create_timer(0.5).timeout

	# Spawn boss
	_spawn_boss()

	await get_tree().create_timer(2.0).timeout

	# Return camera to player
	if active_camera and player:
		var tween = create_tween()
		tween.tween_property(active_camera, "global_position", player.global_position, 1.0).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

	await get_tree().create_timer(0.5).timeout

	# Start fight
	_start_fight()


func _spawn_boss() -> void:
	"""Spawns the boss at the designated spawn point"""

	if not ResourceLoader.exists(BOSS_SCENE_PATH):
		push_error("[Room05] Boss scene not found: " + BOSS_SCENE_PATH)
		return

	var boss_scene = load(BOSS_SCENE_PATH)
	boss_instance = boss_scene.instantiate()

	add_child(boss_instance)

	if boss_spawn:
		boss_instance.global_position = boss_spawn.global_position

	# Set player reference if boss has the method
	if boss_instance.has_method("set_player_target"):
		boss_instance.set_player_target(player)

	# Connect signals
	boss_instance.defeated.connect(_on_boss_defeated)
	boss_instance.phase_changed.connect(_on_boss_phase_changed)

	# Spawn VFX
	_spawn_boss_vfx()

	print("[Room05] Boss spawned")


func _spawn_boss_vfx() -> void:
	"""Spawns VFX when boss appears"""

	var vfx_path = "res://vfx/boss/lythrun_spawn.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Room05] Boss spawn VFX not found")
		return

	var vfx_scene = load(vfx_path)
	var vfx = vfx_scene.instantiate()

	if boss_spawn:
		boss_spawn.add_child(vfx)

	if vfx is GPUParticles2D:
		vfx.emitting = true

	# Play SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("lythrun_spawn")


# ============================================================================
# FIGHT MANAGEMENT
# ============================================================================

func _start_fight() -> void:
	"""Starts the boss fight"""

	fight_started = true

	# Enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()

	# Start boss fight (if not already started by boss_base)
	if boss_instance and boss_instance.has_method("start_fight"):
		if not boss_instance.is_active:
			boss_instance.start_fight()

	# Change music
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_boss_music"):
			audio_manager.play_boss_music("lythrun_theme")

	print("[Room05] Fight started!")


func _on_boss_defeated() -> void:
	"""Called when boss is defeated"""

	fight_ended = true

	# Unlock exit door
	if exit_door and exit_door.has_method("unlock_door"):
		exit_door.unlock_door()

	# Fade out arena boundary
	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate:a", 0.0, 2.0)

	# Set game flag
	GameManager.set_flag("world1_boss_defeated", true)

	print("[Room05] Boss defeated! Fight complete.")


func _on_boss_phase_changed(phase: int) -> void:
	"""Called when boss changes phase"""

	print("[Room05] Boss entered phase: ", phase)

	# Change arena atmosphere based on phase
	match phase:
		2:
			_intensify_arena_phase2()
		3:
			_intensify_arena_phase3()


func _intensify_arena_phase2() -> void:
	"""Changes arena atmosphere for phase 2"""

	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate", Color.ORANGE_RED, 1.0)

	# Play intensify SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("arena_intensify")


func _intensify_arena_phase3() -> void:
	"""Changes arena atmosphere for phase 3"""

	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate", Color.DARK_RED, 1.0)

	# Spawn hazards (placeholder)
	print("[Room05] Phase 3 arena hazards activated")


# ============================================================================
# UTILITY
# ============================================================================

func get_arena_bounds() -> Rect2:
	"""Returns the bounds of the arena for boss positioning"""

	# Circular arena with ~70m diameter (600x600 pixels)
	var center = global_position
	if boss_spawn:
		center = boss_spawn.global_position

	return Rect2(
		center - Vector2(300, 300),
		Vector2(600, 600)
	)
