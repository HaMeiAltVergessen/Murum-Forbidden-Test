extends Area2D
## Base class for all item pickups in the game world

@export var item_id: String = ""
@export var auto_categorize: bool = true

var player_in_range: bool = false
var is_picked_up: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Control = $PickupPrompt


func _ready() -> void:
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Hide prompt initially
	if prompt:
		prompt.visible = false

	# Set collision layers
	set_collision_layer_value(1, true)  # World layer
	set_collision_mask_value(2, true)   # Player layer

	# Update visual if item_id is set
	if item_id != "":
		_update_visual()

	print("[Pickup] Created: ", item_id)


func _process(_delta: float) -> void:
	if not player_in_range or is_picked_up:
		return

	# CRITICAL: Filter input through InputManager (P1 = keyboard-only when P2 active)
	var interact_pressed = false

	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		# Fallback if InputManager missing
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_pickup_item()


func _on_body_entered(body: Node2D) -> void:
	"""Handles player entering pickup range"""
	if body.name == "Murum" or body is Murum:
		player_in_range = true

		if prompt:
			prompt.visible = true

		print("[Pickup] Player in range: ", item_id)


func _on_body_exited(body: Node2D) -> void:
	"""Handles player leaving pickup range"""
	if body.name == "Murum" or body is Murum:
		player_in_range = false

		if prompt:
			prompt.visible = false

		print("[Pickup] Player left range: ", item_id)


func _pickup_item() -> void:
	"""Handles item pickup"""
	if is_picked_up:
		return

	is_picked_up = true

	# Add to inventory
	var category = ""
	if auto_categorize:
		# Auto-detect category from item database
		category = InventoryManager._get_item_category(item_id)

	var success = InventoryManager.add_item(item_id, category)

	if success:
		# Get item data for notification
		var item_data = InventoryManager.get_item_data(item_id)
		var item_name = item_data.get("name", item_id)

		# Show notification
		_show_pickup_notification(item_name, category)

		# Emit signal
		EventBus.item_picked_up.emit(item_id, item_name, category)

		# Visual/Audio feedback
		_play_pickup_effect()

		# Remove from world
		queue_free()

		print("[Pickup] Picked up: ", item_id)
	else:
		print("[Pickup] Failed to pick up: ", item_id)
		is_picked_up = false


func _show_pickup_notification(item_name: String, category: String) -> void:
	"""Shows a notification when item is picked up"""
	var message = "[%s] %s erhalten!" % [category.capitalize(), item_name]
	EventBus.show_notification.emit(message, 2.0)


func _play_pickup_effect() -> void:
	"""Plays visual/audio feedback for pickup"""
	# Audio
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("item_pickup")

	# Visual effect (simple fade out)
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)


# ============ HELPER METHODS ============
func set_item(new_item_id: String) -> void:
	"""Sets the item ID for this pickup"""
	item_id = new_item_id

	# Update visual if possible
	_update_visual()


func _update_visual() -> void:
	"""Updates the pickup visual based on item data"""
	var item_data = InventoryManager.get_item_data(item_id)

	if sprite:
		if item_data.has("icon") and ResourceLoader.exists(item_data["icon"]):
			sprite.texture = load(item_data["icon"])
		else:
			# Create placeholder
			sprite.texture = _create_placeholder_texture()

			# Color based on type
			var item_type = item_data.get("type", "")
			match item_type:
				"consumable":
					sprite.modulate = Color(0.3, 0.8, 0.3, 1.0)  # Green
				"relic":
					sprite.modulate = Color(0.8, 0.6, 0.2, 1.0)  # Gold
				"key_item":
					sprite.modulate = Color(0.5, 0.5, 0.8, 1.0)  # Blue
				_:
					sprite.modulate = Color(0.7, 0.7, 0.7, 1.0)  # Gray


func _create_placeholder_texture() -> ImageTexture:
	"""Creates a simple colored circle as placeholder"""
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	# Draw a simple circle
	for y in range(32):
		for x in range(32):
			var dx = x - 16
			var dy = y - 16
			var dist = sqrt(dx * dx + dy * dy)
			if dist > 14:
				img.set_pixel(x, y, Color.TRANSPARENT)

	return ImageTexture.create_from_image(img)
