extends Node
class_name Echo

## Echo von Urgathon (Echo of Urgathon)
## Press Key 3 to toggle mana restoration buff
## Gain mana on each successful hit (+3 baseline, +5 during Resonance Mode)
## Active for 20 seconds, then enters cooldown

# ============================================================================
# CONSTANTS
# ============================================================================

# Ability Parameters
const MANA_GAIN_BASE: int = 3          # Mana gained per hit (baseline)
const MANA_GAIN_RESONANCE: int = 5     # Mana gained per hit (during Resonance Mode)
const DURATION: float = 20.0           # How long Echo lasts
const PULSE_INTERVAL: float = 2.0      # Visual pulse every 2 seconds

# Resource Costs
const MANA_COST: int = 40
const COOLDOWN_DURATION: float = 25.0

# VFX
const ACTIVATION_HITSTOP: float = 0.08  # Brief hitstop on activation

# ============================================================================
# STATE
# ============================================================================

var is_active: bool = false
var is_on_cooldown: bool = false
var duration_timer: float = 0.0
var cooldown_timer: float = 0.0
var pulse_timer: float = 0.0

# Stats tracking
var total_hits: int = 0
var total_mana_gained: int = 0

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var mana_component: Node = null
var resonance_system: Node = null

# VFX
var aura_vfx: Node = null

# ============================================================================
# SIGNALS
# ============================================================================

signal echo_activated()
signal echo_deactivated()
signal echo_hit_registered(mana_gained: int)
signal echo_pulse()
signal echo_duration_expired()
signal echo_cooldown_started(duration: float)
signal echo_cooldown_finished()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get player reference (via parent CombatSystem)
	var combat_system = get_parent()
	if combat_system:
		player = combat_system.owner as CharacterBody2D

	# Fallback
	if not player:
		player = owner as CharacterBody2D

	if not player:
		print("[Echo] ERROR: Could not find player reference!")
		return

	# Get mana component
	mana_component = player.get_node_or_null("ManaComponent")
	if not mana_component:
		print("[Echo] WARNING: ManaComponent not found!")

	# Get resonance system
	resonance_system = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if not resonance_system:
		print("[Echo] WARNING: ResonanceSystem not found!")

	# Connect to hit events
	EventBus.hit_registered.connect(_on_hit_registered)

	print("[Echo] Initialized (Echo von Urgathon)")

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Toggle on Key 3 press
	if event.is_action_pressed("ability_3"):
		if is_active:
			# Already active - cannot deactivate manually
			print("[Echo] Already active - wait for duration to expire")
		else:
			attempt_activation()

# ============================================================================
# TIMERS
# ============================================================================

func _process(delta: float) -> void:
	# Update duration timer (if active)
	if is_active:
		duration_timer -= delta
		pulse_timer -= delta

		# Check for pulse
		if pulse_timer <= 0.0:
			_trigger_pulse()
			pulse_timer = PULSE_INTERVAL

		# Check for expiration
		if duration_timer <= 0.0:
			_expire_duration()

	# Update cooldown timer
	if is_on_cooldown:
		cooldown_timer -= delta

		if cooldown_timer <= 0.0:
			_finish_cooldown()

func _start_cooldown() -> void:
	"""Starts the cooldown timer"""
	is_on_cooldown = true
	cooldown_timer = COOLDOWN_DURATION

	print("[Echo] Cooldown started (%.1fs)" % COOLDOWN_DURATION)

	# Emit signals
	echo_cooldown_started.emit(COOLDOWN_DURATION)
	EventBus.echo_cooldown_started.emit(COOLDOWN_DURATION)

func _finish_cooldown() -> void:
	"""Finishes the cooldown"""
	is_on_cooldown = false
	cooldown_timer = 0.0

	print("[Echo] Cooldown finished - Ready!")

	# Emit signals
	echo_cooldown_finished.emit()
	EventBus.echo_cooldown_finished.emit()

# ============================================================================
# ACTIVATION
# ============================================================================

func attempt_activation() -> bool:
	"""Attempts to activate Echo. Returns true if successful."""

	# Check if already active
	if is_active:
		print("[Echo] Already active")
		return false

	# Check cooldown
	if is_on_cooldown:
		print("[Echo] On cooldown (%.1fs remaining)" % cooldown_timer)
		return false

	# Check mana
	if not mana_component:
		print("[Echo] ERROR: ManaComponent not available!")
		return false

	if not mana_component.has_mana(MANA_COST):
		print("[Echo] Not enough mana (%d required, %d available)" % [MANA_COST, mana_component.current_mana])
		return false

	# All checks passed - activate!
	_activate()
	return true

func _activate() -> void:
	"""Activates Echo buff"""
	print("[Echo] ===== ACTIVATED =====")

	# Consume mana
	if not mana_component.use_mana(MANA_COST):
		print("[Echo] ERROR: Failed to consume mana!")
		return

	print("[Echo] Consumed %d mana" % MANA_COST)

	# Set active state
	is_active = true
	duration_timer = DURATION
	pulse_timer = PULSE_INTERVAL

	# Reset stats
	total_hits = 0
	total_mana_gained = 0

	# VFX
	_spawn_aura_vfx()

	# Audio
	AudioManager.play_sfx("player_echo_activate", 0.2)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.15)

	# Hitstop
	GlobalTimeEffects.hit_stop(ACTIVATION_HITSTOP)

	# Emit signal
	echo_activated.emit()
	EventBus.echo_activated.emit()

	print("[Echo] Active for %.1fs - Mana on hit: %d (+%d in Resonance Mode)" % [DURATION, MANA_GAIN_BASE, MANA_GAIN_RESONANCE])

