extends Area2D
class_name PuzzleCrystal

## Crystal that can be hit by staff throw and allows piercing
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal crystal_hit(projectile_owner: Node2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var crystal_id: int = 0
@export var can_reset: bool = false  ## If true, crystal resets after being destroyed
@export var reset_time: float = 5.0  ## Time until crystal resets (if can_reset is true)

# ============================================================================
# STATE
# ============================================================================

var is_activated: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var particles: GPUParticles2D = $ActivationParticles if has_node("ActivationParticles") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Godot 4.4: Explicitly set monitoring
	monitoring = true
	monitorable = true

	# Treat crystal as static enemy - set collision layers like enemy hitbox
	collision_layer = 0
	set_collision_layer_value(8, true)  # Interactables/Enemy Hitboxes (Layer 8)

	collision_mask = 0
	set_collision_mask_value(11, true)  # Projectiles (Layer 11)

	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Add to enemies group so projectiles recognize it as target
	add_to_group("puzzle_crystals")
	add_to_group("enemies")

	print("[PuzzleCrystal] %s initialized as static enemy (ID: %d)" % [name, crystal_id])

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	"""Handles area collision (any projectile)"""
	# Only activate once
	if is_activated:
		return

	print("[PuzzleCrystal] Area entered: %s (layer: %d, groups: %s)" % [area.name, area.collision_layer, area.get_groups()])

	# Check if it's on projectile layer (Layer 11)
	if not area.get_collision_layer_value(11):
		print("[PuzzleCrystal] Not a projectile (not on layer 11)")
		return

	# Get owner player
	var owner_player = area.get_meta("owner_player", null) if area.has_meta("owner_player") else area.owner

	# Activate crystal (destroys it)
	activate(owner_player)

func _on_body_entered(body: Node2D) -> void:
	"""Handles body collision (CharacterBody2D projectiles)"""
	# Only activate once
	if is_activated:
		return

	print("[PuzzleCrystal] Body entered: %s (groups: %s)" % [body.name, body.get_groups()])

	# Check if it's a projectile
	if not (body.is_in_group("projectiles") or "Projectile" in body.name):
		return

	# Get owner player
	var owner_player = body.get_meta("owner_player", null) if body.has_meta("owner_player") else body.owner

	# Activate crystal (destroys it)
	activate(owner_player)

# ============================================================================
# ACTIVATION
# ============================================================================

func activate(projectile_owner: Node2D = null) -> void:
	"""Activates/destroys the crystal (HP system: 1 hit = destroyed)"""
	if is_activated:
		return

	is_activated = true
	crystal_hit.emit(projectile_owner)

	# Visual feedback
	_play_destruction_visual()

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/crystal_shatter")

	# Disable detection while destroyed
	monitoring = false

	if can_reset:
		# Crystal will reset after delay
		print("[PuzzleCrystal] %s destroyed (ID: %d) - resetting in %.1fs" % [name, crystal_id, reset_time])
		await get_tree().create_timer(reset_time).timeout
		reset()
	else:
		# Crystal is permanently destroyed
		print("[PuzzleCrystal] %s destroyed permanently (ID: %d)" % [name, crystal_id])
		await get_tree().create_timer(0.3).timeout
		queue_free()

func reset() -> void:
	"""Resets the crystal"""
	is_activated = false
	monitoring = true

	# Reset visual (fade back in)
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE

		# Fade in effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

	if particles:
		particles.emitting = false

	print("[PuzzleCrystal] %s reset (ID: %d)" % [name, crystal_id])


# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_destruction_visual() -> void:
	"""Plays destruction visual effect"""
	if sprite:
		# White flash then fade
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)

		# Explode and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

	if particles:
		particles.restart()
		particles.emitting = true

func set_activated_visual() -> void:
	"""Sets visual to activated state"""
	if sprite:
		sprite.modulate = Color(0.5, 1.5, 2.0, 1.0)
