extends Node2D
## Auto-turret for the Defense Core — fires projectiles at the player

var turret_damage: int = 8
var fire_rate: float = 2.0
var _fire_timer: Timer
var _active: bool = true


func _ready() -> void:
	add_to_group("kollektiv_turret")

	# Visual placeholder
	if get_child_count() == 0:
		var visual := ColorRect.new()
		visual.size = Vector2(30, 30)
		visual.position = Vector2(-15, -15)
		visual.color = Color(0.3, 0.5, 0.9, 0.8)
		add_child(visual)

	# Fire timer
	_fire_timer = Timer.new()
	_fire_timer.name = "FireTimer"
	_fire_timer.wait_time = fire_rate
	_fire_timer.one_shot = false
	_fire_timer.timeout.connect(_on_fire)
	add_child(_fire_timer)
	_fire_timer.start()


func set_config(damage: int, rate: float) -> void:
	turret_damage = damage
	fire_rate = rate
	if _fire_timer:
		_fire_timer.wait_time = rate


func _on_fire() -> void:
	if not _active:
		return

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var dir: Vector2 = (player.global_position - global_position).normalized()

	# Check owner core for cognition status
	var owner_core = get_meta("owner_core", null)
	if owner_core and is_instance_valid(owner_core) and not owner_core.cognition_active:
		dir = dir.rotated(randf_range(-0.4, 0.4))

	# Spawn projectile
	var proj_scene_path: String = "res://bosses/kollektiv/entities/kollektiv_projectile.tscn"
	if ResourceLoader.exists(proj_scene_path):
		var scene: PackedScene = load(proj_scene_path)
		var proj = scene.instantiate()
		proj.global_position = global_position
		proj.direction = dir
		proj.damage = turret_damage
		proj.speed = 280.0

		# Homing if cognition active
		if owner_core and is_instance_valid(owner_core) and owner_core.cognition_active:
			proj.homing_strength = 0.5

		get_parent().add_child(proj)

	# Visual flash
	modulate = Color(1.5, 1.5, 1.5)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE


func deactivate() -> void:
	_active = false
	if _fire_timer:
		_fire_timer.stop()


func activate() -> void:
	_active = true
	if _fire_timer:
		_fire_timer.start()
