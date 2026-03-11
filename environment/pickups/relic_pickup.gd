extends Area2D
class_name RelicPickup
## Relic Pickup — only visible during Siegel-Runs when Qual-Level is high enough.
## Once discovered, permanently added to inventory (survives run resets).
## Place manually in rooms with relic_id and qual_level set in the editor.

# ============================================================================
# EXPORTS (set in editor per instance)
# ============================================================================

@export var relic_id: String = ""        ## ID from relics.json (e.g. "auge_von_xy")
@export var qual_level: int = 0          ## Required Tiefe to see this relic (0 = read from JSON)

# ============================================================================
# STATE
# ============================================================================

var player_in_range: bool = false
var is_picked_up: bool = false
var is_visible_this_run: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if relic_id.is_empty():
		push_error("[RelicPickup] No relic_id set!")
		queue_free()
		return

	# Read qual_level from JSON if not set in editor
	if qual_level == 0 and InventoryManager:
		qual_level = InventoryManager.get_relic_qual_level(relic_id)

	# Check visibility conditions
	if not _should_be_visible():
		visible = false
		set_process(false)
		monitoring = false
		print("[RelicPickup] Hidden: %s (need Tiefe %d)" % [relic_id, qual_level])
		return

	is_visible_this_run = true
	visible = true
	monitoring = true

	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Set collision (detect player on Layer 2)
	collision_layer = 0
	set_collision_mask_value(2, true)

	# Setup visual
	_setup_visual()

	print("[RelicPickup] Visible: %s (Tiefe %d >= %d)" % [
		relic_id, _get_current_tiefe(), qual_level
	])

# ============================================================================
# VISIBILITY CHECK
# ============================================================================

func _should_be_visible() -> bool:
	# Must be in a Siegel-Run
	if not ChallengeRunManager or not ChallengeRunManager.is_challenge_run_active:
		return false

	# Must not already be found
	if InventoryManager and InventoryManager.is_relic_found(relic_id):
		return false

	# Tiefe must be high enough
	return _get_current_tiefe() >= qual_level


func _get_current_tiefe() -> int:
	if ChallengeRunManager:
		return ChallengeRunManager.get_tiefe()
	return 0

# ============================================================================
# INTERACTION
# ============================================================================

func _process(_delta: float) -> void:
	if not player_in_range or is_picked_up:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		_discover_relic()


func _on_body_entered(body: Node2D) -> void:
	if body is Murum or body.name == "Murum":
		player_in_range = true
		_show_prompt(true)


func _on_body_exited(body: Node2D) -> void:
	if body is Murum or body.name == "Murum":
		player_in_range = false
		_show_prompt(false)

# ============================================================================
# DISCOVERY
# ============================================================================

func _discover_relic() -> void:
	if is_picked_up:
		return

	is_picked_up = true

	# Add to inventory permanently
	var success = InventoryManager.discover_relic(relic_id)
	if not success:
		is_picked_up = false
		return

	# Get item info for notification
	var item_data = InventoryManager.get_item_data(relic_id)
	var item_name = item_data.get("name", relic_id)
	var lore = item_data.get("lore", "")

	# Show discovery notification
	_show_discovery_notification(item_name, lore)

	# Audio feedback
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("relic_discovered")

	# VFX + remove
	_play_discovery_effect()

	print("[RelicPickup] Discovered: %s" % relic_id)


func _show_discovery_notification(item_name: String, lore: String) -> void:
	var message = "Relikt entdeckt: %s" % item_name
	if EventBus:
		EventBus.show_notification.emit(message, 4.0)

# ============================================================================
# VISUAL
# ============================================================================

func _setup_visual() -> void:
	# Create sprite if not already present
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	# Try to load icon from database
	var item_data = InventoryManager.get_item_data(relic_id) if InventoryManager else {}
	var icon_path = item_data.get("icon", "")

	if icon_path != "" and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	else:
		# Placeholder: golden glowing circle
		sprite.texture = _create_relic_placeholder()

	# Golden tint for relics
	sprite.modulate = Color(1.0, 0.85, 0.3, 1.0)

	# Gentle float animation
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -6.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE)

	# Prompt label
	var prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "E - Aufnehmen"
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-50, 20)
	prompt_label.size = Vector2(100, 20)
	prompt_label.visible = false
	add_child(prompt_label)

	# Collision shape
	if not get_node_or_null("CollisionShape2D"):
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 30.0
		col.shape = shape
		add_child(col)


func _show_prompt(show: bool) -> void:
	var prompt_label = get_node_or_null("PromptLabel")
	if prompt_label:
		prompt_label.visible = show


func _play_discovery_effect() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _create_relic_placeholder() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var dx = x - 16
			var dy = y - 16
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= 12:
				var brightness = 1.0 - (dist / 12.0) * 0.3
				img.set_pixel(x, y, Color(brightness, brightness * 0.85, brightness * 0.3))
			else:
				img.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(img)
