extends Area2D
class_name Checkpoint

## Checkpoint for saving player progress

# ============================================================================
# PROPERTIES
# ============================================================================

@export var checkpoint_id: String = ""
@export var is_activated: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Generate ID if not set
	if checkpoint_id.is_empty():
		checkpoint_id = "%s/%s/%s" % [
			WorldManager.current_world,
			WorldManager.current_room,
			name
		]

	# Setup interaction
	body_entered.connect(_on_body_entered)

	# Update visual
	_update_visual()

	add_to_group("checkpoints")

	print("[Checkpoint] Ready: %s (activated: %s)" % [checkpoint_id, is_activated])

# ============================================================================
# INTERACTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Activates checkpoint when player enters"""
	if not body.is_in_group("player"):
		return

	if is_activated:
		return

	activate()

func activate() -> void:
	"""Activates this checkpoint"""

	if is_activated:
		return

	is_activated = true

	# Set as last checkpoint in WorldManager
	if WorldManager:
		WorldManager.set_last_checkpoint(checkpoint_id, global_position)

	# Visual feedback
	_update_visual()
	_play_activation_effect()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("environment/checkpoint_activate", global_position, 0.0)

	# Notification
	EventBus.show_notification.emit("Checkpoint Activated", 2.0)

	# Emit signal
	EventBus.checkpoint_set.emit(checkpoint_id, global_position)

	print("[Checkpoint] Activated: %s" % checkpoint_id)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	"""Updates visual based on activation state"""
	if not sprite:
		return

	if is_activated:
		sprite.modulate = Color(0.5, 1.0, 0.5)  # Green
	else:
		sprite.modulate = Color(0.7, 0.7, 0.7)  # Gray

func _play_activation_effect() -> void:
	"""Visual effect for activation"""
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

	# Screen flash
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").flash(Color(0.5, 1.0, 0.5, 0.3), 0.3)
