extends PanelContainer
## Individual item slot in the grid

signal slot_selected(slot: PanelContainer)
signal slot_hovered(slot: PanelContainer)

var item_data: Dictionary = {}
var slot_index: int = 0
var is_selected: bool = false
var is_empty: bool = true

@onready var icon: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var count_label: Label = $MarginContainer/VBoxContainer/CountLabel


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	gui_input.connect(_on_gui_input)


func setup(data: Dictionary, index: int) -> void:
	"""Sets up the slot with item data"""
	item_data = data
	slot_index = index
	is_empty = data.is_empty()

	if is_empty:
		_clear_slot()
	else:
		_populate_slot()


func _populate_slot() -> void:
	"""Populates the slot with item data"""
	# Load icon
	if item_data.has("icon") and ResourceLoader.exists(item_data["icon"]):
		icon.texture = load(item_data["icon"])
	else:
		# Use placeholder if icon doesn't exist
		icon.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# Show count for consumables
	if item_data.has("count"):
		count_label.visible = true
		count_label.text = "x%d" % item_data["count"]
	else:
		count_label.visible = false


func _clear_slot() -> void:
	"""Clears the slot visuals"""
	icon.texture = null
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
