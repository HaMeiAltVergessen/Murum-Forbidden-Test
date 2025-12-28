extends CharacterBody2D
## Murum - The Player Character
class_name Murum

# ============ COMPONENT REFERENCES ============
@onready var movement_controller: MovementController = $MovementController
@onready var combat_system: CombatSystem = $CombatSystem
@onready var health_component: HealthComponent = $HealthComponent
@onready var mana_component: ManaComponent = $ManaComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var player_camera: PlayerCamera = $PlayerCamera
@onready var dodge_roll_system: DodgeRollSystem = $DodgeRollSystem

# ============ ABILITIES ============
var urgathon_will: Node = null
var buff_manager: BuffManager = null

# ============ RELIC BONUSES ============
var relic_damage_bonus: float = 0.0
var relic_attack_speed_bonus: float = 0.0
var relic_parry_window_bonus: float = 0.0

# ============ STATE ============
var is_dead: bool = false


func _ready() -> void:
	# Initialize abilities
	_initialize_abilities()

	# Initialize BuffManager
	_initialize_buff_manager()

	# Connect component signals
	_connect_signals()

	# Register with GameManager
	_register_with_game_manager()

	print("[Murum] Player initialized")


func _initialize_abilities() -> void:
	"""Initializes special abilities that need to be added dynamically"""
	# Create Urgathon's Will
	var urgathon_script = load("res://player/abilities/urgathon_will.gd")
	if urgathon_script:
		urgathon_will = Node.new()
		urgathon_will.set_script(urgathon_script)
		urgathon_will.name = "UrgathonWill"
		add_child(urgathon_will)
		print("[Murum] UrgathonWill ability added")
	else:
		print("[Murum] ERROR: Could not load UrgathonWill script!")


func _initialize_buff_manager() -> void:
	"""Initializes BuffManager for consumable effects"""
	var buff_manager_script = load("res://player/buff_manager.gd")
	if buff_manager_script:
		buff_manager = BuffManager.new()
		buff_manager.name = "BuffManager"
		add_child(buff_manager)
		print("[Murum] BuffManager added")
	else:
		print("[Murum] ERROR: Could not load BuffManager script!")


func _connect_signals() -> void:
	"""Connects all component signals"""
	# Health signals
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)

	# Mana signals
	if mana_component:
		mana_component.mana_changed.connect(_on_mana_changed)

	# Hurtbox signals
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Dodge signals
	if dodge_roll_system:
		dodge_roll_system.dodge_started.connect(_on_dodge_started)
		dodge_roll_system.dodge_completed.connect(_on_dodge_completed)

	# Relic signals
	if is_instance_valid(EventBus):
		EventBus.relic_equipped.connect(_on_relic_equipped)
		EventBus.relic_unequipped.connect(_on_relic_unequipped)


func _register_with_game_manager() -> void:
	"""Registers this player with the GameManager"""
	# Wait one frame to ensure spawn position is set
	await get_tree().process_frame
	GameManager.register_player(self, global_position)


# ============ SIGNAL HANDLERS ============
func _on_health_changed(new_health: int, max_health: int) -> void:
	"""Handles health changes"""
	EventBus.player_hp_changed.emit(new_health, max_health)


func _on_mana_changed(new_mana: int, max_mana: int) -> void:
	"""Handles mana changes"""
	EventBus.player_mana_changed.emit(new_mana, max_mana)


func _on_damage_taken(damage: int) -> void:
	"""Handles damage taken"""
	EventBus.player_damaged.emit(damage, self)
	AudioManager.play_sfx("player_hurt")

	# Camera shake
	if player_camera:
		player_camera.shake_light()

	# Visual feedback
	_flash_sprite()


func _on_damage_received(damage: int, knockback: Vector2, _hitstun: float) -> void:
	"""Handles damage from hurtbox"""
	# Apply knockback
	velocity = knockback

	print("[Murum] Took ", damage, " damage. Knockback: ", knockback)


