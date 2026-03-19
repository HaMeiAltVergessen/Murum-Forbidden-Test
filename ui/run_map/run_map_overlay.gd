extends CanvasLayer
class_name RunMapOverlay

## Semi-transparent overlay showing the run map (Hades-style node network).
## Toggled via EventBus.toggle_run_map (Weltkarte key item).

# ============ COLORS ============
const COLOR_BG := Color(0.02, 0.01, 0.04, 0.85)
const COLOR_CONNECTION := Color(0.3, 0.25, 0.4, 0.5)
const COLOR_CONNECTION_DONE := Color(0.5, 0.4, 0.7, 0.7)

const NODE_COLORS: Dictionary = {
	0: Color(0.3, 0.5, 0.9, 0.9),    # COMBAT — blue
	1: Color(0.7, 0.3, 0.9, 0.9),    # ELITE — purple
	2: Color(0.9, 0.8, 0.2, 0.9),    # TREASURE — gold
	3: Color(0.3, 0.9, 0.4, 0.9),    # REST — green
	4: Color(0.6, 0.6, 0.6, 0.9),    # EVENT — grey
	5: Color(0.9, 0.2, 0.2, 0.9),    # BOSS — red
	6: Color(0.9, 0.6, 0.2, 0.9),    # SHOP — orange
	7: Color(0.9, 0.4, 0.4, 0.9),    # ARENA — dark red
}

const NODE_RADIUS: float = 22.0
const CURRENT_RADIUS: float = 28.0

# ============ STATE ============
var is_visible: bool = false
var _draw_node: Control = null

# ============ MAP LAYOUT ============
const MAP_OFFSET := Vector2(960, 100)  # Center horizontally, start near top
const ROW_SPACING: float = 120.0
const COL_SPACING: float = 200.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	EventBus.toggle_run_map.connect(_toggle)

	# Draw node for custom rendering
	_draw_node = Control.new()
	_draw_node.name = "MapDrawNode"
	_draw_node.anchors_preset = Control.PRESET_FULL_RECT
	_draw_node.anchor_right = 1.0
	_draw_node.anchor_bottom = 1.0
	_draw_node.draw.connect(_on_draw)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)


func _input(event: InputEvent) -> void:
	if not is_visible:
		return
	# Close on ESC or same toggle
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	is_visible = not is_visible
	visible = is_visible
	if is_visible:
		_draw_node.queue_redraw()


func _on_draw() -> void:
	if not is_visible:
		return

	var map: RunMapData.Map = _get_current_map()
	if not map:
		_draw_no_map()
		return

	# Background
	_draw_node.draw_rect(Rect2(0, 0, 1920, 1080), COLOR_BG)

	# Title
	var world_name: String = _get_world_name(map.world_id)
	_draw_centered_text(world_name, Vector2(960, 40), 26, Color(0.8, 0.7, 0.9))

	# Calculate positions for all nodes
	var positions: Dictionary = _calculate_positions(map)

	# Draw connections first (behind nodes)
	for node_id in map.nodes:
		var node: RunMapData.MapNode = map.nodes[node_id]
		var from_pos: Vector2 = positions.get(node_id, Vector2.ZERO)
		for conn_id in node.connections:
			var to_pos: Vector2 = positions.get(conn_id, Vector2.ZERO)
			var conn_color: Color = COLOR_CONNECTION_DONE if node.is_completed else COLOR_CONNECTION
			_draw_node.draw_line(from_pos, to_pos, conn_color, 2.0, true)

	# Draw nodes
	for node_id in map.nodes:
		var node: RunMapData.MapNode = map.nodes[node_id]
		var pos: Vector2 = positions.get(node_id, Vector2.ZERO)
		_draw_map_node(node, pos, map.current_node_id)

	# Legend
	_draw_legend()

	# Hint
	_draw_centered_text("ESC — Schliessen", Vector2(960, 1050), 16, Color(0.5, 0.5, 0.5))


