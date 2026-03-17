extends Area2D
## Boss Test Door - Starts an Abgrund run directly (for testing Welt 3 boss)

var player_in_area: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_in_area:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_start_boss_run()


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


func _start_boss_run() -> void:
	if RunManager.is_run_active():
		return

	# Save boons before run start (run_started signal clears them)
	var saved_boons: Dictionary = BoonManager.get_save_data()

	print("[BossTestDoor] Starting Abgrund boss test run")
	RunManager.start_run(RunMapData.WorldId.ABGRUND)

	# Restore boons after run start cleared them
	if not saved_boons.get("active_boons", {}).is_empty():
		BoonManager.load_from_save(saved_boons)
		print("[BossTestDoor] Restored %d boons" % BoonManager.get_active_boon_count())
