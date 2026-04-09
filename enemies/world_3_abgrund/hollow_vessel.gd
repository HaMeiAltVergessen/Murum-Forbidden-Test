extends CharacterBody2D
class_name HollowVessel

## Hollow Vessel - Corrupted Geist that spawns afterimage clones
## Every 3rd attack creates a 1HP clone that lasts 5s

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 45
const MOVE_SPEED: float = 85.0
const DAMAGE: int = 15
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 400.0
const ATTACK_RANGE: float = 80.0
const ATTACK_WINDUP: float = 0.3
const ATTACK_ACTIVE: float = 0.2
const ATTACK_RECOVERY: float = 0.3
const ATTACK_COOLDOWN: float = 1.5
const CLONE_INTERVAL: int = 3
const MAX_CLONES: int = 2
const CLONE_LIFETIME: float = 5.0

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
var attack_count: int = 0
var is_afterimage: bool = false
var afterimage_timer: float = 0.0
var _default_modulate: Color = Color.WHITE

@onready var sprite: Node2D = $Sprite2D
@onready var hurtbox: Area2D = $HurtboxComponent
@onready var hitbox: Area2D = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea

signal health_changed(current: int, maximum: int)
signal died
signal stunned_signal(duration: float)
signal stun_ended

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hollow_vessel")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)
	# Afterimage setup
	if is_afterimage:
		current_hp = 1
		_default_modulate = Color(0.15, 0.3, 0.3, 0.5)
		if sprite:
			sprite.modulate = _default_modulate
		modulate.a = 0.6
		afterimage_timer = CLONE_LIFETIME

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func _process(delta: float) -> void:
	if is_afterimage:
		afterimage_timer -= delta
		if afterimage_timer <= 0.0:
			die()
			return
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

	var dist := get_distance_to_target()

	match state:
		State.IDLE:
			if dist <= DETECTION_RANGE:
				state = State.CHASE
		State.CHASE:
			_face_target()
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
			elif dist <= ATTACK_RANGE and cooldown_timer <= 0.0:
				state = State.ATTACK_WINDUP
				attack_timer = 0.0
				velocity.x = 0
			else:
				velocity.x = get_direction_to_target().x * MOVE_SPEED
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
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 1.5
			if attack_timer >= ATTACK_ACTIVE:
				if hitbox:
					hitbox.monitoring = false
				attack_count += 1
				# Spawn afterimage every Nth attack
				if not is_afterimage and attack_count >= CLONE_INTERVAL:
					_spawn_afterimage()
					attack_count = 0
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
			velocity.x = get_direction_to_target().x * MOVE_SPEED
			if cooldown_timer <= 0.0:
				state = State.CHASE

func _spawn_afterimage() -> void:
	var clones := get_tree().get_nodes_in_group("hollow_vessel").filter(
		func(n): return n != self and "is_afterimage" in n and n.is_afterimage
	)
	if clones.size() >= MAX_CLONES:
		return
	var scene = load("res://enemies/world_3_abgrund/hollow_vessel.tscn")
	if not scene:
		return
	var clone = scene.instantiate()
	clone.is_afterimage = true
	clone.global_position = global_position + Vector2(randf_range(-30, 30), 0)
	get_tree().current_scene.add_child(clone)

# ============================================================================
# DAMAGE / DEATH / STUN
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	take_damage(damage)
	if knockback.length() > 0:
		velocity = knockback
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
	if not is_afterimage:
		_spawn_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3 if is_afterimage else 0.5)
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

func _face_target() -> void:
	if not target or not sprite:
		return
	if "flip_h" in sprite:
		sprite.flip_h = target.global_position.x < global_position.x

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
