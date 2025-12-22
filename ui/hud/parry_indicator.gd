extends Control
## ParryIndicator - Shows parry/block feedback for spatial system
## Visual feedback for blocking and parry/block success

# ============ REFERENCES ============
@onready var shield_icon: ColorRect = $ShieldIcon
@onready var cooldown_label: Label = $CooldownLabel

# ============ STATE ============
var pulse_tween: Tween = null


func _ready() -> void:
	# Connect to EventBus signals (spatial system)
	EventBus.parry_started.connect(_on_parry_started)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.normal_block_executed.connect(_on_normal_block)

	cooldown_label.visible = false

	print("[ParryIndicator] Initialized (spatial system)")


# ============ SIGNAL HANDLERS ============
func _on_parry_started() -> void:
	"""Called when blocking starts (RMB pressed)"""
	# Stop any existing pulse
	if pulse_tween:
		pulse_tween.kill()

	# Pulse effect while blocking
	pulse_tween = create_tween().set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(shield_icon, "scale", Vector2(1.15, 1.15), 0.25)
	pulse_tween.tween_property(shield_icon, "scale", Vector2(1.0, 1.0), 0.25)

	# Blue tint while blocking
	shield_icon.color = Color(0.6, 0.8, 1.5)


func _on_perfect_parry(_enemy: Node) -> void:
	"""Called on successful perfect parry"""
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()

	shield_icon.scale = Vector2(1.0, 1.0)

	# Success flash (bright yellow/gold for perfect parry)
	var tween = create_tween()
	shield_icon.color = Color(1.5, 1.5, 0.5)  # Bright yellow

	await get_tree().create_timer(0.3).timeout
	shield_icon.color = Color.WHITE


func _on_normal_block(_enemy: Node) -> void:
	"""Called on normal block"""
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()

	shield_icon.scale = Vector2(1.0, 1.0)

	# Block flash (blue for normal block)
	var tween = create_tween()
	shield_icon.color = Color(0.5, 0.8, 1.5)  # Blue

	await get_tree().create_timer(0.2).timeout
	shield_icon.color = Color.WHITE
