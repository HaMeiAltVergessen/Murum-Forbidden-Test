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
@onready var _visual: AnimatedSprite2D = $Visual if has_node("Visual") else null


func _ready() -> void:
	# Collision setup: enemy hitbox, detects world + both players
	collision_layer = 0
	set_collision_layer_value(8, true)   # EnemyHitbox (for parry BlockArea)
	set_collision_layer_value(11, true)  # Projectiles
	collision_mask = 0
	set_collision_mask_value(1, true)    # World
	set_collision_mask_value(2, true)    # P1 body
	set_collision_mask_value(3, true)    # P2 body

	# Add to projectiles group for parry detection
	add_to_group("projectiles")
	add_to_group("enemies")

	# Rotate visual to flight direction
	if _visual:
		_visual.rotation = direction.angle()
		if _visual.sprite_frames and _visual.sprite_frames.has_animation("default"):
			_visual.play("default")

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


