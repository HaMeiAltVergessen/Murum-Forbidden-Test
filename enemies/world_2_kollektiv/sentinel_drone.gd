extends CharacterBody2D
class_name SentinelDrone

## Sentinel Drone - Ranged flyer with networked targeting
## When 2+ drones alive, they sync targets (one P1, one P2)

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 35
const MOVE_SPEED: float = 120.0
const DAMAGE: int = 12
const GRAVITY: float = 980.0
const PREFERRED_DISTANCE: float = 250.0
const DETECTION_RANGE: float = 500.0
const FIRE_COOLDOWN: float = 2.0
const PROJECTILE_SPEED: float = 350.0

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var fire_timer: float = 0.0
var _default_modulate: Color = Color.WHITE

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Node2D = $Sprite2D
@onready var hurtbox: Area2D = $HurtboxComponent
@onready var hitbox: Area2D = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea

# ============================================================================
# SIGNALS
# ============================================================================

signal health_changed(current: int, maximum: int)
signal died
signal stunned_signal(duration: float)
signal stun_ended

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("sentinel_drone")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	_find_target()
	CombatManager.register_enemy(self)
	fire_timer = randf_range(0.5, FIRE_COOLDOWN)

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
	_update_networked_target()
	if not target:
		_find_target()
		return

	var dist := get_distance_to_target()
	if dist > DETECTION_RANGE:
		velocity.x = 0
		return

	_face_target()

	# Maintain preferred distance
	var dir := get_direction_to_target()
	if dist < PREFERRED_DISTANCE - 50.0:
		velocity.x = -dir.x * MOVE_SPEED
	elif dist > PREFERRED_DISTANCE + 50.0:
		velocity.x = dir.x * MOVE_SPEED
	else:
		velocity.x = 0

	# Hover (reduce gravity effect)
	if velocity.y > 0:
		velocity.y *= 0.8

	# Fire projectile
	fire_timer -= delta
	if fire_timer <= 0.0 and dist <= DETECTION_RANGE:
		_fire_projectile()
		fire_timer = FIRE_COOLDOWN

func _update_networked_target() -> void:
	var drones := get_tree().get_nodes_in_group("sentinel_drone")
	if drones.size() < 2:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() < 2:
		return
	# Assign alternating targets based on index
	var my_index := drones.find(self)
	if my_index >= 0:
		target = players[my_index % players.size()]

func _fire_projectile() -> void:
	if not target:
		return
	var dir := get_direction_to_target()
	var projectile := Area2D.new()
	projectile.collision_layer = 128
	projectile.collision_mask = 6
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	projectile.add_child(shape)
	var bolt_tex := load("res://Assets/AIPlaceholder/Gegner/W2/sentinal_Drone_EnergyBolt.png")
	var visual := Sprite2D.new()
	if bolt_tex:
		visual.texture = bolt_tex
		visual.region_enabled = true
		visual.region_rect = Rect2(45, 202, 443, 184)
		visual.scale = Vector2(0.1, 0.1)
	else:
		var fallback := ColorRect.new()
		fallback.offset_left = -6
		fallback.offset_top = -6
		fallback.offset_right = 6
		fallback.offset_bottom = 6
		fallback.color = Color(0.3, 0.8, 1.0, 0.9)
		projectile.add_child(fallback)
	projectile.add_child(visual)
	projectile.rotation = dir.angle()
	projectile.global_position = global_position
	projectile.set_meta("direction", dir)
	projectile.set_meta("speed", PROJECTILE_SPEED)
	projectile.set_meta("damage", DAMAGE)
	projectile.set_meta("lifetime", 4.0)
	projectile.set_script(_get_projectile_script())
	get_tree().current_scene.add_child(projectile)

static func _get_projectile_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Area2D
var _dir: Vector2
var _spd: float
var _dmg: int
var _life: float
func _ready():
	_dir = get_meta("direction")
	_spd = get_meta("speed")
	_dmg = get_meta("damage")
	_life = get_meta("lifetime")
	area_entered.connect(_on_area_entered)
func _process(d):
	position += _dir * _spd * d
	_life -= d
	if _life <= 0: queue_free()
func _on_area_entered(area):
	if area.get_parent().is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(_dmg, Vector2.ZERO, 0.1)
		queue_free()
"""
	return s

# ============================================================================
# DAMAGE
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

# ============================================================================
# DEATH
# ============================================================================

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

# ============================================================================
# STUN
# ============================================================================

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

# ============================================================================
# UTILITY
# ============================================================================

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
