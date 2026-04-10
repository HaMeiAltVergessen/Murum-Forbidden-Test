extends CharacterBody2D
class_name EchoSiren

## Echo Siren - Debuff enemy, scream inverts player controls for 4s
## Maintains medium distance, screams every 8s

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 35
const MOVE_SPEED: float = 90.0
const DAMAGE: int = 10
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 400.0
const PREFERRED_DISTANCE: float = 200.0
const SCREAM_COOLDOWN: float = 8.0
const SCREAM_CHARGE: float = 1.0
const SCREAM_RADIUS: float = 250.0
const INVERT_DURATION: float = 4.0
const ATTACK_RANGE: float = 70.0
const ATTACK_COOLDOWN: float = 2.0

const FRAME_REGIONS: Array = [
	Rect2(20, 80, 500, 1000),    # 0: IDLE
	Rect2(570, 80, 500, 1000),   # 1: REPOSITION
	Rect2(1120, 80, 500, 1000),  # 2: SCREAM_CHARGE
	Rect2(1670, 80, 500, 1000),  # 3: SCREAM_PULSE
	Rect2(2220, 80, 500, 1000),  # 4: ATTACK/STUNNED
]

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, REPOSITION, SCREAM_CHARGE, SCREAM_PULSE, ATTACK, COOLDOWN }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var scream_cooldown: float = 4.0
var charge_timer: float = 0.0
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
	add_to_group("echo_siren")
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

	scream_cooldown -= delta
	attack_cooldown -= delta
	var dist := get_distance_to_target()

	match state:
		State.IDLE:
			_set_sprite_frame(0)
			if dist <= DETECTION_RANGE:
				state = State.REPOSITION
		State.REPOSITION:
			_set_sprite_frame(1)
			_face_target()
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
				return
			# Scream priority
			if scream_cooldown <= 0.0:
				state = State.SCREAM_CHARGE
				charge_timer = 0.0
				velocity.x = 0
				return
			# Maintain distance
			var dir := get_direction_to_target()
			if dist < PREFERRED_DISTANCE - 40.0:
				velocity.x = -dir.x * MOVE_SPEED
			elif dist > PREFERRED_DISTANCE + 40.0:
				velocity.x = dir.x * MOVE_SPEED
			else:
				velocity.x = 0
			# Melee if cornered
			if dist <= ATTACK_RANGE and attack_cooldown <= 0.0:
				_do_melee()
		State.SCREAM_CHARGE:
			_set_sprite_frame(2)
			velocity.x = 0
			charge_timer += delta
			if sprite:
				var intensity := charge_timer / SCREAM_CHARGE
				sprite.modulate = Color(0.7 + intensity * 0.5, 0.4, 0.9 + intensity * 0.3, 1.0)
			if charge_timer >= SCREAM_CHARGE:
				_do_scream()
		State.SCREAM_PULSE:
			_set_sprite_frame(3)
			velocity.x = 0
			charge_timer += delta
			if charge_timer >= 0.5:
				state = State.REPOSITION
				scream_cooldown = SCREAM_COOLDOWN
				if sprite:
					sprite.modulate = _default_modulate
		State.ATTACK:
			_set_sprite_frame(4)
		State.COOLDOWN:
			_set_sprite_frame(0)
			_face_target()
			attack_cooldown -= delta
			velocity.x = -get_direction_to_target().x * MOVE_SPEED * 0.5
			if attack_cooldown <= 0.0:
				state = State.REPOSITION

func _do_scream() -> void:
	state = State.SCREAM_PULSE
	charge_timer = 0.0
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= SCREAM_RADIUS:
				EventBus.controls_inverted.emit(player, INVERT_DURATION)

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
	_set_sprite_frame(4)
	stun_duration = duration
	state = State.IDLE
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	_set_sprite_frame(0)
	stun_duration = 0.0
	if sprite:
		sprite.modulate = _default_modulate
	stun_ended.emit()

func _set_sprite_frame(index: int) -> void:
	if sprite and index >= 0 and index < FRAME_REGIONS.size():
		sprite.region_rect = FRAME_REGIONS[index]

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
