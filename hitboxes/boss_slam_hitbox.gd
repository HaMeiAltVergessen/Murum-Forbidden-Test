extends Area2D
## Boss slam attack hitbox - deals damage on impact

@export var damage: float = 35.0
@export var lifetime: float = 0.3  # How long hitbox stays active
@export var knockback_force: float = 300.0

var hit_targets: Array = []  # Track what we've already hit

func _ready() -> void:
	# Set collision layers (Boss attacks -> Player hurtbox)
	collision_layer = 128   # EnemyHitbox (Layer 8)
	collision_mask = 1024   # PlayerHurtbox (Layer 11)

	# CRITICAL: Add to hitbox group for ParryBlockSystem detection
	add_to_group("hitbox")
	add_to_group("enemy_attack")

	print("[BossSlamHitbox] Spawned at ", global_position, " with damage ", damage)
	print("[BossSlamHitbox] Collision layer: ", collision_layer, ", mask: ", collision_mask)

	# Connect signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	print("[BossSlamHitbox] Destroyed after lifetime")
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with player body"""
	print("[BossSlamHitbox] Body entered: ", body.name, " groups: ", body.get_groups())

	# Ignore boss/enemy bodies
	if body.is_in_group("boss") or body.is_in_group("enemy"):
		print("[BossSlamHitbox] Ignoring boss/enemy body")
		return

	if body in hit_targets:
		print("[BossSlamHitbox] Already hit this target")
		return  # Already hit this target

	if body.is_in_group("player"):
		print("[BossSlamHitbox] Detected player body!")
		_deal_damage(body)


func _on_area_entered(area: Area2D) -> void:
	"""Handles collision with player hurtbox"""
	print("[BossSlamHitbox] Area entered: ", area.name, " type: ", area.get_class())
	print("[BossSlamHitbox] Area collision_layer: ", area.collision_layer, ", mask: ", area.collision_mask)

	var parent = area.get_parent()
	print("[BossSlamHitbox] Parent: ", parent.name if parent else "null", " is player: ", parent.is_in_group("player") if parent else false)

	# Ignore boss/enemy hurtboxes
	if parent and (parent.is_in_group("boss") or parent.is_in_group("enemy")):
		print("[BossSlamHitbox] Ignoring boss/enemy hurtbox")
		return

	if parent in hit_targets:
		print("[BossSlamHitbox] Parent already hit")
		return

	if parent and parent.is_in_group("player"):
		print("[BossSlamHitbox] Detected player hurtbox!")
		_deal_damage(parent)


func _deal_damage(target: Node2D) -> void:
	"""Applies damage to target"""
	hit_targets.append(target)

	# CRITICAL: Check if player is blocking/invulnerable via HurtboxComponent
	if target.has_node("HurtboxComponent"):
		var hurtbox = target.get_node("HurtboxComponent")
		if hurtbox.is_invulnerable:
			print("[BossSlamHitbox] Player is blocking/invulnerable - damage blocked!")
			return

	# Deal damage through health component
	if target.has_node("HealthComponent"):
		var health_component = target.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.take_damage(damage)
			print("[BossSlamHitbox] Dealt ", damage, " damage to player")

	# Apply knockback (reduced when close to walls to prevent out-of-bounds)
	if target is CharacterBody2D:
		var direction = (target.global_position - global_position).normalized()
		# Safety: Clamp knockback direction to prevent pushing into walls
		var safe_knockback = direction * knockback_force * 0.5  # Reduced knockback
		if target.has_method("apply_knockback"):
			target.apply_knockback(safe_knockback)
		else:
			target.velocity = safe_knockback
