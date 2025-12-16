extends Node
## HealthComponent manages entity health and damage reception
class_name HealthComponent

# ============ CONFIGURATION ============
@export var max_health: int = 100
@export var invulnerability_duration: float = 0.5

# ============ STATE ============
var current_health: int
var is_invulnerable: bool = false
var invulnerability_timer: Timer

# ============ SIGNALS ============
signal health_changed(new_health: int, max_health: int)
signal damage_taken(damage: int)
signal health_depleted()
signal invulnerability_started()
signal invulnerability_ended()


func _ready() -> void:
	current_health = max_health

	# Create invulnerability timer
	invulnerability_timer = Timer.new()
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(invulnerability_timer)

	# Emit initial health
	health_changed.emit(current_health, max_health)


# ============ HEALTH MANAGEMENT ============
func take_damage(damage: int) -> bool:
	"""
	Applies damage to health. Returns true if damage was applied.
	"""
	if is_invulnerable or current_health <= 0:
		return false

	current_health = max(0, current_health - damage)

	# Emit signals
	damage_taken.emit(damage)
	health_changed.emit(current_health, max_health)

	# Start invulnerability
	if invulnerability_duration > 0.0:
		start_invulnerability()

	# Check if health depleted
	if current_health <= 0:
		health_depleted.emit()

	return true


func heal(amount: int) -> void:
	"""Restores health by the given amount"""
	if current_health >= max_health:
		return

	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func reset_health() -> void:
	"""Resets health to maximum"""
	current_health = max_health
	is_invulnerable = false
	if invulnerability_timer.time_left > 0:
		invulnerability_timer.stop()
	health_changed.emit(current_health, max_health)


# ============ INVULNERABILITY ============
func start_invulnerability() -> void:
	"""Starts the invulnerability period"""
	is_invulnerable = true
	invulnerability_timer.start(invulnerability_duration)
	invulnerability_started.emit()


func _on_invulnerability_timeout() -> void:
	"""Called when invulnerability period ends"""
	is_invulnerable = false
	invulnerability_ended.emit()


# ============ GETTERS ============
func get_health_percentage() -> float:
	"""Returns current health as a percentage (0.0 to 1.0)"""
	return float(current_health) / float(max_health)


func is_alive() -> bool:
	"""Returns true if entity has health remaining"""
	return current_health > 0
