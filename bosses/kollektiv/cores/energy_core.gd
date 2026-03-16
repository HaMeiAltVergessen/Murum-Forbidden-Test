extends KollektivCore
## Energy Core (Reactor) — Floor position
## Active: Energy pulses from floor (10 DMG every 4s), platforms electrified (5 DMG/s)
## Destroyed: Energy shields fall, ship overheats

# ============ CONFIGURATION ============
const PULSE_DAMAGE: int = 10
const PULSE_INTERVAL: float = 4.0
const PULSE_RADIUS: float = 400.0
const ELECTRIFY_DAMAGE: int = 5
const ELECTRIFY_INTERVAL: float = 1.0

# ============ STATE ============
var _pulse_timer: float = 0.0
var _electrify_timer: float = 0.0
var _pulse_scene: PackedScene = null


func _ready() -> void:
	core_name = "Energiekern"
	max_hp = 200.0
	core_color = Color(1.0, 0.6, 0.1)  # Orange
	super._ready()

	_pulse_scene = preload("res://bosses/kollektiv/entities/energy_pulse.tscn") if ResourceLoader.exists("res://bosses/kollektiv/entities/energy_pulse.tscn") else null


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Energy pulse timer
	_pulse_timer += delta
	if _pulse_timer >= PULSE_INTERVAL / speed_mult:
		_pulse_timer = 0.0
		_fire_energy_pulse()

	# Electrify platforms timer
	_electrify_timer += delta
	if _electrify_timer >= ELECTRIFY_INTERVAL:
		_electrify_timer = 0.0
		_electrify_platforms()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)


func _on_systems_deactivated() -> void:
	set_process(false)
	# Clear any active pulses
	for child in get_tree().get_nodes_in_group("energy_pulse"):
		if is_instance_valid(child):
			child.queue_free()


func _fire_energy_pulse() -> void:
	"""Fire energy pulse from the floor"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Only pulse if player is near floor level (within 600px vertical)
	if abs(player.global_position.y - global_position.y) > 600:
		return

	if _pulse_scene:
		var pulse = _pulse_scene.instantiate()
		pulse.global_position = Vector2(player.global_position.x, global_position.y - 50)
		pulse.damage = int(PULSE_DAMAGE * damage_mult)
		get_parent().add_child(pulse)
	else:
		# Fallback: direct damage via hitbox
		_spawn_pulse_hitbox()

	print("[%s] Energy pulse fired!" % core_name)


func _spawn_pulse_hitbox() -> void:
	"""Fallback pulse using a temporary hitbox"""
	var hitbox := HitboxComponent.new()
	hitbox.damage = int(PULSE_DAMAGE * damage_mult)
	hitbox.knockback_force = 150.0
	hitbox.hitstun_duration = 0.15
	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PULSE_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)

	# Visual warning
	var warning := ColorRect.new()
	warning.size = Vector2(PULSE_RADIUS * 2, 20)
	warning.position = Vector2(-PULSE_RADIUS, -10)
	warning.color = Color(1.0, 0.5, 0.0, 0.4)
	hitbox.add_child(warning)

	hitbox.global_position = Vector2(global_position.x, global_position.y - 50)
	get_parent().add_child(hitbox)
	hitbox.activate()

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _electrify_platforms() -> void:
	"""Electrify random platforms periodically"""
	if not controller:
		return

	var platforms: Array = get_tree().get_nodes_in_group("kollektiv_platform")
	if platforms.is_empty():
		return

	# Electrify 1-2 random platforms
	var count: int = randi_range(1, 2)
	platforms.shuffle()
	for i in range(min(count, platforms.size())):
		var platform = platforms[i]
		if platform.has_method("electrify"):
			platform.electrify(2.0, int(ELECTRIFY_DAMAGE * damage_mult))
