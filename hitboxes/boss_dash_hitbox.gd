extends Area2D
## Boss Dash Hitbox - Deals damage during dash attacks

@export var damage: float = 30.0
@export var knockback: float = 200.0

var is_active: bool = false
var hit_entities: Array = []  # Track already hit entities


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate() -> void:
	"""Activates the hitbox"""
	is_active = true
	hit_entities.clear()
	monitoring = true
	print("[DashHitbox] Activated")


func deactivate() -> void:
	"""Deactivates the hitbox"""
	is_active = false
	monitoring = false
	print("[DashHitbox] Deactivated")

	# Auto-cleanup after a short delay
	await get_tree().create_timer(0.1).timeout
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the hitbox"""

	if not is_active:
		return

	# Don't hit the same entity twice
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
			print("[DashHitbox] Hit player for %d damage" % damage)

	# Apply knockback
	if "velocity" in body:
		var knockback_dir = (body.global_position - global_position).normalized()
		body.velocity += knockback_dir * knockback
