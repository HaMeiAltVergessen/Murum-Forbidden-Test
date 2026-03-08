extends CanvasLayer
## Upgrade Shop UI - Displays all permanent upgrades for purchase with Magicka

signal shop_closed()

# ============ COLORS ============
const COLOR_BG := Color(0.03, 0.01, 0.06, 0.97)
const COLOR_PANEL := Color(0.06, 0.03, 0.1, 0.9)
const COLOR_BORDER := Color(0.3, 0.15, 0.5, 0.6)
const COLOR_MAGICKA := Color(0.3, 0.9, 0.9, 1.0)
const COLOR_MAXED := Color(0.4, 0.8, 0.3, 1.0)
const COLOR_LOCKED := Color(0.5, 0.4, 0.4, 0.6)
const COLOR_LORE := Color(0.6, 0.5, 0.7, 0.7)
const COLOR_LIVES := Color(1.0, 0.4, 0.4, 1.0)

# ============ LIVES SHOP ============
const EXTRA_LIFE_COST: int = 2

# ============ STATE ============
var _upgrade_entries: Dictionary = {}
var _lives_entry: Dictionary = {}
var _magicka_label: Label = null
var _detail_panel: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	RunManager.magicka_changed.connect(_on_magicka_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		shop_closed.emit()
		get_viewport().set_input_as_handled()


# ============ UI BUILDING ============

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var main = Control.new()
	main.anchors_preset = Control.PRESET_FULL_RECT
	main.anchor_right = 1.0
	main.anchor_bottom = 1.0
	add_child(main)

	# Title
	var title = Label.new()
	title.text = "Permanente Upgrades"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_MAGICKA)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1920, 50)
	main.add_child(title)

	# Magicka display
	_magicka_label = Label.new()
	_magicka_label.add_theme_font_size_override("font_size", 22)
	_magicka_label.add_theme_color_override("font_color", COLOR_MAGICKA)
	_magicka_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_magicka_label.position = Vector2(0, 55)
	_magicka_label.size = Vector2(1920, 40)
	main.add_child(_magicka_label)
	_update_magicka_display()

	# Scroll container for upgrade list
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(60, 110)
	scroll.size = Vector2(900, 850)
	main.add_child(scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Build upgrade entries
	var upgrade_ids = UpgradeManager.UPGRADES.keys()
	for upgrade_id in upgrade_ids:
		_build_upgrade_entry(list, upgrade_id)

	# Extra Lives entry
	_build_lives_entry(list)

	# Detail panel (right side)
	_build_detail_panel(main)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Schließen (ESC)"
	close_btn.custom_minimum_size = Vector2(200, 45)
	close_btn.position = Vector2(860, 970)
	close_btn.pressed.connect(func(): shop_closed.emit())
	main.add_child(close_btn)

	# Focus first upgrade
	if not _upgrade_entries.is_empty():
		var first_id = upgrade_ids[0]
		_show_detail(first_id)


func _build_upgrade_entry(parent: Control, upgrade_id: String) -> void:
	var data = UpgradeManager.UPGRADES[upgrade_id]
	var level = UpgradeManager.get_level(upgrade_id)
	var max_level = data["max_level"]
	var is_max = level >= max_level

	var entry = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	entry.add_theme_stylebox_override("panel", style)
	parent.add_child(entry)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	entry.add_child(hbox)

	# Left: Name + level
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	if is_max:
		name_label.add_theme_color_override("font_color", COLOR_MAXED)
	info_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(level_label)

	# Right: Buy button
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 40)
	hbox.add_child(buy_btn)
	buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade_id))

	# Detail on hover/focus
	entry.mouse_entered.connect(_show_detail.bind(upgrade_id))
	buy_btn.focus_entered.connect(_show_detail.bind(upgrade_id))

	_upgrade_entries[upgrade_id] = {
		"entry": entry,
		"name_label": name_label,
		"level_label": level_label,
		"buy_btn": buy_btn,
		"style": style
	}

	_update_entry(upgrade_id)


func _build_lives_entry(parent: Control) -> void:
	var entry = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_LIVES.lerp(COLOR_BORDER, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	entry.add_theme_stylebox_override("panel", style)
	parent.add_child(entry)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	entry.add_child(hbox)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = "Zusaetzliches Leben"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_LIVES)
	info_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 40)
	hbox.add_child(buy_btn)
	buy_btn.pressed.connect(_on_buy_life_pressed)

	entry.mouse_entered.connect(_show_lives_detail)
	buy_btn.focus_entered.connect(_show_lives_detail)

	_lives_entry = {
		"entry": entry,
		"name_label": name_label,
		"level_label": level_label,
		"buy_btn": buy_btn,
		"style": style
	}

	_update_lives_entry()


func _build_detail_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(1000, 110)
	panel.size = Vector2(860, 850)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 24)
	detail_name.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	vbox.add_child(detail_name)
	_detail_panel["name"] = detail_name

	var detail_lore = Label.new()
	detail_lore.add_theme_font_size_override("font_size", 14)
	detail_lore.add_theme_color_override("font_color", COLOR_LORE)
	detail_lore.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(detail_lore)
	_detail_panel["lore"] = detail_lore

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var detail_effects = RichTextLabel.new()
	detail_effects.bbcode_enabled = false
	detail_effects.scroll_active = false
	detail_effects.fit_content = true
	detail_effects.custom_minimum_size = Vector2(0, 300)
	detail_effects.add_theme_font_size_override("normal_font_size", 16)
	detail_effects.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85, 1.0))
	vbox.add_child(detail_effects)
	_detail_panel["effects"] = detail_effects


# ============ UPDATE ============

