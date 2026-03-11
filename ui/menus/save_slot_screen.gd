extends Control
## Save Slot Selection Screen
## Shows 3 slots, allows selecting for New Game or Load Game

# ============================================================================
# SIGNALS
# ============================================================================

signal slot_selected(slot_index: int)
signal back_pressed()

# ============================================================================
# MODE
# ============================================================================

enum Mode { NEW_GAME, LOAD_GAME }

var current_mode: Mode = Mode.NEW_GAME

# ============================================================================
# UI REFERENCES
# ============================================================================

var slot_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []
var back_button: Button = null
var title_label: Label = null
var confirm_dialog: ConfirmationDialog = null
var pending_slot: int = -1

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_build_ui()
	_refresh_slots()


func setup(mode: Mode) -> void:
	current_mode = mode
	if title_label:
		match mode:
			Mode.NEW_GAME:
				title_label.text = "Slot waehlen"
			Mode.LOAD_GAME:
				title_label.text = "Spielstand laden"
	_refresh_slots()

# ============================================================================
# UI BUILDING
# ============================================================================

func _build_ui() -> void:
	# Full-screen background
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(900, 0)
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Slot waehlen"
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Slot cards
	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 20)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(slots_hbox)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var card = _create_slot_card(i)
		slots_hbox.add_child(card)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Back button
	back_button = Button.new()
	back_button.text = "Zurueck"
	back_button.custom_minimum_size = Vector2(200, 45)
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(back_button)

	# Confirm overwrite dialog
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Spielstand ueberschreiben?"
	confirm_dialog.dialog_text = "Dieser Slot enthaelt einen Spielstand.\nSoll er ueberschrieben werden?"
	confirm_dialog.ok_button_text = "Ja"
	confirm_dialog.cancel_button_text = "Nein"
	confirm_dialog.confirmed.connect(_on_overwrite_confirmed)
	add_child(confirm_dialog)

	# Focus on first slot
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()


func _create_slot_card(slot_index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 200)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Slot title
	var slot_label = Label.new()
	slot_label.text = "Slot %d" % slot_index
	slot_label.add_theme_font_size_override("font_size", 26)
	slot_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(slot_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Info label (filled by _refresh_slots)
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.custom_minimum_size = Vector2(240, 80)
	vbox.add_child(info_label)

	# Select button
	var select_btn = Button.new()
	select_btn.name = "SelectButton"
	select_btn.custom_minimum_size = Vector2(220, 40)
	select_btn.add_theme_font_size_override("font_size", 18)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var idx = slot_index
	select_btn.pressed.connect(func(): _on_slot_pressed(idx))
	vbox.add_child(select_btn)
	slot_buttons.append(select_btn)

	# Delete button
	var del_btn = Button.new()
	del_btn.name = "DeleteButton"
	del_btn.text = "Loeschen"
	del_btn.custom_minimum_size = Vector2(220, 30)
	del_btn.add_theme_font_size_override("font_size", 14)
	del_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	del_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	del_btn.pressed.connect(func(): _on_delete_pressed(idx))
	vbox.add_child(del_btn)
	delete_buttons.append(del_btn)

	panel.add_child(vbox)
	return panel

# ============================================================================
# SLOT DISPLAY
# ============================================================================

func _refresh_slots() -> void:
	SaveManager._load_all_slot_metadata()

	for i in range(SaveManager.MAX_SLOTS):
		var slot_index = i + 1
		var meta = SaveManager.get_slot_metadata(slot_index)
		var info_label: Label = slot_buttons[i].get_parent().get_node("InfoLabel")
		var select_btn: Button = slot_buttons[i]
		var del_btn: Button = delete_buttons[i]

		if meta.exists:
			# Filled slot
			var world_name = _get_world_display_name(meta.current_world)
			info_label.text = "%s\nSpielzeit: %s\n%s" % [
				world_name,
				meta.get_formatted_playtime(),
				meta.get_formatted_timestamp()
			]

			match current_mode:
				Mode.NEW_GAME:
					select_btn.text = "Ueberschreiben"
				Mode.LOAD_GAME:
					select_btn.text = "Laden"

			select_btn.disabled = false
			del_btn.visible = true
		else:
			# Empty slot
			info_label.text = "- Leer -"

			match current_mode:
				Mode.NEW_GAME:
					select_btn.text = "Neues Spiel"
					select_btn.disabled = false
				Mode.LOAD_GAME:
					select_btn.text = "- Leer -"
					select_btn.disabled = true

			del_btn.visible = false

# ============================================================================
# ACTIONS
# ============================================================================

func _on_slot_pressed(slot_index: int) -> void:
	if current_mode == Mode.NEW_GAME and SaveManager.slot_exists(slot_index):
		# Existing slot — confirm overwrite
		pending_slot = slot_index
		confirm_dialog.popup_centered()
		return

	# Empty slot or load mode — proceed
	slot_selected.emit(slot_index)


func _on_overwrite_confirmed() -> void:
	if pending_slot > 0:
		slot_selected.emit(pending_slot)
		pending_slot = -1


func _on_delete_pressed(slot_index: int) -> void:
	SaveManager.delete_save(slot_index)
	_refresh_slots()
	print("[SaveSlotScreen] Deleted slot %d" % slot_index)

# ============================================================================
# HELPERS
# ============================================================================

func _get_world_display_name(world_id: String) -> String:
	match world_id:
		"limbus": return "Limbus"
		"world_1_ruins": return "Das Niemandsland"
		"world_2_kollektiv": return "Das Kollektiv"
		"world_3_abgrund": return "Der Abgrund"
		_: return world_id
