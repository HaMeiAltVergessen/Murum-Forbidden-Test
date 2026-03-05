extends CanvasLayer
## Schwindendes Bewusstsein Timer - Displays countdown for consciousness fading

# ============================================================================
# CONSTANTS
# ============================================================================

const WARNING_THRESHOLD: float = 60.0  # Flash red under 60s
const FLASH_SPEED: float = 2.0

# ============================================================================
# STATE
# ============================================================================

var timer_label: Label
var _flash_timer: float = 0.0
var _is_warning: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	layer = 50
	_build_ui()

	# Connect to EventBus
	EventBus.challenge_time_updated.connect(_on_time_updated)
	EventBus.challenge_run_failed.connect(_on_challenge_failed)
	EventBus.challenge_run_completed.connect(_on_challenge_completed)

	print("[ChallengeTimerHUD] Initialized")

func _build_ui() -> void:
	"""Builds timer display UI"""
	var panel = PanelContainer.new()
	panel.position = Vector2(860, 10)  # Top-center
	panel.custom_minimum_size = Vector2(200, 50)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.1, 0.85)
	style.border_color = Color(0.5, 0.2, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	timer_label = Label.new()
	timer_label.text = "Bewusstsein: 00:00"
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 1.0))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(timer_label)

	add_child(panel)

func _process(delta: float) -> void:
	if not _is_warning:
		return
	_flash_timer += delta * FLASH_SPEED
	var alpha = (sin(_flash_timer * TAU) + 1.0) * 0.5
	timer_label.add_theme_color_override("font_color", Color(1.0, lerp(0.2, 0.0, alpha), lerp(0.2, 0.0, alpha), 1.0))

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_time_updated(remaining: float) -> void:
	"""Updates timer display"""
	if remaining <= 0:
		timer_label.text = "Bewusstsein: 00:00"
		return

	var minutes = int(remaining) / 60
	var seconds = int(remaining) % 60
	timer_label.text = "Bewusstsein: %02d:%02d" % [minutes, seconds]

	# Warning state - consciousness fading
	if remaining <= WARNING_THRESHOLD and not _is_warning:
		_is_warning = true
		_flash_timer = 0.0

func _on_challenge_failed(reason: String) -> void:
	"""Shows failure message - consciousness lost"""
	timer_label.text = reason
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	_is_warning = false

	# Auto-hide after 5s
	await get_tree().create_timer(5.0).timeout
	visible = false

func _on_challenge_completed(_modifiers: Dictionary) -> void:
	"""Hides timer on completion"""
	visible = false
