extends Area2D
## Void Orb - Lythrun's projectile attack

@export var damage: float = 25.0
@export var speed: float = 200.0
@export var target: Vector2 = Vector2.ZERO
@export var lifetime: float = 5.0

var direction: Vector2 = Vector2.ZERO
var has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Calculate direction to target
	if target != Vector2.ZERO:
		direction = (target - global_position).normalized()
	else:
		direction = Vector2.RIGHT

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	"""Moves the orb towards target"""

	if has_hit:
		return

	# Move in direction
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	"""Called when orb hits something"""

	if has_hit:
		return

	# Hit player
	if body.is_in_group("player"):
		_hit_player(body)
		return

	# Hit walls/obstacles
	if body is TileMap or body is StaticBody2D:
		_hit_wall()
		return


func _hit_player(player: Node2D) -> void:
	"""Deals damage to player"""

	has_hit = true

	# Deal damage
	if player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		if health_comp.has_method("take_damage"):
			health_comp.take_damage(int(damage))
			print("[VoidOrb] Hit player for %d damage" % damage)

	# Spawn hit VFX
	_spawn_hit_vfx()

	# Destroy orb
	queue_free()


func _hit_wall() -> void:
	"""Called when orb hits a wall"""

	has_hit = true

	# Spawn hit VFX
	_spawn_hit_vfx()

	# Destroy orb
	queue_free()


func _spawn_hit_vfx() -> void:
	"""Spawns hit VFX"""

	# TODO: Spawn actual VFX
	# var vfx = preload("res://vfx/void_orb_impact.tscn").instantiate()
	# get_parent().add_child(vfx)
	# vfx.global_position = global_position

	pass
