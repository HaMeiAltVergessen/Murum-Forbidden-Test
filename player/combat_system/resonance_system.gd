extends Node
## ResonanceSystem - Manages player resonance buildup and decay
## Resonance builds through combat and enables special abilities
class_name ResonanceSystem

# ============ CONFIGURATION ============
@export var enabled: bool = true
@export var max_resonance: float = 100.0
@export var gain_per_hit: float = 6.25  # +6.25 per enemy hit
@export var loss_on_damage: float = 15.0  # -15.0 when player takes damage
@export var decay_rate_idle: float = 4.0  # 4.0 per second when out of combat
@export var decay_rate_combat: float = 1.0  # 1.0 per second when in combat
@export var combat_timeout: float = 3.0  # Time before considered out of combat

# ============ MODE CONFIGURATION ============
@export var mode_duration: float = 16.0  # 16 seconds duration

# ============ STATE ============
var current_resonance: float = 0.0
var is_in_combat: bool = false
var last_combat_time: float = 0.0

# ============ MODE STATE ============
var is_active: bool = false  # Mode active flag
var mode_time_remaining: float = 0.0  # Countdown timer
var aura_effect: GPUParticles2D = null  # VFX reference
var glow_tween: Tween = null  # Sprite glow tween

# ============ MODE BONI ============
const DAMAGE_BONUS: float = 1.25  # +25% damage
const SPEED_BONUS: float = 1.15  # +15% speed
const MANA_COST_REDUCTION: float = 0.5  # -50% mana cost

# ============ SIGNALS ============
signal resonance_changed(current: float, maximum: float, percentage: float)
signal resonance_full()
signal resonance_depleted()
signal resonance_threshold_reached(threshold: int)  # 25, 50, 75, 100

# ============ THRESHOLDS ============
const THRESHOLDS: Array[int] = [25, 50, 75, 100]
var threshold_flags: Dictionary = {
	25: false,
	50: false,
	75: false,
	100: false
}


func _ready() -> void:
	if not enabled:
		return

	# Connect to EventBus signals
	if EventBus:
		EventBus.hit_registered.connect(_on_hit_registered)
		EventBus.player_damaged.connect(_on_player_damaged)
		EventBus.combat_started.connect(_on_combat_started)
		EventBus.combat_ended.connect(_on_combat_ended)

	print("[ResonanceSystem] Initialized - Max: %.1f" % max_resonance)


func _process(delta: float) -> void:
	if not enabled:
		return

	# Mode countdown (takes priority)
	if is_active:
		mode_time_remaining -= delta

		# Update HUD countdown
		EventBus.resonance_mode_timer_updated.emit(mode_time_remaining)

		# Check if mode expired
		if mode_time_remaining <= 0.0:
			deactivate_mode()

		# No decay during mode
		return

	# Normal resonance decay
	_apply_decay(delta)

	# Update combat state
	_update_combat_state(delta)


# ============ RESONANCE MANAGEMENT ============
func add_resonance(amount: float) -> void:
	"""Adds resonance and clamps to max."""
	if not enabled:
		return

	# Block during active mode
	if is_active:
		return

	var old_value: float = current_resonance
	current_resonance = min(current_resonance + amount, max_resonance)

	# Check thresholds
	_check_thresholds(old_value, current_resonance)

	# Emit signals
	_emit_resonance_changed()

	# Check if full and auto-activate mode
	if current_resonance >= max_resonance and old_value < max_resonance:
		resonance_full.emit()
		print("[ResonanceSystem] RESONANCE FULL!")
		activate_mode()  # Auto-activate

	print("[ResonanceSystem] +%.2f resonance (%.1f/%.1f)" % [amount, current_resonance, max_resonance])


func remove_resonance(amount: float) -> void:
	"""Removes resonance and clamps to 0."""
	if not enabled:
		return

	var old_value: float = current_resonance
	current_resonance = max(current_resonance - amount, 0.0)

	# Reset threshold flags if we dropped below them
	_reset_thresholds_below(current_resonance)

	# Emit signals
	_emit_resonance_changed()

	# Check if depleted
	if current_resonance <= 0.0 and old_value > 0.0:
		resonance_depleted.emit()
		print("[ResonanceSystem] Resonance depleted")

	print("[ResonanceSystem] -%.2f resonance (%.1f/%.1f)" % [amount, current_resonance, max_resonance])