func _update_entry(upgrade_id: String) -> void:
	var entry_data = _upgrade_entries[upgrade_id]
	var data = UpgradeManager.UPGRADES[upgrade_id]
	var level = UpgradeManager.get_level(upgrade_id)
	var max_level = data["max_level"]
	var is_max = level >= max_level

	# Level text
	entry_data["level_label"].text = "Stufe %d / %d" % [level, max_level]
	if is_max:
		entry_data["level_label"].add_theme_color_override("font_color", COLOR_MAXED)
	else:
		entry_data["level_label"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))

	# Name color
	if is_max:
		entry_data["name_label"].add_theme_color_override("font_color", COLOR_MAXED)
	else:
		entry_data["name_label"].add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))

	# Buy button
	if is_max:
		entry_data["buy_btn"].text = "MAX"
		entry_data["buy_btn"].disabled = true
	else:
		var cost = UpgradeManager.get_next_cost(upgrade_id)
		var can_afford = RunManager.get_magicka() >= cost
		entry_data["buy_btn"].text = "%d Magicka" % cost
		entry_data["buy_btn"].disabled = not can_afford

		if can_afford:
			entry_data["buy_btn"].add_theme_color_override("font_color", COLOR_MAGICKA)
		else:
			entry_data["buy_btn"].add_theme_color_override("font_color", COLOR_LOCKED)

	# Border highlight
	if is_max:
		entry_data["style"].border_color = COLOR_MAXED.lerp(COLOR_BORDER, 0.5)
	else:
		entry_data["style"].border_color = COLOR_BORDER


func _update_lives_entry() -> void:
	if _lives_entry.is_empty():
		return

	var current_max = RunManager.max_lives
	var is_max = current_max >= RunManager.MAX_LIVES

	_lives_entry["level_label"].text = "Leben: %d / %d" % [current_max, RunManager.MAX_LIVES]

	if is_max:
		_lives_entry["level_label"].add_theme_color_override("font_color", COLOR_MAXED)
		_lives_entry["name_label"].add_theme_color_override("font_color", COLOR_MAXED)
		_lives_entry["buy_btn"].text = "MAX"
		_lives_entry["buy_btn"].disabled = true
		_lives_entry["style"].border_color = COLOR_MAXED.lerp(COLOR_BORDER, 0.5)
	else:
		_lives_entry["level_label"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
		var can_afford = RunManager.get_magicka() >= EXTRA_LIFE_COST
		_lives_entry["buy_btn"].text = "%d Magicka" % EXTRA_LIFE_COST
		_lives_entry["buy_btn"].disabled = not can_afford
		if can_afford:
			_lives_entry["buy_btn"].add_theme_color_override("font_color", COLOR_MAGICKA)
		else:
			_lives_entry["buy_btn"].add_theme_color_override("font_color", COLOR_LOCKED)


func _update_all_entries() -> void:
	for upgrade_id in _upgrade_entries:
		_update_entry(upgrade_id)
	_update_lives_entry()


func _update_magicka_display() -> void:
	_magicka_label.text = "Magicka: %d" % RunManager.get_magicka()


func _show_detail(upgrade_id: String) -> void:
	var data = UpgradeManager.UPGRADES[upgrade_id]
	var level = UpgradeManager.get_level(upgrade_id)

	_detail_panel["name"].text = data["name"]
	_detail_panel["lore"].text = data["lore"]

	# Build effects text
	var text = ""
	for i in data["effects"].size():
		var effect = data["effects"][i]
		var prefix = ""
		if i < level:
			prefix = "[Aktiv] "
		elif i == level:
			prefix = "[Nächste Stufe] "
		else:
			prefix = "[Stufe %d] " % (i + 1)

		var cost_text = ""
		if i < data["costs"].size():
			cost_text = " (%d Magicka)" % data["costs"][i]

		text += "%s%s%s\n\n" % [prefix, effect["description"], cost_text]

	_detail_panel["effects"].text = text


# ============ EVENTS ============

func _on_buy_pressed(upgrade_id: String) -> void:
	var success = UpgradeManager.purchase(upgrade_id)
	if success:
		var data = UpgradeManager.UPGRADES[upgrade_id]
		var level = UpgradeManager.get_level(upgrade_id)
		EventBus.show_notification.emit(
			"%s Stufe %d freigeschaltet!" % [data["name"], level], 3.0
		)
		_update_all_entries()
		_update_magicka_display()
		_show_detail(upgrade_id)


func _show_lives_detail() -> void:
	var current_max = RunManager.max_lives
	_detail_panel["name"].text = "Zusaetzliches Leben"
	_detail_panel["lore"].text = "Ein weiteres Leben fuer den naechsten Run. Mehr Chancen, den Limbus zu ueberleben."

	var text = ""
	for i in range(1, RunManager.MAX_LIVES + 1):
		if i <= current_max:
			text += "[Aktiv] Leben %d\n\n" % i
		elif i == current_max + 1:
			text += "[Naechstes] Leben %d (%d Magicka)\n\n" % [i, EXTRA_LIFE_COST]
		else:
			text += "[Leben %d] (%d Magicka)\n\n" % [i, EXTRA_LIFE_COST]

	_detail_panel["effects"].text = text


func _on_buy_life_pressed() -> void:
	if RunManager.max_lives >= RunManager.MAX_LIVES:
		return
	if not RunManager.spend_magicka(EXTRA_LIFE_COST):
		return

	RunManager.set_max_lives(RunManager.max_lives + 1)
	EventBus.show_notification.emit(
		"Zusaetzliches Leben freigeschaltet! (%d/%d)" % [RunManager.max_lives, RunManager.MAX_LIVES], 3.0
	)
	_update_all_entries()
	_update_magicka_display()
	_show_lives_detail()


func _on_magicka_changed(_new_amount: int) -> void:
	_update_magicka_display()
	_update_all_entries()
