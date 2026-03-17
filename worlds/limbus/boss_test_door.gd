extends Area2D
## Boss Test Door - Oeffnet den Vor-Boss-Raum (Lythrun oder Mirror-Auswahl)

var player_in_area: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_in_area:
		return

	var interact_pressed: bool = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_open_boss_choice_room()


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


func _open_boss_choice_room() -> void:
	if RunManager and RunManager.is_run_active():
		return

	print("[BossTestDoor] Lade Vor-Boss-Raum (Abgrund)")
	get_tree().change_scene_to_file("res://worlds/run_rooms/abgrund/pre_boss_room.tscn")
