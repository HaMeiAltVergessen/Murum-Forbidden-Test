extends CharacterBody2D
class_name Merchant

## Base Merchant NPC that opens shop UI

# ============================================================================
# EXPORTS
# ============================================================================

@export var merchant_name: String = "Merchant"
@export var greeting: String = "Welcome, traveler."
@export var shop_data_path: String = ""

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $InteractionPrompt

# ============================================================================
# STATE
# ============================================================================

var player_in_range: bool = false
var shop_data: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Load shop data
	if not shop_data_path.is_empty():
		_load_shop_data()

	# Setup interaction
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	# Hide prompt initially
	if prompt_label:
		prompt_label.visible = false

	add_to_group("merchants")

	print("[Merchant] %s ready" % merchant_name)

func _load_shop_data() -> void:
	"""Loads shop data from JSON file"""

	if not FileAccess.file_exists(shop_data_path):
		push_error("[Merchant] Shop data not found: %s" % shop_data_path)
		return

	var file = FileAccess.open(shop_data_path, FileAccess.READ)
	if not file:
		push_error("[Merchant] Failed to open shop data: %s" % shop_data_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("[Merchant] Failed to parse shop data: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return

	shop_data = json.get_data()

	print("[Merchant] Shop data loaded: %d items" % shop_data.get("items", []).size())

# ============================================================================
# INTERACTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Called when player enters interaction range"""

	if not body.is_in_group("player"):
		return

	player_in_range = true

	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "E - Talk to %s" % merchant_name

func _on_body_exited(body: Node2D) -> void:
	"""Called when player exits interaction range"""

	if not body.is_in_group("player"):
		return

	player_in_range = false

	if prompt_label:
		prompt_label.visible = false

func _input(event: InputEvent) -> void:
	"""Handles interaction input"""

	if not player_in_range:
		return

	# Only process when interact key is pressed
	if not event.is_action_pressed("interact"):
		return

	# Don't open shop if already open
	if ShopManager.is_open():
		print("[Merchant] Shop already open, ignoring")
		return

	print("[Merchant] Opening shop for %s" % merchant_name)
	_open_shop()
	get_viewport().set_input_as_handled()

func _open_shop() -> void:
	"""Opens shop UI"""

	if shop_data.is_empty():
		push_warning("[Merchant] No shop data loaded!")
		EventBus.show_notification.emit("Shop not available", 2.0)
		return

	# Open shop via ShopManager
	ShopManager.open_shop(shop_data, merchant_name, greeting)

	print("[Merchant] Shop opened: %s" % merchant_name)

# ============================================================================
# ANIMATIONS
# ============================================================================

func play_appear_animation() -> void:
	"""Plays spawn/appear animation"""

	# Fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("environment/merchant_appear", global_position, 0.0)

	print("[Merchant] Appear animation played")
