extends StaticBody2D
class_name TimedDoor

## Door that opens temporarily when activated
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal door_opened()
signal door_closed()

# ============================================================================
# EXPORTS
# ============================================================================

@export var default_open_duration: float = 3.0

# ============================================================================
# STATE
# ============================================================================

var is_open: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var close_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("timed_doors")
	print("[TimedDoor] %s initialized" % name)

# ============================================================================
# OPEN/CLOSE
# ============================================================================

func open_timed(duration: float = -1.0) -> void:
	"""Opens door for specified duration"""
	if duration < 0:
		duration = default_open_duration

	# Open the door
	open()

	# Create timer for auto-close
	if close_timer:
		close_timer.stop()
		close_timer.queue_free()

	close_timer = Timer.new()
	close_timer.one_shot = true
	close_timer.wait_time = duration
	close_timer.timeout.connect(_on_close_timer_timeout)
	add_child(close_timer)
	close_timer.start()

	print("[TimedDoor] %s opened for %.1fs" % [name, duration])

func open() -> void:
	"""Opens the door"""
	if is_open:
		return

	is_open = true

	# Play animation or fallback
	if animation_player and animation_player.has_animation("door_open"):
		animation_player.play("door_open")
	else:
		# Fallback: fade out
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.3, 0.3)

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("puzzle/door_open")

	door_opened.emit()
	print("[TimedDoor] %s opened" % name)

func close() -> void:
	"""Closes the door"""
	if not is_open:
		return

	is_open = false

	# Play reverse animation or fallback
	if animation_player and animation_player.has_animation("door_open"):
		animation_player.play_backwards("door_open")
	else:
		# Fallback: fade in
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, 0.3)

	# Enable collision
	if collision_shape:
		collision_shape.disabled = false

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("puzzle/door_close")

	door_closed.emit()
	print("[TimedDoor] %s closed" % name)

# ============================================================================
# TIMER HANDLER
# ============================================================================

func _on_close_timer_timeout() -> void:
	"""Handles timer timeout - closes door"""
	close()

	# Clean up timer
	if close_timer:
		close_timer.queue_free()
		close_timer = null
