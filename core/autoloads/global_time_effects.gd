extends Node
## GlobalTimeEffects - Handles global time manipulation (slow-mo, hitstop)
## Singleton for managing time scale effects across the game

# ============================================================================
# HITSTOP
# ============================================================================

func hit_stop(duration: float) -> void:
	"""Freezes game for duration (hitstop)"""
	Engine.time_scale = 0.0

	# Use real-time timer (unaffected by time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout

	Engine.time_scale = 1.0


# ============================================================================
# SLOW MOTION
# ============================================================================

var slow_motion_active: bool = false

func slow_motion(scale: float, duration: float) -> void:
	"""Sets time scale for duration"""
	if slow_motion_active:
		return  # Don't stack

	slow_motion_active = true
	Engine.time_scale = scale

	# Wait duration (real time)
	await get_tree().create_timer(duration, true, false, true).timeout

	Engine.time_scale = 1.0
	slow_motion_active = false

	print("[GlobalTimeEffects] Slow motion ended, time restored to 1.0")


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
