extends CanvasLayer
## PachronSelectionScreen — Fullscreen UI for Pachron selection, dialog, and boon choice/upgrade.
## Flow: Symbol-Auswahl (3 Masken) → Pachron-Dialog → [Sync-Dialog] → Boon waehlen/upgraden → Farewell → Done
## Sync skills appear as additional golden option when SyncSkillManager rolls a successful offer.
class_name PachronSelectionScreen

# ============ SIGNALS ============
signal pachron_selected(path_id: String)
signal selection_cancelled()
signal boon_flow_completed()

# ============ CONSTANTS ============
const PACHRON_MASKS: Dictionary = {
	"arthra": "res://Assets/AIPlaceholder/Char/Pachrons/Arthra/arthra maske.png",
	"noron": "res://Assets/AIPlaceholder/Char/Pachrons/Noron/noron maske.png",
	"raelear": "res://Assets/AIPlaceholder/Char/Pachrons/Realear/realear maske.png",
	"murrum": "res://Assets/AIPlaceholder/Char/Pachrons/Mur_rum/Mur_rum Maske.png",
	"sairias": "res://Assets/AIPlaceholder/Char/Pachrons/Sairias/sairias maske.png",
}
const PACHRON_IMAGES: Dictionary = {
	"arthra": "res://Assets/AIPlaceholder/Char/Pachrons/Arthra/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_58172.jpg",
	"noron": "res://Assets/AIPlaceholder/Char/Pachrons/Noron/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_34835.jpg",
	"raelear": "res://Assets/AIPlaceholder/Char/Pachrons/Realear/_Use_the_provided_Murum_artwor_Nano_Banana_60213.jpg",
	"murrum": "res://Assets/AIPlaceholder/Char/Pachrons/Mur_rum/_Use_the_provided_Murum_artwor_Nano_Banana_78991.jpg",
	"sairias": "res://Assets/AIPlaceholder/Char/Pachrons/Sairias/_Use_the_provided_Murum_artwor_Nano_Banana_45046.jpg",
}

# ============ STATE ============
enum Phase { SYMBOL_SELECT, DIALOG, SYNC_DIALOG, BOON_CHOICE, FAREWELL, DONE }
var current_phase: Phase = Phase.SYMBOL_SELECT
var _offered_paths: Array = []  # 3 path_id strings
var _selected_index: int = 0
var _selected_path_id: String = ""
var _mask_nodes: Array = []  # TextureRect references for hover effects

# Boon choice state
var _boon_option_index: int = 0  # 0 = new boon, 1+ = upgrade options
var _boon_options: Array = []  # Array of {type: "new"/"upgrade"/"sync", path_id, tier, boon_data/sync_data}

# Sync skill state
var _offered_sync: Dictionary = {}  # The sync data dict if offered, empty if not
var _chosen_sync_id: String = ""    # Set when player chooses a sync skill

# UI Nodes
var _bg: ColorRect
var _title_label: Label
var _mask_container: HBoxContainer
var _pachron_image: TextureRect
var _boon_panel: VBoxContainer
var _boon_option_nodes: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	# _setup_symbol_phase() is called from setup() after paths are set


# ============ UI CONSTRUCTION ============
func _build_ui() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.85)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 60
	_title_label.offset_bottom = 100
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_title_label.text = "Waehle einen Pachron"
	add_child(_title_label)

	# Mask container (fill most of screen)
	_mask_container = HBoxContainer.new()
	_mask_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask_container.offset_left = 40
	_mask_container.offset_right = -40
	_mask_container.offset_top = 110
	_mask_container.offset_bottom = -30
	_mask_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_mask_container.add_theme_constant_override("separation", 30)
	add_child(_mask_container)

	# Pachron image (left side, hidden initially)
	_pachron_image = TextureRect.new()
	_pachron_image.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_pachron_image.offset_left = 40
	_pachron_image.offset_top = -250
	_pachron_image.offset_right = 500
	_pachron_image.offset_bottom = 250
	_pachron_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pachron_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_pachron_image.visible = false
	add_child(_pachron_image)

	# Boon panel (right side, hidden initially)
	_boon_panel = VBoxContainer.new()
	_boon_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_boon_panel.offset_left = -550
	_boon_panel.offset_right = -40
	_boon_panel.offset_top = -200
	_boon_panel.offset_bottom = 250
	_boon_panel.add_theme_constant_override("separation", 10)
	_boon_panel.visible = false
	add_child(_boon_panel)


