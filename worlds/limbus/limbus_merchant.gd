extends Area2D
## Limbus Merchant - Sells permanent upgrades for Magicka

var player_in_range: bool = false
var shop_open: bool = false
var shop_ui: CanvasLayer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var prompt = get_node_or_null("PromptLabel")
	if prompt:
		prompt.visible = false


func _process(_delta: float) -> void:
	if shop_open or not player_in_range:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_open_shop()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum:
		player_in_range = true
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.text = "E - Upgrades"
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Murum:
		player_in_range = false
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.visible = false


func _open_shop() -> void:
	if shop_open:
		return
	shop_open = true

	# Pause gameplay
	if GameManager:
		GameManager.current_state = GameManager.GameState.PAUSED
	get_tree().paused = true

	# Create shop UI
	var shop_scene = preload("res://worlds/limbus/upgrade_shop_ui.tscn")
	shop_ui = shop_scene.instantiate()
	shop_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(shop_ui)
	shop_ui.shop_closed.connect(_on_shop_closed)

	print("[LimbusMerchant] Shop opened")


func _on_shop_closed() -> void:
	if shop_ui and is_instance_valid(shop_ui):
		shop_ui.queue_free()
		shop_ui = null

	shop_open = false
	get_tree().paused = false
	if GameManager:
		GameManager.current_state = GameManager.GameState.PLAYING

	# Auto-save after shopping
	if SaveManager:
		SaveManager.save_current_game()

	print("[LimbusMerchant] Shop closed")
