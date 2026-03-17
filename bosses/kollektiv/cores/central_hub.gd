extends KollektivCore
## Central Hub — Final phase after all 5 cores are destroyed
## 80 HP, massive lasers from walls, energy bursts, platforms collapse
## No drones, no turrets — pure environmental danger

# ============ CONFIGURATION ============
const WALL_LASER_DAMAGE: int = 15
const WALL_LASER_INTERVAL: float = 3.0
const ENERGY_BURST_DAMAGE: int = 20
const ENERGY_BURST_INTERVAL: float = 5.0
const ENERGY_BURST_RADIUS: float = 150.0
const PLATFORM_COLLAPSE_INTERVAL: float = 4.0

# ============ STATE ============
var _wall_laser_timer: float = 0.0
var _energy_burst_timer: float = 0.0
var _platform_collapse_timer: float = 0.0
var _collapsed_platforms: Array = []


func _ready() -> void:
	core_name = "Zentraler Kern"
	max_hp = 80.0
	core_color = Color(1.0, 0.85, 0.3)  # Gold
	super._ready()


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Wall lasers
	_wall_laser_timer += delta
	if _wall_laser_timer >= WALL_LASER_INTERVAL:
		_wall_laser_timer = 0.0
		_fire_wall_laser()

	# Energy bursts
	_energy_burst_timer += delta
	if _energy_burst_timer >= ENERGY_BURST_INTERVAL:
		_energy_burst_timer = 0.0
		_trigger_energy_burst()

	# Platform collapse
	_platform_collapse_timer += delta
	if _platform_collapse_timer >= PLATFORM_COLLAPSE_INTERVAL:
		_platform_collapse_timer = 0.0
		_collapse_random_platform()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)
	print("[%s] Final phase activated — environmental chaos!" % core_name)


func _on_systems_deactivated() -> void:
	set_process(false)


func _fire_wall_laser() -> void:
	"""Fire massive lasers from the walls"""
	# Pick random wall: left, right, top, bottom
	var wall: int = randi() % 4
	var laser := Area2D.new()
	laser.name = "WallLaser"
	laser.collision_layer = 128
	laser.collision_mask = 1024
	laser.monitoring = false
	laser.monitorable = false
	laser.add_to_group("laser_wall")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var visual := ColorRect.new()

	match wall:
		0:  # Left wall — horizontal beam
			rect.size = Vector2(2800, 30)
			laser.global_position = Vector2(1400, global_position.y + randf_range(-200, 200))
			visual.size = Vector2(2800, 20)
			visual.position = Vector2(-1400, -10)
		1:  # Right wall
			rect.size = Vector2(2800, 30)
			laser.global_position = Vector2(1400, global_position.y + randf_range(-200, 200))
			visual.size = Vector2(2800, 20)
			visual.position = Vector2(-1400, -10)
		2:  # Top — vertical beam
			rect.size = Vector2(30, 2800)
			laser.global_position = Vector2(global_position.x + randf_range(-300, 300), 1400)
			visual.size = Vector2(20, 2800)
			visual.position = Vector2(-10, -1400)
		3:  # Bottom
			rect.size = Vector2(30, 2800)
			laser.global_position = Vector2(global_position.x + randf_range(-300, 300), 1400)
			visual.size = Vector2(20, 2800)
			visual.position = Vector2(-10, -1400)

	shape.shape = rect
	laser.add_child(shape)

	visual.color = Color(1.0, 0.85, 0.3, 0.5)  # Gold laser
	laser.add_child(visual)

	get_parent().add_child(laser)

	# Warning flash
	var tween: Tween = laser.create_tween()
	tween.tween_property(visual, "modulate:a", 0.2, 0.3)
	tween.tween_property(visual, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		if is_instance_valid(laser):
			laser.monitoring = true
	)

	# Connect damage
	laser.area_entered.connect(func(area: Area2D):
		if area is HurtboxComponent:
			var hurtbox: HurtboxComponent = area
			var hurtbox_owner = hurtbox.get_parent()
			if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
				hurtbox.take_damage(WALL_LASER_DAMAGE, Vector2.UP * 120, 0.2)
	)

	# Auto-destroy
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(laser):
		laser.queue_free()


func _trigger_energy_burst() -> void:
	"""Unstable energy burst AoE near player"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Multiple bursts
	var burst_count: int = randi_range(2, 3)
	for i in range(burst_count):
		var offset: Vector2 = Vector2(randf_range(-200, 200), randf_range(-150, 150))
		var target_pos: Vector2 = player.global_position + offset

		# Warning
		var warning := ColorRect.new()
		warning.size = Vector2(ENERGY_BURST_RADIUS * 2, ENERGY_BURST_RADIUS * 2)
		warning.position = target_pos - Vector2(ENERGY_BURST_RADIUS, ENERGY_BURST_RADIUS)
		warning.color = Color(1.0, 0.85, 0.3, 0.15)
		get_parent().add_child(warning)

		var tween: Tween = warning.create_tween()
		tween.tween_property(warning, "color:a", 0.4, 0.6)

		# Delay between bursts
		await get_tree().create_timer(0.8 + i * 0.3).timeout

		if is_instance_valid(warning):
			warning.queue_free()

		if is_destroyed:
			return

		# Damage
		var hitbox := HitboxComponent.new()
		hitbox.damage = ENERGY_BURST_DAMAGE
		hitbox.knockback_force = 300.0
		hitbox.hitstun_duration = 0.3
		hitbox.collision_layer = 128
		hitbox.collision_mask = 1024

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = ENERGY_BURST_RADIUS
		shape.shape = circle
		hitbox.add_child(shape)

		hitbox.global_position = target_pos
		get_parent().add_child(hitbox)
		hitbox.owner = self
		hitbox.activate()

		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(hitbox):
			hitbox.queue_free()


func _collapse_random_platform() -> void:
	"""Make a random platform temporarily collapse"""
	var platforms: Array = get_tree().get_nodes_in_group("kollektiv_platform")
	if platforms.is_empty():
		return

	# Filter out already collapsed
	var available: Array = platforms.filter(func(p): return p not in _collapsed_platforms)
	if available.is_empty():
		# Restore all and start over
		for p in _collapsed_platforms:
			if is_instance_valid(p):
				p.visible = true
				p.set_deferred("collision_layer", 1)
		_collapsed_platforms.clear()
		return

	var platform = available[randi() % available.size()]
	_collapsed_platforms.append(platform)

	# Flash warning
	var visual = platform.get_node_or_null("Visual") if platform.has_node("Visual") else null
	if visual:
		var tween: Tween = platform.create_tween()
		tween.tween_property(visual, "modulate", Color(1.0, 0.3, 0.3), 0.3)
		tween.tween_property(visual, "modulate", Color.WHITE, 0.3)
		tween.tween_property(visual, "modulate", Color(1.0, 0.3, 0.3), 0.3)
		tween.tween_callback(func():
			if is_instance_valid(platform):
				platform.set_deferred("collision_layer", 0)
				platform.visible = false
		)

	# Restore after 3 seconds
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(platform):
		platform.visible = true
		platform.set_deferred("collision_layer", 1)
		_collapsed_platforms.erase(platform)