func set_resonance(amount: float) -> void:
	"""Sets resonance to a specific value."""
	var old_value: float = current_resonance
	current_resonance = clamp(amount, 0.0, max_resonance)

	# Check thresholds
	_check_thresholds(old_value, current_resonance)

	# Emit signals
	_emit_resonance_changed()


func reset_resonance() -> void:
	"""Resets resonance to 0."""
	current_resonance = 0.0
	_reset_all_thresholds()
	_emit_resonance_changed()
	print("[ResonanceSystem] Resonance reset")


# ============ DECAY SYSTEM ============
func _apply_decay(delta: float) -> void:
	"""Applies resonance decay based on combat state."""
	if current_resonance <= 0.0:
		return

	var decay_amount: float = 0.0

	if is_in_combat:
		decay_amount = decay_rate_combat * delta
	else:
		decay_amount = decay_rate_idle * delta

	if decay_amount > 0.0:
		remove_resonance(decay_amount)


# ============ COMBAT STATE ============
func _update_combat_state(delta: float) -> void:
	"""Updates combat state based on time since last action."""
	if not is_in_combat:
		return

	last_combat_time += delta

	if last_combat_time >= combat_timeout:
		_exit_combat()


func _enter_combat() -> void:
	"""Enters combat state."""
	if is_in_combat:
		return

	is_in_combat = true
	last_combat_time = 0.0
	print("[ResonanceSystem] Entered combat")


func _exit_combat() -> void:
	"""Exits combat state."""
	if not is_in_combat:
		return

	is_in_combat = false
	last_combat_time = 0.0
	print("[ResonanceSystem] Exited combat")


func _refresh_combat() -> void:
	"""Refreshes combat timer."""
	last_combat_time = 0.0
	if not is_in_combat:
		_enter_combat()


# ============ THRESHOLDS ============
func _check_thresholds(old_value: float, new_value: float) -> void:
	"""Checks if any thresholds were crossed."""
	for threshold in THRESHOLDS:
		if old_value < threshold and new_value >= threshold:
			if not threshold_flags[threshold]:
				threshold_flags[threshold] = true
				resonance_threshold_reached.emit(threshold)
				print("[ResonanceSystem] Threshold reached: %d%%" % threshold)


func _reset_thresholds_below(value: float) -> void:
	"""Resets threshold flags below the given value."""
	for threshold in THRESHOLDS:
		if value < threshold:
			threshold_flags[threshold] = false


func _reset_all_thresholds() -> void:
	"""Resets all threshold flags."""
	for threshold in THRESHOLDS:
		threshold_flags[threshold] = false


# ============ SIGNAL EMITTERS ============
func _emit_resonance_changed() -> void:
	"""Emits resonance_changed signal."""
	var percentage: float = (current_resonance / max_resonance) * 100.0
	resonance_changed.emit(current_resonance, max_resonance, percentage)

	# Also emit to EventBus for HUD
	EventBus.resonance_changed.emit(current_resonance, max_resonance, percentage)


# ============ EVENT HANDLERS ============
func _on_hit_registered(attacker: Node, _target: Node, _damage: int) -> void:
	"""Called when any hit is registered."""
	# Only gain resonance for player attacks
	if attacker and attacker.is_in_group("player"):
		add_resonance(gain_per_hit)
		_refresh_combat()


func _on_player_damaged(_damage: int, _source: Node) -> void:
	"""Called when player takes damage."""
	remove_resonance(loss_on_damage)
	_refresh_combat()


func _on_combat_started() -> void:
	"""Called when combat starts globally."""
	_enter_combat()


func _on_combat_ended() -> void:
	"""Called when combat ends globally."""
	_exit_combat()


# ============ MODE ACTIVATION ============
func activate_mode() -> void:
	"""Activates Resonance Mode."""
	if is_active:
		return

	print("[ResonanceSystem] Activating Resonance Mode")

	is_active = true
	mode_time_remaining = mode_duration
	current_resonance = 0.0  # Reset to 0

	# Trigger VFX
	_start_visual_effects()

	# Emit signal
	EventBus.resonance_mode_activated.emit()


