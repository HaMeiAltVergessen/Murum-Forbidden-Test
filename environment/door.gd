extends StaticBody2D
## Door - Opens when activated by lever
class_name Door

# ============ DOOR STATES ============
enum DoorState {
	LOCKED,
	CLOSED,
	OPENING,
	OPEN
}

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ============ CONFIGURATION ============
@export var opening_duration: float = 1.0
@export var connected_lever: NodePath

# ============ STATE ============
var current_state: DoorState = DoorState.LOCKED


func _ready() -> void:
	# Set initial visual
	_update_visual()

	# Connect to lever if specified
	if connected_lever:
		var lever: Lever = get_node_or_null(connected_lever) as Lever
		if lever:
			lever.activated.connect(unlock)

	print("[Door] Initialized at ", global_position)


# ============ STATE MANAGEMENT ============
func unlock() -> void:
	"""Unlocks the door (called by lever)"""
	if current_state != DoorState.LOCKED:
		return

	current_state = DoorState.CLOSED
	print("[Door] Unlocked")

	# Immediately start opening
	open()


func open() -> void:
	"""Opens the door"""
	if current_state == DoorState.OPENING or current_state == DoorState.OPEN:
		return

	if current_state == DoorState.LOCKED:
		print("[Door] Cannot open - door is locked!")
		return

	current_state = DoorState.OPENING

	# Play sound
	AudioManager.play_sfx("door_open")

	# Animate opening
	_animate_opening()

	print("[Door] Opening...")


func _animate_opening() -> void:
	"""Animates door opening"""
	# Fade out and move up
	if sprite:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, opening_duration)
		tween.tween_property(sprite, "position:y", sprite.position.y - 64, opening_duration)

	# Disable collision after animation starts
	await get_tree().create_timer(0.1).timeout
	if collision_shape:
		collision_shape.disabled = true

	# Wait for animation to finish
	await get_tree().create_timer(opening_duration).timeout

	# Set to open state
	current_state = DoorState.OPEN
	_update_visual()

	# Emit signal
	EventBus.door_state_changed.emit(self, "open")

	print("[Door] Fully opened")


# ============ VISUAL ============
func _update_visual() -> void:
	"""Updates door appearance based on state"""
	if not sprite:
		return

	match current_state:
		DoorState.LOCKED:
			sprite.modulate = Color(0.6, 0.3, 0.1, 1)  # Brown/locked
		DoorState.CLOSED:
			sprite.modulate = Color(0.8, 0.6, 0.3, 1)  # Lighter brown/unlocked
		DoorState.OPENING:
			pass  # Animation handles this
		DoorState.OPEN:
			sprite.modulate = Color(0.8, 0.6, 0.3, 0)  # Transparent


# ============ GETTERS ============
func is_open() -> bool:
	"""Returns true if door is open"""
	return current_state == DoorState.OPEN


func is_locked() -> bool:
	"""Returns true if door is locked"""
	return current_state == DoorState.LOCKED
