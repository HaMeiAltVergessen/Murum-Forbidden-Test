extends Area2D
## HitboxComponent handles damage dealing and hit detection
class_name HitboxComponent

# ============ CONFIGURATION ============
@export var damage: int = 10
@export var knockback_force: float = 200.0
@export var hitstun_duration: float = 0.2
@export var spawn_hit_effect: bool = true

# ============ VFX ============
const HIT_SPARK_SCENE: String = "res://vfx/hit_spark.tscn"

# ============ SIGNALS ============
signal hit_registered(target: Node, damage: int)


func _ready() -> void:
	# Connect to area entered
	area_entered.connect(_on_area_entered)

	# Start deactivated
	monitoring = false
	monitorable = false

	print("[HitboxComponent] Ready - Layer: ", collision_layer, " Mask: ", collision_mask)


# ============ DETECTION ============
func _on_area_entered(area: Area2D) -> void:
	"""Called when this hitbox overlaps with another area"""
	print("[Hitbox] Area entered: ", area.name, " type: ", area.get_class(), " is HurtboxComponent: ", area is HurtboxComponent)
	print("[Hitbox] Area collision_layer: ", area.collision_layer, ", mask: ", area.collision_mask)

	# Check if it's a hurtbox
	if not area is HurtboxComponent:
		print("[Hitbox] Not a HurtboxComponent, ignoring")
		return

	var hurtbox: HurtboxComponent = area as HurtboxComponent
	var hurtbox_owner = hurtbox.owner if hurtbox.owner else hurtbox.get_parent()
	print("[Hitbox] HurtboxComponent found, owner: ", hurtbox_owner.name if hurtbox_owner else "null")

	# Don't hit entities from same team
	if _is_same_team(hurtbox):
		print("[Hitbox] Same team, ignoring")
		return

	print("[Hitbox] Different team, dealing damage!")
	# Apply damage
	_deal_damage_to(hurtbox)


func _deal_damage_to(hurtbox: HurtboxComponent) -> void:
	"""Deals damage to a hurtbox"""
	# Calculate knockback direction
	var knockback_dir: Vector2 = Vector2.ZERO
	if hurtbox.global_position != global_position:
		knockback_dir = (hurtbox.global_position - global_position).normalized()

	# Get the actual attacker (owner, not immediate parent)
	var attacker: Node = owner if owner else get_parent()

	# Deal damage (pass attacker for parry system)
	hurtbox.take_damage(damage, knockback_dir * knockback_force, hitstun_duration, attacker)

	# Spawn hit effect
	if spawn_hit_effect:
		_spawn_hit_effect(hurtbox.global_position)

	# Get target for signals
	var target: Node = hurtbox.owner if hurtbox.owner else hurtbox.get_parent()

	# Emit signal
	hit_registered.emit(target, damage)
	EventBus.hit_registered.emit(attacker, target, damage)

	print("[Hitbox] Hit registered: ", damage, " damage to ", hurtbox.get_parent().name)
	print("1")  # Success indicator for hits


func _is_same_team(hurtbox: HurtboxComponent) -> bool:
	"""Checks if the hurtbox belongs to the same team"""
	var my_parent: Node = get_parent()
	var their_parent: Node = hurtbox.get_parent()

	# Compare collision layers
	# Player hitbox (layer 3) shouldn't hit player hurtbox (layer 4)
	# Enemy hitbox (layer 6) shouldn't hit enemy hurtbox (layer 7)

	# For now, simple check: same parent type
	if my_parent is CharacterBody2D and their_parent is CharacterBody2D:
		# Both are characters, check if same type
		if my_parent.name.begins_with("Murum") and their_parent.name.begins_with("Murum"):
			return true
		if my_parent.name.begins_with("Untote") and their_parent.name.begins_with("Untote"):
			return true

	return false


# ============ CONTROL ============
func activate() -> void:
	"""Activates the hitbox for damage dealing"""
	monitoring = true
	monitorable = true
	visible = true
	print("[HitboxComponent] ACTIVATED - Monitoring: ", monitoring, " Layer: ", collision_layer, " Mask: ", collision_mask)


func deactivate() -> void:
	"""Deactivates the hitbox"""
	monitoring = false
	monitorable = false
	visible = false


func set_damage(new_damage: int) -> void:
	"""Sets the damage value"""
	damage = new_damage


func set_knockback(new_knockback: float) -> void:
	"""Sets the knockback force"""
	knockback_force = new_knockback


# ============ VFX ============
func _spawn_hit_effect(position: Vector2) -> void:
	"""Spawns a hit spark effect at the given position"""
	var hit_spark_scene: PackedScene = load(HIT_SPARK_SCENE)
	if not hit_spark_scene:
		return

	var hit_spark: GPUParticles2D = hit_spark_scene.instantiate() as GPUParticles2D
	if not hit_spark:
		return

	# Add to scene root
	get_tree().root.add_child(hit_spark)
	hit_spark.global_position = position
	hit_spark.emitting = true

	# Auto-remove after lifetime
	await get_tree().create_timer(hit_spark.lifetime + 0.5).timeout
	if is_instance_valid(hit_spark):
		hit_spark.queue_free()
