extends Node2D
## Weg zum Limbus — Intro-Sequenz fuer neues Spiel
## Phase 1: Tutorial (Movement + Dodge) — keine Gegner
## Phase 2: Stab erscheint, fliegt zum Limbus-Portal via Path2D
##          Endlose Gegnerhorden spawnen und verfolgen den Spieler — FLIEHEN!
## Machtstoss verfuegbar, Stab NICHT (wird erst im Limbus manifestiert)

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "intro"
const WORLD_ID: String = "intro"

# Tutorial area bounds
const TUTORIAL_END_X: float = 1500.0   # X position where tutorial ends, chase begins

# Enemy spawning
const SPAWN_INTERVAL_START: float = 2.5   # Initial seconds between waves
const SPAWN_INTERVAL_MIN: float = 0.8     # Fastest spawn rate (ramps up over time)
const SPAWN_RAMP_RATE: float = 0.05       # Interval decreases per wave
const SPAWN_BEHIND_OFFSET: float = 600.0  # How far behind the player enemies spawn
const SPAWN_SIDE_OFFSET: float = 400.0    # Also spawn from sides
const ENEMIES_PER_WAVE_START: int = 3
const ENEMIES_PER_WAVE_MAX: int = 8
const FIRST_SPAWN_DELAY: float = 1.5      # Seconds after chase phase starts

# Stab
const STAB_SPAWN_OFFSET: Vector2 = Vector2(0, -100)  # Appears above player
const STAB_FLOAT_HEIGHT: float = -80.0   # Floats above ground
const STAB_PATH_SPEED: float = 120.0     # Pixels per second along path

# ============================================================================
# ENEMY SCENES — all worlds, no bosses
# ============================================================================

var ENEMY_SCENES: Array[PackedScene] = []

