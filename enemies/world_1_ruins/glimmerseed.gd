extends CharacterBody2D
class_name Glimmerseed

## Glimmersaat (Glimmerseed) - SWARM
## Small explosive enemy that spawns from destructible corpse traps.
## Zigzags toward player, explodes on death or after 10 seconds.
## Explosion damages players AND other enemies (chain explosions).

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 25
const MOVE_SPEED: float = 140.0
const EXPLOSION_DAMAGE: int = 30
const EXPLOSION_RADIUS: float = 180.0
const FUSE_DURATION: float = 2.0   # Time from death to explosion
const AUTO_EXPLODE_TIME: float = 10.0  # Auto-explode after 10s alive
const ZIGZAG_FREQUENCY: float = 3.0  # How fast the zigzag oscillates
const ZIGZAG_AMPLITUDE: float = 80.0  # How wide the zigzag is

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = MAX_HP
var is_dead: bool = false
var alive_timer: float = 0.0
var fuse_timer: float = 0.0
var is_fuse_active: bool = false
var has_exploded: bool = false
var zigzag_offset: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var detection_area: Area2D = $DetectionArea

# ============================================================================
# SIGNALS
# ============================================================================

signal died
signal exploded(position: Vector2, damage: int, radius: float)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("glimmerseed")

	# Randomize zigzag phase so multiple seeds don't move identically
	zigzag_offset = randf() * TAU

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Connect detection
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	print("[Glimmerseed] Spawned at %v" % global_position)


# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	move_and_slide()


# ============================================================================
# PROCESS
# ============================================================================

var target_player: CharacterBody2D = null

func _process(delta: float) -> void:
	if has_exploded:
		return

	if is_dead:
		# Fuse countdown
		if is_fuse_active:
			fuse_timer += delta
			_update_fuse_visual()
			if fuse_timer >= FUSE_DURATION:
				_explode()
		return

	# Alive timer
	alive_timer += delta
	if alive_timer >= AUTO_EXPLODE_TIME:
		# Auto-explode
		print("[Glimmerseed] Auto-exploding after %ds!" % AUTO_EXPLODE_TIME)
		_start_fuse()
		return

	# Movement: zigzag toward player
	if target_player and is_instance_valid(target_player):
		var direction = (target_player.global_position - global_position).normalized()

		# Zigzag perpendicular to movement direction
		var perpendicular = Vector2(-direction.y, direction.x)
		var zigzag = sin(alive_timer * ZIGZAG_FREQUENCY + zigzag_offset) * ZIGZAG_AMPLITUDE
		var move_dir = direction + perpendicular * (zigzag / ZIGZAG_AMPLITUDE) * 0.5

		velocity.x = move_dir.x * MOVE_SPEED
		# Only apply vertical movement if airborne or chasing upward
		if not is_on_floor() or direction.y < -0.3:
			velocity.y = move_dir.y * MOVE_SPEED * 0.3

		# Face direction
		if sprite:
			sprite.flip_h = direction.x < 0

	# Blink faster as time runs out (warning effect)
	if alive_timer > AUTO_EXPLODE_TIME * 0.7:
		var blink_speed = 8.0 + (alive_timer / AUTO_EXPLODE_TIME) * 12.0
		if sprite:
			var blink = (sin(alive_timer * blink_speed) + 1.0) / 2.0
			sprite.modulate = Color(1.0 + blink * 0.5, 1.0, 1.0 - blink * 0.3)


# ============================================================================
# DAMAGE
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, _hitstun: float) -> void:
	current_hp -= damage
	current_hp = max(current_hp, 0)

	# Visual feedback
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
		await get_tree().create_timer(0.1).timeout
		if sprite:
			sprite.modulate = Color.WHITE

	# Apply knockback
	if knockback.length() > 0:
		velocity = knockback

	AudioManager.play_sfx("enemy_hurt")
	EventBus.enemy_damaged.emit(self, damage)

	if current_hp <= 0:
		_start_fuse()


func take_damage(amount: int, _attacker: Node = null) -> void:
	"""Public API for external damage"""
	if is_dead or has_exploded:
		return
	_on_damage_received(amount, Vector2.ZERO, 0.0)


# ============================================================================
# FUSE & EXPLOSION
# ============================================================================

func _start_fuse() -> void:
	"""Starts the 2-second explosion countdown"""
	if is_dead:
		return

	is_dead = true
	is_fuse_active = true
	fuse_timer = 0.0

	# Stop movement
	velocity = Vector2.ZERO
	set_physics_process(false)

	# Disable hurtbox (can't be hit during fuse)
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	died.emit()
	EventBus.enemy_died.emit(self, global_position)

	print("[Glimmerseed] Fuse started! Exploding in %ds!" % FUSE_DURATION)


func _update_fuse_visual() -> void:
	"""Blinking and color change during fuse countdown"""
	if not sprite:
		return

	var progress = fuse_timer / FUSE_DURATION  # 0.0 -> 1.0
	var blink_speed = 5.0 + progress * 20.0  # Faster blinking as it gets closer
	var blink = (sin(fuse_timer * blink_speed) + 1.0) / 2.0

	# Color shifts from white -> red/orange as fuse progresses
	sprite.modulate = Color(
		1.0 + progress * 1.5 + blink * 0.5,
		1.0 - progress * 0.7,
		1.0 - progress * 0.8,
		1.0
	)

	# Scale pulse
	var pulse = 1.0 + blink * 0.15 * progress
	sprite.scale = sprite.scale * pulse / max(sprite.scale.x, 0.01) * sprite.scale.x


func _explode() -> void:
	"""Triggers the explosion"""
	if has_exploded:
		return

	has_exploded = true
	print("[Glimmerseed] EXPLOSION at %v!" % global_position)

	# Emit explosion signal
	exploded.emit(global_position, EXPLOSION_DAMAGE, EXPLOSION_RADIUS)

	# Create explosion area to damage everyone (players AND enemies)
	var explosion = Area2D.new()
	explosion.collision_layer = 0
	explosion.collision_mask = 1024 | 48  # Hurtbox layers for both enemies and players
	explosion.global_position = global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = EXPLOSION_RADIUS
	shape.shape = circle
	explosion.add_child(shape)

	get_tree().current_scene.add_child(explosion)

	# Wait one physics frame for overlaps
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(explosion):
		var overlapping = explosion.get_overlapping_areas()
		for area in overlapping:
			if area is HurtboxComponent:
				var target = area.get_parent()
				# Don't damage self (already dead anyway)
				if target == self:
					continue

				var kb_dir = (area.global_position - global_position).normalized()
				area.take_damage(EXPLOSION_DAMAGE, kb_dir * 300.0, 0.3, self)
				print("[Glimmerseed] Explosion hit: %s" % target.name)

		explosion.queue_free()

	# Visual: explosion flash
	_play_explosion_visual()

	# Audio
	AudioManager.play_sfx("enemy_death")

	# Cleanup
	await get_tree().create_timer(0.3).timeout
	queue_free()


func _play_explosion_visual() -> void:
	"""Visual explosion effect"""
	if not sprite:
		return

	# Bright flash and expand
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(3.0, 2.0, 0.5, 0.0), 0.3)
	tween.tween_property(sprite, "scale", sprite.scale * 3.0, 0.3)


# ============================================================================
# DETECTION
# ============================================================================

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("player2"):
		target_player = body as CharacterBody2D


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null


# ============================================================================
# UTILITY
# ============================================================================

func is_alive() -> bool:
	return not is_dead
