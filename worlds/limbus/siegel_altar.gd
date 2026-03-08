extends Area2D
## Siegel-Altar - Opens the Seal configuration menu in Limbus
## Player configures seals here, then starts run at the Run Door

var player_in_range: bool = false
var menu_instance: Node = null
var is_menu_open: bool = false

const CHALLENGE_MENU_SCENE = preload("res://ui/menus/challenge_run_menu.tscn")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var prompt = get_node_or_null("PromptLabel")
	if prompt:
		prompt.visible = false


func _process(_delta: float) -> void:
	if is_menu_open or not player_in_range:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_open_seal_menu()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_range = true
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.text = "E - Siegel einstellen"
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_range = false
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.visible = false


func _open_seal_menu() -> void:
	if is_menu_open:
		return

	is_menu_open = true
	print("[SiegelAltar] Opening seal menu")

	# Pause gameplay while menu is open
	if GameManager:
		GameManager.current_state = GameManager.GameState.PAUSED
	get_tree().paused = true

	# Instantiate the seal menu
	menu_instance = CHALLENGE_MENU_SCENE.instantiate()
	menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(menu_instance)

	# Connect signals
	menu_instance.back_pressed.connect(_on_menu_closed)
	menu_instance.challenge_started.connect(_on_seals_confirmed)


func _on_seals_confirmed() -> void:
	"""Seals confirmed — in Limbus this just closes the menu (run starts at door)"""
	var active = ChallengeRunManager.get_active_count()
	var tiefe = ChallengeRunManager.get_tiefe()
	print("[SiegelAltar] Siegel bestätigt! Aktiv: %d, Tiefe: %d" % [active, tiefe])

	if EventBus:
		EventBus.show_notification.emit(
			"Siegel konfiguriert: %d aktiv (Tiefe: %d)" % [active, tiefe], 3.0
		)

	_close_menu(false)


func _on_menu_closed() -> void:
	"""Menu closed via back button — don't reset seals in Limbus"""
	_close_menu(false)


func _close_menu(reset_seals: bool) -> void:
	if menu_instance and is_instance_valid(menu_instance):
		menu_instance.queue_free()
		menu_instance = null

	is_menu_open = false

	# Unpause gameplay
	get_tree().paused = false
	if GameManager:
		GameManager.current_state = GameManager.GameState.PLAYING

	print("[SiegelAltar] Menu closed (reset_seals: %s)" % reset_seals)
