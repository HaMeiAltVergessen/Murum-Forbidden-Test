extends Area2D
class_name PressurePlate

## Pressure plate that detects bodies standing on it
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal plate_pressed(activator: CharacterBody2D)
signal plate_released(last_activator: CharacterBody2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var require_enemy: bool = true  ## Require enemy to activate (vs player)
@export var visual_feedback: bool = true

# ============================================================================
# STATE
# ============================================================================

var is_pressed: bool = false
var bodies_on_plate: Array[CharacterBody2D] = []

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
	body_exited.connect(_on_body_exited)

	add_to_group("pressure_plates")

	print("[PressurePlate] %s initialized (require_enemy: %s)" % [name, require_enemy])

# ============================================================================
# COLLISION HANDLERS
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Handles body entering plate"""
	print("[PressurePlate] Body entered: %s (class: %s, groups: %s)" % [body.name, body.get_class(), body.get_groups()])

	# Check if valid body
	if not _is_valid_body(body):
		print("[PressurePlate] Body not valid for activation")
		return

	var char_body = body as CharacterBody2D
	if not char_body:
		return

	# Add to bodies on plate
	if char_body not in bodies_on_plate:
		bodies_on_plate.append(char_body)

	# Activate if not already pressed
	if not is_pressed:
		_press(char_body)

func _on_body_exited(body: Node2D) -> void:
	"""Handles body leaving plate"""
	var char_body = body as CharacterBody2D
	if not char_body:
		return

	# Remove from bodies on plate
	if char_body in bodies_on_plate:
		bodies_on_plate.erase(char_body)

	# Release if no more bodies
	if bodies_on_plate.is_empty() and is_pressed:
		_release(char_body)

# ============================================================================
# ACTIVATION
# ============================================================================

func _press(activator: CharacterBody2D) -> void:
	"""Activates the pressure plate"""
	is_pressed = true
	plate_pressed.emit(activator)

	# Visual feedback
	if visual_feedback:
		_play_press_visual()

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/plate_pressed")

	print("[PressurePlate] %s pressed by %s" % [name, activator.name])

func _release(last_body: CharacterBody2D = null) -> void:
	"""Deactivates the pressure plate"""
	is_pressed = false
	plate_released.emit(last_body)

	# Visual feedback
	if visual_feedback:
		_play_release_visual()

	# Audio feedback
	if AudioManager:
		AudioManager.play_sfx("puzzle/plate_released")

	print("[PressurePlate] %s released" % name)

# ============================================================================
# VALIDATION
# ============================================================================

func _is_valid_body(body: Node) -> bool:
	"""Checks if body is valid for activation"""
	if not body is CharacterBody2D:
		return false

	if require_enemy:
		# Must be enemy
		return body.is_in_group("enemies") or body.is_in_group("enemy")
	else:
		# Can be player or enemy
		return body.is_in_group("player") or body.is_in_group("player2") or body.is_in_group("enemies") or body.is_in_group("enemy")

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _play_press_visual() -> void:
	"""Plays press visual effect"""
	if sprite:
		# Move down slightly
		var tween = create_tween()
		tween.tween_property(sprite, "position:y", 4.0, 0.1)

		# Yellow color
		sprite.modulate = Color(1.0, 1.0, 0.5, 1.0)

func _play_release_visual() -> void:
	"""Plays release visual effect"""
	if sprite:
		# Move back up
		var tween = create_tween()
		tween.tween_property(sprite, "position:y", 0.0, 0.1)

		# Reset color
		sprite.modulate = Color.WHITE
