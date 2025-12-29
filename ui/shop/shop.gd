extends Control

## Shop UI for purchasing items from merchants

# ============================================================================
# SIGNALS
# ============================================================================

signal shop_closed

# ============================================================================
# REFERENCES
# ============================================================================

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var greeting_label: Label = $Panel/MarginContainer/VBoxContainer/GreetingLabel
@onready var items_container: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ItemsGrid
@onready var coins_label: Label = $Panel/MarginContainer/VBoxContainer/CoinsLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

# ============================================================================
# STATE
# ============================================================================

var current_shop_data: Dictionary = {}
var buy_buttons: Array[Button] = []
var current_focus_index: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# Process mode (works when paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide initially
	visible = false

	print("[Shop UI] Ready")

func _input(event: InputEvent) -> void:
	"""Handles ESC and controller input"""

	if not visible:
		return

	# Close shop
	if event.is_action_pressed("ui_cancel"):
		_close_shop()
		get_viewport().set_input_as_handled()
		return

	# Controller navigation
	if event.is_action_pressed("ui_down"):
		_navigate_buttons(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_navigate_buttons(-1)
		get_viewport().set_input_as_handled()

	# Controller confirm (A button)
	elif event.is_action_pressed("ui_accept"):
		_activate_focused_button()
		get_viewport().set_input_as_handled()

# ============================================================================
# SHOP OPERATIONS
# ============================================================================

func populate_shop(shop_data: Dictionary, merchant_name: String = "Merchant", greeting: String = "") -> void:
	"""Populates shop with items from data"""

	current_shop_data = shop_data

	# Set title and greeting
	if title_label:
		title_label.text = merchant_name

	if greeting_label:
		if greeting.is_empty():
			greeting_label.visible = false
		else:
			greeting_label.visible = true
			greeting_label.text = greeting

	# Update coins display
	_update_coins_display()

	# Clear existing items
	if items_container:
		for child in items_container.get_children():
			child.queue_free()

	# Reset button tracking
	buy_buttons.clear()
	current_focus_index = 0

	# Create item entries
	var items = shop_data.get("items", [])
	for item_data in items:
		_create_item_entry(item_data)

	# Focus first button for controller navigation
	if buy_buttons.size() > 0:
		_update_button_focus()

	print("[Shop UI] Populated with %d items" % items.size())

func _create_item_entry(item_data: Dictionary) -> void:
	"""Creates a shop item entry"""

	var item_panel = Panel.new()
	item_panel.custom_minimum_size = Vector2(350, 120)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	item_panel.add_child(vbox)

	# Item name
	var name_label = Label.new()
	name_label.text = item_data.get("name", "Unknown Item")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 1, 0.7, 1))
	vbox.add_child(name_label)

	# Effect
	var effect_label = Label.new()
	effect_label.text = item_data.get("effect", "")
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(effect_label)

	# Duration
	var duration_label = Label.new()
	duration_label.text = "Duration: " + item_data.get("duration", "")
	duration_label.add_theme_font_size_override("font_size", 10)
	duration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(duration_label)

	# Lythrun influence (special color)
	var lythrun_label = Label.new()
	lythrun_label.text = "Lythrun: " + item_data.get("lythrun_influence", "")
	lythrun_label.add_theme_font_size_override("font_size", 10)
	lythrun_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	lythrun_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lythrun_label)

	# Buy button
	var buy_button = Button.new()
	var price = item_data.get("price", 0)
	buy_button.text = "Buy (%d coins)" % price
	buy_button.pressed.connect(_on_buy_item.bind(item_data))
	buy_button.focus_mode = Control.FOCUS_ALL
	vbox.add_child(buy_button)

	# Track button for controller navigation
	buy_buttons.append(buy_button)

	items_container.add_child(item_panel)

func _on_buy_item(item_data: Dictionary) -> void:
	"""Attempts to purchase item"""

	var item_id = item_data.get("id", "")
	var price = item_data.get("price", 0)

	# Attempt purchase via ShopManager
	var success = ShopManager.attempt_purchase(item_id, price)

	if success:
		# Update coins display
		_update_coins_display()

		# Visual feedback
		AudioManager.play_sfx("ui/purchase_success", 0.0)

		print("[Shop UI] Purchased: %s" % item_data.get("name", item_id))
	else:
		# Failed purchase
		AudioManager.play_sfx("ui/purchase_fail", 0.0)

		print("[Shop UI] Purchase failed: %s" % item_data.get("name", item_id))

func _update_coins_display() -> void:
	"""Updates coin count display"""

	if not coins_label:
		return

	var coins = ShopManager.get_player_coins()
	coins_label.text = "Coins: %d" % coins

# ============================================================================
# CLOSE
# ============================================================================

func _close_shop() -> void:
	"""Closes shop"""

	shop_closed.emit()
	ShopManager.close_shop()

	print("[Shop UI] Closed")

func _on_close_button_pressed() -> void:
	"""Called when close button is pressed"""

	_close_shop()

# ============================================================================
# CONTROLLER NAVIGATION
# ============================================================================

func _navigate_buttons(direction: int) -> void:
	"""Navigates through buy buttons with controller"""

	if buy_buttons.is_empty():
		return

	# Update index with wrapping
	current_focus_index += direction
	if current_focus_index < 0:
		current_focus_index = buy_buttons.size() - 1
	elif current_focus_index >= buy_buttons.size():
		current_focus_index = 0

	_update_button_focus()

func _update_button_focus() -> void:
	"""Updates visual focus indicator for current button"""

	if buy_buttons.is_empty():
		return

	# Remove focus from all buttons
	for button in buy_buttons:
		button.release_focus()

	# Focus current button
	if current_focus_index >= 0 and current_focus_index < buy_buttons.size():
		buy_buttons[current_focus_index].grab_focus()

func _activate_focused_button() -> void:
	"""Activates the currently focused button"""

	if buy_buttons.is_empty():
		return

	if current_focus_index >= 0 and current_focus_index < buy_buttons.size():
		buy_buttons[current_focus_index].emit_signal("pressed")
