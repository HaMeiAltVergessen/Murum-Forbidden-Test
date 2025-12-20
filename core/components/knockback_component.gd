extends Node
## KnockbackComponent - Handles knockback physics for characters
class_name KnockbackComponent

# ============================================================================
# STATE
# ============================================================================

var is_being_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_duration: float = 0.0
var knockback_timer: float = 0.0

# ============================================================================
# SIGNALS
# ============================================================================

signal knockback_started(direction: Vector2, force: float)
signal knockback_ended

# ============================================================================
# KNOCKBACK APPLICATION
# ============================================================================

func apply_knockback(direction: Vector2, force: float, duration: float = 0.3) -> void:
	"""Applies knockback in direction with force"""

	print("[KnockbackComponent] Knockback: %v @ %.0f" % [direction, force])

	is_being_knocked_back = true
	knockback_velocity = direction.normalized() * force
	knockback_duration = duration
	knockback_timer = 0.0

	# Emit signal
	knockback_started.emit(direction, force)

# ============================================================================
# PHYSICS UPDATE
# ============================================================================

func _physics_process(delta: float) -> void:
	if not is_being_knocked_back:
		return

	knockback_timer += delta

	# Decay knockback over time (exponential)
	var progress = knockback_timer / knockback_duration
	var decay_factor = 1.0 - progress

	# Apply to parent (CharacterBody2D)
	var parent = owner as CharacterBody2D
	if parent:
		parent.velocity = knockback_velocity * decay_factor
		parent.move_and_slide()

	# Check completion
	if knockback_timer >= knockback_duration:
		_end_knockback()

func _end_knockback() -> void:
	"""Ends knockback state"""
	is_being_knocked_back = false
	knockback_velocity = Vector2.ZERO

	# Reset parent velocity
	var parent = owner as CharacterBody2D
	if parent:
		parent.velocity = Vector2.ZERO

	# Emit signal
	knockback_ended.emit()

	print("[KnockbackComponent] Knockback ended")

# ============================================================================
# UTILITY
# ============================================================================

func is_knocked_back() -> bool:
	"""Returns true if currently being knocked back"""
	return is_being_knocked_back

func cancel_knockback() -> void:
	"""Cancels current knockback"""
	if is_being_knocked_back:
		_end_knockback()
