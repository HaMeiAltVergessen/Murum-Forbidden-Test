extends CharacterBody2D
class_name Disruptor

## Disruptor - Debuff enemy with slowing frequency field
## Activates field periodically, slows players by 40%

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 40
const MOVE_SPEED: float = 75.0
const DAMAGE: int = 10
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 400.0
const PREFERRED_DISTANCE: float = 200.0
const FIELD_RADIUS: float = 150.0
const FIELD_COOLDOWN: float = 5.0
const FIELD_DURATION: float = 3.0
const FIELD_SLOW: float = 0.4
const FIELD_DPS: float = 5.0
const ATTACK_RANGE: float = 70.0
const ATTACK_COOLDOWN: float = 2.0

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, REPOSITION, FIELD_ACTIVE, ATTACK }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var field_cooldown_timer: float = 3.0
var field_active_timer: float = 0.0
var attack_timer: float = 0.0
var _field_visual: ColorRect = null
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
	add_to_group("disruptor")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)
	_create_field_visual()

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
# FIELD VISUAL
# ============================================================================

func _create_field_visual() -> void:
	_field_visual = ColorRect.new()
	_field_visual.offset_left = -FIELD_RADIUS
	_field_visual.offset_top = -FIELD_RADIUS
	_field_visual.offset_right = FIELD_RADIUS
	_field_visual.offset_bottom = FIELD_RADIUS
	_field_visual.color = Color(0.8, 0.2, 0.8, 0.15)
	_field_visual.visible = false
	_field_visual.z_index = -1
	add_child(_field_visual)

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
	attack_timer -= delta

	match state:
		State.IDLE:
			if dist <= DETECTION_RANGE:
				state = State.REPOSITION
		State.REPOSITION:
			_face_target()
			field_cooldown_timer -= delta
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
				return
			# Move to preferred distance
			var dir := get_direction_to_target()
			if dist < PREFERRED_DISTANCE - 30.0:
				velocity.x = -dir.x * MOVE_SPEED
			elif dist > PREFERRED_DISTANCE + 30.0:
				velocity.x = dir.x * MOVE_SPEED
			else:
				velocity.x = 0
			# Activate field
			if field_cooldown_timer <= 0.0:
				state = State.FIELD_ACTIVE
				field_active_timer = FIELD_DURATION
				if _field_visual:
					_field_visual.visible = true
		State.FIELD_ACTIVE:
			velocity.x = 0
			field_active_timer -= delta
			_apply_field_effects(delta)
			if field_active_timer <= 0.0:
				state = State.REPOSITION
				field_cooldown_timer = FIELD_COOLDOWN
				if _field_visual:
					_field_visual.visible = false
		State.ATTACK:
			pass

func _apply_field_effects(delta: float) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= FIELD_RADIUS:
			# Slow player
			if "velocity" in player:
				player.velocity *= (1.0 - FIELD_SLOW * delta * 10.0)
			# DPS
			if player.has_method("take_damage"):
				var dmg := int(FIELD_DPS * delta)
				if dmg > 0:
					player.take_damage(dmg)

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
	state = State.IDLE
	if _field_visual:
		_field_visual.visible = false
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
