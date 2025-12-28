extends PanelContainer
## Individual item slot in the grid

signal slot_selected(slot: PanelContainer)
signal slot_hovered(slot: PanelContainer)

var item_data: Dictionary = {}
var slot_index: int = 0
var is_selected: bool = false
var is_empty: bool = true

# References to child nodes (found dynamically)
var icon: TextureRect = null
var count_label: Label = null


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	gui_input.connect(_on_gui_input)

	# Find child nodes
	_find_child_nodes()


func _find_child_nodes() -> void:
	"""Finds the icon and count_label nodes"""
	if has_node("MarginContainer/VBoxContainer/Icon"):
		icon = get_node("MarginContainer/VBoxContainer/Icon")
	if has_node("MarginContainer/VBoxContainer/CountLabel"):
		count_label = get_node("MarginContainer/VBoxContainer/CountLabel")


func setup(data: Dictionary, index: int) -> void:
	"""Sets up the slot with item data"""
	item_data = data
	slot_index = index
	is_empty = data.is_empty()

	print("[ItemSlot] Setup slot ", index, " - empty: ", is_empty, " - data: ", data.get("name", "???"))

	# Ensure nodes are found
	if icon == null or count_label == null:
		_find_child_nodes()
		print("[ItemSlot] Finding child nodes - icon: ", icon != null, " label: ", count_label != null)

	if is_empty:
		_clear_slot()
	else:
		_populate_slot()


func _populate_slot() -> void:
	"""Populates the slot with item data"""
	print("[ItemSlot] _populate_slot called - icon: ", icon != null, " label: ", count_label != null)

	if not icon or not count_label:
		print("[ItemSlot] ERROR: Missing nodes, cannot populate!")
		return

	# Create placeholder texture if icon doesn't exist
	if item_data.has("icon") and ResourceLoader.exists(item_data["icon"]):
		icon.texture = load(item_data["icon"])
		print("[ItemSlot] Loaded real icon from: ", item_data["icon"])
	else:
		# Use colored placeholder
		icon.texture = _create_placeholder_texture()
		print("[ItemSlot] Created placeholder texture")

		# Color based on type
		var item_type = item_data.get("type", "")
		match item_type:
			"consumable":
				icon.modulate = Color(0.3, 0.8, 0.3, 1.0)  # Green
			"relic":
				icon.modulate = Color(0.8, 0.6, 0.2, 1.0)  # Gold
			"key_item":
				icon.modulate = Color(0.5, 0.5, 0.8, 1.0)  # Blue
			_:
				icon.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray

		print("[ItemSlot] Set color for type: ", item_type)

	# Make sure the slot is visible
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = true

	# Show count for consumables
	if item_data.has("count"):
		count_label.visible = true
		count_label.text = "x%d" % item_data["count"]
	else:
		count_label.visible = false

	print("[ItemSlot] Populate complete - texture: ", icon.texture != null, " visible: ", visible)


func _create_placeholder_texture() -> ImageTexture:
	"""Creates a simple colored square as placeholder"""
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _clear_slot() -> void:
	"""Clears the slot visuals"""
	if icon:
		icon.texture = null
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset modulate
	if count_label:
		count_label.visible = false
	modulate = Color(0.3, 0.3, 0.3, 0.5)


func set_selected(selected: bool) -> void:
	"""Sets the visual state of selection"""
	is_selected = selected

	if is_selected:
		self_modulate = Color(1.5, 1.5, 1.2, 1.0)  # Highlight
	else:
		self_modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal


func _on_mouse_entered() -> void:
	"""Handles mouse hover"""
	if not is_empty:
		slot_hovered.emit(self)


func _on_focus_entered() -> void:
	"""Handles keyboard/gamepad focus"""
	if not is_empty:
		slot_hovered.emit(self)


func _on_gui_input(event: InputEvent) -> void:
	"""Handles input on this slot"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_empty:
			slot_selected.emit(self)
	elif event.is_action_pressed("ui_accept"):  # A button / Enter
		if not is_empty:
			slot_selected.emit(self)
