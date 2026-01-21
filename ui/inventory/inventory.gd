extends CanvasLayer
## Main Inventory UI Controller
## Manages tabs, navigation, and item interactions

# ============ TAB CONFIGURATION ============
enum Tab {
	CONSUMABLES = 0,
	RELICS = 1,
	KEY_ITEMS = 2
}

const TAB_NAMES = ["Consumables", "Relics", "Key Items"]
const TAB_GRID_SIZES = {
	"Consumables": 20,  # 4x5
	"Relics": 9,        # 3x3
	"Key_Items": 16     # 4x4
}

const TAB_GRID_COLUMNS = {
	"Consumables": 4,
	"Relics": 3,
	"Key_Items": 4
}

# ============ NODE REFERENCES ============
@onready var inventory_panel: Control = $InventoryPanel
@onready var tab_header: HBoxContainer = $InventoryPanel/MainContainer/TabHeader
@onready var content_container: HBoxContainer = $InventoryPanel/MainContainer/ContentContainer

# Tabs
@onready var consumables_tab: Button = $InventoryPanel/MainContainer/TabHeader/ConsumablesTab
@onready var relics_tab: Button = $InventoryPanel/MainContainer/TabHeader/RelicsTab
@onready var key_items_tab: Button = $InventoryPanel/MainContainer/TabHeader/KeyItemsTab

# Grids
@onready var consumables_grid: GridContainer = $InventoryPanel/MainContainer/ContentContainer/GridPanel/MarginContainer/ConsumablesGrid
@onready var relics_grid: GridContainer = $InventoryPanel/MainContainer/ContentContainer/GridPanel/MarginContainer/RelicsGrid
@onready var key_items_grid: GridContainer = $InventoryPanel/MainContainer/ContentContainer/GridPanel/MarginContainer/KeyItemsGrid

# Detail panel
@onready var detail_panel: PanelContainer = $InventoryPanel/MainContainer/ContentContainer/DetailPanel

# Confirmation popup
@onready var confirmation_popup: PopupPanel = $ConfirmationPopup
@onready var popup_label: Label = $ConfirmationPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var yes_button: Button = $ConfirmationPopup/MarginContainer/VBoxContainer/ButtonContainer/YesButton
@onready var no_button: Button = $ConfirmationPopup/MarginContainer/VBoxContainer/ButtonContainer/NoButton

# ============ STATE ============
var current_tab: Tab = Tab.CONSUMABLES
var is_open: bool = false
var pending_use_item: Dictionary = {}
var i_key_was_pressed: bool = false  # Track I key state for just_pressed detection
var viewing_player: int = 1  # 1 = P1, 2 = P2 (tracks who opened the inventory)

# Grid references
var grids: Array[GridContainer] = []


func _ready() -> void:
	# Hide by default
	visible = false
	is_open = false

	# Setup InputMap actions if they don't exist
	_setup_input_actions()

	# Wait for child nodes to be ready before setting up grids
	await get_tree().process_frame

	# Setup grids
	_setup_grids()

	# Connect tab buttons
	consumables_tab.pressed.connect(func(): switch_tab(Tab.CONSUMABLES))
	relics_tab.pressed.connect(func(): switch_tab(Tab.RELICS))
	key_items_tab.pressed.connect(func(): switch_tab(Tab.KEY_ITEMS))

	# Connect popup buttons
	yes_button.pressed.connect(_on_confirm_yes)
	no_button.pressed.connect(_on_confirm_no)

	# Connect inventory signals with safety check
	if is_instance_valid(InventoryManager):
		InventoryManager.inventory_changed.connect(_refresh_current_tab)
		InventoryManager.p2_inventory_changed.connect(_refresh_current_tab)
		print("[Inventory] Connected to P1 and P2 inventory signals")
	else:
		push_error("[Inventory] InventoryManager not available at _ready()")

	print("[Inventory] Initialized (Autoload)")


