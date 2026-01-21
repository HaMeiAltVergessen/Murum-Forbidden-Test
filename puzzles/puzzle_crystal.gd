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
@export var max_hp: int = 10  ## Hit points - crystal destroyed when HP reaches 0
@export var damage_per_hit: int = 1  ## Damage taken per projectile hit

# ============================================================================
# STATE
# ============================================================================

var current_hp: int = 10
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

	# Initialize HP
	current_hp = max_hp

	# Set collision for projectile detection only
	collision_layer = 0
	set_collision_layer_value(8, true)  # Interactables (Layer 8)

	collision_mask = 0
	set_collision_mask_value(5, true)   # Staff Projectiles (Layer 5)
	set_collision_mask_value(11, true)  # Other Projectiles (Layer 11)

	# Connect signals (only area_entered for projectiles)
	area_entered.connect(_on_area_entered)

	# Add to crystal group only (NOT enemies group!)
	add_to_group("puzzle_crystals")

	print("[PuzzleCrystal] %s initialized (ID: %d, HP: %d/%d)" % [name, crystal_id, current_hp, max_hp])

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	"""Handles area collision - only projectiles should trigger"""
	# Already destroyed
	if is_activated:
		return

	print("[PuzzleCrystal] Area entered: %s (layer: %d, groups: %s)" % [area.name, area.collision_layer, area.get_groups()])

	# CRITICAL: Ignore player HurtboxComponent!
	if "Hurtbox" in area.name or "hurtbox" in area.name.to_lower():
		print("[PuzzleCrystal] Ignoring HurtboxComponent")
		return

	# Only accept actual projectiles (check groups)
	var is_projectile = (
		area.is_in_group("staff_projectiles") or   # FIXED: plural!
		area.is_in_group("shadow_scythe") or
		area.is_in_group("projectiles") or
		"Projectile" in area.name
	)

	if not is_projectile:
		print("[PuzzleCrystal] Not a projectile, ignoring")
		return

	print("[PuzzleCrystal] Projectile detected! Taking damage...")

	# Get owner player
	var owner_player = area.get_meta("owner_player", null) if area.has_meta("owner_player") else area.owner

	# Take damage
	take_damage(owner_player)

# ============================================================================
# DAMAGE SYSTEM
# ============================================================================

func take_damage(projectile_owner: Node2D = null) -> void:
	"""Takes damage from projectile hit"""
	if is_activated:
		return

	# Reduce HP
	current_hp -= damage_per_hit
	current_hp = max(0, current_hp)

	print("[PuzzleCrystal] %s hit! HP: %d/%d" % [name, current_hp, max_hp])

	# Visual feedback for damage
	_play_hit_visual()

	# Check if destroyed
	if current_hp <= 0:
		destroy(projectile_owner)  # Pass owner to destroy

func destroy(projectile_owner: Node2D = null) -> void:
	"""Destroys the crystal (HP reached 0)"""
	if is_activated:
		return

	is_activated = true

	# Emit signal for puzzle controller (only on destruction!)
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
	current_hp = max_hp  # Reset HP!

	# Reset visual (fade back in)
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE

		# Fade in effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

	if particles:
		particles.emitting = false

	print("[PuzzleCrystal] %s reset (ID: %d, HP: %d/%d)" % [name, crystal_id, current_hp, max_hp])


# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_hit_visual() -> void:
	"""Plays visual feedback for taking damage (not destroyed yet)"""
	if sprite:
		# Flash white briefly
		var original_color = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)

		# Return to normal
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_color, 0.2)

		# Slight shake
		var shake_amount = 3.0
		var original_pos = sprite.position
		sprite.position = original_pos + Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		tween.tween_property(sprite, "position", original_pos, 0.1)

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
