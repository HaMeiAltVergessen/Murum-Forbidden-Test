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
const FIRE_COOLDOWN: float = 0.8
const BURST_COUNT: int = 3
const BURST_INTERVAL: float = 0.12
const PROJECTILE_SPEED: float = 650.0

const ENERGY_BOLT_SCENE: PackedScene = preload("res://traps/world_2/scenes/energy_bolt.tscn")

# Sprite frame regions: PATROL, ALERT, STRAFE, FIRING, STUNNED
const FRAME_REGIONS: Array = [
	Rect2(20, 10, 200, 240),
	Rect2(340, 10, 250, 240),
	Rect2(680, 10, 200, 240),
	Rect2(50, 280, 340, 270),
	Rect2(600, 280, 300, 270),
]

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var fire_timer: float = 0.0
var _default_modulate: Color = Color.WHITE
var _commander_buffed: bool = false  # +40% damage, -50% damage taken from Synaptik-Kommandant

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
		_set_sprite_frame(0)  # PATROL
		return

	_face_target()
	_set_sprite_frame(1)  # ALERT

	# Maintain preferred distance
	var dir := get_direction_to_target()
	if dist < PREFERRED_DISTANCE - 50.0:
		velocity.x = -dir.x * MOVE_SPEED
		_set_sprite_frame(2)  # STRAFE
	elif dist > PREFERRED_DISTANCE + 50.0:
		velocity.x = dir.x * MOVE_SPEED
		_set_sprite_frame(2)  # STRAFE
	else:
		velocity.x = 0

	# Hover (reduce gravity effect)
	if velocity.y > 0:
		velocity.y *= 0.8

	# Fire projectile
	fire_timer -= delta
	if fire_timer <= 0.0 and dist <= DETECTION_RANGE:
		_set_sprite_frame(3)  # FIRING
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
	if not target or not ENERGY_BOLT_SCENE:
		return
	_fire_burst()

func _fire_burst() -> void:
	for i in range(BURST_COUNT):
		if not is_instance_valid(self) or not target or not is_instance_valid(target):
			return
		_spawn_bolt()
		if i < BURST_COUNT - 1:
			await get_tree().create_timer(BURST_INTERVAL).timeout

func _spawn_bolt() -> void:
	if not target or not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var bolt: EnergyBolt = ENERGY_BOLT_SCENE.instantiate()
	bolt.direction = dir
	bolt.speed = PROJECTILE_SPEED
	bolt.damage = int(DAMAGE * 1.4) if _commander_buffed else DAMAGE
	bolt.can_be_parried = true
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + dir * 40.0
	bolt.rotation = dir.angle()

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
	var actual: int = amount
	if _commander_buffed:
		actual = int(amount * 0.5)
	current_hp -= actual
	current_hp = max(current_hp, 0)
	health_changed.emit(current_hp, MAX_HP)
	_flash_damage()
	if current_hp <= 0:
		die()

func apply_commander_buff(active: bool) -> void:
	if _commander_buffed == active:
		return
	_commander_buffed = active
	if sprite:
		if active:
			_default_modulate = Color(0.6, 1.5, 2.0, 1.0)
		else:
			_default_modulate = Color.WHITE
		sprite.modulate = _default_modulate
	EventBus.commander_buff_applied.emit(self, active)

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
	_set_sprite_frame(4)  # STUNNED
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	_set_sprite_frame(0)  # PATROL
	if sprite:
		sprite.modulate = _default_modulate
	stun_ended.emit()

# ============================================================================
# UTILITY
# ============================================================================

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
