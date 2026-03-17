extends Area2D
## DarkOrb — Parry-able projectile fired by MirrorBoss
## Flies backward toward the player. Can be perfect-parried for +15 Momentum.
class_name DarkOrb

# ============ CONFIG ============
@export var speed: float = 350.0
@export var damage: int = 15
@export var lifetime: float = 6.0

# ============ STATE ============
var direction: Vector2 = Vector2.LEFT
var shooter: Node = null  # MirrorBoss reference (for parry system)
var _lifetime_timer: float = 0.0

# ============ VISUAL ============
var _visual: ColorRect = null

const ORB_SIZE: float = 20.0
const ORB_COLOR := Color(0.3, 0.0, 0.5, 0.9)
const ORB_GLOW_COLOR := Color(0.6, 0.2, 0.8, 0.6)


func _ready() -> void:
	# Collision setup: same as enemy projectiles
	collision_layer = 128  # Layer 8 — Enemy Hitboxes (detected by parry BlockArea)
	collision_mask = 2  # Layer 2 — Player body (for body_entered)

	# Add to projectiles group for parry detection
	add_to_group("projectiles")
	add_to_group("enemies")

	# Create visual if not present
	if not has_node("Visual"):
		_create_visual()
	else:
		_visual = $Visual

	# Create collision shape if not present
	if not has_node("CollisionShape2D"):
		_create_collision()

	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Move
	global_position += direction * speed * delta

	# Lifetime
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()

	# Pulse visual
	if _visual:
		var pulse: float = 0.7 + 0.3 * sin(_lifetime_timer * 8.0)
		_visual.modulate.a = pulse


func _create_visual() -> void:
	# Glow (larger, transparent)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.size = Vector2(ORB_SIZE * 2.0, ORB_SIZE * 2.0)
	glow.position = Vector2(-ORB_SIZE, -ORB_SIZE)
	glow.color = ORB_GLOW_COLOR
	add_child(glow)

	# Core orb
	_visual = ColorRect.new()
	_visual.name = "Visual"
	_visual.size = Vector2(ORB_SIZE, ORB_SIZE)
	_visual.position = Vector2(-ORB_SIZE * 0.5, -ORB_SIZE * 0.5)
	_visual.color = ORB_COLOR
	add_child(_visual)


func _create_collision() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ORB_SIZE * 0.6
	shape.shape = circle
	add_child(shape)


# ============ HIT DETECTION ============
func _on_area_entered(area: Area2D) -> void:
	# Check if we hit a player hurtbox
	if area is HurtboxComponent:
		var owner_node: Node = area.get_parent()
		if owner_node and (owner_node.is_in_group("player") or owner_node.is_in_group("player2")):
			_hit_player(area)

	# Check by name/group as fallback
	if area.name.contains("Hurtbox") or area.is_in_group("player_hurtbox"):
		_hit_player(area)


func _on_body_entered(body: Node2D) -> void:
	# Hit world geometry — destroy
	if not body.is_in_group("player") and not body.is_in_group("player2") and not body.is_in_group("enemies"):
		queue_free()


func _hit_player(hurtbox: Node) -> void:
	"""Deal damage to player via hurtbox"""
	if hurtbox is HurtboxComponent:
		# Check if player is blocking/invulnerable
		if hurtbox.is_invulnerable:
			return
		var knockback: Vector2 = direction * 100.0
		hurtbox.take_damage(damage, knockback, 0.2, shooter)

	queue_free()


# ============ FACTORY ============
static func create(from_position: Vector2, target_direction: Vector2, boss: Node) -> DarkOrb:
	"""Factory method to create a dark orb"""
	var orb := DarkOrb.new()
	orb.global_position = from_position
	orb.direction = target_direction.normalized()
	orb.shooter = boss
	orb.name = "DarkOrb"
	return orb
