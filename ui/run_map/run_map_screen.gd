extends CanvasLayer
## Run-Map UI - Displays Hades-style node selection screen
## Shows node network, connections, reward previews, and handles node selection
class_name RunMapScreen

# ============ CONSTANTS ============
const MAP_OFFSET: Vector2 = Vector2(560, 60)  # Center the 800px map in 1920px screen
const NODE_SIZE: Vector2 = Vector2(64, 64)
const NODE_HOVER_SCALE: float = 1.2

# Node type colors
const COLOR_COMBAT: Color = Color(0.8, 0.3, 0.2, 1.0)    # Red-orange
const COLOR_ELITE: Color = Color(0.9, 0.6, 0.1, 1.0)      # Gold
const COLOR_TREASURE: Color = Color(0.2, 0.8, 0.4, 1.0)   # Green
const COLOR_REST: Color = Color(0.3, 0.6, 0.9, 1.0)       # Blue
const COLOR_EVENT: Color = Color(0.7, 0.4, 0.9, 1.0)      # Purple
const COLOR_BOSS: Color = Color(0.9, 0.1, 0.1, 1.0)       # Bright red
const COLOR_COMPLETED: Color = Color(0.4, 0.4, 0.4, 0.6)  # Grey (done)
const COLOR_LOCKED: Color = Color(0.25, 0.25, 0.25, 0.4)  # Dark grey (not accessible)

const COLOR_CONNECTION: Color = Color(0.3, 0.3, 0.4, 0.5)
const COLOR_CONNECTION_ACTIVE: Color = Color(0.6, 0.5, 0.9, 0.8)
const COLOR_BG: Color = Color(0.03, 0.01, 0.06, 0.97)

# Node type labels
const NODE_LABELS: Dictionary = {
	RunMapData.NodeType.COMBAT_PUZZLE: "K+R",
	RunMapData.NodeType.ELITE_PUZZLE: "E+R",
	RunMapData.NodeType.TREASURE: "S",
	RunMapData.NodeType.REST: "RAST",
	RunMapData.NodeType.EVENT: "Er",
	RunMapData.NodeType.BOSS: "BOSS",
}

# Node type descriptions
const NODE_DESCRIPTIONS: Dictionary = {
	RunMapData.NodeType.COMBAT_PUZZLE: "Kampf + Raetsel",
	RunMapData.NodeType.ELITE_PUZZLE: "Elite + Raetsel (schwer)",
	RunMapData.NodeType.TREASURE: "Schatz (Wahl aus 3 Items)",
	RunMapData.NodeType.REST: "Rast (volle Heilung, NPCs)",
	RunMapData.NodeType.EVENT: "Ereignis (Text-Event)",
	RunMapData.NodeType.BOSS: "Boss-Kampf",
}

# Reward type icons (text placeholders until real icons exist)
const REWARD_ICONS: Dictionary = {
	"gold": "G",
	"relic": "R",
	"item": "I",
	"heal": "+",
	"event": "?",
	"boss": "!",
}

# ============ STATE ============
var current_map: RunMapData.Map = null
var node_buttons: Dictionary = {}  # node_id -> Button
var selected_node_id: int = -1
var hovered_node_id: int = -1

# ============ UI REFERENCES ============
var background: ColorRect
var map_canvas: Control   # Custom draw for connections
var title_label: Label
var world_label: Label
var lives_label: Label
var description_panel: PanelContainer
var description_label: Label
var reward_label: Label
var enter_button: Button


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	visible = false
	print("[RunMapScreen] Initialized")


