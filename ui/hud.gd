extends CanvasLayer
## HUD - Displays player mana, resonance, and interaction prompts
class_name HUD

# ============ REFERENCES ============
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaBar/ManaLabel
@onready var resonance_bar: ResonanceBar = $MarginContainer/VBoxContainer/ResonanceBar
@onready var interaction_prompt: Label = $InteractionPrompt


func _ready() -> void:
	# Connect to EventBus signals
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.show_interaction_prompt.connect(_on_show_interaction_prompt)
	EventBus.hide_interaction_prompt.connect(_on_hide_interaction_prompt)
	EventBus.resonance_changed.connect(_on_resonance_changed)
	EventBus.resonance_mode_activated.connect(_on_resonance_mode_activated)
	EventBus.resonance_mode_deactivated.connect(_on_resonance_mode_deactivated)
	EventBus.resonance_mode_timer_updated.connect(_on_resonance_mode_timer_updated)

	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

	print("[HUD] Initialized")


# ============ SIGNAL HANDLERS ============


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
