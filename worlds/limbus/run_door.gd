extends Area2D
## Run Door - Starts a roguelike run when entered
## Located in Limbus hub

@export var first_room_scene: String = "res://worlds/limbus/test_run_room.tscn"
@export var spawn_position: Vector2 = Vector2(300, 500)

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
		_start_run()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_area = true
		var label = get_node_or_null("PromptLabel")
		if label:
			label.text = "E - Run starten"
			label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_area = false
		var label = get_node_or_null("PromptLabel")
		if label:
			label.visible = false


func _start_run() -> void:
	if RunManager.is_run_active():
		return

	# Activate challenge run if seals are configured
	var active_seals = ChallengeRunManager.get_active_count()
	if active_seals > 0:
		ChallengeRunManager.start_challenge_run()
		print("[RunDoor] Starting run with %d active seals (Tiefe: %d)" % [
			active_seals, ChallengeRunManager.get_tiefe()
		])
	else:
		print("[RunDoor] Starting run without seals")

	# Start the run (generates map, switches to MAP_VIEW state)
	RunManager.start_run(RunMapData.WorldId.NIEMANDSLAND)
