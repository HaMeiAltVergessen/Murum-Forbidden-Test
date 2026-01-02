extends CanvasLayer
## P2 Tutorial - Shows control tutorial when P2 first joins
## Pauses game temporarily
## COMMIT 022.5: Extended with controller-specific button names

@onready var overlay: ColorRect = $Overlay if has_node("Overlay") else null
@onready var controls_grid: GridContainer = $Overlay/CenterContainer/PanelContainer/VBoxContainer/ControlsGrid if has_node("Overlay/CenterContainer/PanelContainer/VBoxContainer/ControlsGrid") else null

var tutorial_shown: bool = false

func _ready() -> void:
	visible = false

	# Connect to CoopManager
	if CoopManager:
		CoopManager.p2_joined.connect(_on_p2_joined)

	print("[P2 Tutorial] Initialized")

func _on_p2_joined() -> void:
	"""Handle P2 joining - show tutorial on first join"""
	if not tutorial_shown:
		show_tutorial()
		tutorial_shown = true

func show_tutorial() -> void:
	"""Show tutorial popup"""
	# Populate controller-specific button names
	populate_controller_controls()

	visible = true

	# Pause game temporarily
	get_tree().paused = true

	# Fade-in (apply to overlay, not CanvasLayer)
	if overlay:
		overlay.modulate.a = 0.0
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Process even when paused
		tween.tween_property(overlay, "modulate:a", 1.0, 0.3)

	print("[P2 Tutorial] Tutorial shown")

func populate_controller_controls() -> void:
	"""Populate controls grid with controller-specific button names"""
	if not controls_grid or not InputManager:
		return

	# Get controller name
	var controller_name = InputManager.get_p2_controller_name()

	# Get button names for this controller type
	var button_names = get_button_names_for_controller(controller_name)

	# Update grid labels
	if controls_grid.has_node("JumpInput"):
		controls_grid.get_node("JumpInput").text = button_names.get("jump", "A Button")
	if controls_grid.has_node("AttackInput"):
		controls_grid.get_node("AttackInput").text = button_names.get("attack", "X Button")
	if controls_grid.has_node("DashInput"):
		controls_grid.get_node("DashInput").text = button_names.get("dash", "B Button")

func get_button_names_for_controller(controller_name: String) -> Dictionary:
	"""Get button names based on controller type"""
	var name_lower = controller_name.to_lower()

	# Xbox controllers
	if "xbox" in name_lower or "xinput" in name_lower:
		return {
			"jump": "A Button",
			"attack": "X Button",
			"dash": "B Button",
			"staff_throw": "Y Button",
			"parry": "LB",
			"urgathon": "RB",
			"inventory": "Select"
		}

	# PlayStation controllers
	elif "playstation" in name_lower or "dualshock" in name_lower or "dualsense" in name_lower:
		return {
			"jump": "✕ (Cross)",
			"attack": "□ (Square)",
			"dash": "○ (Circle)",
			"staff_throw": "△ (Triangle)",
			"parry": "L1",
			"urgathon": "R1",
			"inventory": "Share"
		}

	# Generic controller
	else:
		return {
			"jump": "Button 0",
			"attack": "Button 2",
			"dash": "Button 1",
			"staff_throw": "Button 3",
			"parry": "L-Shoulder",
			"urgathon": "R-Shoulder",
			"inventory": "Select"
		}

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# P2 presses START to close tutorial
	if event.is_action_pressed("p2_join"):
		close_tutorial()
		get_viewport().set_input_as_handled()

func close_tutorial() -> void:
	"""Close tutorial and unpause game"""
	# Fade-out
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		print("[P2 Tutorial] Tutorial closed, game unpaused")
	)
