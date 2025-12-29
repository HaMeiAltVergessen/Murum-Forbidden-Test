extends Node
## Manages boss attack patterns and rotation
class_name AttackPatternManager

signal attack_started(attack_name: String)
signal attack_ended(attack_name: String)
signal pattern_changed(new_pattern: Array)

@export var boss: CharacterBody2D
@export var attack_cooldown: float = 2.0  # Time between attacks
@export var auto_start: bool = false  # Auto-start attacking when ready

var current_pattern: Array[String] = []
var current_attack_index: int = 0
var is_attacking: bool = false
var is_active: bool = false
var cooldown_timer: float = 0.0


func _ready() -> void:
	if auto_start:
		await get_tree().create_timer(1.0).timeout
		activate()


func _process(delta: float) -> void:
	if not is_active or is_attacking or current_pattern.is_empty():
		return

	cooldown_timer -= delta
	if cooldown_timer <= 0:
		execute_next_attack()


func activate() -> void:
	"""Activates the attack pattern manager"""
	is_active = true
	cooldown_timer = attack_cooldown


func deactivate() -> void:
	"""Deactivates the attack pattern manager"""
	is_active = false
	interrupt_attack()


func set_pattern(pattern: Array[String]) -> void:
	"""Sets the current attack pattern"""
	current_pattern = pattern
	current_attack_index = 0
	pattern_changed.emit(pattern)
	print("[AttackPatternManager] Pattern set: ", pattern)


func execute_next_attack() -> void:
	"""Executes the next attack in the pattern"""
	if current_pattern.is_empty():
		return

	is_attacking = true

	var attack_name = current_pattern[current_attack_index]
	attack_started.emit(attack_name)
	print("[AttackPatternManager] Executing attack: ", attack_name)

	# Boss executes the attack
	if boss and boss.has_method("execute_attack"):
		await boss.execute_attack(attack_name)
	else:
		# Fallback if boss doesn't have execute_attack method
		await get_tree().create_timer(1.0).timeout

	attack_ended.emit(attack_name)
	is_attacking = false

	# Move to next attack in pattern
	current_attack_index = (current_attack_index + 1) % current_pattern.size()

	# Start cooldown
	cooldown_timer = attack_cooldown


func interrupt_attack() -> void:
	"""Interrupts the current attack and resets cooldown"""
	is_attacking = false
	cooldown_timer = attack_cooldown * 0.5


func set_attack_speed(speed_multiplier: float) -> void:
	"""Modifies attack speed by changing cooldown"""
	attack_cooldown = attack_cooldown / speed_multiplier
	print("[AttackPatternManager] Attack speed multiplier: ", speed_multiplier)


func skip_to_attack(attack_name: String) -> void:
	"""Skips to a specific attack in the pattern"""
	var index = current_pattern.find(attack_name)
	if index != -1:
		current_attack_index = index
		print("[AttackPatternManager] Skipped to attack: ", attack_name)
