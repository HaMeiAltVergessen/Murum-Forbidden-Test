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

	# Connect parry signals (spatial system - no window indicator needed)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.normal_block_executed.connect(_on_normal_block)

	# Create heart icons
	_create_hearts()

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


# ============ PARRY/BLOCK FEEDBACK ============
func _on_perfect_parry(_enemy: Node) -> void:
	"""Shows brief flash for perfect parry"""
	# Screen flash for perfect parry (yellow)
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 0.3, 0.3)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

	print("[HUD] Perfect parry flash!")


func _on_normal_block(_enemy: Node) -> void:
	"""Shows brief flash for normal block"""
	# Screen flash for block (blue, less intense)
	var flash = ColorRect.new()
	flash.color = Color(0.3, 0.5, 1.0, 0.2)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

	print("[HUD] Normal block flash!")


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
