extends CharacterBody2D
class_name TetheredWarden

## The Tethered (Warden) - Defensive half of elite dual entity
## Connected to Beast by tether. If Beast dies, enrages (+50% dmg, +30% speed)

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 120
const MOVE_SPEED: float = 70.0
const DAMAGE: int = 20
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 500.0
const ATTACK_RANGE: float = 90.0
const ATTACK_WINDUP: float = 0.4
const ATTACK_ACTIVE: float = 0.25
const ATTACK_COOLDOWN: float = 1.8
const TETHER_MAX_DIST: float = 400.0
const FRONT_ARMOR: float = 0.6  # 40% reduction

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, COOLDOWN, TETHER_PULL }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var beast: CharacterBody2D = null
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var is_enraged: bool = false
var facing_right: bool = true
var _default_modulate: Color = Color(0.4, 0.5, 0.7, 0.9)
@export var beast_path: NodePath = ""

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
	add_to_group("tethered_warden")
	add_to_group("mini_boss")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)
	# Find beast
	if beast_path:
		beast = get_node_or_null(beast_path)
	if not beast:
		await get_tree().process_frame
		var beasts := get_tree().get_nodes_in_group("tethered_beast")
		if beasts.size() > 0:
			beast = beasts[0]

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func _process(delta: float) -> void:
	_check_beast_alive()
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return
	_update_ai(delta)

# ============================================================================
# TETHER
# ============================================================================

func _check_beast_alive() -> void:
	if beast and not is_instance_valid(beast):
		beast = null
	if beast == null and not is_enraged:
		_enrage()

func _enrage() -> void:
	is_enraged = true
	_default_modulate = Color(0.8, 0.3, 0.3, 1.0)
	if sprite:
		sprite.modulate = _default_modulate

func _get_effective_speed() -> float:
	return MOVE_SPEED * (1.3 if is_enraged else 1.0)

func _get_effective_damage() -> int:
	return int(float(DAMAGE) * (1.5 if is_enraged else 1.0))

# ============================================================================
# AI
# ============================================================================

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _update_ai(delta: float) -> void:
	if not target:
		_find_target()
		return

	# Tether pull — stay near beast
	if beast and is_instance_valid(beast):
		var beast_dist := global_position.distance_to(beast.global_position)
		if beast_dist > TETHER_MAX_DIST:
			var pull_dir := (beast.global_position - global_position).normalized()
			velocity.x = pull_dir.x * _get_effective_speed() * 1.5
			return

	var dist := get_distance_to_target()
	cooldown_timer -= delta

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
				velocity.x = get_direction_to_target().x * _get_effective_speed()
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
			velocity.x = get_direction_to_target().x * _get_effective_speed() * 1.5
			if attack_timer >= ATTACK_ACTIVE:
				if hitbox:
					hitbox.monitoring = false
				state = State.COOLDOWN
				cooldown_timer = ATTACK_COOLDOWN
		State.COOLDOWN:
			_face_target()
			cooldown_timer -= delta
			# Stay near beast
			if beast and is_instance_valid(beast):
				var to_beast := (beast.global_position - global_position).normalized()
				velocity.x = to_beast.x * _get_effective_speed() * 0.5
			else:
				velocity.x = get_direction_to_target().x * _get_effective_speed() * 0.5
			if cooldown_timer <= 0.0:
				state = State.CHASE

# ============================================================================
# DAMAGE (with front armor)
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	var actual := damage
	if knockback.length() > 0:
		var from_right := knockback.x < 0
		var is_front := (facing_right and from_right) or (not facing_right and not from_right)
		if is_front:
			actual = int(float(damage) * FRONT_ARMOR)
	take_damage(actual)
	if knockback.length() > 0:
		velocity = knockback * 0.4
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
	_spawn_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func _spawn_loot() -> void:
	var coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not coin_scene:
		return
	for i in range(randi() % 4 + 5):
		var coin = coin_scene.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
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
