extends Area2D
## Boss slam attack hitbox - deals damage on impact

@export var damage: float = 35.0
@export var lifetime: float = 0.3  # How long hitbox stays active
@export var knockback_force: float = 300.0

var hit_targets: Array = []  # Track what we've already hit

func _ready() -> void:
	# Set collision layers
	collision_layer = 6  # EnemyHitbox
	collision_mask = 4   # PlayerHurtbox

	# Connect signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with player body"""
	if body in hit_targets:
		return  # Already hit this target

	if body.is_in_group("player"):
		_deal_damage(body)


func _on_area_entered(area: Area2D) -> void:
	"""Handles collision with player hurtbox"""
	if area.get_parent() in hit_targets:
		return

	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_deal_damage(parent)


func _deal_damage(target: Node2D) -> void:
	"""Applies damage to target"""
	hit_targets.append(target)

	# Deal damage through health component
	if target.has_node("HealthComponent"):
		var health_component = target.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.take_damage(damage)
			print("[BossSlamHitbox] Dealt ", damage, " damage to player")

	# Apply knockback
	if target is CharacterBody2D:
		var direction = (target.global_position - global_position).normalized()
		if target.has_method("apply_knockback"):
			target.apply_knockback(direction * knockback_force)
		else:
			# Fallback: direct velocity modification
			target.velocity = direction * knockback_force
