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

# ============ ABILITY ICONS ============
var ability_icons_container: HBoxContainer = null
var machtstoss_icon: AbilityIcon = null
var urteil_icon: AbilityIcon = null
var echo_icon: AbilityIcon = null

# ============ URGATHON'S WILL ============
var urgathon_charge_bar: ProgressBar = null
var urgathon_counter: Label = null
var urgathon_blackscreen: ColorRect = null


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

	# Connect ability cooldown signals
	EventBus.machtstoss_cooldown_started.connect(_on_machtstoss_cooldown_started)
	EventBus.machtstoss_cooldown_finished.connect(_on_machtstoss_cooldown_finished)
	EventBus.urteil_cooldown_started.connect(_on_urteil_cooldown_started)
	EventBus.urteil_cooldown_finished.connect(_on_urteil_cooldown_finished)
	EventBus.echo_cooldown_started.connect(_on_echo_cooldown_started)
	EventBus.echo_cooldown_finished.connect(_on_echo_cooldown_finished)

	# Create heart icons
	_create_hearts()

	# Create ability icons
	_create_ability_icons()

	# Create Urgathon UI
	_create_urgathon_ui()

	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

	# Add to hud group
	add_to_group("hud")

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


# ============ ABILITY ICONS SYSTEM ============
func _create_ability_icons() -> void:
	"""Creates ability icons container and icons"""

	# Create container (bottom right of screen)
	ability_icons_container = HBoxContainer.new()
	ability_icons_container.name = "AbilityIconsContainer"
	ability_icons_container.add_theme_constant_override("separation", 8)

	# Position at bottom right
	ability_icons_container.anchor_left = 1.0
	ability_icons_container.anchor_right = 1.0
	ability_icons_container.anchor_top = 1.0
	ability_icons_container.anchor_bottom = 1.0
	ability_icons_container.offset_left = -220  # 3 icons * 64 + 2 gaps * 8 + margin
	ability_icons_container.offset_right = -10
	ability_icons_container.offset_top = -74
	ability_icons_container.offset_bottom = -10

	add_child(ability_icons_container)

	# Create icons
	machtstoss_icon = AbilityIcon.new()
	machtstoss_icon.ability_name = "Machtstoß"
	machtstoss_icon.keybind = "1"
	ability_icons_container.add_child(machtstoss_icon)

	urteil_icon = AbilityIcon.new()
	urteil_icon.ability_name = "Urteil"
	urteil_icon.keybind = "2"
	ability_icons_container.add_child(urteil_icon)

	echo_icon = AbilityIcon.new()
	echo_icon.ability_name = "Echo"
	echo_icon.keybind = "3"
	ability_icons_container.add_child(echo_icon)

	print("[HUD] Ability icons created")


# ============ ABILITY COOLDOWN HANDLERS ============
func _on_machtstoss_cooldown_started(duration: float) -> void:
	if machtstoss_icon:
		machtstoss_icon.start_cooldown(duration)


func _on_machtstoss_cooldown_finished() -> void:
	# Icon handles this automatically via timer
	pass


func _on_urteil_cooldown_started(duration: float) -> void:
	if urteil_icon:
		urteil_icon.start_cooldown(duration)


func _on_urteil_cooldown_finished() -> void:
	# Icon handles this automatically via timer
	pass


func _on_echo_cooldown_started(duration: float) -> void:
	if echo_icon:
		echo_icon.start_cooldown(duration)


func _on_echo_cooldown_finished() -> void:
	# Icon handles this automatically via timer
	pass


# ============ URGATHON'S WILL UI ============
func _create_urgathon_ui() -> void:
	"""Creates Urgathon's Will UI elements (charge bar and use counter)"""

	# Create charge bar (center-bottom)
	urgathon_charge_bar = ProgressBar.new()
	urgathon_charge_bar.name = "UrgathonChargeBar"
	urgathon_charge_bar.custom_minimum_size = Vector2(300, 30)
	urgathon_charge_bar.max_value = 100
	urgathon_charge_bar.value = 0
	urgathon_charge_bar.show_percentage = false
	urgathon_charge_bar.visible = false

	# Position center-bottom
	urgathon_charge_bar.anchor_left = 0.5
	urgathon_charge_bar.anchor_right = 0.5
	urgathon_charge_bar.anchor_top = 1.0
	urgathon_charge_bar.anchor_bottom = 1.0
	urgathon_charge_bar.offset_left = -150  # Half of width
	urgathon_charge_bar.offset_right = 150
	urgathon_charge_bar.offset_top = -50
	urgathon_charge_bar.offset_bottom = -20

	# Style charge bar (purple gradient)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.5, 0.0, 0.8, 0.8)  # Purple
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.8, 0.4, 1.0, 1.0)  # Light purple border
	urgathon_charge_bar.add_theme_stylebox_override("fill", stylebox)

	add_child(urgathon_charge_bar)

	# Create use counter (top-left)
	urgathon_counter = Label.new()
	urgathon_counter.name = "UrgathonCounter"
	urgathon_counter.text = "Urgathon Uses: 0/4"
	urgathon_counter.add_theme_font_size_override("font_size", 16)
	urgathon_counter.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))  # Purple

	# Position top-left
	urgathon_counter.anchor_left = 0.0
	urgathon_counter.anchor_top = 0.0
	urgathon_counter.offset_left = 10
	urgathon_counter.offset_top = 120  # Below other UI

	add_child(urgathon_counter)

	# Create black screen overlay (fullscreen)
	urgathon_blackscreen = ColorRect.new()
	urgathon_blackscreen.name = "UrgathonBlackscreen"
	urgathon_blackscreen.color = Color(0, 0, 0, 0)  # Transparent initially
	urgathon_blackscreen.visible = false
	urgathon_blackscreen.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input when invisible

	# Fullscreen
	urgathon_blackscreen.anchor_left = 0.0
	urgathon_blackscreen.anchor_right = 1.0
	urgathon_blackscreen.anchor_top = 0.0
	urgathon_blackscreen.anchor_bottom = 1.0

	# Add as first child so it's on top of everything
	add_child(urgathon_blackscreen)
	move_child(urgathon_blackscreen, 0)  # Move to back initially

	print("[HUD] Urgathon UI created")
