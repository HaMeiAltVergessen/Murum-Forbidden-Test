extends Area2D
class_name StaffProjectile

## Thrown staff projectile with auto-return

# ============================================================================
# PROPERTIES
# ============================================================================

var direction: Vector2 = Vector2.RIGHT
var speed: float = 850.0
var return_speed: float = 900.0
var damage: int = 20
var max_range: float = 600.0
var owner_player: Node = null

# ============================================================================
# STATE
# ============================================================================

enum State { FLYING_OUT, RETURNING }

var current_state: State = State.FLYING_OUT
var distance_traveled: float = 0.0

var hit_enemies: Dictionary = {}
const HIT_COOLDOWN: float = 0.3

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: GPUParticles2D = $Trail

# ============================================================================
# SIGNALS
# ============================================================================

signal staff_max_range_reached
signal staff_hit_wall
signal staff_caught

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if trail:
		trail.emitting = true

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	add_to_group("projectiles")
	add_to_group("staff_projectiles")

	print("[StaffProjectile] Spawned, direction: %v" % direction)
	print("[StaffProjectile] Collision layer: %d, mask: %d" % [collision_layer, collision_mask])
	print("[StaffProjectile] Monitoring: %s, Monitorable: %s" % [monitoring, monitorable])

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		State.FLYING_OUT:
			_process_flying_out(delta)
		State.RETURNING:
			_process_returning(delta)

	if sprite:
		sprite.rotation += delta * 15.0

	_update_hit_cooldowns(delta)

func _process_flying_out(delta: float) -> void:
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()

	if distance_traveled >= max_range:
		_start_return()

func _process_returning(delta: float) -> void:
	if not owner_player or not is_instance_valid(owner_player):
		queue_free()
		return

	var to_player = owner_player.global_position - global_position
	var distance = to_player.length()

	if distance < 30.0:
		_on_caught()
		return

	var return_direction = to_player.normalized()
	global_position += return_direction * return_speed * delta

# ============================================================================
# STATE TRANSITIONS
# ============================================================================

func _start_return() -> void:
	if current_state == State.RETURNING:
		return

	print("[StaffProjectile] Starting return")

	current_state = State.RETURNING
	staff_max_range_reached.emit()

func _on_caught() -> void:
	print("[StaffProjectile] Caught by player")
	staff_caught.emit()
	queue_free()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	print("[StaffProjectile] Area entered: %s (parent: %s, owner: %s)" % [area.name, area.get_parent().name if area.get_parent() else "null", area.owner.name if area.owner else "null"])
	print("[StaffProjectile] Area class: %s, is HurtboxComponent: %s" % [area.get_class(), area is HurtboxComponent])

	# Check if we hit a HurtboxComponent
	if area is HurtboxComponent:
		# Try both owner and parent to find the enemy
		var enemy = area.owner if area.owner else area.get_parent()

		print("[StaffProjectile] Found HurtboxComponent, enemy: %s" % (enemy.name if enemy else "null"))

		if not enemy or not enemy.is_in_group("enemies"):
			print("[StaffProjectile] Not in enemies group or null")
			return

		if _is_enemy_on_cooldown(enemy):
			print("[StaffProjectile] Enemy on cooldown")
			return

		# Calculate knockback direction
		var knockback_direction = (enemy.global_position - global_position).normalized()
		var knockback_force = knockback_direction * 400.0  # Strong knockback

		# Deal damage with knockback through HurtboxComponent
		area.take_damage(damage, knockback_force, 0.2)

		print("[StaffProjectile] Hit enemy: %s with knockback (damage: %d)" % [enemy.name, damage])

		_add_hit_enemy(enemy)
		_play_hit_effect(enemy.global_position)
		return

	# Fallback for enemies without HurtboxComponent
	if not area.owner or not area.owner.is_in_group("enemies"):
		return

	if _is_enemy_on_cooldown(area.owner):
		return

	if area.owner.has_method("take_damage"):
		area.owner.take_damage(damage, owner_player)

	print("[StaffProjectile] Hit enemy: %s" % area.owner.name)

	_add_hit_enemy(area.owner)
	_play_hit_effect(area.owner.global_position)

func _on_body_entered(body: Node2D) -> void:
	print("[StaffProjectile] Body entered: %s (class: %s, groups: %s)" % [body.name, body.get_class(), body.get_groups()])

	if body is TileMap or body is StaticBody2D:
		print("[StaffProjectile] Hit wall")

		if current_state == State.FLYING_OUT:
			_start_return()
			staff_hit_wall.emit()
			_play_wall_impact_effect()

# ============================================================================
# HIT TRACKING
# ============================================================================

func _add_hit_enemy(enemy: Node) -> void:
	hit_enemies[enemy] = 0.0

func _is_enemy_on_cooldown(enemy: Node) -> bool:
	return enemy in hit_enemies

func _update_hit_cooldowns(delta: float) -> void:
	var to_remove = []

	for enemy in hit_enemies:
		hit_enemies[enemy] += delta

		if hit_enemies[enemy] >= HIT_COOLDOWN:
			to_remove.append(enemy)

	for enemy in to_remove:
		hit_enemies.erase(enemy)

# ============================================================================
# EFFECTS
# ============================================================================

func _play_hit_effect(position: Vector2) -> void:
	if AudioManager:
		AudioManager.play_sfx_at_position("combat/staff_hit", position, 0.15)

	if owner_player and owner_player.has_node("PlayerCamera"):
		owner_player.get_node("PlayerCamera").add_trauma(0.15)

func _play_wall_impact_effect() -> void:
	if AudioManager:
		AudioManager.play_sfx_at_position("combat/staff_wall_hit", global_position, 0.12)

	if owner_player and owner_player.has_node("PlayerCamera"):
		owner_player.get_node("PlayerCamera").add_trauma(0.1)
