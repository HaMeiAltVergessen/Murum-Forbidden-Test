extends Area2D
class_name ArrowProjectile

## Arrow projectile for arrow traps
## Can be parried by player blocking
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal arrow_hit(target: Node2D)
signal arrow_parried()

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 15
@export var speed: float = 400.0
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

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var trail: GPUParticles2D = $Trail if has_node("Trail") else null

var lifetime_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Godot 4.4: Explicitly set monitoring
	monitoring = true
	monitorable = true

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Setup collision for normal arrows (hit players AND block areas)
	collision_layer = 0
	set_collision_layer_value(8, true)   # Interactables (für BlockArea detection)
	set_collision_layer_value(11, true)  # Projectiles layer
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(2, true)   # P1 Body (Layer 2)
	set_collision_mask_value(3, true)   # P2 Body (Layer 3) - COMMIT 018

	# Trail
	if trail:
		trail.emitting = true

	# Rotate sprite to match direction
	if sprite:
		sprite.rotation = direction.angle()

	# Lifetime timer
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()

	add_to_group("projectiles")
	add_to_group("arrow_projectiles")

	print("[ArrowProjectile] Spawned at %v, direction: %v" % [global_position, direction])

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

# ============================================================================
# COLLISION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with bodies"""
	print("[ArrowProjectile] Body entered: %s (groups: %s)" % [body.name, body.get_groups()])

	# Check if player
	if body.is_in_group("player") or body.is_in_group("player2"):
		_handle_player_hit(body)
		return

	# Check if wall/floor
	if body is TileMap or body is StaticBody2D or body.is_in_group("world"):
		_hit_wall()
		return

	# Check if enemy (after parry)
	if is_parried and body.is_in_group("enemies"):
		_handle_enemy_hit(body)
		return

func _on_area_entered(area: Area2D) -> void:
	"""Handles collision with areas (BlockArea, shields, etc.)"""
	print("[ArrowProjectile] Area entered: %s (groups: %s)" % [area.name, area.get_groups()])

	# Check if it's a BlockArea (player blocking)
	if area.name == "BlockArea" or "block_area" in area.name.to_lower():
		print("[ArrowProjectile] Hit BlockArea - arrow blocked and destroyed!")
		_play_hit_effect()
		queue_free()
		return

# ============================================================================
# PLAYER HIT
# ============================================================================

func _handle_player_hit(player: Node2D) -> void:
	"""Handles hitting a player"""
	# Check if player is invulnerable (blocking/parrying via ParryBlockSystem)
	var hurtbox = player.get_node_or_null("HurtboxComponent")
	if hurtbox and "is_invulnerable" in hurtbox and hurtbox.is_invulnerable:
		# Player is blocking - ParryBlockSystem will handle destruction via BlockArea
		print("[ArrowProjectile] Player invulnerable (blocking) - waiting for ParryBlockSystem")
		return

	# Deal damage through HurtboxComponent
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, direction * speed, 0.0)
		arrow_hit.emit(player)
		print("[ArrowProjectile] Hit player %s for %d damage" % [player.name, damage])
	else:
		print("[ArrowProjectile] No HurtboxComponent found on %s" % player.name)

	# Play hit effect
	_play_hit_effect()

	# Destroy arrow
	queue_free()

# ============================================================================
# PARRY SYSTEM
# ============================================================================

func _check_parry(player: Node2D) -> bool:
	"""Check if player is currently blocking"""
	# Check if player has parry/block system
	var parry_system = player.get_node_or_null("ParryBlockSystem")
	if parry_system and parry_system.has_method("is_blocking"):
		return parry_system.is_blocking()

	# Fallback: check for is_blocking method directly on player
	if player.has_method("is_blocking"):
		return player.is_blocking()

	return false

func _parry(player: Node2D) -> void:
	"""Arrow is parried - reverse direction"""
	is_parried = true
	arrow_parried.emit()

	# Reverse direction
	direction *= -1

	# Increase damage
	damage = int(damage * 1.5)

	# Flip sprite
	if sprite:
		sprite.rotation = direction.angle()

	# Change collision to hit enemies
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(3, true)   # Enemies

	# Audio/visual feedback
	if AudioManager:
		AudioManager.play_sfx_at_position("combat/parry_success", global_position, 0.3)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.2)

	print("[ArrowProjectile] Parried by %s! New direction: %v, damage: %d" % [player.name, direction, damage])

# ============================================================================
# ENEMY HIT (After Parry)
# ============================================================================

func _handle_enemy_hit(enemy: Node2D) -> void:
	"""Handles hitting an enemy after being parried"""
	# Try to damage enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, self)
		arrow_hit.emit(enemy)
		print("[ArrowProjectile] Parried arrow hit enemy %s for %d damage" % [enemy.name, damage])

	# Play hit effect
	_play_hit_effect()

	# Destroy arrow
	queue_free()

# ============================================================================
# WALL HIT
# ============================================================================

func _hit_wall() -> void:
	"""Arrow hits wall"""
	print("[ArrowProjectile] Hit wall")

	# Play hit effect
	_play_hit_effect()

	# Destroy arrow
	queue_free()

# ============================================================================
# LIFETIME
# ============================================================================

func _on_lifetime_expired() -> void:
	"""Arrow lifetime expired"""
	print("[ArrowProjectile] Lifetime expired")
	queue_free()

# ============================================================================
# EFFECTS
# ============================================================================

func _play_hit_effect() -> void:
	"""Play hit visual/audio effect"""
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/arrow_impact", global_position, 0.2)
