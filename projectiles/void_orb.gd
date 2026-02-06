extends Area2D
## Void Orb projectile - homing projectile that seeks player

@export var damage: float = 25.0
@export var speed: float = 400.0  # Doubled from 200
@export var lifetime: float = 8.0  # Increased from 5.0
@export var homing_strength: float = 0.8  # Stronger homing

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var hit_targets: Array = []

func _ready() -> void:
	# Set collision layers (Boss projectile -> Player hurtbox)
	collision_layer = 128   # EnemyHitbox (Layer 8)
	collision_mask = 1024   # PlayerHurtbox (Layer 11)

	# CRITICAL: Add to hitbox group for ParryBlockSystem detection
	add_to_group("hitbox")
	add_to_group("projectiles")
	add_to_group("enemy_attack")

	# Find player target FIRST (before any await!)
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
			# Set initial direction toward player
			if target:
				direction = (target.global_position - global_position).normalized()

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	# Homing behavior
	if target and is_instance_valid(target) and homing_strength > 0:
		var target_direction = (target.global_position - global_position).normalized()
		direction = direction.lerp(target_direction, homing_strength * delta * 2.0).normalized()

	# Move in direction
	global_position += direction * speed * delta

	# Rotate to face movement direction
	rotation = direction.angle()


func set_direction(new_direction: Vector2) -> void:
	"""Sets the initial movement direction"""
	direction = new_direction.normalized()


func set_target(new_target: Node2D) -> void:
	"""Sets the homing target"""
	target = new_target


func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with player body"""
	if body in hit_targets:
		return

	if body.is_in_group("player"):
		_deal_damage(body)
		queue_free()  # Destroy on hit


func _on_area_entered(area: Area2D) -> void:
	"""Handles collision with player hurtbox"""
	if area.get_parent() in hit_targets:
		return

	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_deal_damage(parent)
		queue_free()  # Destroy on hit


func _deal_damage(target_node: Node2D) -> void:
	"""Applies damage to target"""
	hit_targets.append(target_node)

	# CRITICAL: Check if player is blocking/invulnerable via HurtboxComponent
	if target_node.has_node("HurtboxComponent"):
		var hurtbox = target_node.get_node("HurtboxComponent")
		if hurtbox.is_invulnerable:
			print("[VoidOrb] Player is blocking/invulnerable - damage blocked!")
			return

	# Deal damage through health component
	if target_node.has_node("HealthComponent"):
		var health_component = target_node.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.take_damage(damage)
			print("[VoidOrb] Dealt ", damage, " damage to player")

	# Apply knockback (reduced)
	if target_node is CharacterBody2D:
		if target_node.has_method("apply_knockback"):
			target_node.apply_knockback(direction * 100.0)  # Reduced from 200
		else:
			target_node.velocity = direction * 100.0
