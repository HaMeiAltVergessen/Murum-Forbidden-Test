extends Area2D
## Shadow Scythe - Boomerang Projectile for Lythrun (COMMIT 019.5)
## Pierces enemies and returns to player on command or wall hit

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var trail: GPUParticles2D = $ShadowTrail if has_node("ShadowTrail") else null
@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

# ============ PROPERTIES ============
var direction: Vector2 = Vector2.RIGHT
var damage: float = 30.0
var speed: float = 250.0
var owner_player = null
var can_pierce: bool = true
var is_returning: bool = false

# ============ PIERCE TRACKING ============
var hit_enemies: Array = []

func _ready() -> void:
	print("[Shadow Scythe] Spawned")

	# Visual setup - BRIGHTER and MORE VISIBLE
	if sprite:
		sprite.modulate = Color(0.8, 0.4, 1.0)  # Much brighter violet/purple
		sprite.scale = Vector2(1.5, 1.5)  # 50% larger for visibility

	if trail:
		trail.emitting = true

	if light:
		light.enabled = true
		light.color = Color(0.8, 0.4, 1.0)  # Brighter glow
		light.energy = 1.0  # Doubled brightness

	# Collision setup
	collision_layer = 0
	set_collision_layer_value(6, true)  # P2 Projectiles
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(4, true)   # Enemies
	set_collision_mask_value(2, true)   # P1 (in co-op)

	# Connect signals
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Rotate sprite (scythe spins)
	if sprite:
		sprite.rotation_degrees -= 720 * delta  # 2 rotations per second

	# Movement
	if is_returning:
		move_towards_player(delta)
	else:
		# Normal outward flight
		global_position += direction * speed * delta

	# Despawn if too far from player
	if owner_player and not is_returning:
		var distance = global_position.distance_to(owner_player.global_position)
		if distance > 1500:
			queue_free()

func move_towards_player(delta: float) -> void:
	"""Move back towards owner player"""
	if not owner_player or not is_instance_valid(owner_player):
		queue_free()
		return

	# Direction to player
	var to_player = (owner_player.global_position - global_position).normalized()

	# Move faster on return
	global_position += to_player * speed * 1.5 * delta

	# Check if reached player
	if global_position.distance_to(owner_player.global_position) < 30:
		# Return to player
		if owner_player.has_method("on_scythe_returned"):
			owner_player.on_scythe_returned()
		queue_free()

func start_return_to_player(player) -> void:
	"""Start returning to player (boomerang)"""
	if is_returning:
		return

	print("[Shadow Scythe] Returning to player")

	is_returning = true
	owner_player = player

	# VFX changes (brighter)
	if sprite:
		sprite.modulate = Color(0.7, 0.3, 1.0)

	if light:
		light.energy = 0.8

func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with bodies"""
	if is_returning:
		# During return, ignore collisions
		return

	# Wall hit
	if body.is_in_group("walls") or body.is_in_group("world"):
		print("[Shadow Scythe] Wall hit! Returning...")
		# COMMIT 024: Validate owner before returning
		if owner_player and is_instance_valid(owner_player):
			start_return_to_player(owner_player)
		else:
			queue_free()  # Owner is invalid, destroy scythe
		return

	# Enemy hit
	if body.has_method("take_damage"):
		# Check if already hit this enemy
		if body in hit_enemies:
			return  # Pierce through, no second hit

		# Damage enemy
		body.take_damage(damage)
		hit_enemies.append(body)

		print("[Shadow Scythe] Hit enemy! Damage: %.1f" % damage)

		# VFX
		spawn_hit_vfx()

		# If not piercing, destroy
		if not can_pierce:
			queue_free()

func spawn_hit_vfx() -> void:
	"""Spawn impact VFX"""
	# Placeholder
	print("[Shadow Scythe] Hit VFX at ", global_position)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("scythe_hit")
