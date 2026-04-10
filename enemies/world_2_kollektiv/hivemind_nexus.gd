extends CharacterBody2D
class_name HivemindNexus

## Hivemind Nexus - Stationary elite spawner
## Immune while 2+ minions alive, spawns sentinel drones

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 150
const MOVE_SPEED: float = 0.0
const DAMAGE: int = 0
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 600.0
const SPAWN_COOLDOWN: float = 8.0
const MAX_MINIONS: int = 4
const IMMUNITY_THRESHOLD: int = 2
const VULNERABILITY_WINDOW: float = 5.0

const FRAME_REGIONS: Array = [
	Rect2(0, 0, 256, 288),     # 0: DORMANT
	Rect2(256, 0, 256, 288),   # 1: ACTIVE
	Rect2(512, 0, 256, 288),   # 2: SPAWNING
	Rect2(768, 0, 256, 288),   # 3: SHIELDED
	Rect2(0, 288, 256, 288),   # 4: OVERLOAD
	Rect2(256, 288, 256, 288), # 5: STUNNED
]

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var spawn_timer: float = 2.0
var minions: Array = []
var is_immune: bool = true
var vulnerability_timer: float = 0.0
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
	add_to_group("hivemind_nexus")
	add_to_group("mini_boss")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
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
	# Clean dead minions
	minions = minions.filter(func(m): return is_instance_valid(m) and m.is_alive())

	# Update immunity
	var alive_count := minions.size()
	if alive_count >= IMMUNITY_THRESHOLD:
		is_immune = true
		vulnerability_timer = 0.0
	else:
		if is_immune:
			is_immune = false
			vulnerability_timer = VULNERABILITY_WINDOW
		if vulnerability_timer > 0.0:
			vulnerability_timer -= delta

	_update_immune_visual()

	# Spawn minions
	spawn_timer -= delta
	if spawn_timer <= 0.0 and alive_count < MAX_MINIONS:
		_spawn_minion()
		spawn_timer = SPAWN_COOLDOWN

	# Update idle frame based on state
	if is_immune:
		_set_sprite_frame(3)
	elif vulnerability_timer > 0.0:
		_set_sprite_frame(4)
	else:
		_set_sprite_frame(1)

	# Face nearest player
	_face_target()

func _update_immune_visual() -> void:
	if not sprite:
		return
	if is_immune:
		sprite.modulate = Color(0.3, 1.2, 1.2, 1.0)
	else:
		sprite.modulate = _default_modulate

func _spawn_minion() -> void:
	var drone_scene = load("res://enemies/world_2_kollektiv/sentinel_drone.tscn")
	if not drone_scene:
		return
	_set_sprite_frame(2)
	var drone = drone_scene.instantiate()
	var offset := Vector2(randf_range(-100, 100), -50)
	drone.global_position = global_position + offset
	get_tree().current_scene.add_child(drone)
	minions.append(drone)

# ============================================================================
# DAMAGE (with Immunity)
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	if is_immune:
		# Visual feedback: flash cyan
		if sprite:
			sprite.modulate = Color(0.5, 1.5, 1.5, 1.0)
			await get_tree().create_timer(0.15).timeout
			if sprite:
				_update_immune_visual()
		return
	take_damage(damage)
	# Stationary — ignore knockback
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
	# Kill all minions
	for m in minions:
		if is_instance_valid(m) and m.has_method("die"):
			m.die()
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
	_set_sprite_frame(5)
	stun_duration = duration
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	_set_sprite_frame(0)
	stun_duration = 0.0
	_update_immune_visual()
	stun_ended.emit()

func _set_sprite_frame(index: int) -> void:
	if sprite and index >= 0 and index < FRAME_REGIONS.size():
		sprite.region_rect = FRAME_REGIONS[index]

func _face_target() -> void:
	if not target:
		_find_target()
	if not target or not sprite:
		return
	if "flip_h" in sprite:
		sprite.flip_h = target.global_position.x < global_position.x

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func is_alive() -> bool:
	return current_hp > 0
