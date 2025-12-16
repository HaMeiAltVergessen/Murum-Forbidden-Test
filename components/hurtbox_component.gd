extends Area2D
## HurtboxComponent handles damage reception and invulnerability
class_name HurtboxComponent

# ============ CONFIGURATION ============
@export var invulnerability_duration: float = 0.5

# ============ STATE ============
var is_invulnerable: bool = false
var invulnerability_timer: Timer

# ============ SIGNALS ============
signal damage_received(damage: int, knockback: Vector2, hitstun: float)
signal invulnerability_started()
signal invulnerability_ended()


func _ready() -> void:
	# Create invulnerability timer
	invulnerability_timer = Timer.new()
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(invulnerability_timer)

	# Always active for receiving hits
	monitoring = false
	monitorable = true


# ============ DAMAGE RECEPTION ============
func take_damage(damage: int, knockback: Vector2, hitstun: float) -> bool:
	"""
	Receives damage from a hitbox.
	Returns true if damage was applied.
	"""
	if is_invulnerable:
		return false

	# Emit damage signal
	damage_received.emit(damage, knockback, hitstun)

	# Apply damage to parent's HealthComponent if it exists
	var parent: Node = get_parent()
	if parent.has_node("HealthComponent"):
		var health_comp: HealthComponent = parent.get_node("HealthComponent")
		health_comp.take_damage(damage)

	# Start invulnerability
	if invulnerability_duration > 0:
		_start_invulnerability()

	return true


# ============ INVULNERABILITY ============
func _start_invulnerability() -> void:
	"""Starts invulnerability period"""
	is_invulnerable = true
	invulnerability_timer.start(invulnerability_duration)
	invulnerability_started.emit()


func _on_invulnerability_timeout() -> void:
	"""Called when invulnerability ends"""
	is_invulnerable = false
	invulnerability_ended.emit()


func force_end_invulnerability() -> void:
	"""Immediately ends invulnerability"""
	is_invulnerable = false
	if invulnerability_timer.time_left > 0:
		invulnerability_timer.stop()
	invulnerability_ended.emit()


# ============ GETTERS ============
func get_is_invulnerable() -> bool:
	"""Returns invulnerability state"""
	return is_invulnerable
