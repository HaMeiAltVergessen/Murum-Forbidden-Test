extends CharacterBody2D
class_name HollowMender

## Hollow Mender - Corrupted Mender with anti-heal beam
## Beam on player converts all healing to damage

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 35
const MOVE_SPEED: float = 95.0
const DAMAGE: int = 8
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 400.0
const BEAM_RANGE: float = 250.0
const BEAM_BREAK_RANGE: float = 300.0
const FLEE_DISTANCE: float = 100.0
const ATTACK_RANGE: float = 70.0
const ATTACK_COOLDOWN: float = 2.5

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, REPOSITION, BEAM_ACTIVE, FLEE, ATTACK }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var beam_target: CharacterBody2D = null
var state: State = State.IDLE
var attack_cooldown: float = 0.0
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
	add_to_group("hollow_mender")
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

	attack_cooldown -= delta
	var dist := get_distance_to_target()

	# Check beam break
	if beam_target and is_instance_valid(beam_target):
		var beam_dist := global_position.distance_to(beam_target.global_position)
		if beam_dist > BEAM_BREAK_RANGE:
			_stop_beam()

	match state:
		State.IDLE:
			if dist <= DETECTION_RANGE:
				state = State.REPOSITION
		State.REPOSITION:
			_face_target()
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
				return
			# Start beam if in range
			if dist <= BEAM_RANGE and not beam_target:
				_start_beam()
				state = State.BEAM_ACTIVE
			# Flee if too close
			elif dist < FLEE_DISTANCE:
				state = State.FLEE
			else:
				var dir := get_direction_to_target()
				velocity.x = dir.x * MOVE_SPEED * 0.5
		State.BEAM_ACTIVE:
			_face_target()
			# Maintain distance while beaming
			if dist < FLEE_DISTANCE:
				velocity.x = -get_direction_to_target().x * MOVE_SPEED
			elif dist > BEAM_RANGE:
				velocity.x = get_direction_to_target().x * MOVE_SPEED * 0.5
			else:
				velocity.x = 0
			if not beam_target:
				state = State.REPOSITION
		State.FLEE:
			velocity.x = -get_direction_to_target().x * MOVE_SPEED
			if dist > FLEE_DISTANCE + 50.0:
				state = State.REPOSITION
			# Melee if cornered
			if dist <= ATTACK_RANGE and attack_cooldown <= 0.0:
				_do_melee()

func _start_beam() -> void:
	beam_target = target
	EventBus.anti_heal_applied.emit(beam_target, true)

func _stop_beam() -> void:
	if beam_target and is_instance_valid(beam_target):
		EventBus.anti_heal_applied.emit(beam_target, false)
	beam_target = null

func _do_melee() -> void:
	if hitbox:
		hitbox.monitoring = true
	attack_cooldown = ATTACK_COOLDOWN
	await get_tree().create_timer(0.2).timeout
	if hitbox:
		hitbox.monitoring = false

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
	_stop_beam()
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

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration
	_stop_beam()
	state = State.IDLE
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