# ============ BUILD UI ============
func _build_ui() -> void:
	# Background
	background = ColorRect.new()
	background.color = COLOR_BG
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	# Top bar
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(40, 20)
	top_bar.size = Vector2(1840, 50)
	add_child(top_bar)

	title_label = Label.new()
	title_label.text = "RUN MAP"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	top_bar.add_child(title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	world_label = Label.new()
	world_label.text = ""
	world_label.add_theme_font_size_override("font_size", 22)
	world_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.9))
	top_bar.add_child(world_label)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	lives_label = Label.new()
	lives_label.text = ""
	lives_label.add_theme_font_size_override("font_size", 22)
	lives_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	top_bar.add_child(lives_label)

	# Map canvas (for drawing connection lines)
	map_canvas = Control.new()
	map_canvas.position = MAP_OFFSET
	map_canvas.size = Vector2(800, 900)
	map_canvas.draw.connect(_on_map_canvas_draw)
	add_child(map_canvas)

	# Bottom panel (description + enter button)
	var bottom_bar = HBoxContainer.new()
	bottom_bar.position = Vector2(40, 920)
	bottom_bar.size = Vector2(1840, 130)
	bottom_bar.add_theme_constant_override("separation", 20)
	add_child(bottom_bar)

	# Description panel
	description_panel = PanelContainer.new()
	description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.06, 0.03, 0.1, 0.9)
	desc_style.corner_radius_top_left = 8
	desc_style.corner_radius_top_right = 8
	desc_style.corner_radius_bottom_left = 8
	desc_style.corner_radius_bottom_right = 8
	desc_style.content_margin_left = 16
	desc_style.content_margin_right = 16
	desc_style.content_margin_top = 12
	desc_style.content_margin_bottom = 12
	description_panel.add_theme_stylebox_override("panel", desc_style)
	bottom_bar.add_child(description_panel)

	var desc_vbox = VBoxContainer.new()
	description_panel.add_child(desc_vbox)

	description_label = Label.new()
	description_label.text = "Waehle einen Knoten..."
	description_label.add_theme_font_size_override("font_size", 20)
	description_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_vbox.add_child(description_label)

	reward_label = Label.new()
	reward_label.text = ""
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc_vbox.add_child(reward_label)

	# Enter button
	enter_button = Button.new()
	enter_button.text = "BETRETEN"
	enter_button.custom_minimum_size = Vector2(200, 60)
	enter_button.add_theme_font_size_override("font_size", 22)
	enter_button.disabled = true
	enter_button.pressed.connect(_on_enter_pressed)
	bottom_bar.add_child(enter_button)


# ============ SIGNALS ============
func _connect_signals() -> void:
	if RunManager:
		RunManager.show_run_map.connect(_on_show_run_map)
		RunManager.lives_changed.connect(_on_lives_changed)


func _on_show_run_map() -> void:
	current_map = RunManager.get_current_map()
	if not current_map:
		push_warning("[RunMapScreen] No map to display!")
		return

	_update_header()
	_build_map_nodes()
	_update_node_states()
	visible = true

	# Pause the game while on map
	get_tree().paused = true
	print("[RunMapScreen] Showing run map")


func _on_lives_changed(current: int, maximum: int) -> void:
	if lives_label:
		lives_label.text = "Leben: %d/%d" % [current, maximum]


# ============ MAP BUILDING ============
func _update_header() -> void:
	if not current_map:
		return
	world_label.text = RunManager._get_world_name(RunManager.current_world)
	lives_label.text = "Leben: %d/%d" % [RunManager.current_lives, RunManager.max_lives]


func _build_map_nodes() -> void:
	# Clear existing buttons
	for btn in node_buttons.values():
		if is_instance_valid(btn):
			btn.queue_free()
	node_buttons.clear()

	if not current_map:
		return

	# Create a button for each node
	for node_id in current_map.nodes:
		var node: RunMapData.MapNode = current_map.nodes[node_id]
		var btn = _create_node_button(node)
		map_canvas.add_child(btn)
		node_buttons[node_id] = btn

	# Trigger connection redraw
	map_canvas.queue_redraw()


func _create_node_button(node: RunMapData.MapNode) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = NODE_SIZE
	btn.size = NODE_SIZE
	btn.position = node.position - NODE_SIZE / 2.0
	btn.add_theme_font_size_override("font_size", 14)

	# Label
	btn.text = NODE_LABELS.get(node.type, "?")

	# Reward preview icon above button
	var reward_icon = Label.new()
	reward_icon.text = REWARD_ICONS.get(node.reward_type, "")
	reward_icon.add_theme_font_size_override("font_size", 16)
	reward_icon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.8))
	reward_icon.position = Vector2(NODE_SIZE.x / 2.0 - 6, -22)
	btn.add_child(reward_icon)

	# Connect signals
	var node_id = node.id
	btn.pressed.connect(_on_node_clicked.bind(node_id))
	btn.mouse_entered.connect(_on_node_hovered.bind(node_id))
	btn.mouse_exited.connect(_on_node_unhovered.bind(node_id))

	return btn


