extends Node2D
## Void Rift - Growing AoE trap that explodes (COMMIT 019.5)
## Grows from min to max radius over duration, then explodes

@onready var area: Area2D = $Area2D if has_node("Area2D") else null
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null
@onready var rift_vfx: GPUParticles2D = $RiftVFX if has_node("RiftVFX") else null
@onready var growth_particles: GPUParticles2D = $GrowthParticles if has_node("GrowthParticles") else null

# ============ PROPERTIES ============
var min_radius: float = 220.0  # 3m
var max_radius: float = 650.0  # 9m
var duration: float = 3.0
var damage: float = 80.0

var current_radius: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	print("[Void Rift] Created")

func setup(min_r: float, max_r: float, dur: float, dmg: float) -> void:
	"""Initialize rift parameters"""
	min_radius = min_r
	max_radius = max_r
	duration = dur
	damage = dmg

	current_radius = min_radius

	# Setup collision shape
	if not area:
		area = Area2D.new()
		add_child(area)

	if not collision:
		collision = CollisionShape2D.new()
		area.add_child(collision)

	var shape = CircleShape2D.new()
	shape.radius = current_radius
	collision.shape = shape

	# Collision setup
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(4, true)  # Enemies

	# VFX
	if rift_vfx:
		rift_vfx.scale = Vector2(current_radius / 100.0, current_radius / 100.0)
		rift_vfx.emitting = true

	if growth_particles:
		growth_particles.emitting = true

	print("[Void Rift] Setup complete. Min: %.0f | Max: %.0f | Duration: %.1fs" % [min_radius, max_radius, duration])

func _process(delta: float) -> void:
	elapsed_time += delta

	# Growth (linear)
	var growth_factor = elapsed_time / duration
	current_radius = lerp(min_radius, max_radius, growth_factor)

	# Update collision shape
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = current_radius

	# Update VFX
	if rift_vfx:
		rift_vfx.scale = Vector2(current_radius / 100.0, current_radius / 100.0)

	# Explode after duration
	if elapsed_time >= duration:
		explode()

func explode() -> void:
	"""Trigger explosion and damage enemies"""
	print("[Void Rift] EXPLODING! Radius: %.0fpx" % current_radius)

	# Damage all enemies in radius
	if area:
		var enemies = area.get_overlapping_bodies()
		for enemy in enemies:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
				print("[Void Rift] Damaged enemy: %s" % enemy.name)

	# Explosion VFX
	spawn_explosion_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_rift_explode")

	# Camera shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(15.0, 0.6)

	# Cleanup
	queue_free()

func spawn_explosion_vfx() -> void:
	"""Spawn explosion visual effect"""
	# Placeholder
	print("[Void Rift] Explosion VFX at ", global_position)
