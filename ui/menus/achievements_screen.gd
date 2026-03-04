extends PanelContainer
## Achievements Screen - Shows all achievements and their unlock status

# ============================================================================
# SIGNALS
# ============================================================================

signal back_pressed()

# ============================================================================
# CONSTANTS
# ============================================================================

const CATEGORY_ORDER := ["story", "combat", "exploration", "challenge"]
const CATEGORY_NAMES := {
	"story": "Geschichte",
	"combat": "Kampf",
	"exploration": "Erkundung",
	"challenge": "Herausforderung"
}

# ============================================================================
# REFERENCES
# ============================================================================

@onready var achievements_container: VBoxContainer = %AchievementsContainer
@onready var progress_label: Label = %ProgressLabel
@onready var back_button: Button = %AchievementsBackButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	populate_achievements()
	print("[AchievementsScreen] Initialized")

# ============================================================================
# PUBLIC API
# ============================================================================

func populate_achievements() -> void:
	"""Populates the achievement list from AchievementManager"""
	# Clear existing children
	for child in achievements_container.get_children():
		child.queue_free()

	if not AchievementManager:
		return

	var all_achievements = AchievementManager.get_all_achievements()
	var unlocked_count = AchievementManager.get_unlocked_count()
	var total_count = AchievementManager.get_total_count()

	# Update progress
	progress_label.text = "%d / %d" % [unlocked_count, total_count]

	# Group by category
	var categories: Dictionary = {}
	for id in all_achievements:
		var ach = all_achievements[id]
		var cat = ach.get("category", "other")
		if cat not in categories:
			categories[cat] = []
		categories[cat].append(ach)

	# Display in category order
	for category in CATEGORY_ORDER:
		if category not in categories:
			continue

		# Category header
		var header = Label.new()
		header.text = CATEGORY_NAMES.get(category, category)
		header.add_theme_font_size_override("font_size", 20)
		header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
		achievements_container.add_child(header)

		# Achievement cards
		for ach in categories[category]:
			var card = _create_achievement_card(ach)
			achievements_container.add_child(card)

		# Spacer between categories
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		achievements_container.add_child(spacer)

# ============================================================================
# CARD CREATION
# ============================================================================

func _create_achievement_card(achievement_data: Dictionary) -> PanelContainer:
	"""Creates a single achievement card UI element"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 60)

	# Style based on unlock status
	var style = StyleBoxFlat.new()
	var is_unlocked = achievement_data.get("unlocked", false)

	if is_unlocked:
		style.bg_color = Color(0.15, 0.18, 0.12, 0.9)
		style.border_color = Color(0.5, 0.7, 0.3, 0.8)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)

	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	# HBox layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Icon placeholder
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	var icon_path = achievement_data.get("icon", "")
	if is_unlocked and not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	# Locked achievements show no icon (or a lock icon if available)

	hbox.add_child(icon_rect)

	# Text VBox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	# Name
	var name_label = Label.new()
	name_label.text = achievement_data.get("name", "???") if is_unlocked else "???"
	name_label.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = achievement_data.get("description", "") if is_unlocked else "Gesperrt"
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	vbox.add_child(desc_label)

	# Unlock status indicator
	if is_unlocked:
		var check = Label.new()
		check.text = "Freigeschaltet"
		check.add_theme_font_size_override("font_size", 12)
		check.add_theme_color_override("font_color", Color(0.5, 0.7, 0.3, 1.0))
		hbox.add_child(check)

	return card

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_back_pressed() -> void:
	back_pressed.emit()
