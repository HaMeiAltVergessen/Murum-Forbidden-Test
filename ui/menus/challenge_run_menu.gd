extends CanvasLayer
## Siegel-Run Menü - Visuelles Siegel-System
## Kreisförmiges Siegel mit Knotenpunkten für jeden Modifier
## Links: Beschreibung | Rechts: Siegel-Visualisierung

# ============================================================================
# SIGNALS
# ============================================================================

signal challenge_started()
signal back_pressed()

# ============================================================================
# CONSTANTS
# ============================================================================

const SEAL_CENTER := Vector2(1250, 400)
const SEAL_OUTER_RADIUS := 320.0
const SEAL_MIDDLE_RADIUS := 220.0
const SEAL_INNER_RADIUS := 130.0
const NODE_SIZE := Vector2(28, 28)
const NODE_HOVER_SCALE := 1.4

## Colors
const COLOR_INACTIVE := Color(0.25, 0.2, 0.3, 0.8)
const COLOR_ACTIVE := Color(0.6, 0.3, 0.9, 1.0)
const COLOR_HOVER := Color(0.8, 0.6, 1.0, 1.0)
const COLOR_LINE := Color(0.3, 0.15, 0.4, 0.4)
const COLOR_LINE_ACTIVE := Color(0.5, 0.2, 0.8, 0.6)
const COLOR_BG := Color(0.03, 0.01, 0.06, 0.97)

## Category colors for nodes
const CATEGORY_COLORS := {
	"kern": Color(0.9, 0.75, 0.3, 1.0),
	"albtraum": Color(0.6, 0.3, 0.9, 1.0),
	"koerper": Color(0.8, 0.2, 0.2, 1.0),
	"myrkur": Color(0.4, 0.1, 0.6, 1.0),
	"voch_numta": Color(0.9, 0.85, 0.5, 1.0),
	"urgathon": Color(0.3, 0.8, 0.6, 1.0)
}

# ============================================================================
# STATE
# ============================================================================

## Node buttons mapped by modifier_id
var _seal_nodes: Dictionary = {}
## Currently selected/hovered modifier
var _selected_modifier: String = ""
## Pulse animation timer
var _pulse_timer: float = 0.0
## Seal line drawing node
var _seal_lines: Control = null

## Description panel references
var _desc_name_label: Label = null
var _desc_category_label: Label = null
var _desc_tiefe_label: Label = null
var _desc_text_label: RichTextLabel = null
var _seal_count_label: Label = null
var _tiefe_label: Label = null
var _tiefenstufe_label: Label = null
var _schwellensicht_label: Label = null
var _start_button: Button = null
var _back_button: Button = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	print("[SiegelMenu] Siegel-Run Menü initialisiert (%d Knoten)" % _seal_nodes.size())

func _process(delta: float) -> void:
	_pulse_timer += delta
	_update_node_visuals()

# ============================================================================
# UI BUILDING
# ============================================================================

func _build_ui() -> void:
	"""Builds the complete seal menu UI"""
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main HBox: Left (Description) | Right (Seal)
	var main_container = Control.new()
	main_container.anchors_preset = Control.PRESET_FULL_RECT
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# --- LEFT PANEL: Description ---
	_build_description_panel(main_container)

	# --- RIGHT PANEL: Seal Visualization ---
	_build_seal_visualization(main_container)

	# --- BOTTOM BAR: Buttons ---
	_build_bottom_bar(main_container)

	# Initial display update
	_update_seal_count()

