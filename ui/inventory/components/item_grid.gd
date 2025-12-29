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
		slot.custom_minimum_size = Vector2(80, 80)
		slot.focus_mode = Control.FOCUS_ALL

		# Make slots brighter with a StyleBox
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.25, 0.3, 1.0)  # Lighter dark blue-gray
		style.set_border_width_all(2)  # Use method instead of property
		style.border_color = Color(0.4, 0.4, 0.5, 1.0)  # Visible border
		style.set_corner_radius_all(4)  # Use method instead of property
		slot.add_theme_stylebox_override("panel", style)

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

		# ADD CHILD FIRST, THEN SET SCRIPT!
		add_child(slot)

		# Now set script and it will call _ready()
		slot.set_script(item_slot_script)

		# Store reference
		slots.append(slot)

	# Now connect signals AFTER all slots are ready
	await get_tree().process_frame

	for slot in slots:
		# Connect signals
		if slot.has_signal("slot_selected"):
			slot.slot_selected.connect(_on_slot_selected)
		if slot.has_signal("slot_hovered"):
			slot.slot_hovered.connect(_on_slot_hovered)


func populate_items(items: Array) -> void:
	"""Populates the grid with item data"""
	print("[ItemGrid] Populating ", category, " with ", items.size(), " items")
	print("[ItemGrid] Items: ", items)

	for i in range(slots.size()):
		if i < items.size():
			var item_entry = items[i]
			var item_id = ""

			# Handle different data formats
			if item_entry is Dictionary:
				item_id = item_entry.get("item_id", "")
			else:
				item_id = item_entry

			print("[ItemGrid] Processing slot ", i, " with item_id: ", item_id)

			# Get full item data
			var item_data = InventoryManager.get_item_data(item_id)

			if item_data.is_empty():
				print("[ItemGrid] WARNING: No data found for item: ", item_id)
				# Treat as empty slot
				slots[i].setup({}, i)
			else:
				print("[ItemGrid] Found item data: ", item_data.get("name", "???"))

				# Add count for consumables - need to duplicate to modify
				if item_entry is Dictionary and item_entry.has("count"):
					item_data = item_data.duplicate(true)  # Deep copy
					item_data["count"] = item_entry["count"]

				slots[i].setup(item_data, i)
		else:
			slots[i].setup({}, i)

	# Select first non-empty slot
	for i in range(slots.size()):
		if not slots[i].is_empty:
			_select_slot(i)
			return

	# If all empty, select slot 0 anyway
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
