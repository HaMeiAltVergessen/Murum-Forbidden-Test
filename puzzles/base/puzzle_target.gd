extends StaticBody2D
class_name PuzzleTarget

## Base class for puzzle targets (Türen, Barrieren, Belohnungen)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal unlocked()
signal locked()

# ============================================================================
# EXPORTS
# ============================================================================

@export var unlock_sound: String = "puzzle/door_open"
@export var animation_name: String = "open"

# ============================================================================
# STATE
# ============================================================================

var is_unlocked: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("puzzle_targets")
	print("[PuzzleTarget] %s initialized" % name)

# ============================================================================
# UNLOCK/LOCK
# ============================================================================

func unlock() -> void:
	"""Unlocks the target (opens door, removes barrier, etc.)"""
	if is_unlocked:
		return

	is_unlocked = true

	# Play animation
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		await animation_player.animation_finished
	else:
		# Fallback: fade out
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
			await tween.finished

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Play sound
	if AudioManager and unlock_sound != "":
		AudioManager.play_sfx(unlock_sound)

	unlocked.emit()
	print("[PuzzleTarget] %s unlocked" % name)

func lock() -> void:
	"""Locks the target (closes door, enables barrier, etc.)"""
	if not is_unlocked:
		return

	is_unlocked = false

	# Enable collision
	if collision_shape:
		collision_shape.disabled = false

	# Play reverse animation
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play_backwards(animation_name)
	else:
		# Fallback: fade in
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

	locked.emit()
	print("[PuzzleTarget] %s locked" % name)
