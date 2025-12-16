extends Node2D
## Lever - Activates doors and other mechanisms
class_name Lever

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $InteractionPrompt

# ============ STATE ============
var is_activated: bool = false
var player_in_range: bool = false

# ============ SIGNALS ============
signal activated()


func _ready() -> void:
	# Setup interaction area
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Hide prompt initially
	if prompt_label:
		prompt_label.visible = false

	# Set initial visual state
	_update_visual()

	print("[Lever] Initialized at ", global_position)


func _process(_delta: float) -> void:
	# Check for interaction input
	if player_in_range and not is_activated:
		if Input.is_action_just_pressed("interact"):
			activate()


# ============ INTERACTION ============
func _on_body_entered(body: Node2D) -> void:
	"""Player enters interaction range"""
	if body is Murum and not is_activated:
		player_in_range = true
		_show_prompt()


func _on_body_exited(body: Node2D) -> void:
	"""Player exits interaction range"""
	if body is Murum:
		player_in_range = false
		_hide_prompt()


func activate() -> void:
	"""Activates the lever"""
	if is_activated:
		return

	is_activated = true

	# Play sound
	AudioManager.play_sfx("lever_pull")

	# Update visual
	_update_visual()

	# Hide prompt
	_hide_prompt()

	# Emit signals
	activated.emit()
	EventBus.lever_activated.emit(self)

	print("[Lever] Activated at ", global_position)


# ============ UI ============
func _show_prompt() -> void:
	"""Shows interaction prompt"""
	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "Press E"

	EventBus.show_interaction_prompt.emit("Press E to activate")


func _hide_prompt() -> void:
	"""Hides interaction prompt"""
	if prompt_label:
		prompt_label.visible = false

	EventBus.hide_interaction_prompt.emit()


# ============ VISUAL ============
func _update_visual() -> void:
	"""Updates lever appearance based on state"""
	if not sprite:
		return

	if is_activated:
		# Green when activated
		sprite.modulate = Color(0, 1, 0, 1)
	else:
		# Yellow when inactive
		sprite.modulate = Color(1, 1, 0, 1)
