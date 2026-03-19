extends CharacterBody2D
class_name RaelearClone

## Raelear Shadow Clone — spawns from boon effects
## Two modes:
##   CHASE: Runs toward nearest enemy (Glimmerseed-style), explodes on contact/timeout
##   MIRROR: Stands still, mirrors Murum's next ability (half damage)

# ============================================================================
# CONSTANTS
# ============================================================================

const MOVE_SPEED: float = 180.0
const ZIGZAG_FREQUENCY: float = 3.5
const ZIGZAG_AMPLITUDE: float = 60.0
const EXPLOSION_RADIUS: float = 120.0
const FUSE_DURATION: float = 0.5
const DETECTION_RANGE: float = 600.0
const CLONE_ALPHA: float = 0.45

# ============================================================================
# ENUMS
# ============================================================================

enum Mode { CHASE, MIRROR }

# ============================================================================
# EXPORTS
# ============================================================================

@export var clone_damage: int = 15
@export var duration: float = 6.0
@export var mode: Mode = Mode.CHASE

# ============================================================================
# STATE
# ============================================================================

var alive_timer: float = 0.0
var zigzag_offset: float = 0.0
var target_enemy: Node2D = null
var is_exploding: bool = false
var is_dead: bool = false
var _mirror_used: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

# ============================================================================
# SIGNALS
# ============================================================================

signal clone_exploded(position: Vector2, damage: int)
signal clone_expired()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("raelear_clones")
	zigzag_offset = randf() * TAU

	# Make sprite transparent
	if sprite:
		sprite.modulate = Color(0.6, 0.3, 1.0, CLONE_ALPHA)
		sprite.play("idle")

	# Detection area for finding enemies
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	# Fade-in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

	# Auto-destroy timer
	get_tree().create_timer(duration).timeout.connect(_on_duration_expired)

	print("[RaelearClone] Spawned (%s) at %v, %ds" % [Mode.keys()[mode], global_position, duration])


# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or is_exploding:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	if mode == Mode.CHASE:
		_chase_movement(delta)

	move_and_slide()


func _chase_movement(delta: float) -> void:
	alive_timer += delta

	# Find target if none
	if not target_enemy or not is_instance_valid(target_enemy) or target_enemy.get("is_dead"):
		target_enemy = _find_nearest_enemy()

	if not target_enemy:
		# Idle — no enemy in range
		velocity.x = 0.0
		return

	var direction: Vector2 = (target_enemy.global_position - global_position).normalized()

	# Zigzag movement (like Glimmerseed)
	var perpendicular := Vector2(-direction.y, direction.x)
	var zigzag: float = sin(alive_timer * ZIGZAG_FREQUENCY + zigzag_offset) * ZIGZAG_AMPLITUDE
	var move_dir: Vector2 = direction + perpendicular * (zigzag / ZIGZAG_AMPLITUDE) * 0.4

	velocity.x = move_dir.x * MOVE_SPEED
	if not is_on_floor() or direction.y < -0.3:
		velocity.y = move_dir.y * MOVE_SPEED * 0.3

	# Face direction
	if sprite:
		sprite.flip_h = direction.x < 0

	# Check if close enough to explode
	var dist: float = global_position.distance_to(target_enemy.global_position)
	if dist < 50.0:
		_start_explode()


# ============================================================================
# PROCESS (visual updates)
# ============================================================================

func _process(_delta: float) -> void:
	if is_dead or is_exploding:
		return

	# Animate sprite based on movement
	if sprite:
		if abs(velocity.x) > 10.0:
			if sprite.animation != "walk":
				sprite.play("walk")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")


# ============================================================================
# EXPLOSION (CHASE mode)
# ============================================================================

func _start_explode() -> void:
	if is_exploding or is_dead:
		return
	is_exploding = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	# Brief flash before exploding
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.8, 2.0, 0.8), FUSE_DURATION)
		tween.tween_callback(_explode)