func _on_health_depleted() -> void:
	"""Handles player death"""
	if is_dead:
		return

	is_dead = true

	# Disable controls
	set_physics_process(false)
	set_process_input(false)

	# Play death animation/sound
	AudioManager.play_sfx("player_hurt")  # Use hurt sound for now

	# Emit death signal
	EventBus.player_died.emit()

	print("[Murum] Player died")


func _on_dodge_started(_direction: Vector2) -> void:
	"""Handles dodge roll start - disables combat"""
	if combat_system:
		combat_system.set_combat_enabled(false)


func _on_dodge_completed() -> void:
	"""Handles dodge roll completion - re-enables combat"""
	if combat_system:
		combat_system.set_combat_enabled(true)


func _on_relic_equipped(_relic_id: String, stats: Dictionary) -> void:
	"""Handles relic being equipped - applies stat bonuses"""
	# Damage bonus
	if stats.has("damage_bonus"):
		relic_damage_bonus += stats["damage_bonus"]

	# Attack speed bonus
	if stats.has("attack_speed_bonus"):
		relic_attack_speed_bonus += stats["attack_speed_bonus"]

	# Parry window bonus
	if stats.has("parry_window_bonus"):
		relic_parry_window_bonus += stats["parry_window_bonus"]

	# Note: Other relic effects (like mana regen intervals, group damage bonuses, etc.)
	# should be handled by their respective systems that listen to the relic_equipped signal

	print("[Murum] Relic equipped - Damage bonus: ", relic_damage_bonus,
		  " Attack speed: ", relic_attack_speed_bonus)


func _on_relic_unequipped(_relic_id: String, stats: Dictionary) -> void:
	"""Handles relic being unequipped - removes stat bonuses"""
	# Damage bonus
	if stats.has("damage_bonus"):
		relic_damage_bonus -= stats["damage_bonus"]

	# Attack speed bonus
	if stats.has("attack_speed_bonus"):
		relic_attack_speed_bonus -= stats["attack_speed_bonus"]

	# Parry window bonus
	if stats.has("parry_window_bonus"):
		relic_parry_window_bonus -= stats["parry_window_bonus"]

	print("[Murum] Relic unequipped - Damage bonus: ", relic_damage_bonus,
		  " Attack speed: ", relic_attack_speed_bonus)


# ============ VISUAL FEEDBACK ============
func _flash_sprite() -> void:
	"""Creates a white flash effect on damage"""
	if not sprite:
		return

	# Simple modulation flash
	var original_modulate: Color = sprite.modulate

	# Flash white
	sprite.modulate = Color(2, 2, 2, 1)

	# Tween back to normal
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)


# ============ PUBLIC METHODS ============
func respawn(spawn_position: Vector2) -> void:
	"""Respawns the player at the given position"""
	global_position = spawn_position
	is_dead = false

	# Re-enable controls
	set_physics_process(true)
	set_process_input(true)

	print("[Murum] Player respawned at ", spawn_position)


func get_total_damage_multiplier() -> float:
	"""Returns total damage multiplier from relics and buffs"""
	var total = 1.0 + relic_damage_bonus
	if buff_manager:
		total += buff_manager.get_damage_bonus()
	return total


func get_total_attack_speed_multiplier() -> float:
	"""Returns total attack speed multiplier from relics and buffs"""
	var total = 1.0 + relic_attack_speed_bonus
	if buff_manager:
		total *= buff_manager.get_attack_speed_multiplier()
	return total


func get_total_movement_speed_multiplier() -> float:
	"""Returns total movement speed multiplier from buffs"""
	if buff_manager:
		return buff_manager.get_movement_speed_multiplier()
	return 1.0


func get_damage_reduction() -> float:
	"""Returns total damage reduction from buffs"""
	if buff_manager:
		return buff_manager.get_damage_reduction()
	return 0.0
