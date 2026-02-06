extends CharacterBody2D
class_name GuardianStatue

## Wächterstatue (Guardian Statue) - TANK/ELITE
## Massive stone knight, extremely slow but devastating.
## Activates when player gets close, returns to spawn if player retreats.
## 3 distance-based attacks: Shield Bash (close), Horizontal Swing (medium), Overhead Slam (far).
## Resistant to light attacks (-armor%), vulnerable to heavy attacks.
## Perfect Parry stuns for 5 seconds with +100% damage taken.

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 350
const MOVE_SPEED: float = 40.0  # Very slow
const DAMAGE_HORIZONTAL: int = 60
const DAMAGE_OVERHEAD: int = 80
const DAMAGE_OVERHEAD_AOE: int = 30
const DAMAGE_SHIELD_BASH: int = 40
const DETECTION_RANGE: float = 200.0
const DEAGGRO_RANGE: float = 500.0

const MIN_COINS: int = 5
const MAX_COINS: int = 8

# ============================================================================
# ARMOR SYSTEM
# ============================================================================

## Armor value: percentage of damage reduced from light/fast attacks (0.0 - 1.0)
@export var armor_reduction: float = 0.7  # 70% damage reduction from light attacks
## Heavy attacks bypass armor completely
@export var heavy_attack_bypass: bool = true

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_dead: bool = false
var is_stunned: bool = false
var stun_duration: float = 0.0
var is_parry_stunned: bool = false  # Perfect parry stun = +100% damage
var spawn_position: Vector2 = Vector2.ZERO

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var ai_controller: Node = $GuardianStatueAI
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent

# ============================================================================
# SIGNALS
# ============================================================================

signal health_changed(current: int, maximum: int)
signal died
signal stunned_signal(duration: float)
signal stun_ended_signal

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("guardian_statue")

	spawn_position = global_position

	# Setup health
	if health_component:
		health_component.max_health = MAX_HP
		health_component.current_health = MAX_HP

	# Connect hurtbox
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Connect health component
	if health_component:
		health_component.damage_taken.connect(_on_health_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)

	# Connect detection
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	# Connect to EventBus for perfect parry
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)

	print("[GuardianStatue] Initialized at %v, HP: %d/%d" % [global_position, current_hp, MAX_HP])


# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	move_and_slide()


# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if is_dead:
		return

	# Stun countdown
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()


# ============================================================================
# DAMAGE HANDLING WITH ARMOR
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	"""Called when hurtbox receives damage - applies armor reduction"""
	var final_damage = _apply_armor(damage)

	# Double damage if parry stunned
	if is_parry_stunned:
		final_damage *= 2

	take_damage(final_damage)

	# Minimal knockback (heavy enemy)
	if knockback.length() > 0:
		velocity = knockback * 0.2  # 80% knockback resistance

	# Hitstun only from heavy attacks
	if hitstun > 0.3:
		stun(hitstun * 0.5)


func _apply_armor(damage: int) -> int:
	"""Applies armor damage reduction for light attacks"""
	# TODO: When a damage type system is added, check for heavy attack flag
	# For now, reduce all damage by armor percentage
	# Heavy attacks (finisher, staff throw, charged) will be handled when
	# the damage type system is implemented
	var reduced = int(damage * (1.0 - armor_reduction))
	return max(reduced, 1)  # Always at least 1 damage


func _on_health_damage_taken(damage: int) -> void:
	"""Health component reports damage"""
	current_hp = health_component.current_health
	health_changed.emit(current_hp, MAX_HP)
	EventBus.enemy_damaged.emit(self, damage)

	# Visual feedback
	_flash_damage()
	AudioManager.play_sfx("enemy_hurt")

	print("[GuardianStatue] Took %d damage, HP: %d/%d" % [damage, current_hp, MAX_HP])


func _on_health_depleted() -> void:
	"""Health depleted"""
	if is_dead:
		return
	die()


func take_damage(amount: int, _attacker: Node = null) -> void:
	"""Public damage API"""
	if is_dead:
		return

	if health_component:
		health_component.take_damage(amount)


func _flash_damage() -> void:
	"""Visual damage feedback"""
	if not sprite:
		return
	var original_modulate = sprite.modulate
	sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	if sprite:
		sprite.modulate = original_modulate


# ============================================================================
# PERFECT PARRY REACTION
# ============================================================================

func _on_perfect_parry(enemy: Node) -> void:
	"""Reacts to player's perfect parry"""
	if enemy != self:
		return

	print("[GuardianStatue] PERFECT PARRY! Stunned for 5 seconds, +100%% damage")
	is_parry_stunned = true
	stun(5.0)


# ============================================================================
# DETECTION
# ============================================================================

var target_player: CharacterBody2D = null

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("player2"):
		target_player = body as CharacterBody2D
		print("[GuardianStatue] Player detected: ", body.name)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		print("[GuardianStatue] Player lost")


func has_target() -> bool:
	return target_player != null


func get_distance_to_player() -> float:
	if not target_player:
		return INF
	return global_position.distance_to(target_player.global_position)


func get_direction_to_player() -> Vector2:
	if not target_player:
		return Vector2.ZERO
	return (target_player.global_position - global_position).normalized()


func get_distance_to_spawn() -> float:
	return global_position.distance_to(spawn_position)


# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("[GuardianStatue] Died at %v" % global_position)

	died.emit()
	EventBus.enemy_died.emit(self, global_position)

	# Disable AI
	if ai_controller:
		ai_controller.set_process(false)

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	AudioManager.play_sfx("enemy_death")
	_spawn_loot()

	# Death animation: crumble effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 0.5, 0.0), 1.0)
	tween.tween_property(sprite, "scale:y", 0.5, 1.0)
	await tween.finished
	queue_free()


func _spawn_loot() -> void:
	var gold_coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not gold_coin_scene:
		return

	var coin_count = randi() % (MAX_COINS - MIN_COINS + 1) + MIN_COINS
	for i in range(coin_count):
		var coin = gold_coin_scene.instantiate()
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		coin.global_position = global_position + offset
		coin.gold_value = 1
		get_tree().current_scene.add_child(coin)

	print("[GuardianStatue] Spawned %d gold coins" % coin_count)


# ============================================================================
# STUN SYSTEM
# ============================================================================

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration

	if ai_controller and ai_controller.has_method("cancel_attack"):
		ai_controller.cancel_attack()

	# Visual: yellow tint for normal stun, golden for parry stun
	if sprite:
		if is_parry_stunned:
			sprite.modulate = Color(2.0, 1.5, 0.3, 1.0)  # Golden glow
		else:
			sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)  # Yellow

	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)
	print("[GuardianStatue] Stunned for %.2fs" % duration)


func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	is_parry_stunned = false

	if sprite:
		sprite.modulate = Color.WHITE

	stun_ended_signal.emit()
	print("[GuardianStatue] Stun ended")


# ============================================================================
# UTILITY
# ============================================================================

func get_hp_percent() -> float:
	return float(current_hp) / float(MAX_HP)

func is_alive() -> bool:
	return current_hp > 0
