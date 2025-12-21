extends Area2D
class_name Projectile

## Ranged attack projectile
## Flies in straight line, damages player, can be parried

# ============================================================================
# PROPERTIES
# ============================================================================

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: int = 15
var lifetime: float = 2.0
var shooter: Node = null  # Reference to enemy who shot it

# ============================================================================
# REFERENCES
# ============================================================================

var sprite: Node2D  # Can be Sprite2D, Polygon2D, etc.
var hitbox: Area2D
var lifetime_timer: Timer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get references (visual node can be Sprite2D, Polygon2D, etc.)
	sprite = get_node_or_null("Sprite2D")
	hitbox = get_node_or_null("HitboxComponent")
	lifetime_timer = get_node_or_null("LifetimeTimer")

	# Setup hitbox
	if hitbox:
		if hitbox.has_method("set_damage"):
			hitbox.set_damage(damage)
		if hitbox.has_method("activate"):
			hitbox.activate()
		hitbox.set_meta("projectile_owner", shooter)

	# Setup lifetime
	if lifetime_timer:
		lifetime_timer.wait_time = lifetime
		lifetime_timer.timeout.connect(_on_lifetime_expired)
		lifetime_timer.start()

	# Setup collision detection
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Add to groups
	add_to_group("projectiles")
	add_to_group("enemy_attacks")

	print("[Projectile] Spawned at %v, direction: %v, speed: %.0f" % [global_position, direction, speed])

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	# Move in direction
	global_position += direction * speed * delta

	# Rotate sprite (aesthetic)
	if sprite:
		sprite.rotation += delta * 3.0

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	"""Handles collision with areas (player hurtbox, etc.)"""

	# Check if player hurtbox
	if area.owner and area.owner.is_in_group("player"):
		_hit_player(area.owner)

	# Check if player hitbox (for reflection - future feature)
	elif area.is_in_group("hitbox") and area.owner and area.owner.is_in_group("player"):
		# Player attacking projectile (destroy it, no parry check here)
		_destroy_on_hit()

func _on_body_entered(body: Node2D) -> void:
	"""Handles collision with solid bodies (walls)"""

	# Hit wall
	if body is TileMapLayer or body is StaticBody2D:
		_destroy_on_wall()

# ============================================================================
# HIT HANDLING
# ============================================================================

func _hit_player(player: Node) -> void:
	"""Called when projectile hits player"""

	print("[Projectile] Hit player: %s" % player.name)

	# Check if player is blocking or parrying
	var parry_system = player.get_node_or_null("CombatSystem/ParrySystem")
	if parry_system:
		# Check if in perfect parry window
		if parry_system.has_method("is_parrying") and parry_system.is_parrying():
			# PERFECT PARRY - Reflect projectile!
			print("[Projectile] PERFECT PARRY - Reflecting!")
			_reflect_projectile(player, parry_system)
			return
		# Check if just blocking (shield visible but not parry window)
		elif parry_system.has_method("is_blocking") and parry_system.is_blocking():
			# BLOCKED - Destroy projectile without damage
			print("[Projectile] BLOCKED - Destroying without damage")
			_destroy_on_block()
			return

	# Normal hit - damage applied via hurtbox interaction
	# The projectile's HitboxComponent will trigger player's HurtboxComponent
	# We just need to destroy the projectile after hit
	_destroy_on_hit()

func _reflect_projectile(player: Node, parry_system: Node) -> void:
	"""Reflects projectile back to shooter on perfect parry"""

	print("[Projectile] Reflecting back to shooter!")

	# Trigger perfect parry in ParrySystem
	if parry_system.has_method("_handle_perfect_parry") and shooter:
		# This will stun the shooter, add resonance, slow-mo, etc.
		parry_system._handle_perfect_parry(shooter)

	# Spawn parry effect
	_spawn_parry_effect()

	# Reverse direction - send it back to shooter
	if shooter:
		var new_direction = (shooter.global_position - global_position).normalized()
		direction = new_direction
		print("[Projectile] New direction: %v, speed increased!" % direction)

		# Increase speed for dramatic effect
		speed *= 1.5

		# Change visual to indicate reflection (make it brighter/different color)
		if sprite:
			sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)  # Bright yellow

		# Make it damage enemies now instead of player
		# Swap collision layers/masks
		if hitbox:
			hitbox.collision_mask = 16  # Hit enemies instead of player
	else:
		# No shooter to reflect to, just destroy
		queue_free()


func _destroy_on_block() -> void:
	"""Destroys projectile when blocked (not parried)"""

	print("[Projectile] Blocked by shield, destroying")

	# Spawn block effect
	_spawn_parry_effect()  # Reuse parry effect for now

	# Destroy projectile
	queue_free()

func _destroy_on_hit() -> void:
	"""Destroys projectile after hitting target"""

	# Spawn impact VFX
	_spawn_impact_effect()

	# Destroy immediately (damage already applied)
	queue_free()

func _destroy_on_wall() -> void:
	"""Destroys projectile when hitting wall"""

	print("[Projectile] Hit wall, destroying")

	# Small impact effect
	_spawn_wall_impact_effect()

	# Destroy
	queue_free()

# ============================================================================
# LIFETIME
# ============================================================================

func _on_lifetime_expired() -> void:
	"""Called when projectile lifetime expires"""

	print("[Projectile] Lifetime expired, destroying")

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished

	queue_free()

# ============================================================================
# VFX
# ============================================================================

func _spawn_impact_effect() -> void:
	"""Spawns VFX on hit"""
	# TODO: Spawn impact particles
	# Placeholder: Simple flash
	pass

func _spawn_parry_effect() -> void:
	"""Spawns VFX on parry"""
	# Use ParryFlash from Commit 004
	var flash_scene = load("res://vfx/particles/parry_flash.tscn")
	if flash_scene:
		var flash = flash_scene.instantiate()
		get_tree().root.add_child(flash)
		flash.global_position = global_position

func _spawn_wall_impact_effect() -> void:
	"""Spawns VFX on wall hit"""
	# TODO: Small puff
	pass
