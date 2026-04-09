extends CharacterBody2D
class_name Mender

## Mender - Support enemy that heals nearby allies
## Flees from players, prioritizes healing over fighting

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 25
const MOVE_SPEED: float = 100.0
const DAMAGE: int = 8
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 400.0
const HEAL_RANGE: float = 200.0
const HEAL_PER_SECOND: float = 8.0
const FLEE_DISTANCE: float = 300.0
const ATTACK_RANGE: float = 70.0
const ATTACK_COOLDOWN: float = 2.5

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, FLEE, HEAL, ATTACK }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var heal_target: CharacterBody2D = null
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

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("mender")
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

func _find_heal_target() -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_hp_pct: float = 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy.is_in_group("mender"):
			continue
		if not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist > HEAL_RANGE:
			continue
		var hp_pct: float = 1.0
		if "current_hp" in enemy and "MAX_HP" in enemy:
			hp_pct = float(enemy.current_hp) / float(enemy.MAX_HP)
		if hp_pct < best_hp_pct:
			best_hp_pct = hp_pct
			best = enemy
	return best

func _update_ai(delta: float) -> void:
	if not target:
		_find_target()
		return

	attack_cooldown -= delta
	var dist_to_player := get_distance_to_target()

	# Priority: Heal > Flee > Attack
	heal_target = _find_heal_target()

	if heal_target and heal_target.has_method("is_alive") and heal_target.is_alive():
		state = State.HEAL
		_do_heal(delta)
		# Also flee while healing
		if dist_to_player < FLEE_DISTANCE:
			_flee_from_player()
	elif dist_to_player < FLEE_DISTANCE:
		state = State.FLEE
		_flee_from_player()
	elif dist_to_player <= ATTACK_RANGE and attack_cooldown <= 0.0:
		state = State.ATTACK
		_do_attack()
	else:
		state = State.IDLE
		# Move toward allies to be in heal range
		if heal_target:
			var dir := (heal_target.global_position - global_position).normalized()
			velocity.x = dir.x * MOVE_SPEED * 0.5
		else:
			velocity.x = 0

	_face_target()

func _flee_from_player() -> void:
	var dir := get_direction_to_target()
	velocity.x = -dir.x * MOVE_SPEED

func _do_heal(delta: float) -> void:
	if not heal_target or not is_instance_valid(heal_target):
		return
	if "current_hp" in heal_target and "MAX_HP" in heal_target:
		var heal_amount := int(HEAL_PER_SECOND * delta)
		heal_target.current_hp = min(heal_target.current_hp + heal_amount, heal_target.MAX_HP)
		if heal_target.has_signal("health_changed"):
			heal_target.health_changed.emit(heal_target.current_hp, heal_target.MAX_HP)
	# Green tint on heal target
	if heal_target and "sprite" in heal_target and heal_target.sprite:
		heal_target.sprite.modulate = Color(0.5, 1.5, 0.5, heal_target.sprite.modulate.a)

func _do_attack() -> void:
	if hitbox:
		hitbox.monitoring = true
	attack_cooldown = ATTACK_COOLDOWN
	await get_tree().create_timer(0.2).timeout
	if hitbox:
		hitbox.monitoring = false

# ============================================================================
# DAMAGE / DEATH / STUN (standard)
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
