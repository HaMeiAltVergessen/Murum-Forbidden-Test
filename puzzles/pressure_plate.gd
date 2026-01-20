extends Area2D
class_name PressurePlate

## Simple one-time pressure plate (like a switch without interact)
## Activates once when player steps on it
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal plate_pressed(activator: CharacterBody2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var visual_feedback: bool = true

# ============================================================================
# STATE
# ============================================================================

var is_activated: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Godot 4.4: Explicitly set monitoring
	monitoring = true
	monitorable = true

	# Connect signals
	body_entered.connect(_on_body_entered)

	add_to_group("pressure_plates")

	print("[PressurePlate] %s initialized (one-time activation)" % name)

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Handles body entering plate - activates once"""
	# Already activated, ignore
	if is_activated:
		return

	print("[PressurePlate] Body entered: %s (groups: %s)" % [body.name, body.get_groups()])

	# Check if valid body (player or player2)
	if not _is_valid_body(body):
		print("[PressurePlate] Body not valid for activation")
		return

	var char_body = body as CharacterBody2D
	if not char_body:
		return

	# Activate once
	_activate(char_body)

# ============================================================================
# ACTIVATION
# ============================================================================

func _activate(activator: CharacterBody2D) -> void:
	"""Activates the pressure plate once"""
	is_activated = true
	plate_pressed.emit(activator)

	# Visual feedback
	if visual_feedback:
		_play_press_visual()

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/plate_pressed")

	# Disable further detection
	monitoring = false

	print("[PressurePlate] %s activated by %s (one-time)" % [name, activator.name])

# ============================================================================
# VALIDATION
# ============================================================================

func _is_valid_body(body: Node) -> bool:
	"""Checks if body is valid for activation (player only)"""
	if not body is CharacterBody2D:
		return false

	# Only players can activate
	return body.is_in_group("player") or body.is_in_group("player2")

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_press_visual() -> void:
	"""Plays press visual effect"""
	if sprite:
		# Move down slightly
		var tween = create_tween()
		tween.tween_property(sprite, "position:y", 4.0, 0.1)

		# Green color for activated
		sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)
