extends PuzzleSwitch
class_name TimedSwitch

## Switch for timed door puzzle - can be activated multiple times
## Godot 4.4 compatible

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Allow multiple activations
	can_deactivate = true

	super._ready()

	print("[TimedSwitch] %s initialized" % name)

# ============================================================================
# ACTIVATION OVERRIDE
# ============================================================================

func activate() -> void:
	"""Activates the switch (can be reactivated)"""
	# Always allow activation (even if already activated)
	var was_activated = is_activated
	is_activated = true

	switch_activated.emit(switch_id)

	# Visual feedback
	if visual_feedback:
		_play_activation_visual()

	# Audio feedback
	if AudioManager and activation_sound != "":
		AudioManager.play_sfx(activation_sound)

	print("[TimedSwitch] %s activated (ID: %d)" % [name, switch_id])

	# Auto-deactivate after short delay
	_auto_deactivate()

# ============================================================================
# AUTO-DEACTIVATION
# ============================================================================

func _auto_deactivate() -> void:
	"""Automatically deactivates after 0.5 seconds"""
	await get_tree().create_timer(0.5).timeout
	deactivate()
