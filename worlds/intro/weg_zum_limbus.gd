extends Node2D
## Weg zum Limbus — Intro-Sequenz fuer neues Spiel
## Phase 1: Tutorial (Movement + Dodge) — keine Gegner
## Phase 2: Flucht — endlose Gegner spawnen hinter dem Spieler, Richtung Limbus-Portal
## Machtstoss verfuegbar, Stab NICHT (wird erst im Limbus manifestiert)

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "intro"
const WORLD_ID: String = "intro"

# Tutorial area bounds
const TUTORIAL_END_X: float = 1500.0   # X position where tutorial ends, chase begins
const LIMBUS_PORTAL_X: float = 5000.0  # X position of the Limbus portal (end)

# Enemy spawning
const SPAWN_INTERVAL: float = 2.5      # Seconds between spawn waves
const SPAWN_BEHIND_OFFSET: float = 600.0  # How far behind the player enemies spawn
const ENEMIES_PER_WAVE: int = 3
const FIRST_SPAWN_DELAY: float = 2.0   # Seconds after chase phase starts

# ============================================================================
# SCENES
# ============================================================================

const GEIST_SCENE = preload("res://enemies/world_1_ruins/geist.tscn")

# ============================================================================
# STATE
# ============================================================================

enum Phase { TUTORIAL, CHASE, REACHED_LIMBUS }

var current_phase: Phase = Phase.TUTORIAL
var spawn_timer: float = 0.0
var chase_started_time: float = 0.0
var player: CharacterBody2D = null

# Tutorial prompts
var shown_move_prompt: bool = false
var shown_dodge_prompt: bool = false
var shown_machtstoss_prompt: bool = false

# ============================================================================
# NODES
# ============================================================================

@onready var spawn_point: Marker2D = $SpawnPoints/Default
@onready var tutorial_prompt_label: Label = $UI/TutorialPrompt
@onready var limbus_portal: Area2D = $LimbusPortal

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[Intro] Weg zum Limbus initialized")

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

	print("[Intro] Player spawned without staff")


func _disable_staff() -> void:
	if not player:
		return

	# Hide StaffSprite
	var staff_sprite = player.get_node_or_null("StaffSprite")
	if staff_sprite:
		staff_sprite.visible = false

	# Disable StaffController (no throwing)
	var staff_controller = player.get_node_or_null("StaffController")
	if staff_controller:
		staff_controller.set_process(false)
		staff_controller.set_process_input(false)
		staff_controller.set_physics_process(false)

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
	spawn_timer = FIRST_SPAWN_DELAY  # Delay before first spawn

	_show_tutorial_prompt("Flieh zum Limbus! Machtstoss mit Q")
	shown_machtstoss_prompt = true

	print("[Intro] Chase phase started!")


func _process_chase(delta: float) -> void:
	chase_started_time += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		_spawn_enemy_wave()
		spawn_timer = SPAWN_INTERVAL


func _spawn_enemy_wave() -> void:
	if not player or not is_instance_valid(player):
		return

	for i in range(ENEMIES_PER_WAVE):
		var enemy = GEIST_SCENE.instantiate()

		# Spawn behind and slightly random Y
		var spawn_x = player.global_position.x - SPAWN_BEHIND_OFFSET - randf_range(0, 200)
		var spawn_y = player.global_position.y + randf_range(-150, 150)

		enemy.global_position = Vector2(spawn_x, spawn_y)
		add_child(enemy)

	print("[Intro] Spawned %d enemies behind player" % ENEMIES_PER_WAVE)

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
