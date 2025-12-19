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
@export var required_levers: Array[NodePath] = []  # Array of levers required to open

# Room Transition Properties
@export var is_transition_door: bool = false
@export var target_room: String = ""
@export var spawn_point: String = "default"
@export var unlock_on_room_clear: bool = true

# ============ STATE ============
var current_state: DoorState = DoorState.LOCKED
var player_in_range: bool = false
var activated_levers: Array[Lever] = []  # Track which levers have been activated


func _ready() -> void:
	# Add to doors group
	add_to_group("doors")

	# Set initial visual
	_update_visual()

	# Connect to all required levers
	for lever_path in required_levers:
		var lever: Lever = get_node_or_null(lever_path) as Lever
		if lever:
			lever.lever_activated.connect(_on_lever_activated)
			print("[Door] Connected to lever: %s" % lever.name)
		else:
			push_warning("[Door] Could not find lever at path: %s" % lever_path)

	# Setup interaction area for transition doors
	if is_transition_door and interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		print("[Door] Interaction area signals connected - layer: %d, mask: %d, monitoring: %s" % [interaction_area.collision_layer, interaction_area.collision_mask, interaction_area.monitoring])
	else:
		if not is_transition_door:
			print("[Door] Not a transition door - skipping interaction setup")
		if not interaction_area:
			push_warning("[Door] InteractionArea not found!")

	# Hide prompt initially
	if prompt_label:
		prompt_label.visible = false

	# If no levers required, start unlocked
	if required_levers.is_empty() and not unlock_on_room_clear:
		unlock()

	print("[Door] Initialized at %v (transition: %s, levers required: %d)" % [global_position, is_transition_door, required_levers.size()])


# ============ INPUT ============
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		print("[Door] E pressed - player_in_range: %s, is_transition: %s, state: %s" % [player_in_range, is_transition_door, DoorState.keys()[current_state]])

	if not player_in_range or not is_transition_door:
		return

	if event.is_action_pressed("interact"):
		print("[Door] Attempting to use door")
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
	print("[Door] Body entered interaction area: %s (groups: %s)" % [body.name, body.get_groups()])

	if body.is_in_group("player"):
		player_in_range = true
		print("[Door] Player in range, state: %s, is_transition: %s" % [DoorState.keys()[current_state], is_transition_door])

		if prompt_label:
			prompt_label.visible = true
			_update_prompt_text()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		print("[Door] Player left range")

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

# ============ LEVER SYSTEM ============
func _on_lever_activated(lever: Lever) -> void:
	"""Called when a connected lever is activated"""
	if lever in activated_levers:
		return  # Already activated

	activated_levers.append(lever)
	print("[Door] Lever activated: %s (%d/%d)" % [lever.name, activated_levers.size(), required_levers.size()])

	# Check if all required levers are activated
	if activated_levers.size() >= required_levers.size():
		unlock()

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

	# Always open the door when unlocked (makes it passable)
	open()

	# Update prompt if player is in range
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
	# Fade to semi-transparent and move up slightly
	if sprite:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.3, opening_duration)  # Semi-transparent
		tween.tween_property(sprite, "position:y", sprite.position.y - 32, opening_duration)

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

	print("[Door] Fully opened - player can pass through")


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
			sprite.modulate = Color(0.5, 0.8, 0.5, 0.3)  # Green-ish semi-transparent (passable)


# ============ GETTERS ============
func is_open() -> bool:
	"""Returns true if door is open"""
	return current_state == DoorState.OPEN


func is_locked() -> bool:
	"""Returns true if door is locked"""
	return current_state == DoorState.LOCKED
