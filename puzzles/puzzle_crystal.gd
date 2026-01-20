extends Area2D
class_name PuzzleCrystal

## Crystal that can be hit by staff throw and allows piercing
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal crystal_hit()

# ============================================================================
# EXPORTS
# ============================================================================

@export var crystal_id: int = 0
@export var pierce_delay: float = 0.1  ## Time to disable monitoring to allow piercing

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

	# Set collision layers for staff projectile detection
	# Staff projectiles are typically on layer 11
	collision_mask = 0
	set_collision_mask_value(1, true)   # Default
	set_collision_mask_value(11, true)  # Projectiles

	# Connect signals
	area_entered.connect(_on_area_entered)

	add_to_group("puzzle_crystals")

	print("[PuzzleCrystal] %s initialized (ID: %d)" % [name, crystal_id])

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	"""Handles area collision (staff projectile)"""
	print("[PuzzleCrystal] Area entered: %s (groups: %s)" % [area.name, area.get_groups()])

	# Check if it's a staff projectile
	if not (area.is_in_group("staff_projectile") or area.is_in_group("staff_projectiles")):
		return

	# Only activate once per chain
	if is_activated:
		return

	# Activate crystal
	activate()

	# Allow piercing: temporarily disable monitoring
	_allow_pierce()

# ============================================================================
# ACTIVATION
# ============================================================================

func activate() -> void:
	"""Activates the crystal"""
	if is_activated:
		return

	is_activated = true
	crystal_hit.emit()

	# Visual feedback
	_play_activation_visual()

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/crystal_hit")

	print("[PuzzleCrystal] %s activated (ID: %d)" % [name, crystal_id])

func reset() -> void:
	"""Resets the crystal"""
	is_activated = false
	monitoring = true

	# Reset visual
	if sprite:
		sprite.modulate = Color.WHITE

	if particles:
		particles.emitting = false

	print("[PuzzleCrystal] %s reset" % name)

# ============================================================================
# PIERCING MECHANIC
# ============================================================================

func _allow_pierce() -> void:
	"""Temporarily disables monitoring to allow staff to pierce through"""
	monitoring = false

	# Re-enable after delay
	await get_tree().create_timer(pierce_delay).timeout
	monitoring = true

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_activation_visual() -> void:
	"""Plays activation visual effect"""
	if sprite:
		# Bright cyan glow
		sprite.modulate = Color(0.5, 1.5, 2.0, 1.0)

		# Pulse effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5)

	if particles:
		particles.restart()
		particles.emitting = true

func set_activated_visual() -> void:
	"""Sets visual to activated state"""
	if sprite:
		sprite.modulate = Color(0.5, 1.5, 2.0, 1.0)
