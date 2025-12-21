extends CanvasLayer
## HUD - Displays player health, mana, resonance, and interaction prompts
class_name HUD

# ============ REFERENCES ============
@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthBar
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaBar/ManaLabel
@onready var resonance_bar: ResonanceBar = $MarginContainer/VBoxContainer/ResonanceBar
@onready var interaction_prompt: Label = $InteractionPrompt

# ============ HEART TRACKING ============
var heart_textures: Array[TextureRect] = []
const HEARTS_COUNT: int = 5
const HP_PER_HEART: int = 20

# ============ PARRY INDICATOR ============
var parry_indicator: Label = null


func _ready() -> void:
	# Connect to EventBus signals
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.show_interaction_prompt.connect(_on_show_interaction_prompt)
	EventBus.hide_interaction_prompt.connect(_on_hide_interaction_prompt)
	EventBus.resonance_changed.connect(_on_resonance_changed)
	EventBus.resonance_mode_activated.connect(_on_resonance_mode_activated)
	EventBus.resonance_mode_deactivated.connect(_on_resonance_mode_deactivated)
	EventBus.resonance_mode_timer_updated.connect(_on_resonance_mode_timer_updated)

	# Connect parry signals
	EventBus.parry_window_opened.connect(_on_parry_window_opened)
	EventBus.parry_failed.connect(_on_parry_ended)
	EventBus.perfect_parry.connect(_on_parry_ended)

	# Create heart icons
	_create_hearts()

	# Create parry indicator
	_create_parry_indicator()

	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

	print("[HUD] Initialized")


# ============ HEART SYSTEM ============
func _create_hearts() -> void:
	"""Creates heart icons for health display"""
	if not health_container:
		return

	for i in range(HEARTS_COUNT):
		var heart: TextureRect = TextureRect.new()
		heart.custom_minimum_size = Vector2(32, 32)
		heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Create colored rect as placeholder
		var heart_rect: ColorRect = ColorRect.new()
		heart_rect.size = Vector2(32, 32)
		heart_rect.color = Color(1, 0, 0, 1)  # Red heart
		heart.add_child(heart_rect)

		health_container.add_child(heart)
		heart_textures.append(heart)


func _update_hearts(current_hp: int) -> void:
	"""Updates heart display based on current HP"""
	for i in range(HEARTS_COUNT):
		var heart_hp_threshold: int = (i + 1) * HP_PER_HEART

		if heart_textures[i].get_child_count() > 0:
			var heart_rect: ColorRect = heart_textures[i].get_child(0) as ColorRect

			if current_hp >= heart_hp_threshold:
				# Full heart
				heart_rect.color = Color(1, 0, 0, 1)
			elif current_hp > (i * HP_PER_HEART):
				# Half heart
				heart_rect.color = Color(1, 0.5, 0.5, 1)
			else:
				# Empty heart
				heart_rect.color = Color(0.3, 0.3, 0.3, 1)


# ============ PARRY INDICATOR ============
func _create_parry_indicator() -> void:
	"""Creates the JETZT! parry timing indicator"""
	parry_indicator = Label.new()
	parry_indicator.name = "ParryIndicator"
	parry_indicator.text = "JETZT!"
	parry_indicator.add_theme_font_size_override("font_size", 48)
	parry_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 1.0))  # Yellow
	parry_indicator.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	parry_indicator.add_theme_constant_override("outline_size", 4)

	# Center on screen
	parry_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parry_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parry_indicator.anchor_left = 0.5
	parry_indicator.anchor_right = 0.5
	parry_indicator.anchor_top = 0.3
	parry_indicator.anchor_bottom = 0.3
	parry_indicator.offset_left = -100
	parry_indicator.offset_right = 100
	parry_indicator.offset_top = -30
	parry_indicator.offset_bottom = 30

	# Start hidden
	parry_indicator.visible = false
	parry_indicator.modulate.a = 0.0

	add_child(parry_indicator)
	print("[HUD] Parry indicator created")


func _on_parry_window_opened() -> void:
	"""Shows JETZT! indicator when parry window opens"""
	if not parry_indicator:
		return

	print("[HUD] Showing JETZT! indicator")
	parry_indicator.visible = true

	# Fade in with scale animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(parry_indicator, "modulate:a", 1.0, 0.1)
	tween.tween_property(parry_indicator, "scale", Vector2(1.2, 1.2), 0.1)

	# Pulse animation
	tween.chain().tween_property(parry_indicator, "scale", Vector2(1.0, 1.0), 0.2)


func _on_parry_ended(_enemy: Node = null) -> void:
	"""Hides JETZT! indicator when parry window ends"""
	if not parry_indicator:
		return

	print("[HUD] Hiding JETZT! indicator")

	# Fade out
	var tween = create_tween()
	tween.tween_property(parry_indicator, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): parry_indicator.visible = false)


# ============ SIGNAL HANDLERS ============
func _on_player_hp_changed(new_hp: int, _max_hp: int) -> void:
	"""Updates health display"""
	_update_hearts(new_hp)


func _on_player_mana_changed(new_mana: int, max_mana: int) -> void:
	"""Updates mana bar"""
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = new_mana

	if mana_label:
		mana_label.text = str(new_mana) + "/" + str(max_mana)


func _on_show_interaction_prompt(text: String) -> void:
	"""Shows interaction prompt with text"""
	if interaction_prompt:
		interaction_prompt.text = text
		interaction_prompt.visible = true


func _on_hide_interaction_prompt() -> void:
	"""Hides interaction prompt"""
	if interaction_prompt:
		interaction_prompt.visible = false


func _on_resonance_changed(current: float, maximum: float, _percentage: float) -> void:
	"""Updates resonance bar"""
	if resonance_bar:
		resonance_bar.set_resonance(current, maximum)


func _on_resonance_mode_activated() -> void:
	"""Called when resonance mode activates."""
	if resonance_bar:
		resonance_bar.set_mode_active(true, 16.0)


func _on_resonance_mode_deactivated() -> void:
	"""Called when resonance mode deactivates."""
	if resonance_bar:
		resonance_bar.set_mode_active(false)


func _on_resonance_mode_timer_updated(time_remaining: float) -> void:
	"""Called when mode timer updates."""
	if resonance_bar:
		resonance_bar.update_mode_timer(time_remaining)