func _setup_input_actions() -> void:
	"""Creates inventory input actions if they don't exist"""

	# tab_right (next tab)
	if not InputMap.has_action("tab_right"):
		InputMap.add_action("tab_right")

		# Q key
		var key_q = InputEventKey.new()
		key_q.keycode = KEY_Q
		InputMap.action_add_event("tab_right", key_q)

		# Right Bumper (RB/R1)
		var rb = InputEventJoypadButton.new()
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("tab_right", rb)

		print("[Inventory] Created 'tab_right' action (Q / RB)")

	# tab_left (previous tab)
	if not InputMap.has_action("tab_left"):
		InputMap.add_action("tab_left")

		# E key
		var key_e = InputEventKey.new()
		key_e.keycode = KEY_E
		InputMap.action_add_event("tab_left", key_e)

		# Left Bumper (LB/L1)
		var lb = InputEventJoypadButton.new()
		lb.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("tab_left", lb)

		print("[Inventory] Created 'tab_left' action (E / LB)")


func _setup_grids() -> void:
	"""Sets up all item grids"""
	# Ensure scripts are attached
	var item_grid_script = load("res://ui/inventory/components/item_grid.gd")

	if consumables_grid.get_script() == null:
		consumables_grid.set_script(item_grid_script)
		print("[Inventory] WARNING: ConsumablesGrid had no script, attached manually")

	if relics_grid.get_script() == null:
		relics_grid.set_script(item_grid_script)
		print("[Inventory] WARNING: RelicsGrid had no script, attached manually")

	if key_items_grid.get_script() == null:
		key_items_grid.set_script(item_grid_script)
		print("[Inventory] WARNING: KeyItemsGrid had no script, attached manually")

	# Setup Consumables
	consumables_grid.setup_grid("consumables", TAB_GRID_SIZES["Consumables"])
	consumables_grid.columns = TAB_GRID_COLUMNS["Consumables"]
	consumables_grid.item_selected.connect(_on_item_selected)
	consumables_grid.item_hovered.connect(_on_item_hovered)

	# Setup Relics
	relics_grid.setup_grid("relics", TAB_GRID_SIZES["Relics"])
	relics_grid.columns = TAB_GRID_COLUMNS["Relics"]
	relics_grid.item_selected.connect(_on_item_selected)
	relics_grid.item_hovered.connect(_on_item_hovered)

	# Setup Key Items
	key_items_grid.setup_grid("key_items", TAB_GRID_SIZES["Key_Items"])
	key_items_grid.columns = TAB_GRID_COLUMNS["Key_Items"]
	key_items_grid.item_selected.connect(_on_item_selected)
	key_items_grid.item_hovered.connect(_on_item_hovered)

	grids = [consumables_grid, relics_grid, key_items_grid]

	print("[Inventory] Grids setup complete")
	print("  ConsumablesGrid has methods: ", consumables_grid.has_method("populate_items"))