func deactivate_mode() -> void:
	"""Deactivates Resonance Mode."""
	if not is_active:
		return

	print("[ResonanceSystem] Deactivating Resonance Mode")

	is_active = false
	mode_time_remaining = 0.0

	# Stop VFX
	_stop_visual_effects()

	# Emit signal
	EventBus.resonance_mode_deactivated.emit()


# ============ VISUAL EFFECTS ============
func _start_visual_effects() -> void:
	"""Starts all visual effects."""
	# Screen flash
	var camera = owner.get_node_or_null("PlayerCamera")
	if camera and camera.has_method("flash"):
		camera.flash(Color(1.0, 1.0, 0.8, 0.7), 0.2)

	# TODO: Spawn aura (will create VFX in next step)
	# var aura_scene = preload("res://vfx/particles/resonance_aura.tscn")
	# aura_effect = aura_scene.instantiate()
	# owner.add_child(aura_effect)

	# Start sprite glow
	var sprite = owner.get_node_or_null("Sprite2D")
	if sprite:
		_start_sprite_glow(sprite)


func _stop_visual_effects() -> void:
	"""Stops all visual effects."""
	# Stop aura
	if aura_effect:
		# aura_effect.stop_emission()
		await get_tree().create_timer(1.0).timeout
		if aura_effect:
			aura_effect.queue_free()
			aura_effect = null

	# Stop sprite glow
	var sprite = owner.get_node_or_null("Sprite2D")
	if sprite:
		_stop_sprite_glow(sprite)


func _start_sprite_glow(sprite: Sprite2D) -> void:
	"""Starts pulsing glow on sprite."""
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.5), 0.5)
	glow_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.5)


func _stop_sprite_glow(sprite: Sprite2D) -> void:
	"""Stops glow and resets sprite."""
	if glow_tween:
		glow_tween.kill()
	sprite.modulate = Color(1.0, 1.0, 1.0)


# ============ GETTERS ============
func get_current_resonance() -> float:
	"""Returns current resonance value."""
	return current_resonance


func get_max_resonance() -> float:
	"""Returns maximum resonance value."""
	return max_resonance


func get_resonance_percentage() -> float:
	"""Returns resonance as percentage (0-100)."""
	if max_resonance <= 0.0:
		return 0.0
	return (current_resonance / max_resonance) * 100.0


func get_resonance_normalized() -> float:
	"""Returns resonance as normalized value (0.0-1.0)."""
	if max_resonance <= 0.0:
		return 0.0
	return current_resonance / max_resonance


func is_resonance_full() -> bool:
	"""Returns true if resonance is at maximum."""
	return current_resonance >= max_resonance


func is_resonance_empty() -> bool:
	"""Returns true if resonance is at 0."""
	return current_resonance <= 0.0


func is_above_threshold(threshold: int) -> bool:
	"""Returns true if resonance is above the given threshold."""
	return get_resonance_percentage() >= threshold


func is_mode_active() -> bool:
	"""Returns true if mode is currently active."""
	return is_active


func get_mode_time_remaining() -> float:
	"""Returns time remaining in mode."""
	return mode_time_remaining


func get_damage_multiplier() -> float:
	"""Returns current damage multiplier."""
	return DAMAGE_BONUS if is_active else 1.0


func get_speed_multiplier() -> float:
	"""Returns current speed multiplier."""
	return SPEED_BONUS if is_active else 1.0


func get_mana_cost_multiplier() -> float:
	"""Returns current mana cost multiplier."""
	return MANA_COST_REDUCTION if is_active else 1.0


# ============ CONTROL ============
func enable() -> void:
	"""Enables resonance system."""
	enabled = true
	print("[ResonanceSystem] Enabled")


func disable() -> void:
	"""Disables resonance system."""
	enabled = false
	print("[ResonanceSystem] Disabled")


# ============ DEBUG ============
func get_debug_info() -> Dictionary:
	"""Returns debug information."""
	return {
		"enabled": enabled,
		"current": current_resonance,
		"max": max_resonance,
		"percentage": get_resonance_percentage(),
		"in_combat": is_in_combat,
		"time_since_combat": last_combat_time,
		"thresholds": threshold_flags
	}


func print_debug_info() -> void:
	"""Prints debug information."""
	var info: Dictionary = get_debug_info()
	print("[ResonanceSystem] Debug Info:")
	for key in info:
		print("  %s: %s" % [key, str(info[key])])