func _load_enemy_scenes() -> void:
	var paths: Array[String] = [
		# World 1
		"res://enemies/world_1_ruins/geist.tscn",
		"res://enemies/world_1_ruins/hermit.tscn",
		"res://enemies/world_1_ruins/glimmerseed.tscn",
		"res://enemies/world_1_ruins/guardian_statue.tscn",
		"res://enemies/world_1_ruins/corpse_trap.tscn",
		# Placeholder / Other worlds
		"res://enemies/placeholder/ashworm_small.tscn",
		"res://enemies/placeholder/ashworm_medium.tscn",
		"res://enemies/placeholder/dark_fantasy.tscn",
		"res://enemies/placeholder/monster_creature.tscn",
		"res://enemies/placeholder/nightborne.tscn",
		"res://enemies/placeholder/fire_worm.tscn",
		"res://enemies/placeholder/frost_guardian.tscn",
		"res://enemies/placeholder/golem.tscn",
		"res://enemies/placeholder/bringer_of_death.tscn",
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var scene = load(path) as PackedScene
			if scene:
				ENEMY_SCENES.append(scene)
	print("[Intro] Loaded %d enemy types" % ENEMY_SCENES.size())

# ============================================================================
# STATE
# ============================================================================

enum Phase { TUTORIAL, CHASE, REACHED_LIMBUS }

var current_phase: Phase = Phase.TUTORIAL
var spawn_timer: float = 0.0
var spawn_interval: float = SPAWN_INTERVAL_START
var enemies_per_wave: int = ENEMIES_PER_WAVE_START
var waves_spawned: int = 0
var chase_started_time: float = 0.0
var player: CharacterBody2D = null

# Tutorial prompts
var shown_move_prompt: bool = false
var shown_dodge_prompt: bool = false
var shown_machtstoss_prompt: bool = false

# Stab
var stab_sprite: Sprite2D = null
var stab_path_follow: PathFollow2D = null
var stab_spawned: bool = false
var stab_reached_end: bool = false

# ============================================================================
# NODES
# ============================================================================

@onready var spawn_point: Marker2D = $SpawnPoints/Default
@onready var tutorial_prompt_label: Label = $UI/TutorialPrompt
@onready var limbus_portal: Area2D = $LimbusPortal
@onready var stab_path: Path2D = $StabPath

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[Intro] Weg zum Limbus initialized")

	_load_enemy_scenes()

	# Register with GameManager
	if GameManager:
		GameManager.register_room(self)
		GameManager.current_state = GameManager.GameState.PLAYING

	# Spawn player without staff
	_spawn_player()

	# Setup portal detection
	if limbus_portal:
		limbus_portal.body_entered.connect(_on_portal_entered)

	# Start with tutorial
	current_phase = Phase.TUTORIAL
	_show_tutorial_prompt("Bewege dich mit WASD")
	shown_move_prompt = true


func _spawn_player() -> void:
	var player_scene = preload("res://player/murum.tscn")
	player = player_scene.instantiate()
	player.global_position = spawn_point.global_position
	add_child(player)

	if GameManager:
		GameManager.set_player(player)

	# Hide staff — will be manifested in Limbus
	await get_tree().process_frame
	_disable_staff()
	_disable_combat_for_intro()

	print("[Intro] Player spawned without staff (combat restricted)")


func _disable_staff() -> void:
	if not player:
		return

	# Hide StaffSprite
	var staff_sprite_node = player.get_node_or_null("StaffSprite")
	if staff_sprite_node:
		staff_sprite_node.visible = false

	# Disable StaffController (no throwing)
	var staff_controller = player.get_node_or_null("StaffController")
	if staff_controller:
		staff_controller.set_process(false)
		staff_controller.set_process_input(false)
		staff_controller.set_physics_process(false)


func _disable_combat_for_intro() -> void:
	"""Disables all combat except Machtstoss, dash, dodge, and jump"""
	if not player:
		return

	# Disable normal attacks/combos — block _input so dodge-complete can't re-enable
	# Machtstoss is a child of CombatSystem but handles its own _input independently
	var combat = player.get_node_or_null("CombatSystem")
	if combat:
		if combat.has_method("set_combat_enabled"):
			combat.set_combat_enabled(false)
		combat.set_process_input(false)

		# Disable CombatSystem sub-systems (except Machtstoss)
		for child in combat.get_children():
			if child is Machtstoss:
				continue  # Keep Machtstoss active
			if child.has_method("set_process"):
				child.set_process(false)
				child.set_process_input(false)
				child.set_physics_process(false)

	# Disable combat systems on player root (not under CombatSystem)
	var systems_to_disable: Array[String] = [
		"LauncherSystem",
		"AirComboSystem",
		"Wolkenbruch",
		"EchoVonUrgathon",
		"LuftgottSystem",
		"EndeSchwerkraft",
	]
	for system_name in systems_to_disable:
		var node = player.get_node_or_null(system_name)
		if node:
			node.set_process(false)
			node.set_process_input(false)
			node.set_physics_process(false)

	print("[Intro] Combat disabled (Machtstoss/Dash/Dodge/Jump still active)")

# ============================================================================
# GAME LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	match current_phase:
		Phase.TUTORIAL:
			_process_tutorial()
		Phase.CHASE:
			_process_chase(delta)
		Phase.REACHED_LIMBUS:
			pass


func _process_tutorial() -> void:
	if not player:
		return

	# Show dodge prompt after player moves a bit
	if not shown_dodge_prompt and player.global_position.x > spawn_point.global_position.x + 300:
		_show_tutorial_prompt("Ausweichen mit Leertaste")
		shown_dodge_prompt = true

	# Transition to chase phase
	if player.global_position.x >= TUTORIAL_END_X:
		_start_chase_phase()


func _start_chase_phase() -> void:
	current_phase = Phase.CHASE
	chase_started_time = 0.0
	spawn_timer = FIRST_SPAWN_DELAY
	spawn_interval = SPAWN_INTERVAL_START
	enemies_per_wave = ENEMIES_PER_WAVE_START
	waves_spawned = 0

	_show_tutorial_prompt("FLIEH ZUM LIMBUS!")
	shown_machtstoss_prompt = true

	# Spawn the Stab
	_spawn_stab()

	print("[Intro] Chase phase started! Stab leads the way!")


func _process_chase(delta: float) -> void:
	chase_started_time += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		_spawn_enemy_wave()
		spawn_timer = spawn_interval

		# Ramp up difficulty
		waves_spawned += 1
		spawn_interval = max(SPAWN_INTERVAL_MIN, spawn_interval - SPAWN_RAMP_RATE)
		if waves_spawned % 3 == 0 and enemies_per_wave < ENEMIES_PER_WAVE_MAX:
			enemies_per_wave += 1

	# Move stab along path
	_update_stab(delta)

# ============================================================================
# STAB (Staff Guide)
# ============================================================================

func _spawn_stab() -> void:
	if stab_spawned or not stab_path:
		return

	stab_spawned = true

	# Create PathFollow2D on the path
	stab_path_follow = PathFollow2D.new()
	stab_path_follow.rotates = false
	stab_path_follow.loop = false
	stab_path_follow.progress = 0.0
	stab_path.add_child(stab_path_follow)

	# Create Stab sprite
	stab_sprite = Sprite2D.new()
	var stab_texture = load("res://Assets/AIPlaceholder/MurumStab.png")
	if stab_texture:
		stab_sprite.texture = stab_texture
	else:
		# Fallback placeholder
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(16, 64)
		stab_sprite.texture = placeholder
	stab_sprite.scale = Vector2(0.5, 0.5)
	stab_path_follow.add_child(stab_sprite)

	# Spawn VFX: flash in
	stab_sprite.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(stab_sprite, "modulate:a", 1.0, 0.5)

	# Glow effect
	var glow_tween = create_tween().set_loops()
	glow_tween.tween_property(stab_sprite, "modulate", Color(1.2, 1.0, 0.8, 1.0), 0.8)
	glow_tween.tween_property(stab_sprite, "modulate", Color(1.0, 0.8, 1.2, 1.0), 0.8)

	print("[Intro] Stab spawned, following path to Limbus")


func _update_stab(delta: float) -> void:
	if not stab_path_follow or stab_reached_end:
		return

	# Move along path
	stab_path_follow.progress += STAB_PATH_SPEED * delta

	# Check if reached end
	if stab_path_follow.progress_ratio >= 1.0:
		stab_reached_end = true
		print("[Intro] Stab reached Limbus portal")

		# Pulse at destination
		if stab_sprite:
			var pulse = create_tween().set_loops()
			pulse.tween_property(stab_sprite, "scale", Vector2(0.6, 0.6), 0.4)
			pulse.tween_property(stab_sprite, "scale", Vector2(0.45, 0.45), 0.4)

# ============================================================================
# ENEMY SPAWNING
# ============================================================================

func _spawn_enemy_wave() -> void:
	if not player or not is_instance_valid(player):
		return

	if ENEMY_SCENES.is_empty():
		return

	for i in range(enemies_per_wave):
		var scene = ENEMY_SCENES.pick_random()
		var enemy = scene.instantiate()

		# Randomize spawn position: behind, left, right (never ahead)
		var spawn_pos: Vector2
		var roll = randf()
		if roll < 0.6:
			# Behind player (most common)
			spawn_pos.x = player.global_position.x - SPAWN_BEHIND_OFFSET - randf_range(0, 300)
			spawn_pos.y = player.global_position.y + randf_range(-200, 200)
		elif roll < 0.8:
			# Left side
			spawn_pos.x = player.global_position.x - randf_range(100, 400)
			spawn_pos.y = player.global_position.y - SPAWN_SIDE_OFFSET - randf_range(0, 150)
		else:
			# Right side
			spawn_pos.x = player.global_position.x - randf_range(100, 400)
			spawn_pos.y = player.global_position.y + SPAWN_SIDE_OFFSET + randf_range(0, 150)

		enemy.global_position = spawn_pos
		add_child(enemy)

		# Force enemy to chase player immediately (override detection range)
		if "target_player" in enemy:
			enemy.target_player = player
		if "detection_range" in enemy:
			enemy.detection_range = 9999.0

	if waves_spawned % 5 == 0:
		print("[Intro] Wave %d: %d enemies (interval: %.1fs)" % [waves_spawned, enemies_per_wave, spawn_interval])

# ============================================================================
# PORTAL / FINISH
# ============================================================================

func _on_portal_entered(body: Node2D) -> void:
	if not (body is Murum):
		return

	if current_phase == Phase.REACHED_LIMBUS:
		return

	current_phase = Phase.REACHED_LIMBUS
	print("[Intro] Player reached the Limbus portal!")

	_hide_tutorial_prompt()

	# Fade out stab
	if stab_sprite:
		var tween = create_tween()
		tween.tween_property(stab_sprite, "modulate:a", 0.0, 0.5)

	# Transition to Limbus
	await get_tree().create_timer(0.5).timeout
	_go_to_limbus()


func _go_to_limbus() -> void:
	# Set WorldManager state
	if WorldManager:
		WorldManager.current_world = "limbus"
		WorldManager.current_room = "limbus"

	# Transition to Limbus — first save happens there
	get_tree().change_scene_to_file("res://worlds/limbus/limbus.tscn")

# ============================================================================
# TUTORIAL UI
# ============================================================================

func _show_tutorial_prompt(text: String) -> void:
	if tutorial_prompt_label:
		tutorial_prompt_label.text = text
		tutorial_prompt_label.visible = true

		# Auto-hide after 4 seconds
		var timer = get_tree().create_timer(4.0)
		timer.timeout.connect(func():
			if tutorial_prompt_label and tutorial_prompt_label.text == text:
				tutorial_prompt_label.visible = false
		)


func _hide_tutorial_prompt() -> void:
	if tutorial_prompt_label:
		tutorial_prompt_label.visible = false
