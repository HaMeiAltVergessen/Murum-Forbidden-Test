extends Area2D
class_name PuzzleSwitch

## Base class for all puzzle switches (Schalter, Kristalle, Druckplatten)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal switch_activated(switch_id: int, activator: Node2D)
signal switch_deactivated(switch_id: int)

# ============================================================================
# EXPORTS
# ============================================================================

@export var switch_id: int = 0
@export var can_deactivate: bool = false  ## Can this switch be turned off?
@export var activation_sound: String = "puzzle/switch_activate"
@export var visual_feedback: bool = true

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

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Add to group
	add_to_group("puzzle_switches")

	# Update ID label if it exists
	var id_label = get_node_or_null("Sprite2D/IDLabel")
	if id_label and id_label is Label:
		id_label.text = str(switch_id)

	print("[PuzzleSwitch] %s initialized (ID: %d)" % [name, switch_id])

# ============================================================================
# ACTIVATION
# ============================================================================

func activate(activator: Node2D = null) -> void:
	"""Activates the switch"""
	if is_activated:
		return

	is_activated = true
	switch_activated.emit(switch_id, activator)

	# Visual feedback
	if visual_feedback:
		_play_activation_visual()

	# Audio feedback
	if AudioManager and activation_sound != "":
		AudioManager.play_sfx(activation_sound)

	print("[PuzzleSwitch] %s activated (ID: %d)" % [name, switch_id])

func deactivate() -> void:
	"""Deactivates the switch (if allowed)"""
	if not can_deactivate or not is_activated:
		return

	is_activated = false
	switch_deactivated.emit(switch_id)

	# Visual feedback
	if visual_feedback:
		_play_deactivation_visual()

	print("[PuzzleSwitch] %s deactivated (ID: %d)" % [name, switch_id])

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Handles body collision (player interaction)"""
	if body.is_in_group("player") or body.is_in_group("player2"):
		activate(body)

func _on_area_entered(area: Area2D) -> void:
	"""Handles area collision (staff projectile or shadow scythe)"""
	# Support both P1 Staff Throw and P2 Shadow Scythe
	if area.is_in_group("staff_projectile") or area.is_in_group("staff_projectiles") or area.is_in_group("shadow_scythe"):
		# Try to get owner player from metadata
		var owner_player = area.get_meta("owner_player", null) if area.has_meta("owner_player") else area.owner
		activate(owner_player)
		print("[PuzzleSwitch] Hit by projectile (owner: %s)" % (owner_player.name if owner_player else "unknown"))

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_activation_visual() -> void:
	"""Plays activation visual effect"""
	if sprite:
		# Green flash
		var original_modulate = sprite.modulate
		sprite.modulate = Color(0.5, 2.0, 0.5, 1.0)  # Green

		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.3)

	if particles:
		particles.restart()
		particles.emitting = true

func _play_deactivation_visual() -> void:
	"""Plays deactivation visual effect"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

	if particles:
		particles.emitting = false

func set_correct_visual() -> void:
	"""Sets visual to 'correct' state (green)"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.2)

func set_incorrect_visual() -> void:
	"""Sets visual to 'incorrect' state (red flash)"""
	if sprite:
		# Red flash
		sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)

		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
