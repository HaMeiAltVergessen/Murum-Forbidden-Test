extends StaticBody2D
## Door - Opens when activated by lever OR transitions to another room
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
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

# ============ CONFIGURATION ============
@export var door_id: String = ""
@export var opening_duration: float = 1.0
@export var connected_lever: NodePath

# Room Transition Properties
@export var is_transition_door: bool = false
@export var target_room: String = ""
@export var spawn_point: String = "default"
@export var unlock_on_room_clear: bool = true

# ============ STATE ============
var current_state: DoorState = DoorState.LOCKED
var player_in_range: bool = false


func _ready() -> void:
	# Add to doors group
	add_to_group("doors")

	# Set initial visual
	_update_visual()

	# Connect to lever if specified
	if connected_lever:
		var lever: Lever = get_node_or_null(connected_lever) as Lever
		if lever:
			lever.activated.connect(unlock)

	# Setup interaction area for transition doors
	if is_transition_door and interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Hide prompt initially
	if prompt_label:
		prompt_label.visible = false

	# Check if should start unlocked
	if is_transition_door and not unlock_on_room_clear:
		unlock()

	print("[Door] Initialized at %v (transition: %s)" % [global_position, is_transition_door])


# ============ INPUT ============
func _input(event: InputEvent) -> void:
	if not player_in_range or not is_transition_door:
		return

	if event.is_action_pressed("interact"):
		attempt_use()

func attempt_use() -> void:
	"""Attempts to use transition door"""
	if is_locked():
		_show_locked_message()
		return

	# Trigger room transition
	_transition_to_target_room()

func _transition_to_target_room() -> void:
	"""Transitions to target room"""
	if target_room.is_empty():
		push_error("[Door] No target room set!")
		return

	print("[Door] Transitioning to room: %s" % target_room)
	WorldManager.transition_to_room(target_room, spawn_point)

func _show_locked_message() -> void:
	"""Shows locked door message"""
	if not is_transition_door:
		return

	if prompt_label:
		prompt_label.text = "Locked - Clear room first"

# ============ PLAYER DETECTION ============
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

		if prompt_label:
			prompt_label.visible = true
			_update_prompt_text()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

		if prompt_label:
			prompt_label.visible = false

func _update_prompt_text() -> void:
	"""Updates interaction prompt"""
	if not prompt_label:
		return

	if is_locked():
		prompt_label.text = "Locked"
	else:
		prompt_label.text = "Press E to Enter"

# ============ ROOM CLEAR UNLOCK ============
func try_unlock_on_clear(_room_id: String) -> void:
	"""Called by WorldManager when room is cleared"""
	if unlock_on_room_clear and is_locked():
		unlock()

# ============ STATE MANAGEMENT ============
func lock() -> void:
	"""Locks the door"""
	if current_state == DoorState.LOCKED:
		return

	current_state = DoorState.LOCKED
	print("[Door] Locked")

	# Update visual
	_update_visual()
	if player_in_range:
		_update_prompt_text()

func unlock() -> void:
	"""Unlocks the door (called by lever or room clear)"""
	if current_state != DoorState.LOCKED:
		return

	current_state = DoorState.CLOSED
	print("[Door] Unlocked")

	# For lever doors, immediately open
	# For transition doors, just unlock (player must interact)
	if not is_transition_door:
		open()
	else:
		# Update visual for unlocked state
		_update_visual()
		if player_in_range:
			_update_prompt_text()


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
