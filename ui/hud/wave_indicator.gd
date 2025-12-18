extends Control
class_name WaveIndicator

## Displays current wave and remaining enemies

# ============================================================================
# REFERENCES
# ============================================================================

@onready var wave_label: Label = $VBoxContainer/WaveLabel
@onready var enemies_label: Label = $VBoxContainer/EnemiesLabel
@onready var background: Panel = $Background

# ============================================================================
# STATE
# ============================================================================

var current_wave: int = 0
var total_waves: int = 0
var remaining_enemies: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to EventBus
	EventBus.wave_spawner_started.connect(_on_wave_spawner_started)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.all_waves_completed.connect(_on_all_waves_completed)
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Start hidden
	visible = false

# ============================================================================
# WAVE EVENTS
# ============================================================================

func _on_wave_spawner_started() -> void:
	"""Called when wave spawner starts"""
	visible = true
	_animate_show()

func _on_wave_started(wave_index: int, total: int) -> void:
	"""Called when new wave starts"""
	current_wave = wave_index + 1  # 1-indexed for display
	total_waves = total

	_update_display()
	_animate_wave_start()

func _on_wave_completed(wave_index: int, total: int) -> void:
	"""Called when wave is cleared"""
	_animate_wave_complete()

func _on_all_waves_completed() -> void:
	"""Called when all waves cleared"""
	await get_tree().create_timer(2.0).timeout
	_animate_hide()

func _on_enemy_killed(_enemy: Node, _killer: Node) -> void:
	"""Called when enemy killed"""
	# Update remaining count
	# Note: WaveSpawner tracks this, we just display
	_update_display()

# ============================================================================
# DISPLAY
# ============================================================================

func _update_display() -> void:
	"""Updates UI text"""
	if wave_label:
		wave_label.text = "Wave %d/%d" % [current_wave, total_waves]

	if enemies_label:
		# Get count from active WaveSpawner
		var spawner = _find_active_spawner()
		if spawner:
			remaining_enemies = spawner.get_remaining_enemies()
			enemies_label.text = "Enemies: %d" % remaining_enemies
		else:
			enemies_label.text = "Enemies: ?"

func _find_active_spawner() -> WaveSpawner:
	"""Finds active WaveSpawner in scene"""
	var spawners = get_tree().get_nodes_in_group("wave_spawners")

	for spawner in spawners:
		if spawner is WaveSpawner and spawner.is_waves_active():
			return spawner

	return null

# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_show() -> void:
	"""Animates indicator appearance"""
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func _animate_hide() -> void:
	"""Animates indicator disappearance"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	visible = false

func _animate_wave_start() -> void:
	"""Animates wave start"""
	if not background:
		return

	var tween = create_tween()
	tween.tween_property(background, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	tween.tween_property(background, "modulate", Color.WHITE, 0.3)

func _animate_wave_complete() -> void:
	"""Animates wave completion"""
	if not background:
		return

	var tween = create_tween()
	tween.tween_property(background, "modulate", Color(0.5, 1.5, 0.5), 0.2)
	tween.tween_property(background, "modulate", Color.WHITE, 0.5)
