extends CanvasLayer
## Schwellensicht Overlay - Global cosmic horror screen tint
## Activates when 50%+ of Murums Qualen are active
## Pulsating purple film over the entire screen

# ============================================================================
# CONSTANTS
# ============================================================================

const PULSE_SPEED: float = 0.8
const PULSE_MIN_ALPHA: float = 0.08
const PULSE_MAX_ALPHA: float = 0.15

# ============================================================================
# STATE
# ============================================================================

var _overlay: ColorRect = null
var _pulse_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	layer = 90
	_build_ui()

	if EventBus:
		EventBus.schwellensicht_changed.connect(_on_schwellensicht_changed)

	# Check initial state
	if ChallengeRunManager and ChallengeRunManager.is_schwellensicht_active:
		_on_schwellensicht_changed(true)

	print("[SchwellensichtOverlay] Initialisiert")

func _build_ui() -> void:
	"""Builds the full-screen cosmic tint overlay"""
	_overlay = ColorRect.new()
	_overlay.color = Color(0.15, 0.0, 0.25, PULSE_MIN_ALPHA)
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

func _process(delta: float) -> void:
	if not _overlay or not _overlay.visible:
		return

	# Pulsating alpha
	_pulse_timer += delta * PULSE_SPEED
	var alpha = lerp(PULSE_MIN_ALPHA, PULSE_MAX_ALPHA, (sin(_pulse_timer * TAU) + 1.0) * 0.5)
	_overlay.color.a = alpha

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_schwellensicht_changed(active: bool) -> void:
	"""Toggles the cosmic overlay"""
	if _overlay:
		_overlay.visible = active
	if active:
		_pulse_timer = 0.0