func _process(_delta: float) -> void:
	# CRITICAL: Filter inventory toggle through InputManager (P1 = keyboard-only when P2 active)
	# Use direct key check for "I" key when P2 active, since inventory_toggle action includes controller

	if InputManager and InputManager.p2_active:
		# Co-op mode: Check BOTH P1 (keyboard) AND P2 (controller via InputManager)
		var i_key_is_pressed = Input.is_key_pressed(KEY_I)
		var p1_pressed = i_key_is_pressed and not i_key_was_pressed
		var p2_pressed = InputManager.is_p2_action_just_pressed("inventory")

		if p1_pressed:
			print("[Inventory] P1 opened inventory (Keyboard I)")
			toggle_inventory(1)  # P1 opened it
		elif p2_pressed:
			print("[Inventory] P2 opened inventory (Controller Button 6)")
			toggle_inventory(2)  # P2 opened it

		i_key_was_pressed = i_key_is_pressed
	else:
		# Solo mode: Allow keyboard + controller
		if Input.is_action_just_pressed("p1_inventory"):
			toggle_inventory(1)  # P1 only in solo mode
		i_key_was_pressed = false  # Reset when not in co-op


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Debug: Log all button presses when inventory is open
	if event is InputEventJoypadButton and event.pressed:
		print("[Inventory] Joypad button pressed: ", event.button_index)
	if event is InputEventKey and event.pressed:
		print("[Inventory] Key pressed: ", event.keycode)

	# Tab switching
	if event.is_action_pressed("tab_right"):
		switch_tab((current_tab + 1) % 3)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		switch_tab((current_tab - 1 + 3) % 3)
		get_viewport().set_input_as_handled()

	# Grid navigation
	if event.is_action_pressed("ui_left"):
		_navigate_grid(Vector2i(-1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_navigate_grid(Vector2i(1, 0))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_navigate_grid(Vector2i(0, -1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_navigate_grid(Vector2i(0, 1))
		get_viewport().set_input_as_handled()

	# Use consumable with E key (keyboard) or A button (ui_accept on controller)
	# Note: interact is now Y button, only use A button in inventory
	if event.is_action_pressed("ui_accept"):
		_use_selected_consumable()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_action_pressed("interact"):
		# Allow E key on keyboard, but not Y button on controller
		_use_selected_consumable()
		get_viewport().set_input_as_handled()

	# Close inventory
	if event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func toggle_inventory(player: int = 1) -> void:
	"""Toggles inventory open/closed for specified player (1=P1, 2=P2)"""
	if is_open:
		close_inventory()
	else:
		open_inventory(player)


func open_inventory(player: int = 1) -> void:
	"""Opens the inventory for specified player (1=P1, 2=P2)"""

	# COMMIT 023.9: Block inventory during PvP
	if CoopManager and CoopManager.pvp_mode:
		print("[Inventory] Cannot open - PvP mode active!")
		return

	# Safety check
	if not is_instance_valid(InventoryManager):
		push_error("[Inventory] Cannot open - InventoryManager not valid")
		return

	if not is_instance_valid(GameManager):
		push_error("[Inventory] Cannot open - GameManager not valid")
		return

	viewing_player = player
	is_open = true
	visible = true

	print("[Inventory] Opening for P%d" % viewing_player)

	# Disable player movement and input
	if GameManager.player and is_instance_valid(GameManager.player):
		GameManager.player.set_physics_process(false)
		GameManager.player.set_process_input(false)

		# Also disable all player components that might process input
		var movement = GameManager.player.get_node_or_null("MovementController")
		if movement:
			movement.set_process_input(false)
			movement.set_physics_process(false)

		var combat = GameManager.player.get_node_or_null("CombatSystem")
		if combat:
			combat.set_process_input(false)
			combat.set_physics_process(false)

		var dodge = GameManager.player.get_node_or_null("DodgeRollSystem")
		if dodge:
			dodge.set_process_input(false)
			dodge.set_physics_process(false)

		print("[Inventory] Player input and movement fully disabled")

	print("[Inventory] Opening - current inventory state:")
	print("  Consumables: ", InventoryManager.get_items_by_category("consumables"))
	print("  Relics: ", InventoryManager.get_items_by_category("relics"))
	print("  Key Items: ", InventoryManager.get_items_by_category("key_items"))

	# Refresh all tabs BEFORE switching (to populate data)
	_refresh_all_tabs()

	# Select first tab (this will refresh again, but that's ok)
	switch_tab(Tab.CONSUMABLES)

	print("[Inventory] Opened")


func close_inventory() -> void:
	"""Closes the inventory"""
	is_open = false
	visible = false

	# Re-enable player movement and input
	if is_instance_valid(GameManager) and GameManager.player and is_instance_valid(GameManager.player):
		GameManager.player.set_physics_process(true)
		GameManager.player.set_process_input(true)

		# Also re-enable all player components
		var movement = GameManager.player.get_node_or_null("MovementController")
		if movement:
			movement.set_process_input(true)
			movement.set_physics_process(true)

		var combat = GameManager.player.get_node_or_null("CombatSystem")
		if combat:
			combat.set_process_input(true)
			combat.set_physics_process(true)

		var dodge = GameManager.player.get_node_or_null("DodgeRollSystem")
		if dodge:
			dodge.set_process_input(true)
			dodge.set_physics_process(true)

		print("[Inventory] Player input and movement fully enabled")

	print("[Inventory] Closed")


func switch_tab(tab: Tab) -> void:
	"""Switches to a different tab"""
	current_tab = tab

	# Hide all grids
	consumables_grid.visible = false
	relics_grid.visible = false
	key_items_grid.visible = false

	# Update tab button states
	consumables_tab.button_pressed = (tab == Tab.CONSUMABLES)
	relics_tab.button_pressed = (tab == Tab.RELICS)
	key_items_tab.button_pressed = (tab == Tab.KEY_ITEMS)

	# Show current grid
	match tab:
		Tab.CONSUMABLES:
			consumables_grid.visible = true
			_refresh_tab_data(consumables_grid, "consumables")
		Tab.RELICS:
			relics_grid.visible = true
			_refresh_tab_data(relics_grid, "relics")
		Tab.KEY_ITEMS:
			key_items_grid.visible = true
			_refresh_tab_data(key_items_grid, "key_items")


func _refresh_all_tabs() -> void:
	"""Refreshes all tab data"""
	_refresh_tab_data(consumables_grid, "consumables")
	_refresh_tab_data(relics_grid, "relics")
	_refresh_tab_data(key_items_grid, "key_items")


func _refresh_current_tab() -> void:
	"""Refreshes only the current tab"""
	match current_tab:
		Tab.CONSUMABLES:
			_refresh_tab_data(consumables_grid, "consumables")
		Tab.RELICS:
			_refresh_tab_data(relics_grid, "relics")
		Tab.KEY_ITEMS:
			_refresh_tab_data(key_items_grid, "key_items")


func _refresh_tab_data(grid: GridContainer, category: String) -> void:
	"""Refreshes a specific tab's data"""
	# Safety check in case this is called during scene transition
	if not is_instance_valid(InventoryManager):
		print("[Inventory] WARNING: InventoryManager not available")
		return

	# Get items from the correct player's inventory
	var items: Array = []
	if viewing_player == 2:
		items = InventoryManager.get_p2_items_by_category(category)
		print("[Inventory] Refreshing P2's ", category, " tab with ", items.size(), " items")
	else:
		items = InventoryManager.get_items_by_category(category)
		print("[Inventory] Refreshing P1's ", category, " tab with ", items.size(), " items")

	if grid and grid.has_method("populate_items"):
		grid.populate_items(items)
	else:
		print("[Inventory] ERROR: Grid doesn't have populate_items method!")


func _navigate_grid(direction: Vector2i) -> void:
	"""Navigates the current grid"""
	var current_grid = grids[current_tab]
	current_grid.navigate(direction)


func _on_item_hovered(item_data: Dictionary) -> void:
	"""Handles item hover - updates detail panel"""
	detail_panel.display_item(item_data)


func _on_item_selected(item_data: Dictionary) -> void:
	"""Handles item selection"""
	var item_type = item_data.get("type", "")

	# Only consumables can be used
	if item_type == "consumable":
		_show_use_confirmation(item_data)
	else:
		# For relics and key items, just inspect (already shown in detail panel)
		print("[Inventory] Inspecting: ", item_data.get("name", ""))


func _use_selected_consumable() -> void:
	"""Shows confirmation dialog for the currently selected consumable (E/A key press)"""
	var current_grid = grids[current_tab]
	var selected_item = current_grid.get_selected_item()

	if selected_item.is_empty():
		print("[Inventory] No item selected")
		return

	var item_type = selected_item.get("type", "")
	if item_type != "consumable":
		print("[Inventory] Cannot use non-consumable item")
		return

	# Show confirmation dialog before using
	_show_use_confirmation(selected_item)


func _show_use_confirmation(item_data: Dictionary) -> void:
	"""Shows the use item confirmation popup"""
	pending_use_item = item_data

	var item_name = item_data.get("name", "???")
	popup_label.text = "%s verwenden?" % item_name

	# Show popup
	confirmation_popup.popup_centered()

	# Focus yes button
	yes_button.grab_focus()


func _on_confirm_yes() -> void:
	"""Handles 'Yes' in confirmation popup"""
	confirmation_popup.hide()

	if pending_use_item.is_empty():
		return

	var item_id = pending_use_item.get("id", "")
	if item_id != "":
		# Use the item from the correct player's inventory
		var success = false
		if viewing_player == 2:
			success = InventoryManager.use_p2_consumable(item_id)
			print("[Inventory] P2 used item: ", item_id)
		else:
			success = InventoryManager.use_item(item_id)
			print("[Inventory] P1 used item: ", item_id)

		if not success:
			print("[Inventory] Failed to use item: ", item_id)

	pending_use_item = {}


func _on_confirm_no() -> void:
	"""Handles 'No' in confirmation popup"""
	confirmation_popup.hide()
	pending_use_item = {}