func _build_description_panel(parent: Control) -> void:
	"""Builds the left-side description panel"""
	var panel = PanelContainer.new()
	panel.position = Vector2(40, 40)
	panel.size = Vector2(500, 600)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.1, 0.9)
	style.border_color = Color(0.3, 0.15, 0.5, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Siegel-Run"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Vervollständige das Siegel"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.3, 0.7, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Selected modifier name
	_desc_name_label = Label.new()
	_desc_name_label.text = "Wähle einen Knotenpunkt"
	_desc_name_label.add_theme_font_size_override("font_size", 22)
	_desc_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))
	_desc_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_desc_name_label)

	# Category label
	_desc_category_label = Label.new()
	_desc_category_label.text = ""
	_desc_category_label.add_theme_font_size_override("font_size", 14)
	_desc_category_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6, 0.8))
	vbox.add_child(_desc_category_label)

	# Tiefe contribution label (per modifier)
	_desc_tiefe_label = Label.new()
	_desc_tiefe_label.text = ""
	_desc_tiefe_label.add_theme_font_size_override("font_size", 13)
	_desc_tiefe_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 0.7))
	vbox.add_child(_desc_tiefe_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Description text
	_desc_text_label = RichTextLabel.new()
	_desc_text_label.text = "Aktiviere Knotenpunkte im Siegel, um den Albtraum zu vertiefen.\n\nJeder Knoten erzeugt Tiefe-Punkte. Je tiefer der Traum, desto näher ist Murum an der Wahrheit seiner Versiegelung.\n\nMyrkur- und Albtraum-Qualen erzeugen +3 Tiefe.\nUrgathon- und Voch Numta-Qualen erzeugen +2 Tiefe.\nKern- und Körper-Qualen erzeugen +1 Tiefe."
	_desc_text_label.bbcode_enabled = false
	_desc_text_label.scroll_active = false
	_desc_text_label.fit_content = true
	_desc_text_label.custom_minimum_size = Vector2(0, 200)
	_desc_text_label.add_theme_font_size_override("normal_font_size", 15)
	_desc_text_label.add_theme_color_override("default_color", Color(0.7, 0.65, 0.75, 1.0))
	vbox.add_child(_desc_text_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Seal count
	_seal_count_label = Label.new()
	_seal_count_label.text = "Aktive Siegel: 0 / 33"
	_seal_count_label.add_theme_font_size_override("font_size", 16)
	_seal_count_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7, 1.0))
	_seal_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_seal_count_label)

	# Tiefe display
	_tiefe_label = Label.new()
	_tiefe_label.text = "Tiefe: 0"
	_tiefe_label.add_theme_font_size_override("font_size", 20)
	_tiefe_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9, 1.0))
	_tiefe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tiefe_label)

	# Tiefenstufe display
	_tiefenstufe_label = Label.new()
	_tiefenstufe_label.text = "Der ruhige Traum"
	_tiefenstufe_label.add_theme_font_size_override("font_size", 16)
	_tiefenstufe_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.85, 0.9))
	_tiefenstufe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tiefenstufe_label)

	# Schwellensicht indicator
	_schwellensicht_label = Label.new()
	_schwellensicht_label.text = "Schwellensicht aktiv"
	_schwellensicht_label.add_theme_font_size_override("font_size", 14)
	_schwellensicht_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1.0))
	_schwellensicht_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_schwellensicht_label.visible = false
	vbox.add_child(_schwellensicht_label)

