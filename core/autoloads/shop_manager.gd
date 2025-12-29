extends Node

## ShopManager handles shop UI and transactions

# ============================================================================
# STATE
# ============================================================================

var current_shop_data: Dictionary = {}
var current_merchant_name: String = ""
var current_greeting: String = ""
var is_shop_open: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

var shop_ui: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[ShopManager] Initialized")

# ============================================================================
# SHOP OPERATIONS
# ============================================================================

func open_shop(shop_data: Dictionary, merchant_name: String = "Merchant", greeting: String = "") -> void:
	"""Opens shop UI with given data"""

	if is_shop_open:
		push_warning("[ShopManager] Shop already open")
		return

	current_shop_data = shop_data
	current_merchant_name = merchant_name
	current_greeting = greeting

	# Create shop UI if it doesn't exist
	if not shop_ui:
		_create_shop_ui()

	if not shop_ui:
		push_error("[ShopManager] Failed to create shop UI")
		return

	# Populate shop with data
	if shop_ui.has_method("populate_shop"):
		shop_ui.populate_shop(shop_data, merchant_name, greeting)

	# Show UI
	shop_ui.visible = true
	is_shop_open = true

	# Pause game
	get_tree().paused = true

	print("[ShopManager] Shop opened: %s" % merchant_name)

func close_shop() -> void:
	"""Closes shop UI"""

	if not is_shop_open:
		return

	if shop_ui:
		shop_ui.visible = false

	is_shop_open = false
	current_shop_data.clear()
	current_merchant_name = ""
	current_greeting = ""

	# Unpause game
	get_tree().paused = false

	print("[ShopManager] Shop closed")

func _create_shop_ui() -> void:
	"""Creates shop UI instance"""

	var shop_scene_path = "res://ui/shop/shop.tscn"

	if not ResourceLoader.exists(shop_scene_path):
		push_error("[ShopManager] Shop UI scene not found: %s" % shop_scene_path)
		return

	var shop_scene = load(shop_scene_path)
	shop_ui = shop_scene.instantiate()

	# Add to scene tree (as high-layer UI)
	var canvas = CanvasLayer.new()
	canvas.name = "ShopUILayer"
	canvas.layer = 90
	add_child(canvas)
	canvas.add_child(shop_ui)

	# Connect close signal
	if shop_ui.has_signal("shop_closed"):
		shop_ui.shop_closed.connect(close_shop)

	shop_ui.visible = false

	print("[ShopManager] Shop UI created")

# ============================================================================
# PURCHASE HANDLING
# ============================================================================

func attempt_purchase(item_id: String, price: int) -> bool:
	"""Attempts to purchase item, returns true if successful"""

	# Check if player has enough coins
	if GameManager.coins_collected < price:
		EventBus.show_notification.emit("Not enough coins", 2.0)
		return false

	# Deduct coins
	GameManager.coins_collected -= price

	# Find item data
	var item_data = null
	for item in current_shop_data.get("items", []):
		if item.get("id") == item_id:
			item_data = item
			break

	if not item_data:
		push_error("[ShopManager] Item not found: %s" % item_id)
		return false

	# Add to inventory
	if InventoryManager:
		InventoryManager.add_item(item_data)

	# Notification
	EventBus.show_notification.emit("Purchased: %s" % item_data.get("name", item_id), 2.0)
	EventBus.item_picked_up.emit(item_id, item_data.get("name", item_id), "consumable")

	print("[ShopManager] Purchased: %s for %d coins" % [item_id, price])

	return true

# ============================================================================
# QUERY
# ============================================================================

func get_player_coins() -> int:
	"""Returns player's current coins"""
	return GameManager.coins_collected

func is_open() -> bool:
	"""Returns true if shop is currently open"""
	return is_shop_open
