extends Node
## Shadow Dash + Dodge system extracted from lythrun_player.gd
## Shadow Dash: Teleport-dash with afterimage stun hitboxes (LB)
## Dodge: Simple dodge roll with i-frames (B button)
class_name ShadowDashSystem

# ============ DODGE CONSTANTS ============
const DODGE_DURATION: float = 0.5
const DODGE_SPEED: float = 300.0
const DODGE_COOLDOWN: float = 1.0

# ============ SHADOW DASH CONSTANTS ============
const SHADOW_DASH_DURATION: float = 0.4
const SHADOW_DASH_SPEED: float = 450.0
const SHADOW_DASH_COOLDOWN: float = 1.5  # COMMIT 024: Reduced from 2.0s
const AFTERIMAGE_LIFETIME: float = 1.0
const AFTERIMAGE_STUN_RADIUS: float = 80.0

# ============ STATE ============
var shadow_dash_active: bool = false
var shadow_dash_cooldown_active: bool = false
var dodge_cooldown_active: bool = false

# Player reference (set in _ready)
var player = null

func _ready() -> void:
	player = get_parent()


# ============ PUBLIC API ============

func shadow_dash() -> void:
	"""Enhanced dash with afterimage stun effect"""
	if shadow_dash_active or shadow_dash_cooldown_active:
		return

	if player.is_attacking or player.is_dodging:
		return

	shadow_dash_active = true
	shadow_dash_cooldown_active = true
	player.is_dashing = true

	# Dash direction
	var dash_direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT

	# VFX: Shadow trail
	if player.shadow_trail:
		player.shadow_trail.emitting = true

	# Movement with afterimages
	var start_time = Time.get_ticks_msec() / 1000.0
	var last_afterimage_time = start_time

	while (Time.get_ticks_msec() / 1000.0 - start_time) < SHADOW_DASH_DURATION:
		player.velocity.x = dash_direction.x * SHADOW_DASH_SPEED
		player.velocity.y = 0  # Disable gravity during dash
		player.move_and_slide()

		# Spawn afterimage every 0.05s
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_afterimage_time >= 0.05:
			last_afterimage_time = current_time
			spawn_stun_afterimage()

		await get_tree().process_frame

	player.velocity.x = 0
	shadow_dash_active = false
	player.is_dashing = false

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("lythrun_shadow_dash")

	# Cooldown
	await get_tree().create_timer(SHADOW_DASH_COOLDOWN).timeout
	shadow_dash_cooldown_active = false
	print("[Shadow Dash] Cooldown complete")


func dodge() -> void:
	"""Simple dodge roll with i-frames (mapped to B button)"""
	if player.is_dodging or dodge_cooldown_active:
		print("[Dodge] Cooldown active or already dodging")
		return

	if player.is_attacking or shadow_dash_active:
		print("[Dodge] Blocked by other action")
		return

	player.is_dodging = true
	dodge_cooldown_active = true

	# Dodge direction (prefer movement input, fall back to facing direction)
	var input_vector = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
	var dodge_direction = Vector2.ZERO

	if input_vector.length() > 0.1:
		dodge_direction = input_vector.normalized()
	else:
		dodge_direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT

	print("[Dodge] Started - Direction: %s" % dodge_direction)

	# Disable hurtbox during dodge (i-frames)
	if player.hurtbox:
		player.hurtbox.set_deferred("monitoring", false)

	# Perform dodge movement
	var start_time = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0 - start_time) < DODGE_DURATION:
		player.velocity = dodge_direction * DODGE_SPEED
		player.move_and_slide()
		await get_tree().process_frame

	# Re-enable hurtbox
	if player.hurtbox:
		player.hurtbox.set_deferred("monitoring", true)

	player.velocity = Vector2.ZERO
	player.is_dodging = false

	print("[Dodge] Completed")

	# Cooldown
	await get_tree().create_timer(DODGE_COOLDOWN).timeout
	dodge_cooldown_active = false
	print("[Dodge] Cooldown complete")


# ============ AFTERIMAGE ============

func spawn_stun_afterimage() -> void:
	"""Spawn afterimage with stun hitbox"""
	if not player.sprite:
		return

	# Create afterimage sprite
	var afterimage = Sprite2D.new()
	afterimage.texture = player.sprite.texture
	if player.sprite.hframes > 1:
		afterimage.hframes = player.sprite.hframes
	if player.sprite.vframes > 1:
		afterimage.vframes = player.sprite.vframes
	afterimage.frame = player.sprite.frame
	afterimage.flip_h = player.sprite.flip_h
	afterimage.modulate = Color(0.3, 0, 0.6, 0.7)  # Dark violet

	player.get_parent().add_child(afterimage)
	afterimage.global_position = player.global_position

	# Stun hitbox
	var stun_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = AFTERIMAGE_STUN_RADIUS

	collision.shape = shape
	stun_area.add_child(collision)
	afterimage.add_child(stun_area)

	# Collision setup
	stun_area.collision_layer = 0
	stun_area.set_collision_layer_value(6, true)  # P2 Projectiles
	stun_area.collision_mask = 0
	stun_area.set_collision_mask_value(4, true)  # Enemies

	# Enable monitoring
	stun_area.monitoring = true
	stun_area.monitorable = true

	# Stun on contact
	stun_area.body_entered.connect(func(body):
		print("[Shadow Dash Afterimage] Hit: %s" % body.name)
		if body.has_method("apply_stun"):
			body.apply_stun(0.5)
			spawn_stun_vfx(body.global_position)
			print("[Shadow Dash Afterimage] Stunned %s for 0.5s" % body.name)
		elif body.has_method("stun"):
			body.stun(0.5)
			spawn_stun_vfx(body.global_position)
			print("[Shadow Dash Afterimage] Stunned %s for 0.5s (via stun method)" % body.name)
		else:
			print("[Shadow Dash Afterimage] %s has no stun method!" % body.name)
	)

	# Fade out
	var tween = player.create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tween.tween_callback(afterimage.queue_free)


# ============ VFX ============

func spawn_stun_vfx(pos: Vector2) -> void:
	"""Spawn stun effect VFX"""
	print("[VFX] Stun effect at ", pos)