func _build_seal_visualization(parent: Control) -> void:
	"""Builds the circular seal with modifier nodes"""
	# Seal container (right side)
	var seal_container = Control.new()
	seal_container.position = Vector2(580, 0)
	seal_container.size = Vector2(1340, 780)
	parent.add_child(seal_container)

	# Line drawing layer (behind nodes)
	_seal_lines = Control.new()
	_seal_lines.position = Vector2.ZERO
	_seal_lines.size = seal_container.size
	_seal_lines.draw.connect(_draw_seal_lines)
	seal_container.add_child(_seal_lines)

	# Place nodes on concentric rings by category
	var modifier_ids = ChallengeRunManager.SIEGEL_MODIFIERS.keys()

	# Ring assignments by category
	var outer_ring: Array = []   # kern (8) + albtraum (6) = 14
	var middle_ring: Array = []  # koerper (8) = 8
	var inner_ring: Array = []   # myrkur (3) + voch_numta (3) + urgathon (5) = 11

	for mod_id in modifier_ids:
		var cat = ChallengeRunManager.SIEGEL_MODIFIERS[mod_id]["category"]
		match cat:
			"kern", "albtraum":
				outer_ring.append(mod_id)
			"koerper":
				middle_ring.append(mod_id)
			"myrkur", "voch_numta", "urgathon":
				inner_ring.append(mod_id)

	# Place nodes on rings
	_place_nodes_on_ring(seal_container, outer_ring, SEAL_OUTER_RADIUS, SEAL_CENTER)
	_place_nodes_on_ring(seal_container, middle_ring, SEAL_MIDDLE_RADIUS, SEAL_CENTER)
	_place_nodes_on_ring(seal_container, inner_ring, SEAL_INNER_RADIUS, SEAL_CENTER)

	# Center seal circle placeholder
	var center_circle = ColorRect.new()
	center_circle.color = Color(0.15, 0.05, 0.25, 0.5)
	center_circle.size = Vector2(40, 40)
	center_circle.position = SEAL_CENTER - Vector2(20, 20)
	center_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal_container.add_child(center_circle)

func _place_nodes_on_ring(parent: Control, modifier_ids: Array, radius: float, center: Vector2) -> void:
	"""Places modifier nodes evenly on a ring"""
	var count = modifier_ids.size()
	if count == 0:
		return

	for i in count:
		var angle = (TAU / count) * i - PI / 2  # Start from top
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		var mod_id = modifier_ids[i]
		_create_seal_node(parent, mod_id, pos)

func _create_seal_node(parent: Control, modifier_id: String, pos: Vector2) -> void:
	"""Creates a single seal node (clickable ColorRect placeholder)"""
	var mod_data = ChallengeRunManager.SIEGEL_MODIFIERS[modifier_id]
	var category = mod_data["category"]
	var cat_color = CATEGORY_COLORS.get(category, COLOR_INACTIVE)

	var node_btn = Button.new()
	node_btn.flat = true
	node_btn.custom_minimum_size = NODE_SIZE
	node_btn.size = NODE_SIZE
	node_btn.position = pos - NODE_SIZE / 2
	node_btn.tooltip_text = mod_data["name"]
	parent.add_child(node_btn)

	# Visual ColorRect inside button
	var visual = ColorRect.new()
	visual.color = COLOR_INACTIVE
	visual.size = NODE_SIZE
	visual.position = Vector2.ZERO
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node_btn.add_child(visual)

	# Store reference
	_seal_nodes[modifier_id] = {
		"button": node_btn,
		"visual": visual,
		"position": pos,
		"category": category,
		"cat_color": cat_color
	}

	# Connect signals
	node_btn.pressed.connect(_on_node_clicked.bind(modifier_id))
	node_btn.mouse_entered.connect(_on_node_hovered.bind(modifier_id))
	node_btn.mouse_exited.connect(_on_node_unhovered.bind(modifier_id))

func _build_bottom_bar(parent: Control) -> void:
	"""Builds the bottom button bar"""
	var bar = HBoxContainer.new()
	bar.position = Vector2(40, 720)
	bar.size = Vector2(500, 60)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 30)
	parent.add_child(bar)

	_back_button = Button.new()
	_back_button.text = "Erwachen"
	_back_button.custom_minimum_size = Vector2(200, 50)
	_back_button.pressed.connect(_on_back_pressed)
	bar.add_child(_back_button)

	_start_button = Button.new()
	_start_button.text = "Siegel aktivieren"
	_start_button.custom_minimum_size = Vector2(200, 50)
	_start_button.pressed.connect(_on_start_pressed)
	bar.add_child(_start_button)

# ============================================================================
# SEAL LINE DRAWING
# ============================================================================

