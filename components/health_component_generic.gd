extends Node
## Generic HealthComponent for entities (bosses, enemies, NPCs)
class_name HealthComponentGeneric

# ============ CONFIGURATION ============
@export var max_hp: float = 100.0
@export var invulnerability_duration: float = 0.0  # 0 = no iframes

# ============ STATE ============
var current_hp: float
var is_invulnerable: bool = false

# ============ SIGNALS ============
signal health_changed(current_hp: float, max_hp: float)
signal damage_taken(damage: float)
signal died()
signal invulnerability_changed(is_invulnerable: bool)


func _ready() -> void:
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


# ============ HEALTH MANAGEMENT ============
func take_damage(damage: float) -> bool:
	"""
	Applies damage to health. Returns true if damage was applied.
	"""
	if is_invulnerable or current_hp <= 0:
		return false

	current_hp = max(0, current_hp - damage)

	# Emit signals
	damage_taken.emit(damage)
	health_changed.emit(current_hp, max_hp)

	# Start invulnerability if configured
	if invulnerability_duration > 0.0 and current_hp > 0:
		start_invulnerability(invulnerability_duration)

	# Check if dead
	if current_hp <= 0:
		died.emit()

	return true


func heal(amount: float) -> void:
	"""Restores health by the given amount"""
	if current_hp >= max_hp:
		return

	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


func reset_health() -> void:
	"""Resets health to maximum"""
	current_hp = max_hp
	is_invulnerable = false
	health_changed.emit(current_hp, max_hp)


# ============ INVULNERABILITY ============
func set_invulnerable(value: bool) -> void:
	"""Manually set invulnerability state"""
	if is_invulnerable != value:
		is_invulnerable = value
		invulnerability_changed.emit(is_invulnerable)


func start_invulnerability(duration: float) -> void:
	"""Starts the invulnerability period for a specific duration"""
	is_invulnerable = true
	invulnerability_changed.emit(true)

	await get_tree().create_timer(duration).timeout

	is_invulnerable = false
	invulnerability_changed.emit(false)


# ============ GETTERS ============
func get_health_percentage() -> float:
	"""Returns current health as a percentage (0.0 to 1.0)"""
	return current_hp / max_hp


func is_alive() -> bool:
	"""Returns true if entity has health remaining"""
	return current_hp > 0
