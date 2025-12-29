extends Node
## Manages boss phases based on HP thresholds
class_name PhaseManager

signal phase_changed(old_phase: int, new_phase: int)
signal phase_transition_started(new_phase: int)
signal phase_transition_ended(new_phase: int)

@export var boss: CharacterBody2D
@export var phase_thresholds: Array[float] = [1.0, 0.6, 0.3]  # Phase 1: 100%, Phase 2: 60%, Phase 3: 30%

var current_phase: int = 1
var is_transitioning: bool = false


func _ready() -> void:
	# Wait for boss to be ready before connecting
	await get_tree().process_frame

	if boss and boss.has_node("HealthComponent"):
		var health_comp = boss.get_node("HealthComponent")
		health_comp.health_changed.connect(_on_boss_health_changed)


func _on_boss_health_changed(current_hp: float, max_hp: float) -> void:
	if is_transitioning:
		return

	var hp_percent = current_hp / max_hp
	var target_phase = get_phase_for_hp(hp_percent)

	if target_phase != current_phase:
		start_phase_transition(target_phase)


func get_phase_for_hp(hp_percent: float) -> int:
	"""Determines which phase based on HP percentage"""
	for i in range(phase_thresholds.size() - 1, -1, -1):
		if hp_percent <= phase_thresholds[i]:
			return i + 1
	return 1


func start_phase_transition(new_phase: int) -> void:
	"""Starts the transition to a new phase"""
	is_transitioning = true
	phase_transition_started.emit(new_phase)

	# Boss becomes invulnerable during transition
	if boss.has_method("set_invulnerable"):
		boss.set_invulnerable(true)

	# Play transition animation
	await play_transition_animation(new_phase)

	# Change phase
	var old_phase = current_phase
	current_phase = new_phase

	# Boss becomes vulnerable again
	if boss.has_method("set_invulnerable"):
		boss.set_invulnerable(false)

	is_transitioning = false

	phase_changed.emit(old_phase, new_phase)
	phase_transition_ended.emit(new_phase)


func play_transition_animation(new_phase: int) -> void:
	"""Plays the phase transition animation"""
	# Boss plays transformation animation
	if boss.has_method("play_phase_transition"):
		await boss.play_phase_transition(new_phase)
	else:
		# Default transition: brief pause
		await get_tree().create_timer(1.0).timeout


func is_in_final_phase() -> bool:
	"""Returns true if boss is in the final phase"""
	return current_phase == phase_thresholds.size()


func force_phase(phase: int) -> void:
	"""Manually forces a phase change (for testing/debug)"""
	if phase != current_phase and phase > 0 and phase <= phase_thresholds.size():
		start_phase_transition(phase)
