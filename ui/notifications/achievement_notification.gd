extends CanvasLayer
## Achievement notification toast - slides in from top-right, auto-dismisses

# ============================================================================
# CONSTANTS
# ============================================================================

const DISPLAY_DURATION: float = 4.0
const SLIDE_DURATION: float = 0.5
const PANEL_WIDTH: float = 400.0
const PANEL_HEIGHT: float = 80.0

# ============================================================================
# REFERENCES
# ============================================================================

var panel: PanelContainer
var icon_texture: TextureRect
var title_label: Label
var desc_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	"""Builds the notification UI programmatically"""
	# Panel container
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.position = Vector2(1920.0 - PANEL_WIDTH - 20.0, -PANEL_HEIGHT)  # Start off-screen

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.95)
	style.border_color = Color(0.9, 0.75, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	# HBox for icon + text
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Icon
	icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(56, 56)
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	hbox.add_child(icon_texture)

	# VBox for title + description
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# "Achievement Unlocked" header
	var header = Label.new()
	header.text = "Achievement freigeschaltet!"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	vbox.add_child(header)

	# Achievement name
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(title_label)

	# Description
	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(desc_label)

	add_child(panel)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_achievement(achievement_data: Dictionary) -> void:
	"""Shows the achievement notification with slide-in animation"""
	title_label.text = achievement_data.get("name", "Achievement")
	desc_label.text = achievement_data.get("description", "")

	# Try loading icon
	var icon_path = achievement_data.get("icon", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)

	# Slide in from top
	var target_y = 20.0
	var tween = create_tween()
	tween.tween_property(panel, "position:y", target_y, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wait then slide out
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(panel, "position:y", -PANEL_HEIGHT, SLIDE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Remove self after animation
	tween.tween_callback(queue_free)