func _draw_seal_lines() -> void:
	"""Draws connecting lines between seal nodes"""
	if _seal_nodes.is_empty():
		return

	# Draw ring outlines (placeholder circles as lines between adjacent nodes)
	var modifier_ids = ChallengeRunManager.SIEGEL_MODIFIERS.keys()

	# Group by ring
	var rings: Array[Array] = [[], [], []]
	for mod_id in modifier_ids:
		var cat = ChallengeRunManager.SIEGEL_MODIFIERS[mod_id]["category"]
		match cat:
			"kern", "albtraum":
				rings[0].append(mod_id)
			"koerper":
				rings[1].append(mod_id)
			"myrkur", "voch_numta", "urgathon":
				rings[2].append(mod_id)

	# Draw lines connecting nodes within each ring
	for ring in rings:
		if ring.size() < 2:
			continue
		for i in ring.size():
			var from_id = ring[i]
			var to_id = ring[(i + 1) % ring.size()]
			if from_id in _seal_nodes and to_id in _seal_nodes:
				var from_pos = _seal_nodes[from_id]["position"] - _seal_lines.global_position + Vector2(580, 0)
				var to_pos = _seal_nodes[to_id]["position"] - _seal_lines.global_position + Vector2(580, 0)
				var both_active = ChallengeRunManager.is_modifier_active(from_id) and ChallengeRunManager.is_modifier_active(to_id)
				var color = COLOR_LINE_ACTIVE if both_active else COLOR_LINE
				_seal_lines.draw_line(from_pos, to_pos, color, 1.5, true)

	# Draw radial lines from center to each ring (cross-connections)
	var local_center = SEAL_CENTER - _seal_lines.global_position + Vector2(580, 0)
	for ring in rings:
		for mod_id in ring:
			if mod_id in _seal_nodes:
				var node_pos = _seal_nodes[mod_id]["position"] - _seal_lines.global_position + Vector2(580, 0)
				var is_active = ChallengeRunManager.is_modifier_active(mod_id)
				var color = COLOR_LINE_ACTIVE if is_active else Color(COLOR_LINE.r, COLOR_LINE.g, COLOR_LINE.b, 0.15)
				_seal_lines.draw_line(local_center, node_pos, color, 0.8, true)

# ============================================================================
# NODE VISUALS & ANIMATION
# ============================================================================

func _update_node_visuals() -> void:
	"""Updates all node colors and pulse animation"""
	for modifier_id in _seal_nodes:
		var node_data = _seal_nodes[modifier_id]
		var visual: ColorRect = node_data["visual"]
		var is_active = ChallengeRunManager.is_modifier_active(modifier_id)
		var is_selected = modifier_id == _selected_modifier
		var cat_color: Color = node_data["cat_color"]

		if is_active:
			# Pulsating glow for active nodes
			var pulse = (sin(_pulse_timer * 2.0) + 1.0) * 0.5
			var glow_color = cat_color.lerp(Color.WHITE, pulse * 0.3)
			visual.color = glow_color
		elif is_selected:
			visual.color = COLOR_HOVER
		else:
			visual.color = COLOR_INACTIVE

	# Update seal lines
	if _seal_lines:
		_seal_lines.queue_redraw()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_node_clicked(modifier_id: String) -> void:
	"""Toggles a modifier node on/off"""
	ChallengeRunManager.toggle_modifier(modifier_id)
	_update_description(modifier_id)
	_update_seal_count()

func _on_node_hovered(modifier_id: String) -> void:
	"""Shows modifier description on hover"""
	_selected_modifier = modifier_id
	_update_description(modifier_id)

func _on_node_unhovered(modifier_id: String) -> void:
	"""Clears hover state"""
	if _selected_modifier == modifier_id:
		_selected_modifier = ""

