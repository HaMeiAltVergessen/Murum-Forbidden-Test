extends CanvasLayer
## P2 Tutorial - Shows control tutorial when P2 first joins
## Pauses game temporarily

@onready var overlay: ColorRect = $Overlay if has_node("Overlay") else null

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
	visible = true

	# Pause game temporarily
	get_tree().paused = true

	# Fade-in
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Process even when paused
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	print("[P2 Tutorial] Tutorial shown")

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