func _deactivate() -> void:
	"""Deactivates Echo (called when duration expires)"""

	if not is_active:
		return

	print("[Echo] ===== DEACTIVATED =====")
	print("[Echo] Stats: %d hits, %d total mana gained" % [total_hits, total_mana_gained])

	is_active = false
	duration_timer = 0.0
	pulse_timer = 0.0

	# Remove aura VFX
	if aura_vfx:
		aura_vfx.queue_free()
		aura_vfx = null

	# Audio
	AudioManager.play_sfx("player_echo_deactivate", 0.15)

	# Emit signal
	echo_deactivated.emit()
	EventBus.echo_deactivated.emit()

func _expire_duration() -> void:
	"""Called when Echo duration expires"""

	print("[Echo] Duration expired")

	# Deactivate
	_deactivate()

	# Start cooldown
	_start_cooldown()

	# Emit signal
	echo_duration_expired.emit()
	EventBus.echo_duration_expired.emit()

func _trigger_pulse() -> void:
	"""Triggers visual pulse effect"""

	if not is_active:
		return

	# Spawn pulse VFX
	_spawn_pulse_vfx()

	# Emit signal
	echo_pulse.emit()
	EventBus.echo_pulse.emit()

# ============================================================================
# MANA GAIN
# ============================================================================

func _on_hit_registered(attacker: Node, target: Node, damage: int) -> void:
	"""Called when any hit is registered - check if it's from player"""

	# Only react if Echo is active
	if not is_active:
		return

	# Only react to player hits
	if attacker != player:
		return

	# Grant mana based on Resonance Mode status
	var mana_to_gain: int
	var in_resonance_mode = resonance_system and resonance_system.is_mode_active()

	if in_resonance_mode:
		mana_to_gain = MANA_GAIN_RESONANCE
	else:
		mana_to_gain = MANA_GAIN_BASE

	# Restore mana
	if mana_component and mana_component.has_method("restore_mana"):
		mana_component.restore_mana(mana_to_gain)

		# Track stats
		total_hits += 1
		total_mana_gained += mana_to_gain

		var mode_text = " (Resonance Mode)" if in_resonance_mode else ""
		print("[Echo] Hit #%d: +%d mana%s (total: %d)" % [total_hits, mana_to_gain, mode_text, total_mana_gained])

		# Emit signal
		echo_hit_registered.emit(mana_to_gain)
		EventBus.echo_hit_registered.emit(mana_to_gain)

		# Spawn mini-VFX on player
		_spawn_hit_feedback_vfx()

# ============================================================================
# VFX
# ============================================================================

func _spawn_aura_vfx() -> void:
	"""Spawns persistent aura VFX around player"""

	var vfx_path = "res://vfx/particles/echo_aura.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Echo] Aura VFX not found: %s" % vfx_path)
		return

	var aura_scene = load(vfx_path)
	aura_vfx = aura_scene.instantiate()
	player.add_child(aura_vfx)

	if aura_vfx.has_property("emitting"):
		aura_vfx.emitting = true

	print("[Echo] Aura VFX spawned")

func _spawn_pulse_vfx() -> void:
	"""Spawns pulse VFX (periodic visual feedback)"""

	var vfx_path = "res://vfx/particles/echo_pulse.tscn"

	if not ResourceLoader.exists(vfx_path):
		# Silently skip if VFX not found
		return

	var pulse_scene = load(vfx_path)
	var pulse = pulse_scene.instantiate()
	player.add_child(pulse)

	if pulse.has_property("emitting"):
		pulse.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if pulse:
		pulse.queue_free()

func _spawn_hit_feedback_vfx() -> void:
	"""Spawns small VFX when mana is gained from hit"""

	var vfx_path = "res://vfx/particles/echo_hit.tscn"

	if not ResourceLoader.exists(vfx_path):
		# Silently skip if VFX not found
		return

	var hit_scene = load(vfx_path)
	var hit = hit_scene.instantiate()
	player.add_child(hit)

	if hit.has_property("emitting"):
		hit.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(0.5).timeout
	if hit:
		hit.queue_free()

# ============================================================================
# UTILITY
# ============================================================================

func is_available() -> bool:
	"""Returns true if Echo can be activated"""
	if is_active:
		return false

	if is_on_cooldown:
		return false

	if not mana_component:
		return false

	return mana_component.has_mana(MANA_COST)

func is_echo_active() -> bool:
	"""Returns true if Echo buff is currently active"""
	return is_active

func get_duration_remaining() -> float:
	"""Returns remaining active duration"""
	return duration_timer if is_active else 0.0

func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return cooldown_timer if is_on_cooldown else 0.0

func get_cooldown_percentage() -> float:
	"""Returns cooldown as percentage (0.0 = ready, 1.0 = just used)"""
	if not is_on_cooldown:
		return 0.0

	return cooldown_timer / COOLDOWN_DURATION

func get_duration_percentage() -> float:
	"""Returns duration as percentage (1.0 = just activated, 0.0 = expired)"""
	if not is_active:
		return 0.0

	return duration_timer / DURATION

func get_total_hits() -> int:
	"""Returns total hits during current activation"""
	return total_hits

func get_total_mana_gained() -> int:
	"""Returns total mana gained during current activation"""
	return total_mana_gained
