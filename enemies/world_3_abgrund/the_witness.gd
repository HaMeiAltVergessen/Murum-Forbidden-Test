extends CharacterBody2D
class_name TheWitness

## The Witness - Elite caster with gaze beam and blink teleport
## Beam deals 15 DPS, switches targets every 5s. Blinks + AoE every 12s.

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 180
const MOVE_SPEED: float = 40.0
const BEAM_DPS: float = 15.0
const BLINK_DAMAGE: int = 30
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 600.0
const TARGET_SWITCH_INTERVAL: float = 5.0
const BLINK_COOLDOWN: float = 12.0
const BLINK_RANGE: float = 300.0
const BLINK_AOE_RADIUS: float = 120.0
const BLINK_RECOVERY: float = 1.0

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, BEAM_ACTIVE, BLINK_CHARGE, BLINK_RECOVERY, TARGET_SWITCH }

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var beam_target: CharacterBody2D = null
var state: State = State.IDLE
var switch_timer: float = TARGET_SWITCH_INTERVAL
var blink_cooldown: float = 6.0
var recovery_timer: float = 0.0
var target_index: int = 0
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
	add_to_group("the_witness")
	add_to_group("mini_boss")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	_find_target()
	beam_target = target
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

	blink_cooldown -= delta
	switch_timer -= delta
	var dist := get_distance_to_target()

	match state:
		State.IDLE:
			if dist <= DETECTION_RANGE:
				beam_target = target
				state = State.BEAM_ACTIVE
		State.BEAM_ACTIVE:
			_face_beam_target()
			# Slow drift
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 0.3
			# Apply beam damage
			if beam_target and is_instance_valid(beam_target):
				var beam_dist := global_position.distance_to(beam_target.global_position)
				if beam_dist <= DETECTION_RANGE and beam_target.has_method("take_damage"):
					var dmg := int(BEAM_DPS * delta)
					if dmg > 0:
						beam_target.take_damage(dmg)
			# Switch target
			if switch_timer <= 0.0:
				_switch_beam_target()
				switch_timer = TARGET_SWITCH_INTERVAL
			# Blink
			if blink_cooldown <= 0.0:
				_do_blink()
		State.BLINK_CHARGE:
			velocity = Vector2.ZERO
			# Instant blink
			_do_blink_teleport()
		State.BLINK_RECOVERY:
			velocity = Vector2.ZERO
			recovery_timer -= delta
			if recovery_timer <= 0.0:
				state = State.BEAM_ACTIVE
				blink_cooldown = BLINK_COOLDOWN
		State.TARGET_SWITCH:
			# Brief pause during switch (solo mode)
			recovery_timer -= delta
			if recovery_timer <= 0.0:
				state = State.BEAM_ACTIVE

func _switch_beam_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() >= 2:
		target_index = (target_index + 1) % players.size()
		beam_target = players[target_index]
	else:
		# Solo: brief break
		beam_target = null
		state = State.TARGET_SWITCH
		recovery_timer = 2.0
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self) and state == State.TARGET_SWITCH:
			beam_target = target
			state = State.BEAM_ACTIVE

func _face_beam_target() -> void:
	var t := beam_target if beam_target and is_instance_valid(beam_target) else target
	if not t or not sprite:
		return
	if "flip_h" in sprite:
		sprite.flip_h = t.global_position.x < global_position.x

# ============================================================================
# BLINK
# ============================================================================

func _do_blink() -> void:
	state = State.BLINK_CHARGE
	modulate.a = 0.3

func _do_blink_teleport() -> void:
	# Teleport to random position
	var offset := Vector2(randf_range(-BLINK_RANGE, BLINK_RANGE), 0)
	global_position += offset
	modulate.a = 1.0
	# AoE damage on arrival
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= BLINK_AOE_RADIUS and player.has_method("take_damage"):
			player.take_damage(BLINK_DAMAGE)
	state = State.BLINK_RECOVERY
	recovery_timer = BLINK_RECOVERY

# ============================================================================
# DAMAGE / DEATH / STUN
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	take_damage(damage)
	# Mostly ignores knockback (heavy caster)
	if knockback.length() > 0:
		velocity = knockback * 0.2
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
	_spawn_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
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
	beam_target = null
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	beam_target = target
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