func _update_node_states() -> void:
	"""Update button colors/states based on accessibility"""
	if not current_map:
		return

	var accessible_nodes = current_map.get_accessible_nodes()
	var accessible_ids: Dictionary = {}
	for node in accessible_nodes:
		accessible_ids[node.id] = true

	for node_id in current_map.nodes:
		var node: RunMapData.MapNode = current_map.nodes[node_id]
		var btn: Button = node_buttons.get(node_id)
		if not btn or not is_instance_valid(btn):
			continue

		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2

		if node.is_completed:
			# Completed node
			style.bg_color = COLOR_COMPLETED
			style.border_color = COLOR_COMPLETED
			btn.disabled = true
		elif accessible_ids.has(node_id):
			# Accessible — colorful and clickable
			var color = _get_node_color(node.type)
			style.bg_color = color * 0.6
			style.border_color = color
			btn.disabled = false
		else:
			# Locked
			style.bg_color = COLOR_LOCKED
			style.border_color = COLOR_LOCKED
			btn.disabled = true

		# Highlight selected
		if node_id == selected_node_id:
			style.border_color = Color(1.0, 1.0, 1.0, 0.9)
			style.border_width_bottom = 3
			style.border_width_top = 3
			style.border_width_left = 3
			style.border_width_right = 3

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("disabled", style)

	map_canvas.queue_redraw()


# ============ DRAWING CONNECTIONS ============
func _on_map_canvas_draw() -> void:
	if not current_map:
		return

	var accessible_nodes = current_map.get_accessible_nodes()
	var accessible_ids: Dictionary = {}
	for node in accessible_nodes:
		accessible_ids[node.id] = true

	for node_id in current_map.nodes:
		var node: RunMapData.MapNode = current_map.nodes[node_id]
		var from_pos = node.position

		for target_id in node.connections:
			var target: RunMapData.MapNode = current_map.nodes.get(target_id)
			if not target:
				continue
			var to_pos = target.position

			# Color: active if source is completed/current and target is accessible
			var line_color = COLOR_CONNECTION
			if node.is_completed and accessible_ids.has(target_id):
				line_color = COLOR_CONNECTION_ACTIVE
			elif node.is_completed:
				line_color = Color(0.5, 0.5, 0.6, 0.4)

			map_canvas.draw_line(from_pos, to_pos, line_color, 2.0, true)


# ============ INPUT HANDLING ============
func _on_node_clicked(node_id: int) -> void:
	if selected_node_id == node_id:
		# Double-click / already selected — enter the node
		_on_enter_pressed()
		return

	selected_node_id = node_id
	_update_description(node_id)
	_update_node_states()
	enter_button.disabled = false
	print("[RunMapScreen] Node %d selected" % node_id)


func _on_node_hovered(node_id: int) -> void:
	hovered_node_id = node_id
	_update_description(node_id)

	# Scale up hovered button
	var btn = node_buttons.get(node_id)
	if btn and is_instance_valid(btn):
		btn.scale = Vector2(NODE_HOVER_SCALE, NODE_HOVER_SCALE)
		btn.pivot_offset = NODE_SIZE / 2.0


func _on_node_unhovered(node_id: int) -> void:
	if hovered_node_id == node_id:
		hovered_node_id = -1

	# Reset scale
	var btn = node_buttons.get(node_id)
	if btn and is_instance_valid(btn):
		btn.scale = Vector2.ONE

	# Show selected node description or default
	if selected_node_id >= 0:
		_update_description(selected_node_id)
	else:
		description_label.text = "Waehle einen Knoten..."
		reward_label.text = ""


func _update_description(node_id: int) -> void:
	if not current_map:
		return
	var node: RunMapData.MapNode = current_map.nodes.get(node_id)
	if not node:
		return

	description_label.text = "%s — %s" % [
		node.get_type_name(),
		NODE_DESCRIPTIONS.get(node.type, "Unbekannt")
	]
	reward_label.text = "Belohnung: %s" % node.reward_type.capitalize()


func _on_enter_pressed() -> void:
	if selected_node_id < 0:
		return

	print("[RunMapScreen] Entering node %d" % selected_node_id)
	visible = false
	get_tree().paused = false

	# Tell RunManager about the selection
	RunManager.select_map_node(selected_node_id)

	# Reset selection for next time
	selected_node_id = -1
	enter_button.disabled = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# ESC to quit run (back to Limbus)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm_exit_run()


func _confirm_exit_run() -> void:
	# For now, directly end the run. Later: add confirmation dialog
	print("[RunMapScreen] Player exited run from map")
	visible = false
	get_tree().paused = false
	RunManager.end_run(false)


# ============ HELPERS ============
func _get_node_color(type: RunMapData.NodeType) -> Color:
	match type:
		RunMapData.NodeType.COMBAT_PUZZLE: return COLOR_COMBAT
		RunMapData.NodeType.ELITE_PUZZLE: return COLOR_ELITE
		RunMapData.NodeType.TREASURE: return COLOR_TREASURE
		RunMapData.NodeType.REST: return COLOR_REST
		RunMapData.NodeType.EVENT: return COLOR_EVENT
		RunMapData.NodeType.BOSS: return COLOR_BOSS
	return Color.WHITE
