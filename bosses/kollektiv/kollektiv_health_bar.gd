extends Control
## Custom health bar for the Kollektiv boss fight
## Shows total HP bar + 5 core mini-bars + hub bar in final phase
class_name KollektivHealthBar

# ============ CONFIGURATION ============
const BAR_WIDTH: float = 700.0
const BAR_HEIGHT: float = 20.0
const MINI_BAR_WIDTH: float = 120.0
const MINI_BAR_HEIGHT: float = 8.0
const MINI_BAR_SPACING: float = 12.0

# ============ CORE COLORS ============
const CORE_COLORS: Dictionary = {
	"energy":     Color(1.0, 0.6, 0.1),   # Orange
	"defense":    Color(0.3, 0.5, 0.9),   # Blue
	"mobility":   Color(0.3, 0.9, 0.4),   # Green
	"fabricator": Color(0.7, 0.3, 0.9),   # Purple
	"cognition":  Color(0.2, 0.8, 0.9),   # Cyan
}

# ============ STATE ============
var _cores: Array = []
var _hub: Node = null
var _total_bar: ColorRect
var _total_bar_bg: ColorRect
var _total_label: Label
var _mini_bars: Array = []
var _hub_bar: Dictionary = {}  # {bg, fill, label}
var _is_final_phase: bool = false


func _ready() -> void:
	position = Vector2((1920 - BAR_WIDTH) * 0.5, 30)


func setup(cores: Array) -> void:
	_cores = cores
	_build_ui()


func _build_ui() -> void:
	# Boss name
	var title := Label.new()
	title.text = "Das Kollektiv der Einen Stimme"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(BAR_WIDTH, 28)
	add_child(title)

	# Total HP bar background
	_total_bar_bg = ColorRect.new()
	_total_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_bar_bg.position = Vector2(0, 30)
	_total_bar_bg.color = Color(0.15, 0.15, 0.15)
	add_child(_total_bar_bg)

	# Total HP bar fill
	_total_bar = ColorRect.new()
	_total_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_bar.position = Vector2(0, 30)
	_total_bar.color = Color(0.2, 0.7, 0.8)
	add_child(_total_bar)

	# Total HP label
	_total_label = Label.new()
	_total_label.position = Vector2(0, 30)
	_total_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total_label.add_theme_font_size_override("font_size", 13)
	add_child(_total_label)

	# Mini bars for each core
	var mini_y: float = 56.0
	var total_mini_width: float = _cores.size() * MINI_BAR_WIDTH + (_cores.size() - 1) * MINI_BAR_SPACING
	var start_x: float = (BAR_WIDTH - total_mini_width) * 0.5

	for i in range(_cores.size()):
		var core: KollektivCore = _cores[i]
		var core_id: String = core.get_meta("core_id", "unknown")
		var x_pos: float = start_x + i * (MINI_BAR_WIDTH + MINI_BAR_SPACING)

		# Core name
		var name_label := Label.new()
		name_label.text = core.core_name
		name_label.position = Vector2(x_pos, mini_y)
		name_label.size = Vector2(MINI_BAR_WIDTH, 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		add_child(name_label)

		# Mini bar bg
		var bg := ColorRect.new()
		bg.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
		bg.position = Vector2(x_pos, mini_y + 14)
		bg.color = Color(0.2, 0.2, 0.2)
		add_child(bg)

		# Mini bar fill
		var fill := ColorRect.new()
		fill.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
		fill.position = Vector2(x_pos, mini_y + 14)
		fill.color = CORE_COLORS.get(core_id, Color(0.7, 0.7, 0.7))
		add_child(fill)

		_mini_bars.append({
			"bg": bg,
			"fill": fill,
			"name_label": name_label,
			"core": core,
			"core_id": core_id,
		})


func update_health(cores: Array, hub: Node = null) -> void:
	# Update total bar
	var total_current: float = 0.0
	var total_max: float = 0.0
	for core in cores:
		total_current += max(0, core.current_hp)
		total_max += core.max_hp
	if hub and is_instance_valid(hub):
		total_current += max(0, hub.current_hp)
		total_max += hub.max_hp

	var total_pct: float = total_current / total_max if total_max > 0 else 0.0
	_total_bar.size.x = BAR_WIDTH * total_pct
	_total_label.text = "%.0f / %.0f" % [total_current, total_max]

	# Update mini bars
	for data in _mini_bars:
		var core: KollektivCore = data["core"]
		var fill: ColorRect = data["fill"]
		var name_label: Label = data["name_label"]
		var core_id: String = data["core_id"]
		var pct: float = core.get_hp_percent()

		fill.size.x = MINI_BAR_WIDTH * pct

		if core.is_destroyed:
			fill.color = Color(0.3, 0.3, 0.3, 0.5)
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			fill.color = CORE_COLORS.get(core_id, Color(0.7, 0.7, 0.7))
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	# Update hub bar if in final phase
	if _is_final_phase and hub and is_instance_valid(hub) and not _hub_bar.is_empty():
		var hub_pct: float = hub.current_hp / hub.max_hp if hub.max_hp > 0 else 0.0
		_hub_bar["fill"].size.x = MINI_BAR_WIDTH * hub_pct


func start_final_phase(hub: Node) -> void:
	"""Show the central hub health bar"""
	_is_final_phase = true
	_hub = hub

	# Add hub bar below mini bars
	var hub_y: float = 82.0
	var hub_x: float = (BAR_WIDTH - MINI_BAR_WIDTH) * 0.5

	# Hub name
	var name_label := Label.new()
	name_label.text = "ZENTRALER KERN"
	name_label.position = Vector2(hub_x, hub_y)
	name_label.size = Vector2(MINI_BAR_WIDTH, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(name_label)

	# Hub bar bg
	var bg := ColorRect.new()
	bg.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT + 2)
	bg.position = Vector2(hub_x, hub_y + 14)
	bg.color = Color(0.2, 0.2, 0.2)
	add_child(bg)

	# Hub bar fill (gold)
	var fill := ColorRect.new()
	fill.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT + 2)
	fill.position = Vector2(hub_x, hub_y + 14)
	fill.color = Color(1.0, 0.85, 0.3)
	add_child(fill)

	_hub_bar = {"bg": bg, "fill": fill, "name_label": name_label}
