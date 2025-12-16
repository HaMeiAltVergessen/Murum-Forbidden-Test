extends CharacterBody2D
## BaseEnemy - Base class for all enemies
class_name BaseEnemy

# ============ COMPONENT REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent
@onready var ai_controller: Node = $AIController

# ============ STATS ============
@export var max_health: int = 40
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 50.0
@export var detection_range: float = 300.0

# ============ STATE ============
var is_dead: bool = false
var target_player: CharacterBody2D = null


func _ready() -> void:
	# Set health
	if health_component:
		health_component.max_health = max_health
		health_component.current_health = max_health

	# Connect signals
	_connect_signals()

	# Configure detection area
	_setup_detection_area()

	print("[BaseEnemy] ", name, " initialized")


func _connect_signals() -> void:
	"""Connects component signals"""
	if health_component:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)


func _setup_detection_area() -> void:
	"""Configures the detection area radius"""
	if not detection_area:
		return

	# Set detection radius
	var collision_shape: CollisionShape2D = detection_area.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = detection_range


# ============ PHYSICS ============
func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 980.0 * _delta

	move_and_slide()


# ============ SIGNAL HANDLERS ============
func _on_damage_taken(damage: int) -> void:
	"""Handles damage taken"""
	EventBus.enemy_damaged.emit(self, damage)
	AudioManager.play_sfx("enemy_hurt")

	# Visual feedback
	_flash_sprite()

	print("[Enemy] ", name, " took ", damage, " damage")


func _on_damage_received(_damage: int, knockback: Vector2, _hitstun: float) -> void:
	"""Handles damage from hurtbox"""
	# Apply knockback
	# Note: Damage is handled by HealthComponent via signal
	velocity = knockback


func _on_health_depleted() -> void:
	"""Handles enemy death"""
	if is_dead:
		return

	is_dead = true
	_die()


func _on_detection_body_entered(body: Node2D) -> void:
	"""Detects player entering range"""
	if body is Murum:
		target_player = body as CharacterBody2D
		print("[Enemy] Player detected by ", name)


func _on_detection_body_exited(body: Node2D) -> void:
	"""Detects player leaving range"""
	if body == target_player:
		target_player = null
		print("[Enemy] Player lost by ", name)


# ============ DEATH ============
func _die() -> void:
	"""Handles death sequence"""
	# Disable physics
	set_physics_process(false)
	set_process(false)

	# Disable collisions
	collision_layer = 0
	collision_mask = 0

	# Play death sound
	AudioManager.play_sfx("enemy_death")

	# Emit death signal
	EventBus.enemy_died.emit(self, global_position)

	# Spawn coin placeholder
	_spawn_coin()

	# Play death animation (fade out for now)
	_play_death_animation()

	print("[Enemy] ", name, " died")


func _spawn_coin() -> void:
	"""Spawns a coin at death location"""
	# Simple coin sprite
	var coin: Sprite2D = Sprite2D.new()
	coin.global_position = global_position

	# Create colored rect as placeholder
	var coin_rect: ColorRect = ColorRect.new()
	coin_rect.size = Vector2(16, 16)
	coin_rect.position = Vector2(-8, -8)
	coin_rect.color = Color(1, 0.84, 0, 1)  # Gold color
	coin.add_child(coin_rect)

	get_parent().add_child(coin)

	print("[Enemy] Coin spawned at ", global_position)


func _play_death_animation() -> void:
	"""Plays death animation"""
	# Fade out
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Remove enemy
	queue_free()


# ============ VISUAL FEEDBACK ============
func _flash_sprite() -> void:
	"""Creates a white flash effect on damage"""
	if not sprite:
		return

	var original_modulate: Color = sprite.modulate

	# Flash white
	sprite.modulate = Color(2, 2, 2, 1)

	# Tween back to normal
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)


# ============ GETTERS ============
func get_distance_to_player() -> float:
	"""Returns distance to target player, or INF if no target"""
	if not target_player:
		return INF
	return global_position.distance_to(target_player.global_position)


func get_direction_to_player() -> Vector2:
	"""Returns normalized direction to player, or ZERO if no target"""
	if not target_player:
		return Vector2.ZERO
	return (target_player.global_position - global_position).normalized()


func has_target() -> bool:
	"""Returns true if enemy has detected a player"""
	return target_player != null
