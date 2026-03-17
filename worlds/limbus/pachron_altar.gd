extends Area2D
## PachronAltar — Test altar in Limbus for Pachron boon selection
## Can be used repeatedly

var player_in_area: bool = false
var _selection_active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_in_area or _selection_active:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_open_pachron_selection()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_area = true
		var label = get_node_or_null("PromptLabel")
		if label:
			label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_area = false
		var label = get_node_or_null("PromptLabel")
		if label:
			label.visible = false


func _open_pachron_selection() -> void:
	_selection_active = true

	var screen: PachronSelectionScreen = preload("res://ui/pachron/pachron_selection_screen.tscn").instantiate()
	get_tree().root.add_child(screen)

	# Offer 3 random paths
	var paths: Array = BoonManager.PATH_IDS.duplicate()
	paths.shuffle()
	screen.setup(paths.slice(0, 3))

	# Re-enable on completion or cancel
	screen.boon_flow_completed.connect(_on_selection_done)
	screen.selection_cancelled.connect(_on_selection_cancelled.bind(screen))


func _on_selection_done() -> void:
	_selection_active = false


func _on_selection_cancelled(screen: Node) -> void:
	_selection_active = false
	if is_instance_valid(screen):
		screen.queue_free()
