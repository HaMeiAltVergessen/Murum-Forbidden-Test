extends Node2D
## Abgrund - Aerial slam with suction vortex (COMMIT 019.5)
## Creates a vortex that pulls enemies inward and damages over time

@onready var area: Area2D = $Area2D if has_node("Area2D") else null
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null
@onready var vfx: GPUParticles2D = $AbgrundVFX if has_node("AbgrundVFX") else null
@onready var suction_particles: GPUParticles2D = $SuctionParticles if has_node("SuctionParticles") else null

# ============ PROPERTIES ============
var radius: float = 220.0
var duration: float = 3.0
var suction_strength: float = 200.0
var damage_per_tick: float = 5.0

var elapsed_time: float = 0.0
var damage_timer: float = 0.0

func _ready() -> void:
	print("[Abgrund] Created")

func setup(r: float, dur: float, suction: float, dmg: float) -> void:
	"""Initialize abgrund parameters"""
	radius = r
	duration = dur
	suction_strength = suction
	damage_per_tick = dmg

	# Setup collision
	if not area:
		area = Area2D.new()
		add_child(area)

	if not collision:
		collision = CollisionShape2D.new()
		area.add_child(collision)

	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape

	# Collision setup
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(4, true)  # Enemies
	area.set_collision_mask_value(2, true)  # P1
	area.set_collision_mask_value(3, true)  # P2

	# VFX
	if vfx:
		vfx.scale = Vector2(radius / 100.0, radius / 100.0)
		vfx.emitting = true

	if suction_particles:
		suction_particles.emitting = true

	print("[Abgrund] Setup complete. Radius: %.0f | Duration: %.1fs | Suction: %.0f" % [radius, duration, suction_strength])

func _process(delta: float) -> void:
	elapsed_time += delta
	damage_timer += delta

	# Apply suction force
	apply_suction(delta)

	# Damage every 0.5s
	if damage_timer >= 0.5:
		damage_timer = 0.0
		apply_damage()

	# Disappear after duration
	if elapsed_time >= duration:
		disappear()

func apply_suction(delta: float) -> void:
	"""Pull enemies towards center"""
	if not area:
		return

	var bodies = area.get_overlapping_bodies()

	for body in bodies:
		if body is CharacterBody2D or body.has_method("apply_force"):
			# Direction to center
			var to_center = (global_position - body.global_position).normalized()
			var distance = global_position.distance_to(body.global_position)

			# Suction stronger near edge
			var suction_factor = 1.0 - (distance / radius)
			var force = to_center * suction_strength * suction_factor * delta

			# Apply force
			if body is CharacterBody2D:
				body.velocity += force * 60  # Scale up for CharacterBody2D
			elif body.has_method("apply_force"):
				body.apply_force(force)

func apply_damage() -> void:
	"""Damage all enemies in vortex"""
	if not area:
		return

	var enemies = area.get_overlapping_bodies()

	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_per_tick)

func disappear() -> void:
	"""Fade out and despawn"""
	print("[Abgrund] Disappearing...")

	# Stop VFX
	if vfx:
		vfx.emitting = false

	if suction_particles:
		suction_particles.emitting = false

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
