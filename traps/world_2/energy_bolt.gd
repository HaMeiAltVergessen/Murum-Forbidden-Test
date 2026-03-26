extends Area2D
class_name EnergyBolt

## Energy projectile for W2 Turrets
## Parry-able - reflects to nearest enemy with 1.5x damage
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal bolt_hit(target: Node2D)
signal bolt_parried()

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 18
@export var speed: float = 350.0
@export var lifetime: float = 5.0
@export var can_be_parried: bool = true

# ============================================================================
# STATE
# ============================================================================

var direction: Vector2 = Vector2.RIGHT
var is_parried: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var bolt_visual: ColorRect = $BoltVisual if has_node("BoltVisual") else null
@onready var trail: GPUParticles2D = $Trail if has_node("Trail") else null

var lifetime_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Collision: Interactables + Projectiles, Mask: World + P1 + P2
	collision_layer = 0
	set_collision_layer_value(8, true)
	set_collision_layer_value(11, true)
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(2, true)   # P1
	set_collision_mask_value(3, true)   # P2

	# Trail
	if trail:
		trail.emitting = true

	# Rotate visual to match direction
	rotation = direction.angle()

	# Lifetime
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)
	lifetime_timer.start()

	add_to_group("projectiles")
	add_to_group("energy_bolts")

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

# ============================================================================
# COLLISION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	# Player hit
	if body.is_in_group("player") or body.is_in_group("player2"):
		_handle_player_hit(body)
		return

	# Wall hit
	if body is TileMap or body is StaticBody2D or body.is_in_group("world"):
		_hit_wall()
		return

	# Enemy hit (after parry)
	if is_parried and (body.is_in_group("enemies") or body.is_in_group("enemy")):
		_handle_enemy_hit(body)
		return

func _on_area_entered(area: Area2D) -> void:
	# BlockArea detection (player blocking)
	if area.name == "BlockArea" or "block_area" in area.name.to_lower():
		_play_hit_effect()
		queue_free()
		return

# ============================================================================
# PLAYER HIT
# ============================================================================

func _handle_player_hit(player: Node2D) -> void:
	var hurtbox = player.get_node_or_null("HurtboxComponent")

	# Check invulnerability
	if hurtbox and "is_invulnerable" in hurtbox and hurtbox.is_invulnerable:
		return

	# Deal damage
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, direction * speed, 0.0)
		bolt_hit.emit(player)
		print("[EnergyBolt] Hit %s for %d damage" % [player.name, damage])

	_play_hit_effect()
	queue_free()

# ============================================================================
# PARRY
# ============================================================================

func _parry(player: Node2D) -> void:
	"""Bolt is parried - redirect to nearest enemy"""
	is_parried = true
	bolt_parried.emit()

	# Find nearest enemy to redirect towards
	var nearest_enemy = _find_nearest_enemy()
	if nearest_enemy:
		direction = (nearest_enemy.global_position - global_position).normalized()
	else:
		direction *= -1  # Reverse if no enemy found

	# Increase damage
	damage = int(damage * 1.5)

	# Update rotation
	rotation = direction.angle()

	# Change collision to hit enemies
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(4, true)   # Enemies

	# Feedback
	if AudioManager:
		AudioManager.play_sfx_at_position("combat/parry_success", global_position, 0.3)

	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.2)

	# Visual: Change color to green (reflected)
	if bolt_visual:
		bolt_visual.color = Color(0.2, 1.0, 0.4, 1.0)

	print("[EnergyBolt] Parried! Redirected, damage: %d" % damage)

func _find_nearest_enemy() -> Node2D:
	"""Find nearest enemy to redirect bolt towards"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest

# ============================================================================
# ENEMY HIT
# ============================================================================

func _handle_enemy_hit(enemy: Node2D) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, self)
		bolt_hit.emit(enemy)
		print("[EnergyBolt] Reflected bolt hit %s for %d" % [enemy.name, damage])

	_play_hit_effect()
	queue_free()

# ============================================================================
# WALL HIT
# ============================================================================

func _hit_wall() -> void:
	_play_hit_effect()
	queue_free()

# ============================================================================
# EFFECTS
# ============================================================================

func _play_hit_effect() -> void:
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/energy_impact", global_position, 0.2)