func _explode() -> void:
	if is_dead:
		return
	is_dead = true

	clone_exploded.emit(global_position, clone_damage)

	# AoE damage to enemies
	var explosion := Area2D.new()
	explosion.collision_layer = 0
	explosion.collision_mask = 1024  # Enemy hurtbox layer
	explosion.global_position = global_position

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = EXPLOSION_RADIUS
	shape.shape = circle
	explosion.add_child(shape)

	get_tree().current_scene.add_child(explosion)

	# Wait for physics overlap
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(explosion):
		var overlapping := explosion.get_overlapping_areas()
		for area in overlapping:
			if area is HurtboxComponent:
				var target = area.get_parent()
				if target == self:
					continue
				if target.is_in_group("player") or target.is_in_group("player2"):
					continue
				var kb_dir: Vector2 = (area.global_position - global_position).normalized()
				area.take_damage(clone_damage, kb_dir * 200.0, 0.2, self)
				print("[RaelearClone] Explosion hit: %s for %d" % [target.name, clone_damage])
		explosion.queue_free()

	# VFX: explosion flash
	_play_explosion_visual()

	AudioManager.play_sfx("enemy_death")

	await get_tree().create_timer(0.3).timeout
	queue_free()


func _play_explosion_visual() -> void:
	if not sprite:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 3.0, 0.0), 0.3)
	tween.tween_property(sprite, "scale", sprite.scale * 2.5, 0.3)


# ============================================================================
# MIRROR MODE (T3)
# ============================================================================

func mirror_ability(ability_name: String, damage_mult: float = 0.5) -> void:
	"""Called by BoonEffectHandler when Murum uses an ability and T3 is active."""
	if mode != Mode.MIRROR or _mirror_used or is_dead:
		return
	_mirror_used = true

	# Flash to show activation
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 1.5, 0.7)

	# Spawn AoE damage at clone position (simplified ability mirror)
	var mirror_damage: int = int(clone_damage * damage_mult / 0.5)  # Normalize to base, then apply mult
	var radius: float = 100.0

	match ability_name:
		"wolkenbruch":
			radius = 150.0
			mirror_damage = int(40 * damage_mult)
		"machtbruch":
			radius = 130.0
			mirror_damage = int(35 * damage_mult)
		"machtstoss":
			radius = 120.0
			mirror_damage = int(30 * damage_mult)
		_:
			mirror_damage = int(20 * damage_mult)

	# Apply AoE damage
	var enemies := _get_enemies_in_radius(global_position, radius)
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(mirror_damage, null)

	# VFX
	BoonEffectHandler._spawn_raelear_vfx(global_position, radius)
	print("[RaelearClone] Mirrored %s for %d damage (x%d enemies)" % [ability_name, mirror_damage, enemies.size()])


# ============================================================================
# DURATION / CLEANUP
# ============================================================================

func _on_duration_expired() -> void:
	if is_dead or is_exploding:
		return

	# In CHASE mode: explode at current pos if enemies nearby, otherwise fade
	if mode == Mode.CHASE:
		var nearest := _find_nearest_enemy()
		if nearest and global_position.distance_to(nearest.global_position) < EXPLOSION_RADIUS:
			_start_explode()
			return

	# Fade out and die
	is_dead = true
	clone_expired.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


# ============================================================================
# DETECTION
# ============================================================================

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not body.get("is_dead"):
		if not target_enemy or not is_instance_valid(target_enemy):
			target_enemy = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_enemy:
		target_enemy = _find_nearest_enemy()


# ============================================================================
# UTILITY
# ============================================================================

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = DETECTION_RANGE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_dead") or enemy.get("is_destroyed"):
			continue
		var dist: float = enemy.global_position.distance_to(global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D

	return nearest


func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var result: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_dead") or enemy.get("is_destroyed"):
			continue
		if enemy.has_method("take_damage"):
			if enemy.global_position.distance_to(center) <= radius:
				result.append(enemy)
	return result
