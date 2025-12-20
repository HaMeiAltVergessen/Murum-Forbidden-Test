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

# ============ STATE ============
var is_dead: bool = false


func _ready() -> void:
	# Connect component signals
	_connect_signals()

	# Register with GameManager
	_register_with_game_manager()

	print("[Murum] Player initialized")


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