# ============ PHASE 1: SYMBOL SELECT ============
func setup(offered_paths: Array) -> void:
	_offered_paths = offered_paths
	_selected_index = 0
	_setup_symbol_phase()


func _setup_symbol_phase() -> void:
	current_phase = Phase.SYMBOL_SELECT
	_title_label.text = "Waehle einen Pachron"
	_title_label.visible = true
	_mask_container.visible = true
	_pachron_image.visible = false
	_boon_panel.visible = false

	# Clear old masks
	for child in _mask_container.get_children():
		child.queue_free()
	_mask_nodes.clear()

	if _offered_paths.is_empty():
		_offered_paths = BoonManager.PATH_IDS.duplicate()
		_offered_paths.shuffle()
		_offered_paths = _offered_paths.slice(0, 3)

	for i in range(_offered_paths.size()):
		var path_id: String = _offered_paths[i]
		var path_color: Color = BoonManager.get_path_color(path_id)
		var path_data: Dictionary = BoonManager.get_path_data(path_id)
		var path_name: String = path_data.get("name", path_id.capitalize())

		# Use a container that allows overlay children
		var card := Control.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# Content layout
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)

		# Mask image (fills available space, keeps aspect ratio)
		var mask_rect := TextureRect.new()
		mask_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mask_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mask_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mask_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mask_path: String = PACHRON_MASKS.get(path_id, "")
		if mask_path != "" and ResourceLoader.exists(mask_path):
			mask_rect.texture = load(mask_path)
		mask_rect.modulate = Color(path_color.r, path_color.g, path_color.b, 0.7)
		vbox.add_child(mask_rect)
		_mask_nodes.append(mask_rect)

		# Focus (no Pachron name — only gameplay hint)
		var focus_label := Label.new()
		focus_label.text = path_data.get("Pachron", "")
		focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		focus_label.add_theme_font_size_override("font_size", 20)
		focus_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(focus_label)

		# Clickable overlay covering the entire card
		var captured_i := i
		var button := Button.new()
		button.flat = true
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.modulate = Color(1, 1, 1, 0)  # Invisible
		button.pressed.connect(func():
			_selected_index = captured_i
			_update_mask_highlight()
			_confirm_symbol_selection()
		)
		button.mouse_entered.connect(func():
			_selected_index = captured_i
			_update_mask_highlight()
		)
		card.add_child(button)

		_mask_container.add_child(card)

	_update_mask_highlight()


func _update_mask_highlight() -> void:
	for i in range(_mask_nodes.size()):
		var mask: TextureRect = _mask_nodes[i]
		var path_id: String = _offered_paths[i]
		var path_color: Color = BoonManager.get_path_color(path_id)
		if i == _selected_index:
			mask.modulate = Color(path_color.r, path_color.g, path_color.b, 1.0)
			mask.scale = Vector2(1.1, 1.1)
		else:
			mask.modulate = Color(path_color.r, path_color.g, path_color.b, 0.5)
			mask.scale = Vector2(1.0, 1.0)


