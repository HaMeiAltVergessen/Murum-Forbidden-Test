extends KollektivCore
## Drone Fabricator Core — Right wall
## Active: Spawns drones every 5s (max 6), 4 types with weighted chances
## Destroyed: All active drones explode, no new spawns

# ============ CONFIGURATION ============
const SPAWN_INTERVAL: float = 5.0
const MAX_DRONES: int = 6

# Drone type weights (must sum ~1.0)
const DRONE_WEIGHTS: Array = [
	{"type": "melee",    "weight": 0.40, "scene": "res://bosses/kollektiv/entities/drone_melee.tscn"},
	{"type": "kamikaze", "weight": 0.25, "scene": "res://bosses/kollektiv/entities/drone_kamikaze.tscn"},
	{"type": "ranged",   "weight": 0.25, "scene": "res://bosses/kollektiv/entities/drone_ranged.tscn"},
	{"type": "repair",   "weight": 0.10, "scene": "res://bosses/kollektiv/entities/repair_bot.tscn"},
]

# ============ STATE ============
var _spawn_timer: float = 0.0
var _active_drones: Array = []


func _ready() -> void:
	core_name = "Drohnenfabrik"
	max_hp = 150.0
	core_color = Color(0.7, 0.3, 0.9)  # Purple
	super._ready()


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Clean up dead drones
	_active_drones = _active_drones.filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion())

	# Spawn timer
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL / speed_mult and _active_drones.size() < MAX_DRONES:
		_spawn_timer = 0.0
		_spawn_drone()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)
	# Spawn initial drone
	_spawn_drone()


func _on_systems_deactivated() -> void:
	set_process(false)
	# All drones explode
	for drone in _active_drones:
		if is_instance_valid(drone) and drone.has_method("explode"):
			drone.explode()
		elif is_instance_valid(drone):
			drone.queue_free()
	_active_drones.clear()


func _spawn_drone() -> void:
	"""Spawn a random drone based on weighted chances"""
	var drone_type: Dictionary = _pick_weighted_drone()
	var drone: Node2D = null

	if ResourceLoader.exists(drone_type["scene"]):
		var scene: PackedScene = load(drone_type["scene"])
		drone = scene.instantiate()
	else:
		drone = _create_placeholder_drone(drone_type["type"])

	# Spawn near fabricator with slight offset
	var offset: Vector2 = Vector2(randf_range(-80, -30), randf_range(-100, 100))
	drone.global_position = global_position + offset
	drone.add_to_group("kollektiv_drone")

	if drone.has_method("set_fabricator"):
		drone.set_fabricator(self)

	get_parent().add_child(drone)
	_active_drones.append(drone)

	print("[%s] Spawned %s drone (%d/%d)" % [core_name, drone_type["type"], _active_drones.size(), MAX_DRONES])


func _pick_weighted_drone() -> Dictionary:
	"""Pick a drone type based on weighted random"""
	var roll: float = randf()
	var cumulative: float = 0.0
	for entry in DRONE_WEIGHTS:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry
	return DRONE_WEIGHTS[0]


func _create_placeholder_drone(type: String) -> CharacterBody2D:
	"""Create minimal placeholder drone"""
	var drone := CharacterBody2D.new()
	drone.name = "Drone_%s" % type
	drone.collision_layer = 8
	drone.collision_mask = 1
	drone.add_to_group("enemies")
	drone.add_to_group("kollektiv_drone")

	# Collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	col.shape = rect
	drone.add_child(col)

	# Visual
	var visual := ColorRect.new()
	visual.name = "Visual"
	var drone_color: Color
	match type:
		"melee": drone_color = Color(0.9, 0.3, 0.3)
		"kamikaze": drone_color = Color(1.0, 0.6, 0.0)
		"ranged": drone_color = Color(0.3, 0.3, 0.9)
		"repair": drone_color = Color(0.3, 0.9, 0.3)
		_: drone_color = Color(0.7, 0.7, 0.7)
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = drone_color
	drone.add_child(visual)

	# Sprite2D placeholder
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	drone.add_child(sprite)

	# Hurtbox
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.collision_layer = 1024
	hurtbox.collision_mask = 48
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var hb_shape := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(30, 30)
	hb_shape.shape = hb_rect
	hurtbox.add_child(hb_shape)
	drone.add_child(hurtbox)

	# Attach drone script based on type
	var script_path: String = "res://bosses/kollektiv/entities/drone_%s.gd" % type
	if type == "repair":
		script_path = "res://bosses/kollektiv/entities/repair_bot.gd"
	if ResourceLoader.exists(script_path):
		drone.set_script(load(script_path))

	return drone
