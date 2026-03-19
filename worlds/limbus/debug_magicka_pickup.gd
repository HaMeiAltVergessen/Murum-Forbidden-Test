extends Area2D
## Debug Magicka Pickup - Respawns after collection (infinite Magicka for testing)

@export var amount: int = 5
@export var respawn_time: float = 3.0

var player_in_range: bool = false
var is_picked_up: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)

	var prompt = get_node_or_null("PromptLabel")
	if prompt:
		prompt.visible = false

	print("[DebugMagicka] Ready: +%d per pickup, respawns after %.1fs" % [amount, respawn_time])


func _process(_delta: float) -> void:
	if not player_in_range or is_picked_up:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_collect()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Murum" or body is Murum:
		player_in_range = true
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Murum" or body is Murum:
		player_in_range = false
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.visible = false


func _collect() -> void:
	if is_picked_up:
		return
	is_picked_up = true

	RunManager.add_magicka(amount)
	EventBus.magicka_changed.emit(RunManager.get_magicka())
	EventBus.show_notification.emit("Magicka +%d erhalten!" % amount, 2.0)

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("item_pickup")

	print("[DebugMagicka] Collected: +%d (total: %d)" % [amount, RunManager.get_magicka()])

	# Fade out visual
	var visual = get_node_or_null("Visual")
	if visual:
		visual.modulate.a = 0.3

	var prompt = get_node_or_null("PromptLabel")
	if prompt:
		prompt.visible = false

	# Respawn after delay
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	is_picked_up = false

	var visual = get_node_or_null("Visual")
	if visual:
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 1.0, 0.5)

	# Re-show prompt if player still in range
	if player_in_range:
		var prompt = get_node_or_null("PromptLabel")
		if prompt:
			prompt.visible = true

	print("[DebugMagicka] Respawned!")
