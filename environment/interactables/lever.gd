extends StaticBody2D
class_name Lever

## Interactive lever for puzzles

# ============================================================================
# PROPERTIES
# ============================================================================

@export var lever_id: String = ""
@export var starts_active: bool = false
@export var can_toggle: bool = false  # Can be switched back
@export var connected_door_ids: Array[String] = []

# ============================================================================
# STATE
# ============================================================================

var is_active: bool = false
var player_in_range: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Node = get_node_or_null("Sprite2D")
@onready var handle: Node = get_node_or_null("Handle")
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt: Label = $PromptLabel

# ============================================================================
# SIGNALS
# ============================================================================

signal lever_activated(lever: Lever)
signal lever_deactivated(lever: Lever)
signal lever_toggled(lever: Lever, state: bool)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Generate ID if not set
	if lever_id.is_empty():
		lever_id = "%s/%s/%s" % [
			WorldManager.current_world,
			WorldManager.current_room,
			name
		]

	is_active = starts_active

	# Setup interaction
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Update visual
	_update_visual()

	# Hide prompt
	if prompt:
		prompt.visible = false

	add_to_group("levers")

	print("[Lever] Ready: %s (active: %s)" % [lever_id, is_active])

# ============================================================================
# INTERACTION
# ============================================================================

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("interact"):
		toggle()

func toggle() -> void:
	"""Toggles lever state"""

	# Check if can toggle off
	if is_active and not can_toggle:
		_show_cannot_toggle_message()
		return

	# Toggle state
	is_active = not is_active

	# Visual feedback
	_update_visual()
	_play_toggle_effect()

	# Audio
	if AudioManager:
		var sound = "environment/lever_on" if is_active else "environment/lever_off"
		AudioManager.play_sfx_at_position(sound, global_position, 0.0)

	# Emit signals
	lever_toggled.emit(self, is_active)

	if is_active:
		lever_activated.emit(self)
		_unlock_connected_doors()
	else:
		lever_deactivated.emit(self)
		_lock_connected_doors()

	print("[Lever] Toggled: %s → %s" % [lever_id, "ON" if is_active else "OFF"])

# ============================================================================
# DOOR CONNECTIONS
# ============================================================================

func _unlock_connected_doors() -> void:
	"""Unlocks all connected doors"""

	for door_id in connected_door_ids:
		# Find door by ID
		var door = _find_door_by_id(door_id)

		if door and door.has_method("unlock"):
			door.unlock()
			print("[Lever] Unlocked door: %s" % door_id)

func _lock_connected_doors() -> void:
	"""Locks all connected doors"""

	for door_id in connected_door_ids:
		var door = _find_door_by_id(door_id)

		if door and door.has_method("lock"):
			door.lock()
			print("[Lever] Locked door: %s" % door_id)

func _find_door_by_id(door_id: String) -> Node:
	"""Finds door in scene by ID"""
	var doors = get_tree().get_nodes_in_group("doors")

	for door in doors:
		if door.has("door_id") and door.door_id == door_id:
			return door

	return null

# ============================================================================
# PLAYER DETECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

		if prompt:
			prompt.visible = true
			prompt.text = "Press E to Toggle"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

		if prompt:
			prompt.visible = false

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	"""Updates lever visual based on state"""
	var display_node = handle if handle else sprite
	if not display_node:
		return

	if is_active:
		display_node.rotation = 0.785398  # 45 degrees (lever down)
		display_node.modulate = Color(0.5, 1.0, 0.5)  # Green
	else:
		display_node.rotation = -0.785398  # -45 degrees (lever up)
		display_node.modulate = Color.WHITE

func _play_toggle_effect() -> void:
	"""Visual toggle effect"""
	var display_node = handle if handle else sprite
	if not display_node:
		return

	var tween = create_tween()
	tween.tween_property(display_node, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(display_node, "scale", Vector2(1.0, 1.0), 0.1)

func _show_cannot_toggle_message() -> void:
	"""Shows message when lever cannot be toggled off"""
	EventBus.show_notification.emit("Lever is locked in place", 1.5)
