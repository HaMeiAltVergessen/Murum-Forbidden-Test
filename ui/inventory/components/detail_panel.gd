extends PanelContainer
## Displays detailed information about the selected item

@onready var icon_display: TextureRect = $MarginContainer/VBoxContainer/IconDisplay
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var world_label: Label = $MarginContainer/VBoxContainer/WorldLabel
@onready var lore_text: RichTextLabel = $MarginContainer/VBoxContainer/LoreText
@onready var effect_list: VBoxContainer = $MarginContainer/VBoxContainer/EffectList


func _ready() -> void:
	clear_display()


func display_item(item_data: Dictionary) -> void:
	"""Displays item information"""
	if item_data.is_empty():
		clear_display()
		return

	# Icon
	if icon_display:
		if item_data.has("icon") and ResourceLoader.exists(item_data["icon"]):
			icon_display.texture = load(item_data["icon"])
		else:
			# Create placeholder
			icon_display.texture = _create_placeholder_icon()

			# Color based on type
			var item_type = item_data.get("type", "")
			match item_type:
				"consumable":
					icon_display.modulate = Color(0.3, 0.8, 0.3, 1.0)  # Green
				"relic":
					icon_display.modulate = Color(0.8, 0.6, 0.2, 1.0)  # Gold
				"key_item":
					icon_display.modulate = Color(0.5, 0.5, 0.8, 1.0)  # Blue
				_:
					icon_display.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# Name
	if name_label:
		name_label.text = item_data.get("name", "???")

	# World
	if world_label:
		var world_num = item_data.get("world", 0)
		if world_num > 0:
			world_label.text = "Welt: %d" % world_num
			world_label.visible = true
		else:
			world_label.visible = false

	# Lore
	if lore_text:
		var lore = item_data.get("lore", "")
		if lore != "":
			lore_text.text = lore
			lore_text.visible = true
		else:
			lore_text.visible = false

	# Clear previous effects
	if effect_list:
		for child in effect_list.get_children():
			child.queue_free()

	# Display effects/stats based on type
	var item_type = item_data.get("type", "")

	match item_type:
		"consumable":
			_display_consumable_effect(item_data)
		"relic":
			_display_relic_stats(item_data)
		"key_item":
			_display_key_item_description(item_data)


func _display_consumable_effect(item_data: Dictionary) -> void:
	"""Displays consumable effect information"""
	if not item_data.has("effect") or not effect_list:
		return

	var effect = item_data["effect"]
	var effect_type = effect.get("type", "")
	var value = effect.get("value", 0)
	var duration = effect.get("duration", 0)

	var title_label = Label.new()
	title_label.text = "[Effekt]"
	title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	effect_list.add_child(title_label)

	var effect_text = ""

	match effect_type:
		"hp_regen":
			effect_text = "• HP Regeneration: +%.1f%% / Sekunde" % (value * 100)
			if duration > 0:
				effect_text += "\n• Dauer: %d Sekunden" % duration
		"mana_regen":
			effect_text = "• Mana Regeneration: +%.1f%% / Sekunde" % (value * 100)
			if duration > 0:
				effect_text += "\n• Dauer: %d Sekunden" % duration
		"instant_heal":
			effect_text = "• Sofortige Heilung: +%d HP" % value

	if effect_text != "":
		var effect_label = Label.new()
		effect_label.text = effect_text
		effect_list.add_child(effect_label)

	# Show count
	if item_data.has("count"):
		var count_label = Label.new()
		count_label.text = "\nAnzahl: x%d" % item_data["count"]
		count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
		effect_list.add_child(count_label)


func _display_relic_stats(item_data: Dictionary) -> void:
	"""Displays relic passive stats"""
	if not item_data.has("stats") or not effect_list:
		return

	var stats = item_data["stats"]

	var title_label = Label.new()
	title_label.text = "[Passive Boni]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	effect_list.add_child(title_label)

	for stat_key in stats.keys():
		var stat_value = stats[stat_key]
		var stat_text = _format_stat(stat_key, stat_value)

		var stat_label = Label.new()
		stat_label.text = stat_text
		effect_list.add_child(stat_label)


func _format_stat(stat_key: String, value) -> String:
	"""Formats a stat for display"""
	match stat_key:
		"parry_window_bonus":
			return "• Parry-Fenster: +%.0f%%" % (value * 100)
		"parry_slow_duration":
			return "• Parry-Slowdown: +%.1fs" % value
		"mana_regen_bonus":
			return "• Mana-Regeneration: +%.0f%%" % (value * 100)
		"mana_regen_interval":
			return "• Regen-Intervall: %ds" % value
		"max_hp_bonus":
			return "• Max HP: +%d" % value
		"damage_reduction":
			return "• Schadensreduktion: %.0f%%" % (value * 100)
		"dodge_roll_cooldown_reduction":
			return "• Dodge-Cooldown: -%.0f%%" % (value * 100)
		"dodge_roll_distance_bonus":
			return "• Dodge-Distanz: +%d%%" % value
		"combo_timer_bonus":
			return "• Combo-Timer: +%.1fs" % value
		"ability_cooldown_reduction":
			return "• Fähigkeits-Cooldown: -%.0f%%" % (value * 100)
		"knockback_resistance":
			return "• Knockback-Resistenz: %.0f%%" % (value * 100)
		"stagger_threshold_bonus":
			return "• Stagger-Schwelle: +%d" % value
		"damage_bonus":
			return "• Schaden: +%.0f%%" % (value * 100)
		"critical_chance":
			return "• Krit-Chance: +%.0f%%" % (value * 100)
		"ability_damage_bonus":
			return "• Fähigkeitsschaden: +%.0f%%" % (value * 100)
		"mana_cost_reduction":
			return "• Manakosten: -%.0f%%" % (value * 100)
		"hp_drain_per_second":
			return "• HP-Drain: -%d / Sekunde" % value
		_:
			return "• %s: %s" % [stat_key, str(value)]


func _display_key_item_description(item_data: Dictionary) -> void:
	"""Displays key item description"""
	if not effect_list:
		return

	if item_data.has("description"):
		var desc_label = Label.new()
		desc_label.text = item_data["description"]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_list.add_child(desc_label)


func clear_display() -> void:
	"""Clears the display"""
	if icon_display:
		icon_display.texture = null
		icon_display.modulate = Color.WHITE
	if name_label:
		name_label.text = ""
	if world_label:
		world_label.visible = false
	if lore_text:
		lore_text.visible = false

	if effect_list:
		for child in effect_list.get_children():
			child.queue_free()


func _create_placeholder_icon() -> ImageTexture:
	"""Creates a simple colored square as placeholder"""
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