# ============ PHASE 3: BOON CHOICE/UPGRADE ============
func _setup_boon_phase() -> void:
	current_phase = Phase.BOON_CHOICE
	_bg.visible = true
	_title_label.visible = false
	_mask_container.visible = false
	_pachron_image.visible = true
	_boon_panel.visible = true

	# Show Pachron image
	var img_path: String = PACHRON_IMAGES.get(_selected_path_id, "")
	if img_path != "" and ResourceLoader.exists(img_path):
		_pachron_image.texture = load(img_path)

	# Build boon options
	_boon_options.clear()
	_boon_option_nodes.clear()
	for child in _boon_panel.get_children():
		child.queue_free()

	# Header
	var header := Label.new()
	var path_data: Dictionary = BoonManager.get_path_data(_selected_path_id)
	var path_color: Color = BoonManager.get_path_color(_selected_path_id)
	header.text = "Waehle eine Erinnerung"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", path_color)
	_boon_panel.add_child(header)

	# SYNC SKILL OPTION (if offered — always first/top option)
	if not _offered_sync.is_empty():
		_boon_options.append({
			"type": "sync",
			"sync_id": _offered_sync.get("id", ""),
			"sync_data": _offered_sync,
		})

	# Option A: New boon (if available)
	var next_tier: int = BoonManager.get_next_available_tier(_selected_path_id)
	if next_tier > 0:
		var boon_data: Dictionary = BoonManager.get_boon_data(_selected_path_id, next_tier)
		_boon_options.append({
			"type": "new",
			"path_id": _selected_path_id,
			"tier": next_tier,
			"boon_data": boon_data,
		})

	# Option B+: Upgrade existing boons
	var upgradeable: Array = BoonManager.get_upgradeable_boons(_selected_path_id)
	for boon in upgradeable:
		_boon_options.append({
			"type": "upgrade",
			"path_id": _selected_path_id,
			"tier": boon.get("tier", 1),
			"boon_data": boon,
		})

	if _boon_options.is_empty():
		# Edge case: nothing to do (shouldn't happen normally)
		_finish_flow()
		return

	# Build option UI cards
	for i in range(_boon_options.size()):
		var option: Dictionary = _boon_options[i]
		var card: PanelContainer
		if option["type"] == "sync":
			card = _create_sync_option_card(option, i)
		else:
			card = _create_boon_option_card(option, i)
		_boon_panel.add_child(card)
		_boon_option_nodes.append(card)

		# Mouse click support
		var captured_i := i
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_boon_option_index = captured_i
				_update_boon_highlight()
				_confirm_boon_selection()
		)
		card.mouse_entered.connect(func():
			_boon_option_index = captured_i
			_update_boon_highlight()
		)
		card.mouse_filter = Control.MOUSE_FILTER_STOP

	_boon_option_index = 0
	_update_boon_highlight()


func _create_boon_option_card(option: Dictionary, _index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var boon_data: Dictionary = option.get("boon_data", {})
	var tier: int = option.get("tier", 1)
	var path_color: Color = BoonManager.get_path_color(option.get("path_id", ""))

	if option["type"] == "new":
		# New boon header
		var type_label := Label.new()
		type_label.text = "NEUER BOON — T%d" % tier
		type_label.add_theme_font_size_override("font_size", 14)
		type_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		vbox.add_child(type_label)

		var name_label := Label.new()
		name_label.text = boon_data.get("name", "?")
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", path_color)
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = boon_data.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)
	else:
		# Upgrade header
		var level: int = BoonManager.get_boon_level(option.get("path_id", ""), tier)
		var type_label := Label.new()
		type_label.text = "STAERKEN — T%d (Lv.%d → Lv.%d)" % [tier, level, level + 1]
		type_label.add_theme_font_size_override("font_size", 14)
		type_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		vbox.add_child(type_label)

		var name_label := Label.new()
		name_label.text = boon_data.get("name", "?")
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", path_color)
		vbox.add_child(name_label)

		# Show stat changes
		var scaling: Dictionary = boon_data.get("level_scaling", {})
		var params: Dictionary = boon_data.get("params", {})
		for param_name in scaling:
			if not params.has(param_name):
				continue
			var base_val: float = float(params[param_name])
			var scale_val: float = float(scaling[param_name])
			var current_val: float = base_val + (level - 1) * scale_val
			var next_val: float = base_val + level * scale_val
			var stat_label := Label.new()
			stat_label.text = "%s: %.2f → %.2f" % [param_name, current_val, next_val]
			stat_label.add_theme_font_size_override("font_size", 13)
			stat_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			vbox.add_child(stat_label)

	return card


