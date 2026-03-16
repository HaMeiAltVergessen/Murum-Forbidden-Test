extends Control
## Custom health bar for the hero group boss fight
## Shows total HP bar + 5 individual mini-bars
class_name HeroGroupHealthBar

# ============ CONFIGURATION ============
const BAR_WIDTH: float = 600.0
const BAR_HEIGHT: float = 20.0
const MINI_BAR_WIDTH: float = 100.0
const MINI_BAR_HEIGHT: float = 8.0
const MINI_BAR_SPACING: float = 20.0

# ============ STATE ============
var _heroes: Array = []
var _total_bar: ColorRect
var _total_bar_bg: ColorRect
var _total_label: Label
var _mini_bars: Array = []  # Array of {bg: ColorRect, fill: ColorRect, label: Label, hero: HeroGroupMember}


func _ready() -> void:
	# Position at top center
	position = Vector2((1920 - BAR_WIDTH) * 0.5, 30)


func setup(heroes: Array) -> void:
	_heroes = heroes
	_build_ui()


func _build_ui() -> void:
	# Boss name
	var title := Label.new()
	title.text = "Die Heldengruppe"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(BAR_WIDTH, 30)
	add_child(title)

	# Total HP bar background
	_total_bar_bg = ColorRect.new()
	_total_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_bar_bg.position = Vector2(0, 32)
	_total_bar_bg.color = Color(0.15, 0.15, 0.15)
	add_child(_total_bar_bg)

	# Total HP bar fill
	_total_bar = ColorRect.new()
	_total_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_bar.position = Vector2(0, 32)
	_total_bar.color = Color(0.8, 0.15, 0.15)
	add_child(_total_bar)

	# Total HP label
	_total_label = Label.new()
	_total_label.position = Vector2(0, 32)
	_total_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total_label.add_theme_font_size_override("font_size", 14)
	add_child(_total_label)

	# Mini bars for each hero
	var mini_y: float = 58.0
	var total_mini_width: float = _heroes.size() * MINI_BAR_WIDTH + (_heroes.size() - 1) * MINI_BAR_SPACING
	var start_x: float = (BAR_WIDTH - total_mini_width) * 0.5

	for i in range(_heroes.size()):
		var hero: HeroGroupMember = _heroes[i]
		var x_pos: float = start_x + i * (MINI_BAR_WIDTH + MINI_BAR_SPACING)

		# Hero name
		var name_label := Label.new()
		name_label.text = hero.hero_name
		name_label.position = Vector2(x_pos, mini_y)
		name_label.size = Vector2(MINI_BAR_WIDTH, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		add_child(name_label)

		# Mini bar bg
		var bg := ColorRect.new()
		bg.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
		bg.position = Vector2(x_pos, mini_y + 16)
		bg.color = Color(0.2, 0.2, 0.2)
		add_child(bg)

		# Mini bar fill
		var fill := ColorRect.new()
		fill.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
		fill.position = Vector2(x_pos, mini_y + 16)
		fill.color = _get_hero_color(hero.hero_name)
		add_child(fill)

		_mini_bars.append({
			"bg": bg,
			"fill": fill,
			"name_label": name_label,
			"hero": hero,
		})


func update_health(heroes: Array) -> void:
	# Update total bar
	var total_current: float = 0.0
	var total_max: float = 0.0
	for hero in heroes:
		total_current += max(0, hero.current_hp)
		total_max += hero.max_hp

	var total_pct: float = total_current / total_max if total_max > 0 else 0.0
	_total_bar.size.x = BAR_WIDTH * total_pct
	_total_label.text = "%.0f / %.0f" % [total_current, total_max]

	# Update mini bars
	for data in _mini_bars:
		var hero: HeroGroupMember = data["hero"]
		var fill: ColorRect = data["fill"]
		var name_label: Label = data["name_label"]
		var pct: float = hero.get_hp_percent()

		fill.size.x = MINI_BAR_WIDTH * pct

		if hero.current_state == HeroGroupMember.State.DEAD:
			fill.color = Color(0.3, 0.3, 0.3, 0.5)
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif hero.is_last_standing:
			fill.color = Color(1.0, 0.5, 0.1)
			name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		else:
			fill.color = _get_hero_color(hero.hero_name)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func _get_hero_color(name: String) -> Color:
	match name:
		"Ritter":
			return Color(0.3, 0.5, 0.9)   # Blue (tank)
		"Kleriker":
			return Color(0.9, 0.9, 0.3)   # Yellow (healer)
		"Blutjaeger":
			return Color(0.9, 0.2, 0.2)   # Red (DPS)
		"Barbar":
			return Color(0.8, 0.5, 0.2)   # Orange (bruiser)
		"Nekromant":
			return Color(0.6, 0.2, 0.8)   # Purple (caster)
	return Color(0.7, 0.7, 0.7)
