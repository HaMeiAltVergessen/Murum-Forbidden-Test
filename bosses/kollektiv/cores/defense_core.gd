extends KollektivCore
## Defense Core (Weapon Control) — Left wall
## Active: 2-3 Auto-Turrets (8 DMG every 2s), Laser barriers (12 DMG)
## Destroyed: Turrets deactivate, no more projectile salvos

# ============ CONFIGURATION ============
const TURRET_COUNT: int = 3
const TURRET_DAMAGE: int = 8
const TURRET_FIRE_RATE: float = 2.0
const LASER_BARRIER_DAMAGE: int = 12
const LASER_BARRIER_INTERVAL: float = 8.0

# ============ STATE ============
var _turrets: Array = []
var _laser_timer: float = 0.0


func _ready() -> void:
	core_name = "Verteidigungskern"
	max_hp = 150.0
	core_color = Color(0.3, 0.5, 0.9)  # Blue
	super._ready()


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Laser barrier timer
	_laser_timer += delta
	if _laser_timer >= LASER_BARRIER_INTERVAL / speed_mult:
		_laser_timer = 0.0
		_fire_laser_barrier()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)
	_spawn_turrets()


func _on_systems_deactivated() -> void:
	set_process(false)
	_destroy_turrets()


func _spawn_turrets() -> void:
	"""Spawn turrets near the defense core"""
	var turret_positions: Array = [
		global_position + Vector2(0, -200),
		global_position + Vector2(0, 200),
		global_position + Vector2(80, 0),
	]

	var turret_scene_path: String = "res://bosses/kollektiv/entities/turret.tscn"
	var has_scene: bool = ResourceLoader.exists(turret_scene_path)

	for i in range(TURRET_COUNT):
		var turret: Node2D
		if has_scene:
			var scene: PackedScene = load(turret_scene_path)
			turret = scene.instantiate()
		else:
			turret = _create_placeholder_turret()

		turret.global_position = turret_positions[i]
		if turret.has_method("set_config"):
			turret.set_config(int(TURRET_DAMAGE * damage_mult), TURRET_FIRE_RATE / speed_mult)
		turret.set_meta("owner_core", self)
		get_parent().add_child(turret)
		_turrets.append(turret)

	print("[%s] Spawned %d turrets" % [core_name, _turrets.size()])


func _create_placeholder_turret() -> Node2D:
	"""Create a simple turret that fires projectiles"""
	var turret := Node2D.new()
	turret.name = "Turret"
	turret.add_to_group("kollektiv_turret")

	# Visual
	var visual := ColorRect.new()
	visual.size = Vector2(30, 30)
	visual.position = Vector2(-15, -15)
	visual.color = Color(0.3, 0.5, 0.9, 0.8)
	turret.add_child(visual)

	# Fire timer
	var timer := Timer.new()
	timer.name = "FireTimer"
	timer.wait_time = TURRET_FIRE_RATE
	timer.one_shot = false
	turret.add_child(timer)

	# Script-less turret: use meta and timer callback
	timer.timeout.connect(_on_turret_fire.bind(turret))
	timer.start()

	return turret


func _on_turret_fire(turret: Node2D) -> void:
	"""Turret fires a projectile toward the player"""
	if not is_systems_active or is_destroyed:
		return
	if not is_instance_valid(turret):
		return

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var dir: Vector2 = (player.global_position - turret.global_position).normalized()

	# Apply cognition: slight homing correction
	if not cognition_active:
		# Chaotic: add random deviation
		dir = dir.rotated(randf_range(-0.4, 0.4))

	_spawn_projectile(turret.global_position, dir, int(TURRET_DAMAGE * damage_mult))


func _destroy_turrets() -> void:
	for turret in _turrets:
		if is_instance_valid(turret):
			# Flash and destroy
			turret.queue_free()
	_turrets.clear()