func _draw_map_node(node: RunMapData.MapNode, pos: Vector2, current_id: int) -> void:
	var is_current: bool = node.id == current_id
	var radius: float = CURRENT_RADIUS if is_current else NODE_RADIUS
	var color: Color = NODE_COLORS.get(node.type, Color.WHITE)

	# Completed nodes: dimmed
	if node.is_completed and not is_current:
		color = color.darkened(0.5)
		color.a = 0.5

	# Accessible nodes: bright + pulsing outline
	if node.is_accessible:
		color = color.lightened(0.2)

	# Draw circle
	_draw_node.draw_circle(pos, radius, color)

	# Current node: white outline
	if is_current:
		_draw_node.draw_arc(pos, radius + 3, 0, TAU, 32, Color.WHITE, 2.0)

	# Accessible node: dashed outline
	if node.is_accessible and not is_current:
		_draw_node.draw_arc(pos, radius + 2, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5)

	# Node type label
	var label: String = _get_node_label(node.type)
	_draw_centered_text(label, pos + Vector2(0, -2), 12, Color.WHITE)

	# Reward preview (small text below)
	if node.reward_type != "" and not node.is_completed:
		_draw_centered_text(node.reward_type, pos + Vector2(0, radius + 12), 10, Color(0.7, 0.7, 0.5, 0.7))


func _draw_legend() -> void:
	var x: float = 30.0
	var y: float = 1000.0
	var legend_items: Array = [
		["K", 0, "Kampf"], ["E", 1, "Elite"], ["S", 2, "Schatz"],
		["R", 3, "Rast"], ["Er", 4, "Ereignis"], ["B", 5, "Boss"],
		["H", 6, "Haendler"],
	]
	for item in legend_items:
		var color: Color = NODE_COLORS.get(item[1], Color.WHITE)
		_draw_node.draw_circle(Vector2(x, y), 8.0, color)
		_draw_text_at(item[2] as String, Vector2(x + 14, y - 7), 12, Color(0.7, 0.7, 0.7))
		x += 130.0


func _draw_no_map() -> void:
	_draw_node.draw_rect(Rect2(0, 0, 1920, 1080), COLOR_BG)
	_draw_centered_text("Kein aktiver Run", Vector2(960, 540), 24, Color(0.6, 0.4, 0.4))


# ============ POSITION CALCULATION ============
func _calculate_positions(map: RunMapData.Map) -> Dictionary:
	"""Calculate screen positions for all nodes based on rows/columns."""
	var positions: Dictionary = {}
	var total_rows: int = map.rows.size()

	for row_idx in range(total_rows):
		var row_nodes: Array = map.rows[row_idx]
		var count: int = row_nodes.size()
		var y: float = MAP_OFFSET.y + row_idx * ROW_SPACING + 60

		for col_idx in range(count):
			var node_id: int = row_nodes[col_idx]
			# Center nodes horizontally
			var total_width: float = (count - 1) * COL_SPACING
			var start_x: float = MAP_OFFSET.x - total_width / 2.0
			var x: float = start_x + col_idx * COL_SPACING
			positions[node_id] = Vector2(x, y)

	return positions


# ============ HELPERS ============
func _get_current_map() -> RunMapData.Map:
	if RunManager and RunManager.current_map:
		return RunManager.current_map
	return null


func _get_world_name(world_id: RunMapData.WorldId) -> String:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND: return "Das Niemandsland"
		RunMapData.WorldId.KOLLEKTIV: return "Das Kollektiv"
		RunMapData.WorldId.ABGRUND: return "Der Abgrund"
	return "Unbekannt"


func _get_node_label(type: int) -> String:
	match type:
		0: return "K"    # COMBAT
		1: return "E"    # ELITE
		2: return "S"    # TREASURE
		3: return "R"    # REST
		4: return "Er"   # EVENT
		5: return "B"    # BOSS
		6: return "H"    # SHOP
		7: return "A"    # ARENA
	return "?"


func _draw_centered_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	_draw_node.draw_string(font, pos - Vector2(text_size.x / 2.0, -text_size.y / 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_text_at(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	_draw_node.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
