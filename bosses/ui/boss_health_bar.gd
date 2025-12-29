extends CanvasLayer
## Boss health bar UI displayed during boss fights
class_name BossHealthBar

@onready var name_label: Label = $MarginContainer/VBoxContainer/BossNameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var hp_text: Label = $MarginContainer/VBoxContainer/HealthBar/HPLabel
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel

var boss_name: String = "Boss"
var max_health: float = 1000.0


func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	visible = true


func setup(boss_name_text: String, max_hp: float) -> void:
	"""Sets up the boss health bar with initial values"""
	boss_name = boss_name_text
	max_health = max_hp

	if name_label:
		name_label.text = boss_name
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = max_hp
	if hp_text:
		hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]


func show_bar() -> void:
	"""Fades in the boss health bar"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func hide_bar() -> void:
	"""Fades out the boss health bar"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)


func update_health(current_hp: float, max_hp: float) -> void:
	"""Updates the health bar display"""
	if hp_bar:
		hp_bar.value = current_hp

	if hp_text:
		hp_text.text = "%d / %d" % [int(current_hp), int(max_hp)]

	# Change color based on HP percentage
	if hp_bar:
		var hp_percent = current_hp / max_hp
		if hp_percent < 0.3:
			hp_bar.modulate = Color.RED
		elif hp_percent < 0.6:
			hp_bar.modulate = Color.ORANGE
		else:
			hp_bar.modulate = Color.GREEN_YELLOW


func update_phase(phase: int) -> void:
	"""Updates the phase indicator"""
	if phase_label:
		phase_label.text = "Phase %d" % phase
