extends CharacterBody2D
class_name Vanguard

## Vanguard - Elite melee with frontal energy shield + rally cry
## Shield blocks all front damage (80 HP), regenerates after 5s

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 200
const MOVE_SPEED: float = 80.0
const DAMAGE: int = 25
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 500.0
const ATTACK_RANGE: float = 100.0
const SHIELD_MAX_HP: int = 80
const SHIELD_REGEN_RATE: float = 10.0
const SHIELD_REGEN_DELAY: float = 5.0
const COMBO_HITS: int = 3
const ATTACK_WINDUP: float = 0.5
const ATTACK_ACTIVE: float = 0.25
const ATTACK_RECOVERY: float = 0.5
const ATTACK_COOLDOWN: float = 2.0
const RALLY_COOLDOWN: float = 15.0
const RALLY_RANGE: float = 300.0
const RALLY_DURATION: float = 5.0
const RALLY_DMG_BONUS: float = 0.25

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY, COOLDOWN }

var current_hp: int = MAX_HP
var shield_hp: int = SHIELD_MAX_HP
var shield_regen_timer: float = 0.0
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var combo_count: int = 0
var rally_timer: float = 8.0
var facing_right: bool = true
var _shield_visual: ColorRect = null
var _default_modulate: Color = Color(1.0, 0.7, 0.2, 0.9)

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
	add_to_group("vanguard")
	add_to_group("mini_boss")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)
	_create_shield_visual()

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
	_update_shield(delta)
	_update_rally(delta)
	_update_ai(delta)

# ============================================================================
# SHIELD
# ============================================================================

func _create_shield_visual() -> void:
	_shield_visual = ColorRect.new()
	_shield_visual.offset_left = -10.0
	_shield_visual.offset_top = -50.0
	_shield_visual.offset_right = 10.0
	_shield_visual.offset_bottom = 10.0
	_shield_visual.color = Color(0.3, 0.6, 1.0, 0.4)
	_shield_visual.z_index = 1
	add_child(_shield_visual)
	_update_shield_visual()

func _update_shield(delta: float) -> void:
	if shield_hp < SHIELD_MAX_HP:
		shield_regen_timer -= delta
		if shield_regen_timer <= 0.0:
			shield_hp = min(shield_hp + int(SHIELD_REGEN_RATE * delta), SHIELD_MAX_HP)
	_update_shield_visual()

func _update_shield_visual() -> void:
	if _shield_visual:
		_shield_visual.visible = shield_hp > 0
		var alpha := 0.4 * (float(shield_hp) / float(SHIELD_MAX_HP))
		_shield_visual.color = Color(0.3, 0.6, 1.0, alpha)
		# Position shield on facing side
		if facing_right:
			_shield_visual.offset_left = 20.0
			_shield_visual.offset_right = 40.0
		else:
			_shield_visual.offset_left = -40.0
			_shield_visual.offset_right = -20.0

# ============================================================================
# RALLY CRY
# ============================================================================

func _update_rally(delta: float) -> void:
	rally_timer -= delta
	if rally_timer <= 0.0:
		_rally_cry()
		rally_timer = RALLY_COOLDOWN

func _rally_cry() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= RALLY_RANGE:
			# Visual feedback: orange flash
			if "sprite" in enemy and enemy.sprite:
				var orig := enemy.sprite.modulate
				enemy.sprite.modulate = Color(1.5, 0.8, 0.3, orig.a)
				get_tree().create_timer(RALLY_DURATION).timeout.connect(
					func():
						if is_instance_valid(enemy) and enemy.sprite:
							enemy.sprite.modulate = orig
				)

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
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 2.0
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
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 0.5
			if cooldown_timer <= 0.0:
				state = State.CHASE

# ============================================================================
# DAMAGE (with Shield)
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	var actual_damage := damage
	# Check front hit → shield absorbs
	if knockback.length() > 0 and shield_hp > 0:
		var attack_from_right := knockback.x < 0
		var is_front := (facing_right and attack_from_right) or (not facing_right and not attack_from_right)
		if is_front:
			var absorbed := min(shield_hp, damage)
			shield_hp -= absorbed
			actual_damage = damage - absorbed
			shield_regen_timer = SHIELD_REGEN_DELAY
	if actual_damage > 0:
		take_damage(actual_damage)
	if knockback.length() > 0:
		velocity = knockback * 0.3  # Heavy, less knockback
	if hitstun > 0 and shield_hp <= 0:
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
	for i in range(randi() % 5 + 8):
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
