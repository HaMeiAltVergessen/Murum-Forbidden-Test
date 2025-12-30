extends Area2D
## Boss AoE Ring - Large area damage

@export var damage: float = 50.0
@export var radius: float = 150.0
@export var lifetime: float = 0.5

var is_active: bool = false
var hit_entities: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set collision shape radius
	if has_node("CollisionShape2D"):
		var collision = $CollisionShape2D
		if collision.shape is CircleShape2D:
			collision.shape.radius = radius


func activate() -> void:
	"""Activates the AoE hitbox"""
	is_active = true
	monitoring = true

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the AoE"""

	if not is_active:
		return

	# Don't hit same entity twice
	if body in hit_entities:
		return

	# Only hit player
	if not body.is_in_group("player"):
		return

	hit_entities.append(body)

	# Deal damage
	if body.has_node("HealthComponent"):
		var health_comp = body.get_node("HealthComponent")
		if health_comp.has_method("take_damage"):
			health_comp.take_damage(int(damage))
			print("[AoERing] Hit player for %d damage" % damage)
