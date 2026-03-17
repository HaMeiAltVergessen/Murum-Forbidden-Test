extends KollektivCore
## Mobility Core (Navigation) — Ceiling position
## Active: Platforms shift (hin/her), laser walls sweep through arena (10 DMG)
## Destroyed: Platforms stable, arena layout constant

# ============ CONFIGURATION ============
const PLATFORM_MOVE_SPEED: float = 60.0
const PLATFORM_MOVE_RANGE: float = 150.0
const LASER_WALL_DAMAGE: int = 10
const LASER_WALL_INTERVAL: float = 6.0

# ============ STATE ============
var _laser_timer: float = 0.0


func _ready() -> void:
	core_name = "Navigationskern"
	max_hp = 120.0
	core_color = Color(0.3, 0.9, 0.4)  # Green
	super._ready()


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Laser wall timer
	_laser_timer += delta
	if _laser_timer >= LASER_WALL_INTERVAL / speed_mult:
		_laser_timer = 0.0
		_spawn_laser_wall()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)
	# Start platform movement
	for platform in get_tree().get_nodes_in_group("kollektiv_platform"):
		if platform.has_method("start_moving"):
			platform.start_moving(PLATFORM_MOVE_SPEED * speed_mult, PLATFORM_MOVE_RANGE)


func _on_systems_deactivated() -> void:
	set_process(false)
	# Stop platforms
	for platform in get_tree().get_nodes_in_group("kollektiv_platform"):
		if platform.has_method("stop_moving"):
			platform.stop_moving()
	# Clear laser walls
	for laser in get_tree().get_nodes_in_group("laser_wall"):
		if is_instance_valid(laser):
			laser.queue_free()


func _spawn_laser_wall() -> void:
	"""Spawn a laser wall that sweeps through the arena"""
	var laser_scene_path: String = "res://bosses/kollektiv/entities/laser_wall.tscn"

	# Alternate between horizontal and vertical
	var is_horizontal: bool = randi() % 2 == 0

	if ResourceLoader.exists(laser_scene_path):
		var scene: PackedScene = load(laser_scene_path)
		var laser = scene.instantiate()
		laser.damage = int(LASER_WALL_DAMAGE * damage_mult)
		laser.is_horizontal = is_horizontal
		laser.move_speed = 200.0 * speed_mult
		if cognition_active:
			laser.move_speed *= 1.3  # Faster with cognition
		get_parent().add_child(laser)
	else:
		_spawn_placeholder_laser_wall(is_horizontal)


func _spawn_placeholder_laser_wall(horizontal: bool) -> void:
	"""Fallback laser wall"""
	var laser := Area2D.new()
	laser.name = "LaserWall"
	laser.collision_layer = 128
	laser.collision_mask = 1024
	laser.monitoring = true
	laser.monitorable = false
	laser.add_to_group("laser_wall")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()

	var visual := ColorRect.new()

	if horizontal:
		rect.size = Vector2(2800, 16)
		laser.global_position = Vector2(1400, 0)  # Start at top
		visual.size = Vector2(2800, 12)
		visual.position = Vector2(-1400, -6)
	else:
		rect.size = Vector2(16, 2800)
		laser.global_position = Vector2(0, 1400)  # Start at left
		visual.size = Vector2(12, 2800)
		visual.position = Vector2(-6, -1400)

	shape.shape = rect
	laser.add_child(shape)

	visual.color = Color(1.0, 0.3, 0.3, 0.6)
	laser.add_child(visual)

	# Warning phase
	laser.monitoring = false
	get_parent().add_child(laser)

	# Flash warning
	var tween: Tween = laser.create_tween()
	tween.tween_property(visual, "modulate:a", 0.2, 0.3)
	tween.tween_property(visual, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(laser):
			laser.monitoring = true
	)

	# Connect damage
	var dmg: int = int(LASER_WALL_DAMAGE * damage_mult)
	laser.area_entered.connect(func(area: Area2D):
		if area is HurtboxComponent:
			var hurtbox: HurtboxComponent = area
			var hurtbox_owner = hurtbox.get_parent()
			if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
				hurtbox.take_damage(dmg, Vector2.UP * 80, 0.15)
	)

	# Movement
	var move_speed: float = 200.0 * speed_mult
	if cognition_active:
		move_speed *= 1.3

	var move_tween: Tween = laser.create_tween()
	if horizontal:
		move_tween.tween_property(laser, "global_position:y", 2800.0, 2800.0 / move_speed)
	else:
		move_tween.tween_property(laser, "global_position:x", 2800.0, 2800.0 / move_speed)
	move_tween.tween_callback(func():
		if is_instance_valid(laser):
			laser.queue_free()
	)
