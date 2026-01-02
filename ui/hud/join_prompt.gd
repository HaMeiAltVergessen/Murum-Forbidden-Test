extends CanvasLayer
## Join Prompt - Prompts P2 to join the game
## Shows "Press START to join" message
## COMMIT 022.5: Extended with controller detection and warnings

@onready var prompt_panel: Control = $CenterContainer/PanelContainer if has_node("CenterContainer/PanelContainer") else null
@onready var prompt_label: Label = $CenterContainer/PanelContainer/VBoxContainer/PromptLabel if has_node("CenterContainer/PanelContainer/VBoxContainer/PromptLabel") else null
@onready var warning_label: Label = $CenterContainer/PanelContainer/VBoxContainer/WarningLabel if has_node("CenterContainer/PanelContainer/VBoxContainer/WarningLabel") else null

var is_showing: bool = false
var show_timer: float = 0.0
const SHOW_DURATION: float = 8.0  # Show prompt for 8 seconds (longer for better visibility)
const SHOW_DELAY: float = 2.0  # Delay before showing

func _ready() -> void:
	visible = false

	# Hide warning label initially
	if warning_label:
		warning_label.visible = false

	# Wait before showing prompt
	await get_tree().create_timer(SHOW_DELAY).timeout

	# Show prompt if P2 not active yet
	if not (CoopManager and CoopManager.is_p2_active):
		check_controller_and_show_prompt()

	# Connect signals
	if InputManager and InputManager.has_signal("p2_join_requested"):
		InputManager.p2_join_requested.connect(_on_p2_join_requested)

	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)

	print("[Join Prompt] Initialized")

func check_controller_and_show_prompt() -> void:
	"""Check if controller is available and show appropriate prompt"""
	if not InputManager:
		show_prompt()
		return

	# Check if controller is available
	if not InputManager.has_controller():
		# No controller - show warning
		if prompt_label:
			prompt_label.text = "Connect a controller to join as Lythrun"
		if warning_label:
			warning_label.text = "⚠ No controller detected"
			warning_label.visible = true
			warning_label.modulate = Color(1.0, 0.6, 0)  # Orange warning
	else:
		# Controller available
		var controller_name = "Controller"
		if InputManager.detected_controllers.size() > 0:
			controller_name = Input.get_joy_name(InputManager.detected_controllers[0])

		if prompt_label:
			prompt_label.text = "Press START on controller to join as Lythrun"

		if warning_label:
			warning_label.visible = false

	show_prompt()

func show_prompt() -> void:
	"""Show the join prompt with fade-in"""
	visible = true
	is_showing = true
	show_timer = SHOW_DURATION

	# Fade-in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_prompt() -> void:
	"""Hide the join prompt with fade-out"""
	is_showing = false

	# Fade-out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)

func _process(delta: float) -> void:
	if is_showing:
		show_timer -= delta

		if show_timer <= 0:
			hide_prompt()

func _on_p2_join_requested() -> void:
	"""Handle P2 join request - hide prompt immediately"""
	hide_prompt()

func _on_p2_joined() -> void:
	"""Handle P2 successfully joining - keep prompt hidden"""
	visible = false
	is_showing = false
