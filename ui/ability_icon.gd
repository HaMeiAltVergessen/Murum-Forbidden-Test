extends Control
class_name AbilityIcon
## Displays an ability icon with cooldown overlay

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var ability_name: String = "Ability"
@export var keybind: String = "1"
@export var icon_texture: Texture2D = null

# ============================================================================
# NODES
# ============================================================================

var background: ColorRect
var icon: TextureRect
var cooldown_overlay: ColorRect
var cooldown_label: Label
var keybind_label: Label

# ============================================================================
# STATE
# ============================================================================

var cooldown_duration: float = 0.0
var cooldown_remaining: float = 0.0
var is_on_cooldown: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)

	# Create background
	background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.8)
	background.size = Vector2(64, 64)
	background.position = Vector2.ZERO
	add_child(background)

	# Create icon
	icon = TextureRect.new()
	icon.size = Vector2(56, 56)
	icon.position = Vector2(4, 4)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Use placeholder or provided texture
	if icon_texture:
		icon.texture = icon_texture
	else:
		# Create placeholder (colored square)
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.5, 0.5, 0.5, 1.0)
		placeholder.size = Vector2(56, 56)
		icon.add_child(placeholder)

	add_child(icon)

	# Create cooldown overlay (starts hidden)
	cooldown_overlay = ColorRect.new()
	cooldown_overlay.color = Color(0, 0, 0, 0.7)
	cooldown_overlay.size = Vector2(64, 64)
	cooldown_overlay.position = Vector2.ZERO
	cooldown_overlay.visible = false
	add_child(cooldown_overlay)

	# Create cooldown label
	cooldown_label = Label.new()
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 20)
	cooldown_label.size = Vector2(64, 64)
	cooldown_label.position = Vector2.ZERO
	cooldown_label.visible = false
	add_child(cooldown_label)

	# Create keybind label (bottom right)
	keybind_label = Label.new()
	keybind_label.text = keybind
	keybind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keybind_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	keybind_label.add_theme_font_size_override("font_size", 14)
	keybind_label.size = Vector2(60, 60)
	keybind_label.position = Vector2(2, 2)
	add_child(keybind_label)

	print("[AbilityIcon] %s initialized (key: %s)" % [ability_name, keybind])


func _process(delta: float) -> void:
	if is_on_cooldown:
		cooldown_remaining -= delta

		if cooldown_remaining <= 0.0:
			_end_cooldown()
		else:
			_update_cooldown_display()


# ============================================================================
# COOLDOWN CONTROL
# ============================================================================

func start_cooldown(duration: float) -> void:
	"""Starts cooldown timer"""

	cooldown_duration = duration
	cooldown_remaining = duration
	is_on_cooldown = true

	cooldown_overlay.visible = true
	cooldown_label.visible = true

	print("[AbilityIcon] %s cooldown started (%.1fs)" % [ability_name, duration])


func _end_cooldown() -> void:
	"""Ends cooldown"""

	is_on_cooldown = false
	cooldown_remaining = 0.0

	cooldown_overlay.visible = false
	cooldown_label.visible = false

	print("[AbilityIcon] %s cooldown finished" % ability_name)


func _update_cooldown_display() -> void:
	"""Updates cooldown visual"""

	# Update label (show seconds remaining)
	cooldown_label.text = "%.1f" % cooldown_remaining

	# Update overlay opacity based on progress
	var progress = cooldown_remaining / cooldown_duration
	var overlay_height = 64.0 * progress
	cooldown_overlay.size = Vector2(64, overlay_height)
	cooldown_overlay.position = Vector2(0, 64.0 - overlay_height)
