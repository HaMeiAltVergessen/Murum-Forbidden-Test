extends Control
class_name ReboundIndicator

## Displays Rebound progress (3 dots)

# ============================================================================
# REFERENCES
# ============================================================================

@onready var dot_1: ColorRect = $HBoxContainer/Dot1
@onready var dot_2: ColorRect = $HBoxContainer/Dot2
@onready var dot_3: ColorRect = $HBoxContainer/Dot3
@onready var label: Label = $Label

# ============================================================================
# STATE
# ============================================================================

var current_count: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to events
	EventBus.rebound_progress.connect(_on_rebound_progress)
	EventBus.rebound_ready.connect(_on_rebound_ready)
	EventBus.rebound_executed.connect(_on_rebound_executed)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)

	# Initialize
	_update_display(0)
	visible = false  # Hide until first parry

# ============================================================================
# UPDATE
# ============================================================================

func _on_rebound_progress(current: int, required: int) -> void:
	"""Updates progress display"""
	current_count = current
	_update_display(current)

	# Show indicator on first parry
	if not visible:
		visible = true

func _update_display(count: int) -> void:
	"""Updates dot visuals"""

	# Dot 1
	if count >= 1:
		dot_1.color = Color.GOLD
		_pulse_dot(dot_1)
	else:
		dot_1.color = Color(0.3, 0.3, 0.3)

	# Dot 2
	if count >= 2:
		dot_2.color = Color.GOLD
		_pulse_dot(dot_2)
	else:
		dot_2.color = Color(0.3, 0.3, 0.3)

	# Dot 3
	if count >= 3:
		dot_3.color = Color.GOLD
		_pulse_dot(dot_3)
	else:
		dot_3.color = Color(0.3, 0.3, 0.3)

func _pulse_dot(dot: ColorRect) -> void:
	"""Pulses dot when filled"""
	var tween = create_tween()
	tween.tween_property(dot, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(dot, "scale", Vector2(1.0, 1.0), 0.2)

func _on_rebound_ready() -> void:
	"""Called when Rebound is ready"""

	# Flash all dots
	var tween = create_tween().set_loops(3)
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_rebound_executed(enemy: Node) -> void:
	"""Called when Rebound is used"""

	# Reset display
	_update_display(0)
	current_count = 0

	# Hide after brief delay
	await get_tree().create_timer(1.0).timeout
	visible = false

func _on_perfect_parry(enemy: Node) -> void:
	"""Called on any perfect parry (might reset)"""

	# If count went to 0, hide
	if current_count == 0:
		await get_tree().create_timer(0.5).timeout
		visible = false