func _create_sync_option_card(option: Dictionary, _index: int) -> PanelContainer:
	"""Creates a golden sync skill card — visually distinct from normal boons."""
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 0)

	var sync_data: Dictionary = option.get("sync_data", {})
	var sync_color: Color = SyncSkillManager.get_sync_color(sync_data.get("id", ""))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.05, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	# Golden border by default
	style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Sync header
	var path_a: String = sync_data.get("path_a", "")
	var path_b: String = sync_data.get("path_b", "")
	var name_a: String = BoonManager.get_path_data(path_a).get("name", path_a.capitalize())
	var name_b: String = BoonManager.get_path_data(path_b).get("name", path_b.capitalize())

	var type_label := Label.new()
	type_label.text = "SYNC SKILL — %s + %s" % [name_a, name_b]
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(type_label)

	var name_label := Label.new()
	name_label.text = sync_data.get("name", "?")
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", sync_color)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = sync_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	return card


func _update_boon_highlight() -> void:
	for i in range(_boon_option_nodes.size()):
		var card: PanelContainer = _boon_option_nodes[i]
		var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
		var option: Dictionary = _boon_options[i]

		if i == _boon_option_index:
			if option.get("type", "") == "sync":
				# Golden glow for sync
				style.border_color = Color(1.0, 0.9, 0.3, 1.0)
			else:
				style.border_color = Color(1.0, 0.85, 0.3)
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			if option.get("type", "") == "sync":
				# Keep subtle golden border for sync even when not selected
				style.border_color = Color(1.0, 0.85, 0.2, 0.5)
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2
			else:
				style.border_width_left = 0
				style.border_width_right = 0
				style.border_width_top = 0
				style.border_width_bottom = 0


# ============ INPUT ============
func _input(event: InputEvent) -> void:
	if current_phase == Phase.SYMBOL_SELECT:
		_handle_symbol_input(event)
	elif current_phase == Phase.BOON_CHOICE:
		_handle_boon_input(event)
	elif current_phase == Phase.DIALOG or current_phase == Phase.SYNC_DIALOG or current_phase == Phase.FAREWELL:
		pass  # Dialog system handles its own input


func _handle_symbol_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_selected_index = wrapi(_selected_index - 1, 0, _offered_paths.size())
		_update_mask_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_selected_index = wrapi(_selected_index + 1, 0, _offered_paths.size())
		_update_mask_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_confirm_symbol_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		selection_cancelled.emit()
		get_viewport().set_input_as_handled()


func _handle_boon_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_boon_option_index = wrapi(_boon_option_index - 1, 0, _boon_options.size())
		_update_boon_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_boon_option_index = wrapi(_boon_option_index + 1, 0, _boon_options.size())
		_update_boon_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_confirm_boon_selection()
		get_viewport().set_input_as_handled()


func _confirm_symbol_selection() -> void:
	if _selected_index < 0 or _selected_index >= _offered_paths.size():
		return
	_selected_path_id = _offered_paths[_selected_index]
	pachron_selected.emit(_selected_path_id)
	print("[PachronSelection] Pachron selected: %s" % _selected_path_id)

	# Reset sync state
	_offered_sync = {}
	_chosen_sync_id = ""

	# Start dialog phase
	_start_dialog_phase()


func _start_dialog_phase() -> void:
	current_phase = Phase.DIALOG
	# Hide all PachronSelectionScreen visuals — DialogUI has its own dark bg + character sprite
	_mask_container.visible = false
	_title_label.visible = false
	_pachron_image.visible = false
	_boon_panel.visible = false
	_bg.visible = false

	# Start Pachron dialog
	if PachronDialogSystem:
		PachronDialogSystem.start_dialog(_selected_path_id)
		# Wait for dialog to finish
		PachronDialogSystem.dialog_sequence_finished.connect(_on_pachron_dialog_finished, CONNECT_ONE_SHOT)
	else:
		# No dialog system — go straight to boon choice
		_on_pachron_dialog_finished()


