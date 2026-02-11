extends CanvasLayer
## DeathScreen - Displayed when player dies
class_name DeathScreen

# ============ REFERENCES ============
@onready var background: ColorRect = $Background
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var respawn_button: Button = $CenterContainer/VBoxContainer/RespawnButton

# ============ FADE SETTINGS ============
@export var fade_in_duration: float = 0.5


func _ready() -> void:
	# Ensure death screen works even when tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect to EventBus
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)

	# Connect button
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_button_pressed)

	# Hide initially
	hide()

	print("[DeathScreen] Initialized")


# ============ SIGNAL HANDLERS ============
func _on_player_died() -> void:
	"""Shows the death screen with fade-in effect"""
	show()
	_fade_in()


func _on_player_respawned() -> void:
	"""Hides the death screen"""
	hide()


func _on_respawn_button_pressed() -> void:
	"""Handles respawn button press"""
	print("[DeathScreen] Respawn button pressed")
	GameManager.respawn_player()


# ============ VISUAL EFFECTS ============
func _fade_in() -> void:
	"""Fades in the death screen"""
	if not background:
		return

	# Start fully transparent
	background.modulate.a = 0.0

	if title_label:
		title_label.modulate.a = 0.0

	if respawn_button:
		respawn_button.modulate.a = 0.0

	# Fade in
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.8, fade_in_duration)

	if title_label:
		tween.tween_property(title_label, "modulate:a", 1.0, fade_in_duration)

	if respawn_button:
		tween.tween_property(respawn_button, "modulate:a", 1.0, fade_in_duration)
