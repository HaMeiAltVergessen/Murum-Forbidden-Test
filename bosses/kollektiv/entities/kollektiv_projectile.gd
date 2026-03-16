extends Area2D
## Generic projectile for Kollektiv boss — turrets, cores, etc.

var damage: int = 8
var speed: float = 300.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 5.0
var homing_strength: float = 0.0  # 0 = no homing, higher = more homing

var _age: float = 0.0


func _ready() -> void:
	collision_layer = 128
	collision_mask = 1024
	monitoring = true
	monitorable = false

	add_to_group("kollektiv_projectile")

	area_entered.connect(_on_area_entered)

	# Add collision shape if not present
	if get_child_count() == 0 or not _has_collision_shape():
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6.0
		shape.shape = circle
		add_child(shape)

	# Add visual if not present
	if not _has_visual():
		var visual := ColorRect.new()
		visual.size = Vector2(10, 10)
		visual.position = Vector2(-5, -5)
		visual.color = Color(0.3, 0.6, 1.0)
		add_child(visual)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# Homing
	if homing_strength > 0:
		var player: Node2D = GameManager.player if GameManager else null
		if player and is_instance_valid(player):
			var to_player: Vector2 = (player.global_position - global_position).normalized()
			direction = direction.lerp(to_player, homing_strength * delta).normalized()

	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox: HurtboxComponent = area
		var hurtbox_owner = hurtbox.get_parent()
		if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
			hurtbox.take_damage(damage, direction * 100, 0.1)
			queue_free()


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape2D:
			return true
	return false


func _has_visual() -> bool:
	for child in get_children():
		if child is ColorRect or child is Sprite2D:
			return true
	return false
