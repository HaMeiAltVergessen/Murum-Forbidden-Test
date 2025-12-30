extends CharacterBody2D
## Base Boss Framework - All bosses inherit from this
class_name BaseBoss

# ============ SIGNALS ============
signal health_changed(current_hp: float, max_hp: float)
signal phase_changed(new_phase: int)
signal defeated
signal fight_started

# ============ COMPONENTS (Auto-found) ============
@onready var health_component: HealthComponentGeneric = $HealthComponent
@onready var phase_manager: PhaseManager = $Components/PhaseManager
@onready var attack_manager: AttackPatternManager = $Components/AttackPatternManager
@onready var camera_controller: BossCameraController = $Components/BossCameraController
@onready var victory_sequence: VictorySequence = $Components/VictorySequence
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: BossHealthBar = $BossHealthBar

# ============ BOSS STATS (Configured per boss) ============
@export_group("Boss Stats")
@export var boss_name: String = "Boss"
@export var max_health: float = 1000.0
@export var movement_speed: float = 100.0

# ============ ATTACK PATTERNS (Configured per boss) ============
@export_group("Attack Patterns")
@export var phase_1_pattern: Array[String] = []
@export var phase_2_pattern: Array[String] = []
@export var phase_3_pattern: Array[String] = []

# ============ REWARDS ============
@export_group("Rewards")
@export var gold_reward: int = 500
@export var unlock_flag: String = ""

# ============ STATE ============
var is_invulnerable: bool = false
var is_defeated: bool = false
var is_active: bool = false


func _ready() -> void:
	# Set boss reference for all components
	_setup_component_references()

	setup_boss()
	connect_signals()

	# Don't auto-start fight - let the room control the timing
	# start_fight() will be called by room_05_boss_arena.gd


func _setup_component_references() -> void:
	"""Sets up boss references for all components that need it"""
	if phase_manager and "boss" in phase_manager:
		phase_manager.boss = self
	if attack_manager and "boss" in attack_manager:
		attack_manager.boss = self
	if camera_controller and "boss" in camera_controller:
		camera_controller.boss = self


func _physics_process(delta: float) -> void:
	"""Applies gravity and basic physics"""
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += 980.0 * delta  # Gravity

	# Apply movement
	move_and_slide()


func setup_boss() -> void:
	"""Sets up boss components with initial values"""
	# Setup health
	if health_component:
		health_component.max_hp = max_health
		health_component.current_hp = max_health

	# Setup health bar
	if health_bar:
		health_bar.setup(boss_name, max_health)

	# Setup victory sequence
	if victory_sequence:
		victory_sequence.gold_reward = gold_reward
		victory_sequence.unlock_flag = unlock_flag

	print("[BaseBoss] Boss setup complete: ", boss_name)


func connect_signals() -> void:
	"""Connects all component signals"""
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_defeated)
		health_component.invulnerability_changed.connect(_on_invulnerability_changed)

	if phase_manager:
		phase_manager.phase_changed.connect(_on_phase_changed)
		phase_manager.phase_transition_started.connect(_on_phase_transition_started)

	if attack_manager:
		attack_manager.attack_started.connect(_on_attack_started)


func start_fight() -> void:
	"""Starts the boss fight"""
	is_active = true
	fight_started.emit()

	# Show health bar
	if health_bar:
		health_bar.show_bar()

	# Activate camera
	if camera_controller:
		camera_controller.activate()

	# Play intro animation (non-blocking)
	play_intro_animation()

	# Set initial attack pattern immediately (boss is now attackable)
	if attack_manager:
		attack_manager.set_pattern(phase_1_pattern)
		attack_manager.activate()

	print("[BaseBoss] Fight started: ", boss_name)


func play_intro_animation() -> void:
	"""Plays boss intro animation (override in child)"""
	# Default: just play idle
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


# ============ HEALTH MANAGEMENT ============
func _on_health_changed(current_hp: float, max_hp: float) -> void:
	"""Called when boss takes damage"""
	health_changed.emit(current_hp, max_hp)

	if health_bar:
		health_bar.update_health(current_hp, max_hp)

	# Hit feedback
	if current_hp > 0:
		play_hit_feedback()


func play_hit_feedback() -> void:
	"""Visual feedback when boss is hit"""
	if not sprite:
		return

	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

	# Camera shake
	if camera_controller:
		camera_controller.shake(3.0, 0.2)


func _on_invulnerability_changed(invulnerable: bool) -> void:
	"""Called when invulnerability state changes"""
	is_invulnerable = invulnerable


# ============ PHASE MANAGEMENT ============
func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	"""Called when boss enters a new phase"""
	phase_changed.emit(new_phase)

	# Update UI
	if health_bar:
		health_bar.update_phase(new_phase)

	# Change attack pattern
	if attack_manager:
		match new_phase:
			2:
				attack_manager.set_pattern(phase_2_pattern)
			3:
				attack_manager.set_pattern(phase_3_pattern)

	print("[BaseBoss] Phase changed: %d -> %d" % [old_phase, new_phase])


func _on_phase_transition_started(new_phase: int) -> void:
	"""Called when phase transition starts"""
	# Stop attacks during transition
	if attack_manager:
		attack_manager.interrupt_attack()


func play_phase_transition(new_phase: int) -> void:
	"""Plays phase transition animation (override in child)"""
	# Default: brief pause
	await get_tree().create_timer(1.0).timeout


# ============ ATTACK MANAGEMENT ============
func _on_attack_started(attack_name: String) -> void:
	"""Called when an attack starts"""
	# Child classes can override this
	pass


# ============ DEFEAT/VICTORY ============
func _on_defeated() -> void:
	"""Called when boss health reaches 0"""
	if is_defeated:
		return

	is_defeated = true
	defeated.emit()

	# Stop all attacks
	if attack_manager:
		attack_manager.deactivate()

	# Hide health bar
	if health_bar:
		health_bar.hide_bar()

	# Start victory sequence
	if victory_sequence:
		victory_sequence.start()

	print("[BaseBoss] Boss defeated: ", boss_name)


# ============ ABSTRACT METHODS (Override in child classes) ============
func execute_attack(attack_name: String) -> void:
	"""Executes a specific attack (MUST be overridden by child)"""
	push_error("[BaseBoss] execute_attack() must be overridden by child class: " + boss_name)
	await get_tree().create_timer(1.0).timeout


func play_death_animation() -> void:
	"""Plays death animation (override in child)"""
	# Default: fade out
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		await tween.finished


# ============ UTILITY METHODS ============
func set_invulnerable(value: bool) -> void:
	"""Sets invulnerability state"""
	if health_component:
		health_component.set_invulnerable(value)


func get_player() -> CharacterBody2D:
	"""Gets the player node"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func face_player() -> void:
	"""Makes boss face the player"""
	var player = get_player()
	if player and sprite:
		sprite.flip_h = player.global_position.x < global_position.x
