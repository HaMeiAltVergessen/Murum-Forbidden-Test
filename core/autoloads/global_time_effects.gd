extends Node
## GlobalTimeEffects - Handles global time manipulation (slow-mo, hitstop)
## Singleton for managing time scale effects across the game

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

var hitstop_active: bool = false
var slow_motion_active: bool = false
var slow_motion_scale: float = 1.0


# ============================================================================
# HITSTOP
# ============================================================================

func hit_stop(duration: float) -> void:
	"""Freezes game for duration (hitstop) - Has priority over slow motion"""
	hitstop_active = true
	_update_time_scale()

	# Use real-time timer (unaffected by time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout

	hitstop_active = false
	_update_time_scale()

	print("[GlobalTimeEffects] Hitstop ended, time scale: %.2f" % Engine.time_scale)


# ============================================================================
# SLOW MOTION
# ============================================================================

func slow_motion(scale: float, duration: float) -> void:
	"""Sets time scale for duration - Paused during hitstop"""
	if slow_motion_active:
		return  # Don't stack

	slow_motion_active = true
	slow_motion_scale = scale
	_update_time_scale()

	# Wait duration (real time)
	await get_tree().create_timer(duration, true, false, true).timeout

	slow_motion_active = false
	slow_motion_scale = 1.0
	_update_time_scale()

	print("[GlobalTimeEffects] Slow motion ended, time scale: %.2f" % Engine.time_scale)


# ============================================================================
# PRIORITY SYSTEM
# ============================================================================

func _update_time_scale() -> void:
	"""Updates Engine.time_scale based on active effects (hitstop > slow motion > normal)"""
	if hitstop_active:
		# Hitstop has highest priority
		Engine.time_scale = 0.0
	elif slow_motion_active:
		# Slow motion active
		Engine.time_scale = slow_motion_scale
	else:
		# Normal time
		Engine.time_scale = 1.0


# ============================================================================
# UTILITY
# ============================================================================

func get_current_time_scale() -> float:
	"""Returns current time scale"""
	return Engine.time_scale


func is_slowed() -> bool:
	"""Returns true if slow motion is active"""
	return slow_motion_active


func _ready() -> void:
	print("[GlobalTimeEffects] Initialized")
