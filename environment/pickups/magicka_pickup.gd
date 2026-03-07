extends Area2D
## Magicka Pickup - Persistent currency for permanent upgrades
## Survives death. Dropped by bosses or hidden in the world.

@export var amount: int = 1
@export var pickup_id: String = ""  # Unique ID so it's only collectible once per world placement

var player_in_range: bool = false
var is_picked_up: bool = false


func _ready() -> void:
	if pickup_id == "":
		pickup_id = "magicka_%d" % get_instance_id()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)

	var prompt = get_node_or_null("PromptLabel")
	if prompt:
		prompt.visible = false

	print("[MagickaPickup] Ready: amount=%d id=%s" % [amount, pickup_id])


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
	EventBus.show_notification.emit("Magicka +%d erhalten!" % amount, 2.5)

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("item_pickup")

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

	print("[MagickaPickup] Collected: +%d Magicka (total: %d)" % [amount, RunManager.get_magicka()])
