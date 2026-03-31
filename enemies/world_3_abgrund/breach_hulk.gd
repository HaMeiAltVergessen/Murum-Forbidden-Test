extends CharacterBody2D
class_name BreachHulk

## Breach Hulk - Corrupted Enforcer with Void Burst, Tendril Grab, Void Trail
## Heavy melee, leaves damaging trail, periodically bursts AoE

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 85
const MOVE_SPEED: float = 55.0
const DAMAGE: int = 22
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 350.0
const ATTACK_RANGE: float = 100.0
const ATTACK_WINDUP: float = 0.4
const ATTACK_ACTIVE: float = 0.25
const ATTACK_COOLDOWN: float = 2.0
const VOID_BURST_COOLDOWN: float = 10.0
const VOID_BURST_CHARGE: float = 1.5
const VOID_BURST_RADIUS: float = 180.0
const VOID_BURST_DAMAGE: int = 30
const GRAB_CHANCE: float = 0.3
const GRAB_DURATION: float = 2.0
const TRAIL_DPS: float = 5.0
const TRAIL_LIFETIME: float = 3.0
const TRAIL_INTERVAL: float = 0.5

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, COOLDOWN, VOID_CHARGE, VOID_BURST }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var burst_cooldown: float = 5.0
var trail_timer: float = 0.0
var grabbed_player: CharacterBody2D = null
var grab_timer: float = 0.0
var _default_modulate: Color = Color(0.6, 0.1, 0.3, 0.9)

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
	add_to_group("breach_hulk")
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
	_update_grab(delta)
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return
	_update_ai(delta)
	_update_trail(delta)

# ============================================================================
# AI
# ============================================================================

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _update_ai(delta: float) -> void:
	if not target:
		_find_target()
		return

	burst_cooldown -= delta
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
				return
			# Void burst priority
			if burst_cooldown <= 0.0:
				state = State.VOID_CHARGE
				attack_timer = 0.0
				velocity.x = 0
				return
			if dist <= ATTACK_RANGE and cooldown_timer <= 0.0:
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
				# Grab chance
				if randf() < GRAB_CHANCE and dist <= ATTACK_RANGE:
					_grab_player()
				state = State.COOLDOWN
				cooldown_timer = ATTACK_COOLDOWN
		State.COOLDOWN:
			_face_target()
			cooldown_timer -= delta
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 0.3
			if cooldown_timer <= 0.0:
				state = State.CHASE
		State.VOID_CHARGE:
			velocity.x = 0
			attack_timer += delta
			# Pulsing visual
			if sprite:
				var pulse := 0.5 + 0.5 * sin(attack_timer * 8.0)
				sprite.modulate = Color(0.6 + pulse * 0.4, 0.1, 0.3 + pulse * 0.3, 1.0)
			if attack_timer >= VOID_BURST_CHARGE:
				_do_void_burst()
		State.VOID_BURST:
			velocity.x = 0
			attack_timer += delta
			if attack_timer >= 0.3:
				state = State.CHASE
				burst_cooldown = VOID_BURST_COOLDOWN
				if sprite:
					sprite.modulate = _default_modulate

# ============================================================================
# VOID BURST
# ============================================================================

func _do_void_burst() -> void:
	state = State.VOID_BURST
	attack_timer = 0.0
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= VOID_BURST_RADIUS and player.has_method("take_damage"):
			player.take_damage(VOID_BURST_DAMAGE)

# ============================================================================
# TENDRIL GRAB
# ============================================================================

func _grab_player() -> void:
	if grabbed_player:
		return
	grabbed_player = target
	grab_timer = GRAB_DURATION

func _update_grab(delta: float) -> void:
	if not grabbed_player or not is_instance_valid(grabbed_player):
		grabbed_player = null
		return
	grab_timer -= delta
	# Immobilize grabbed player
	if "velocity" in grabbed_player:
		grabbed_player.velocity = Vector2.ZERO
	# Check if other player hits us to free
	if grab_timer <= 0.0:
		_release_grab()

func _release_grab() -> void:
	grabbed_player = null

# ============================================================================
# VOID TRAIL
# ============================================================================

func _update_trail(delta: float) -> void:
	if velocity.x == 0:
		return
	trail_timer -= delta
	if trail_timer <= 0.0:
		_spawn_trail_segment()
		trail_timer = TRAIL_INTERVAL

func _spawn_trail_segment() -> void:
	var trail := ColorRect.new()
	trail.offset_left = -15
	trail.offset_top = -5
	trail.offset_right = 15
	trail.offset_bottom = 5
	trail.color = Color(0.4, 0.0, 0.2, 0.5)
	trail.global_position = global_position + Vector2(0, 30)
	trail.z_index = -1
	get_tree().current_scene.add_child(trail)
	# Auto-remove after lifetime
	get_tree().create_timer(TRAIL_LIFETIME).timeout.connect(
		func():
			if is_instance_valid(trail):
				trail.queue_free()
	)

# ============================================================================
# DAMAGE / DEATH / STUN
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	take_damage(damage)
	if knockback.length() > 0:
		velocity = knockback * 0.4
	if hitstun > 0:
		stun(hitstun)
	# Free grabbed player if hit
	if grabbed_player:
		_release_grab()

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
	if grabbed_player:
		_release_grab()
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
