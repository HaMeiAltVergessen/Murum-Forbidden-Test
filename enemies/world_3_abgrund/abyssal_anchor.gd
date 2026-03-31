extends CharacterBody2D
class_name AbyssalAnchor

## Abyssal Anchor - Control enemy with persistent gravity well
## Pulls players toward center, doubles radius in coop

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 55
const MOVE_SPEED: float = 50.0
const DAMAGE: int = 5
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 500.0
const WELL_RADIUS: float = 200.0
const WELL_RADIUS_COOP: float = 400.0
const PULL_FORCE: float = 80.0
const DPS: float = 5.0

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var active_radius: float = WELL_RADIUS
var _well_visual: ColorRect = null
var _default_modulate: Color = Color(0.15, 0.1, 0.4, 0.9)

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
	add_to_group("abyssal_anchor")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	_find_target()
	CombatManager.register_enemy(self)
	# Check coop
	var players := get_tree().get_nodes_in_group("player")
	if players.size() >= 2:
		active_radius = WELL_RADIUS_COOP
	_create_well_visual()

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
	_apply_gravity_well(delta)

# ============================================================================
# GRAVITY WELL
# ============================================================================

func _create_well_visual() -> void:
	_well_visual = ColorRect.new()
	_well_visual.offset_left = -active_radius
	_well_visual.offset_top = -active_radius
	_well_visual.offset_right = active_radius
	_well_visual.offset_bottom = active_radius
	_well_visual.color = Color(0.15, 0.05, 0.3, 0.1)
	_well_visual.z_index = -1
	add_child(_well_visual)

func _apply_gravity_well(delta: float) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist > active_radius or dist < 10.0:
			continue
		# Pull toward center
		var pull_dir := (global_position - player.global_position).normalized()
		var strength := PULL_FORCE * (1.0 - dist / active_radius)
		if "velocity" in player:
			player.velocity += pull_dir * strength * delta * 60.0
		# DPS
		if player.has_method("take_damage"):
			var dmg := int(DPS * delta)
			if dmg > 0:
				player.take_damage(dmg)

# ============================================================================
# AI
# ============================================================================

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _update_ai(delta: float) -> void:
	if not target:
		_find_target()
		return
	_face_target()
	# Try to position between players
	var players := get_tree().get_nodes_in_group("player")
	if players.size() >= 2:
		var midpoint := (players[0].global_position + players[1].global_position) / 2.0
		var dir := (midpoint - global_position).normalized()
		velocity.x = dir.x * MOVE_SPEED
	else:
		var dist := get_distance_to_target()
		if dist > DETECTION_RANGE:
			velocity.x = 0
		else:
			velocity.x = get_direction_to_target().x * MOVE_SPEED * 0.5

# ============================================================================
# DAMAGE / DEATH / STUN
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	take_damage(damage)
	if knockback.length() > 0:
		velocity = knockback * 0.5
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
