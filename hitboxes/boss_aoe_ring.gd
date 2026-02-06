extends Area2D
## Boss AOE ring attack - expanding damage ring

@export var damage: float = 40.0
@export var lifetime: float = 0.5
@export var final_radius: float = 200.0
@export var initial_radius: float = 50.0
@export var knockback_force: float = 500.0

var hit_targets: Array = []
var elapsed_time: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_polygon: Polygon2D = $VisualIndicator/OuterRing if has_node("VisualIndicator/OuterRing") else null

func _ready() -> void:
	# Set collision layers (Boss attacks -> Player hurtbox)
	collision_layer = 128   # EnemyHitbox (Layer 8)
	collision_mask = 1024   # PlayerHurtbox (Layer 11)

	# CRITICAL: Add to hitbox group for ParryBlockSystem detection
	add_to_group("hitbox")
	add_to_group("enemy_attack")

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Set initial size
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = initial_radius

	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _process(delta: float) -> void:
	elapsed_time += delta
	var progress = min(elapsed_time / lifetime, 1.0)

	# Expand the ring
	var current_radius = lerp(initial_radius, final_radius, progress)

	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = current_radius

	# Update visual if present
	if visual_polygon:
		_update_visual_ring(current_radius)


func _update_visual_ring(radius: float) -> void:
	"""Updates the visual polygon to match current radius"""
	var points = PackedVector2Array()
	var segments = 16

	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius
		points.append(point)

	if visual_polygon:
		visual_polygon.polygon = points


func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with player body"""
	if body in hit_targets:
		return

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

	# CRITICAL: Check if player is blocking/invulnerable via HurtboxComponent
	if target.has_node("HurtboxComponent"):
		var hurtbox = target.get_node("HurtboxComponent")
		if hurtbox.is_invulnerable:
			print("[BossAOERing] Player is blocking/invulnerable - damage blocked!")
			return

	# Deal damage through health component
	if target.has_node("HealthComponent"):
		var health_component = target.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.take_damage(damage)
			print("[BossAOERing] Dealt ", damage, " damage to player")

	# Apply knockback (outward from center) - reduced to prevent pushing out of bounds
	if target is CharacterBody2D:
		var direction = (target.global_position - global_position).normalized()
		var safe_knockback = direction * knockback_force * 0.5  # Reduced knockback
		if target.has_method("apply_knockback"):
			target.apply_knockback(safe_knockback)
		else:
			target.velocity = safe_knockback