func _on_pachron_dialog_finished() -> void:
	# After normal dialog, check for sync skill offer
	if SyncSkillManager:
		_offered_sync = SyncSkillManager.roll_sync_offer(_selected_path_id)

	if not _offered_sync.is_empty():
		# Sync offered! Play the dual-Pachron sync dialog
		_start_sync_dialog_phase()
	else:
		# No sync — go straight to boon choice
		_setup_boon_phase()


# ============ SYNC DIALOG PHASE ============
func _start_sync_dialog_phase() -> void:
	current_phase = Phase.SYNC_DIALOG
	# Hide all visuals — DialogUI handles display
	_mask_container.visible = false
	_title_label.visible = false
	_pachron_image.visible = false
	_boon_panel.visible = false
	_bg.visible = false

	var sync_id: String = _offered_sync.get("id", "")
	print("[PachronSelection] Sync dialog starting: %s" % sync_id)

	if PachronDialogSystem:
		PachronDialogSystem.start_sync_dialog(sync_id)
		PachronDialogSystem.dialog_sequence_finished.connect(_on_sync_dialog_finished, CONNECT_ONE_SHOT)
	else:
		_on_sync_dialog_finished()


func _on_sync_dialog_finished() -> void:
	# Sync dialog done — now show boon choice with sync option
	_setup_boon_phase()


# ============ BOON SELECTION ============
func _confirm_boon_selection() -> void:
	if _boon_option_index < 0 or _boon_option_index >= _boon_options.size():
		return

	var option: Dictionary = _boon_options[_boon_option_index]

	var success: bool = false
	if option["type"] == "sync":
		# Sync skill chosen
		var sync_id: String = option.get("sync_id", "")
		success = SyncSkillManager.acquire_sync(sync_id)
		if success:
			_chosen_sync_id = sync_id
			var sync_name: String = option.get("sync_data", {}).get("name", "?")
			EventBus.show_notification.emit("Sync Skill: %s erworben!" % sync_name, 4.0)
			print("[PachronSelection] Sync skill acquired: %s" % sync_id)
	elif option["type"] == "new":
		var path_id: String = option.get("path_id", "")
		var tier: int = option.get("tier", 1)
		success = BoonManager.add_boon(path_id, tier)
		if success:
			var boon_name: String = option.get("boon_data", {}).get("name", "?")
			EventBus.show_notification.emit("%s T%d: %s erworben!" % [path_id.capitalize(), tier, boon_name], 4.0)
			print("[PachronSelection] New boon: %s T%d" % [path_id, tier])
	else:
		var path_id: String = option.get("path_id", "")
		var tier: int = option.get("tier", 1)
		success = BoonManager.upgrade_boon(path_id, tier)
		if success:
			var boon_name: String = option.get("boon_data", {}).get("name", "?")
			var new_level: int = BoonManager.get_boon_level(path_id, tier)
			EventBus.show_notification.emit("%s T%d: %s → Level %d!" % [path_id.capitalize(), tier, boon_name, new_level], 4.0)
			print("[PachronSelection] Upgraded boon: %s T%d → Lv.%d" % [path_id, tier, new_level])

	if not success:
		EventBus.show_notification.emit("Konnte nicht erworben werden!", 2.0)
		return

	# Start farewell dialog
	_start_farewell_phase()


func _start_farewell_phase() -> void:
	current_phase = Phase.FAREWELL
	# Hide all visuals — DialogUI handles display
	_boon_panel.visible = false
	_pachron_image.visible = false
	_bg.visible = false

	if PachronDialogSystem:
		if _chosen_sync_id != "":
			# Sync farewell (both Pachrons)
			PachronDialogSystem.play_sync_farewell(_chosen_sync_id)
		else:
			# Normal farewell
			PachronDialogSystem.play_farewell(_selected_path_id)
		PachronDialogSystem.dialog_sequence_finished.connect(_finish_flow, CONNECT_ONE_SHOT)
	else:
		_finish_flow()


func _finish_flow() -> void:
	current_phase = Phase.DONE
	boon_flow_completed.emit()
	queue_free()
