extends CharacterBody2D
class_name Enforcer

## Enforcer - Melee Tank with Directional Armor
## Takes 60% less damage from front, full damage from back

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 60
const MOVE_SPEED: float = 65.0
const DAMAGE: int = 20
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 350.0
const ATTACK_RANGE: float = 90.0
const FRONT_ARMOR: float = 0.4  # 60% reduction = take 40%
const COMBO_HITS: int = 3
const ATTACK_WINDUP: float = 0.4
const ATTACK_ACTIVE: float = 0.2
const ATTACK_RECOVERY: float = 0.3
const ATTACK_COOLDOWN: float = 2.0

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, COOLDOWN }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var combo_count: int = 0
var facing_right: bool = true
var _default_modulate: Color = Color(0.2, 0.3, 0.8, 0.9)

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Node2D = $Sprite2D
@onready var hurtbox: Area2D = $HurtboxComponent
@onready var hitbox: Area2D = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea

signal health_changed(current: int, maximum: int)
signal died
signal stunned_signal(duration: float)
signal stun_ended

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enforcer")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func _process(delta: float) -> void:
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return
	_update_ai(delta)

# ============================================================================
# AI
# ============================================================================

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _update_ai(delta: float) -> void:
	if not target:
		_find_target()
		return

	match state:
		State.IDLE:
			if get_distance_to_target() <= DETECTION_RANGE:
				state = State.CHASE
		State.CHASE:
			_face_target()
			var dist := get_distance_to_target()
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
			elif dist <= ATTACK_RANGE and cooldown_timer <= 0.0:
				state = State.ATTACK_WINDUP
				attack_timer = 0.0
				combo_count = 0
				velocity.x = 0
			else:
				var dir := get_direction_to_target()
				velocity.x = dir.x * MOVE_SPEED
		State.ATTACK_WINDUP:
			velocity.x = 0
			attack_timer += delta
			if attack_timer >= ATTACK_WINDUP:
				state = State.ATTACK_ACTIVE
				attack_timer = 0.0
				if hitbox:
					hitbox.monitoring = true
		State.ATTACK_ACTIVE:
			attack_timer += delta
			# Lunge forward slightly
			var dir := get_direction_to_target()
			velocity.x = dir.x * MOVE_SPEED * 1.5
			if attack_timer >= ATTACK_ACTIVE:
				if hitbox:
					hitbox.monitoring = false
				combo_count += 1
				if combo_count < COMBO_HITS:
					state = State.ATTACK_WINDUP
					attack_timer = 0.0
				else:
					state = State.ATTACK_RECOVERY
					attack_timer = 0.0
		State.ATTACK_RECOVERY:
			velocity.x = 0
			attack_timer += delta
			if attack_timer >= ATTACK_RECOVERY:
				state = State.COOLDOWN
				cooldown_timer = ATTACK_COOLDOWN
		State.COOLDOWN:
			_face_target()
			cooldown_timer -= delta
			var dir := get_direction_to_target()
			velocity.x = dir.x * MOVE_SPEED * 0.5
			if cooldown_timer <= 0.0:
				state = State.CHASE

# ============================================================================
# DAMAGE (with Directional Armor)
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	var actual_damage := damage
	# Check if attacker is in front
	if knockback.length() > 0:
		var attack_from_right := knockback.x < 0
		var is_front_hit := (facing_right and attack_from_right) or (not facing_right and not attack_from_right)
		if is_front_hit:
			actual_damage = int(float(damage) * FRONT_ARMOR)
	take_damage(actual_damage)
	if knockback.length() > 0:
		velocity = knockback * (0.5 if state == State.ATTACK_ACTIVE else 1.0)
	if hitstun > 0:
		stun(hitstun)

func take_damage(amount: int, _attacker: Node = null) -> void:
	current_hp -= amount
	current_hp = max(current_hp, 0)
	health_changed.emit(current_hp, MAX_HP)
	_flash_damage()
	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	if not sprite:
		return
	sprite.modulate = Color(2.0, 0.5, 0.5, _default_modulate.a)
	await get_tree().create_timer(0.1).timeout
	if sprite:
		sprite.modulate = _default_modulate

# ============================================================================
# DEATH
# ============================================================================

func die() -> void:
	died.emit()
	EventBus.enemy_died.emit(self, global_position)
	CombatManager.unregister_enemy(self)
	set_physics_process(false)
	set_process(false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	_spawn_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func _spawn_loot() -> void:
	var coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not coin_scene:
		return
	for i in range(randi() % 3 + 2):
		var coin = coin_scene.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		coin.gold_value = 1
		get_tree().current_scene.add_child(coin)

# ============================================================================
# STUN
# ============================================================================

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration
	state = State.IDLE
	if hitbox:
		hitbox.monitoring = false
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	if sprite:
		sprite.modulate = _default_modulate
	stun_ended.emit()

# ============================================================================
# UTILITY
# ============================================================================

func _face_target() -> void:
	if not target or not sprite:
		return
	facing_right = target.global_position.x > global_position.x
	if "flip_h" in sprite:
		sprite.flip_h = not facing_right

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func is_alive() -> bool:
	return current_hp > 0