func _update_description(modifier_id: String) -> void:
	"""Updates the left panel with modifier details"""
	if modifier_id.is_empty() or modifier_id not in ChallengeRunManager.SIEGEL_MODIFIERS:
		return

	var mod_data = ChallengeRunManager.SIEGEL_MODIFIERS[modifier_id]
	var is_active = ChallengeRunManager.is_modifier_active(modifier_id)
	var category = mod_data["category"]
	var cat_info = ChallengeRunManager.CATEGORY_INFO.get(category, {})

	_desc_name_label.text = mod_data["name"]
	if is_active:
		_desc_name_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, COLOR_ACTIVE))
	else:
		_desc_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1.0))

	_desc_category_label.text = cat_info.get("name", category)
	_desc_category_label.add_theme_color_override("font_color", cat_info.get("color", Color.WHITE).lerp(Color.WHITE, 0.3))

	# Show depth point contribution
	var tiefe_points = ChallengeRunManager.get_modifier_tiefe(modifier_id)
	_desc_tiefe_label.text = "Tiefe: +%d" % tiefe_points

	var status_text = "[AKTIV]" if is_active else "[INAKTIV]"
	_desc_text_label.text = "%s\n\n%s" % [mod_data["description"], status_text]

func _update_seal_count() -> void:
	"""Updates seal counter, Tiefe, Tiefenstufe, and Schwellensicht indicator"""
	var active = ChallengeRunManager.get_active_count()
	var total = ChallengeRunManager.get_max_delirium()
	_seal_count_label.text = "Aktive Siegel: %d / %d" % [active, total]

	if ChallengeRunManager.are_all_modifiers_maxed():
		_seal_count_label.add_theme_color_override("font_color", Color(0.7, 0.1, 1.0, 1.0))
	elif active > 0:
		_seal_count_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9, 1.0))
	else:
		_seal_count_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7, 1.0))

	# Tiefe display
	var tiefe = ChallengeRunManager.get_tiefe()
	var max_tiefe = ChallengeRunManager.get_max_tiefe()
	_tiefe_label.text = "Tiefe: %d / %d" % [tiefe, max_tiefe]

	# Color based on depth level
	var stufe_index = ChallengeRunManager.get_tiefenstufe_index()
	var tiefe_colors = [
		Color(0.5, 0.6, 0.7, 1.0),    # 0: ruhig - grau
		Color(0.5, 0.6, 0.9, 1.0),    # 1: flüstern - blau
		Color(0.6, 0.4, 0.8, 1.0),    # 2: zerbrochen - lila
		Color(0.4, 0.1, 0.6, 1.0),    # 3: myrkurs blick - dunkel-lila
		Color(0.8, 0.2, 0.3, 1.0),    # 4: albtraum - rot
		Color(0.3, 0.8, 0.6, 1.0),    # 5: urgathon - türkis
		Color(0.9, 0.3, 1.0, 1.0),    # 6: versiegelte wahrheit - magenta
	]
	var tiefe_color = tiefe_colors[mini(stufe_index, tiefe_colors.size() - 1)]
	_tiefe_label.add_theme_color_override("font_color", tiefe_color)

	# Tiefenstufe name
	var stufe_name = ChallengeRunManager.get_tiefenstufe_name()
	_tiefenstufe_label.text = stufe_name
	_tiefenstufe_label.add_theme_color_override("font_color", tiefe_color.lerp(Color.WHITE, 0.2))

	# Schwellensicht threshold check (based on Tiefe now)
	var threshold = max_tiefe * 0.5
	_schwellensicht_label.visible = tiefe >= threshold

func _on_start_pressed() -> void:
	"""Starts the Siegel-Run"""
	ChallengeRunManager.start_challenge_run()
	challenge_started.emit()
	print("[SiegelMenu] Siegel-Run gestartet! Aktive Siegel: %d" % ChallengeRunManager.get_active_count())

func _on_back_pressed() -> void:
	"""Returns to main menu"""
	ChallengeRunManager._reset_modifiers()
	back_pressed.emit()
