extends GridContainer
## Manages a grid of item slots for one category

signal item_selected(item_data: Dictionary)
signal item_hovered(item_data: Dictionary)

var category: String = ""
var slots: Array[PanelContainer] = []
var selected_index: int = 0


func _ready() -> void:
	# Grid will be populated when inventory is opened
	pass


func setup_grid(category_name: String, max_slots: int) -> void:
	"""Sets up the grid with empty slots"""
	category = category_name

	# Clear existing slots
	for child in get_children():
		child.queue_free()

	slots.clear()

	# Create slot nodes
	var item_slot_script = load("res://ui/inventory/components/item_slot.gd")

	for i in range(max_slots):
		var slot = PanelContainer.new()
		slot.set_script(item_slot_script)
		slot.custom_minimum_size = Vector2(80, 80)
		slot.focus_mode = Control.FOCUS_ALL

		# Create internal structure for slot
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var count_label = Label.new()
		count_label.name = "CountLabel"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.visible = false

		vbox.add_child(icon)
		vbox.add_child(count_label)
		margin.add_child(vbox)
		slot.add_child(margin)

		# Connect signals
		slot.slot_selected.connect(_on_slot_selected)
		slot.slot_hovered.connect(_on_slot_hovered)

		add_child(slot)
		slots.append(slot)


func populate_items(items: Array) -> void:
	"""Populates the grid with item data"""
	for i in range(slots.size()):
		if i < items.size():
			var item_entry = items[i]
			var item_id = ""

			# Handle different data formats
			if item_entry is Dictionary:
				item_id = item_entry.get("item_id", "")
			else:
				item_id = item_entry

			# Get full item data
			var item_data = InventoryManager.get_item_data(item_id)

			# Add count for consumables
			if item_entry is Dictionary and item_entry.has("count"):
				item_data["count"] = item_entry["count"]

			slots[i].setup(item_data, i)
		else:
			slots[i].setup({}, i)

	# Select first non-empty slot
	if slots.size() > 0:
		_select_slot(0)


func _select_slot(index: int) -> void:
	"""Selects a slot by index"""
	if index < 0 or index >= slots.size():
		return

	# Deselect all
	for slot in slots:
		slot.set_selected(false)

	# Select new
	selected_index = index
	slots[selected_index].set_selected(true)
	slots[selected_index].grab_focus()

	# Emit hover to update detail panel
	if not slots[selected_index].is_empty:
		item_hovered.emit(slots[selected_index].item_data)


func _on_slot_selected(slot: PanelContainer) -> void:
	"""Handles slot selection"""
	_select_slot(slot.slot_index)
	item_selected.emit(slot.item_data)


func _on_slot_hovered(slot: PanelContainer) -> void:
	"""Handles slot hover"""
	item_hovered.emit(slot.item_data)


func navigate(direction: Vector2i) -> void:
	"""Navigates the grid with directional input"""
	var cols = columns
	var rows = ceili(float(slots.size()) / float(cols))

	var current_row = selected_index / cols
	var current_col = selected_index % cols

	# Calculate new position
	var new_row = current_row + direction.y
	var new_col = current_col + direction.x

	# Clamp to grid bounds
	new_row = clampi(new_row, 0, rows - 1)
	new_col = clampi(new_col, 0, cols - 1)

	# Calculate new index
	var new_index = new_row * cols + new_col
	new_index = clampi(new_index, 0, slots.size() - 1)

	if new_index != selected_index:
		_select_slot(new_index)


func get_selected_item() -> Dictionary:
	"""Returns the currently selected item data"""
	if selected_index >= 0 and selected_index < slots.size():
		return slots[selected_index].item_data

	return {}