func _fire_laser_barrier() -> void:
	"""Fire a horizontal laser barrier across the arena"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Laser at player's Y position (with some offset)
	var laser_y: float = player.global_position.y + randf_range(-100, 100)

	var laser_scene_path: String = "res://bosses/kollektiv/entities/laser_wall.tscn"
	if ResourceLoader.exists(laser_scene_path):
		var scene: PackedScene = load(laser_scene_path)
		var laser = scene.instantiate()
		laser.global_position = Vector2(0, laser_y)
		laser.damage = int(LASER_BARRIER_DAMAGE * damage_mult)
		laser.set_meta("horizontal", true)
		get_parent().add_child(laser)
	else:
		_spawn_placeholder_laser(laser_y)


func _spawn_placeholder_laser(y_pos: float) -> void:
	"""Quick laser barrier using Area2D"""
	var laser := Area2D.new()
	laser.name = "LaserBarrier"
	laser.global_position = Vector2(0, y_pos)
	laser.collision_layer = 128
	laser.collision_mask = 1024
	laser.monitoring = true
	laser.monitorable = false
	laser.add_to_group("laser_wall")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2800, 20)
	shape.shape = rect
	shape.position = Vector2(1400, 0)
	laser.add_child(shape)

	# Visual: red line
	var visual := ColorRect.new()
	visual.size = Vector2(2800, 8)
	visual.position = Vector2(0, -4)
	visual.color = Color(1.0, 0.2, 0.2, 0.7)
	laser.add_child(visual)

	# Warning: flash for 0.5s before activating
	laser.monitoring = false
	get_parent().add_child(laser)

	# Warning phase
	var tween := laser.create_tween()
	tween.tween_property(visual, "modulate:a", 0.3, 0.2)
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
				hurtbox.take_damage(int(LASER_BARRIER_DAMAGE * damage_mult), Vector2.UP * 100, 0.2)
	)

	# Auto-destroy
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(laser):
		laser.queue_free()


func _spawn_projectile(from: Vector2, dir: Vector2, dmg: int) -> void:
	"""Spawn a generic projectile"""
	var proj_scene_path: String = "res://bosses/kollektiv/entities/kollektiv_projectile.tscn"
	if ResourceLoader.exists(proj_scene_path):
		var scene: PackedScene = load(proj_scene_path)
		var proj = scene.instantiate()
		proj.global_position = from
		proj.direction = dir
		proj.damage = dmg
		get_parent().add_child(proj)
	else:
		_spawn_placeholder_projectile(from, dir, dmg)


func _spawn_placeholder_projectile(from: Vector2, dir: Vector2, dmg: int) -> void:
	"""Fallback projectile"""
	var proj := Area2D.new()
	proj.name = "TurretProjectile"
	proj.global_position = from
	proj.collision_layer = 128
	proj.collision_mask = 1024
	proj.monitoring = true
	proj.monitorable = false

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	proj.add_child(shape)

	var visual := ColorRect.new()
	visual.size = Vector2(10, 10)
	visual.position = Vector2(-5, -5)
	visual.color = Color(0.3, 0.6, 1.0)
	proj.add_child(visual)

	get_parent().add_child(proj)

	# Movement + lifetime
	var speed: float = 300.0
	proj.set_meta("dir", dir)
	proj.set_meta("speed", speed)
	proj.set_meta("dmg", dmg)

	# Connect damage
	proj.area_entered.connect(func(area: Area2D):
		if area is HurtboxComponent:
			var hurtbox: HurtboxComponent = area
			var hurtbox_owner = hurtbox.get_parent()
			if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
				hurtbox.take_damage(dmg, dir * 100, 0.1)
				if is_instance_valid(proj):
					proj.queue_free()
	)

	# Simple movement via process
	proj.set_process(true)
	proj.set_script(load("res://bosses/kollektiv/entities/kollektiv_projectile.gd") if ResourceLoader.exists("res://bosses/kollektiv/entities/kollektiv_projectile.gd") else null)

	# Lifetime auto-destroy
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(proj):
		proj.queue_free()
