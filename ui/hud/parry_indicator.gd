extends Control
## ParryIndicator - Shows parry availability and cooldown
## Visual feedback for parry timing window

# ============ REFERENCES ============
@onready var shield_icon: ColorRect = $ShieldIcon
@onready var cooldown_label: Label = $CooldownLabel

# ============ STATE ============
var is_on_cooldown: bool = false
var pulse_tween: Tween = null


func _ready() -> void:
	# Connect to EventBus signals
	EventBus.parry_started.connect(_on_parry_started)
	EventBus.parry_window_opened.connect(_on_parry_opened)
	EventBus.parry_failed.connect(_on_parry_failed)
	EventBus.perfect_parry.connect(_on_perfect_parry)
	EventBus.parry_cooldown_updated.connect(_on_cooldown_updated)

	cooldown_label.visible = false

	print("[ParryIndicator] Initialized")


# ============ SIGNAL HANDLERS ============
func _on_parry_started() -> void:
	"""Called when parry attempt starts"""
	# Anticipation flash
	var tween = create_tween()
	tween.tween_property(shield_icon, "color", Color(0.8, 0.8, 1.2), 0.05)
	tween.tween_property(shield_icon, "color", Color.WHITE, 0.05)


func _on_parry_opened() -> void:
	"""Called when parry window opens"""
	# Pulse effect während window
	if pulse_tween:
		pulse_tween.kill()

	pulse_tween = create_tween().set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(shield_icon, "scale", Vector2(1.2, 1.2), 0.2)
	pulse_tween.tween_property(shield_icon, "scale", Vector2(1.0, 1.0), 0.2)

	# Cyan tint during window
	shield_icon.color = Color(0.5, 1.5, 1.5)


func _on_parry_failed() -> void:
	"""Called when parry fails (timeout)"""
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()

	shield_icon.scale = Vector2(1.0, 1.0)
	shield_icon.color = Color(0.5, 0.5, 0.5)  # Gray

	is_on_cooldown = true
	cooldown_label.visible = true


func _on_perfect_parry(_enemy: Node) -> void:
	"""Called on successful parry"""
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()

	shield_icon.scale = Vector2(1.0, 1.0)

	# Success flash (green)
	var tween = create_tween()
	shield_icon.color = Color(0.5, 1.5, 0.5)

	await get_tree().create_timer(0.2).timeout
	shield_icon.color = Color.WHITE


func _on_cooldown_updated(time_remaining: float) -> void:
	"""Updates cooldown timer display"""
	if is_on_cooldown:
		cooldown_label.text = "%.1fs" % time_remaining

		if time_remaining <= 0.0:
			# Cooldown ended
			is_on_cooldown = false
			cooldown_label.visible = false
			shield_icon.color = Color.WHITE
