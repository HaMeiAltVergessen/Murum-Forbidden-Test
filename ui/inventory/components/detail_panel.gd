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

	# World - HIDDEN per user request
	if world_label:
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
	if not effect_list:
		return

	# Display effect text if available
	if item_data.has("effect") and item_data["effect"] != "":
		var title_label = Label.new()
		title_label.text = "[Effekt]"
		title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		effect_list.add_child(title_label)

		var effect_label = Label.new()
		effect_label.text = item_data["effect"]
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_list.add_child(effect_label)

	# Display stats if available
	if item_data.has("stats"):
		var stats_label = Label.new()
		stats_label.text = "\n[Passive Boni]"
		stats_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		effect_list.add_child(stats_label)

		var stats = item_data["stats"]
		for stat_key in stats.keys():
			var stat_value = stats[stat_key]
			var stat_text = _format_stat(stat_key, stat_value)

			if stat_text != "":
				var stat_label = Label.new()
				stat_label.text = stat_text
				effect_list.add_child(stat_label)

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
		# Healing & Regeneration
		"heal_percent":
			return "• Heilung: +%.0f%% HP" % (value * 100)
		"hp_regen_percent_per_sec":
			return "• HP-Regen: +%.1f%% / Sek." % (value * 100)
		"hp_regen_flat":
			return "• HP-Regen: +%.0f / 5s" % value
		"mana_regen_percent_per_sec":
			return "• Mana-Regen: +%.1f%% / Sek." % (value * 100)
		"mana_regen_percent":
			return "• Mana-Regen: +%.0f%%" % (value * 100)
		"mana_regen_interval":
			return "• Regen-Intervall: %ds" % value
		"mana_on_hit":
			return "• Mana bei Treffer: +%d" % value

		# Damage & Combat
		"damage_bonus":
			return "• Schaden: +%.0f%%" % (value * 100)
		"damage_reduction":
			return "• Schadensreduktion: -%.0f%%" % (value * 100)
		"group_damage_bonus":
			return "• Gruppen-Schaden: +%.0f%%" % (value * 100)
		"group_enemy_threshold":
			return "  (ab %d Gegnern)" % value
		"environmental_damage_reduction":
			return "• Umweltschaden-Reduktion: -%.0f%%" % (value * 100)

		# Attack Speed & Movement
		"attack_speed_bonus":
			return "• Angriffsgeschwindigkeit: +%.0f%%" % (value * 100)
		"movement_speed_bonus":
			return "• Bewegungsgeschwindigkeit: +%.0f%%" % (value * 100)
		"out_of_combat_speed_bonus":
			return "• Geschwindigkeit (außer Kampf): +%.0f%%" % (value * 100)

		# Knockback & Control
		"knockback_reduction":
			return "• Knockback-Reduktion: -%.0f%%" % (value * 100)
		"knockback_resistance":
			return "• Knockback-Resistenz: %.0f%%" % (value * 100)

		# Parry System
		"parry_window_bonus":
			return "• Parry-Fenster: +%.1fs" % value
		"parry_slow_duration":
			return "• Parry-Slowdown: +%.1fs" % value
		"parry_slow_strength":
			return "• Parry-Slow-Stärke: %.0f%%" % (value * 100)
		"perfect_parry_shockwave_damage":
			return "• Perfect Parry Schockwelle: %d Schaden" % value
		"perfect_parry_shockwave_radius":
			return "• Schockwellen-Radius: %dm" % value

		# Resonance & Special
		"resonance_gain_bonus":
			return "• Resonanz-Aufbau: +%.0f%%" % (value * 100)
		"resonance_state_until_hit":
			return "• Startet in Resonanz (bis Treffer)"
		"urgathon_damage_bonus":
			return "• Urgathon-Schaden: +%.0f%%" % (value * 100)
		"urgathon_duration":
			return "• Urgathon-Dauer: %ds" % value

		# Buffs & Max Stats
		"max_hp_bonus":
			return "• Max HP: +%d" % value
		"max_mana_bonus":
			return "• Max Mana: +%.0f%%" % (value * 100)

		# Revive & Special Effects
		"revive_on_death":
			return "• Wiederbelebung bei Tod"
		"revive_hp_percent":
			return "• Wiederbelebungs-HP: %.0f%%" % (value * 100)
		"revive_mana_percent":
			return "• Wiederbelebungs-Mana: %.0f%%" % (value * 100)
		"revive_max_hp_penalty":
			return "• Max HP-Strafe: -%.0f%%" % (value * 100)
		"revive_damage_buff":
			return "• Schadens-Buff: +%.0f%%" % (value * 100)
		"revive_buff_duration":
			return "• Buff-Dauer: %ds" % value

		# Duration & Misc
		"duration_sec":
			return "• Dauer: %ds" % value
		"duration_levels":
			return "• Hält für %d Level" % value
		"max_uses":
			return "• Max. Nutzungen: %d" % value
		"block_next_hit":
			return "• Blockt nächsten Treffer"
		"gold_drop_bonus":
			return "• Münz-Drops: +%.0f%%" % (value * 100)

		_:
			# Fallback for unknown stats
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
