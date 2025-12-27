extends Node
class_name EchoVonUrgathon

## Echo von Urgathon - Mana gain on hit ability
## Toggle buff that restores mana with each hit
## Synergizes with Resonance Mode for increased mana gain

# ============================================================================
# CONSTANTS
# ============================================================================

const MANA_COST: int = 40
const DURATION: float = 20.0
const COOLDOWN: float = 25.0

const MANA_PER_HIT_BASE: int = 3
const MANA_PER_HIT_RESONANCE: int = 5

# ============================================================================
# STATE
# ============================================================================

var is_active: bool = false
var time_remaining: float = 0.0
var cooldown_remaining: float = 0.0

# Story flag - set to true for testing
@export var is_unlocked: bool = true

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner
@onready var mana_component: ManaComponent = player.get_node("ManaComponent")
@onready var resonance_system: ResonanceSystem = player.get_node_or_null("CombatSystem/ResonanceSystem")

# VFX
var aura_effect: GPUParticles2D = null

# ============================================================================
# SIGNALS
# ============================================================================

signal echo_activated()
signal echo_deactivated()
signal mana_restored_from_hit(amount: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[EchoVonUrgathon] Initialized (unlocked: %s)" % is_unlocked)

	# Connect to hit signal
	if EventBus:
		EventBus.hit_registered.connect(_on_hit_registered)

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if not is_unlocked:
		return

	# Toggle on key 3 press
	if event.is_action_pressed("echo_ability"):
		_toggle_ability()

# ============================================================================
# TOGGLE MECHANICS
# ============================================================================

func _toggle_ability() -> void:
	"""Toggles the Echo ability on/off"""

	# If on cooldown, can't activate
	if cooldown_remaining > 0.0:
		print("[EchoVonUrgathon] On cooldown: %.1fs remaining" % cooldown_remaining)
		_show_cooldown_message()
		return

	# If active, deactivate
	if is_active:
		_deactivate()
		return

	# Try to activate
	_try_activate()

func _try_activate() -> void:
	"""Attempts to activate Echo ability"""

	# Check mana
	if not mana_component:
		print("[EchoVonUrgathon] No mana component")
		return

	if not mana_component.has_mana(MANA_COST):
		print("[EchoVonUrgathon] Not enough mana (%d required)" % MANA_COST)
		_show_insufficient_mana_message()
		return

	# Consume mana
	if not mana_component.use_mana(MANA_COST):
		print("[EchoVonUrgathon] Failed to consume mana")
		return

	# Activate!
	_activate()

func _activate() -> void:
	"""Activates Echo ability"""

	is_active = true
	time_remaining = DURATION

	print("[EchoVonUrgathon] ACTIVATED (duration: %.1fs)" % DURATION)

	# Spawn aura effect
	_spawn_aura()

	# Emit signals
	echo_activated.emit()
	EventBus.echo_von_urgathon_activated.emit()

func _deactivate() -> void:
	"""Deactivates Echo ability"""

	is_active = false
	time_remaining = 0.0
	cooldown_remaining = COOLDOWN

	print("[EchoVonUrgathon] DEACTIVATED (cooldown: %.1fs)" % COOLDOWN)

	# Remove aura effect
	_remove_aura()

	# Emit signals
	echo_deactivated.emit()
	EventBus.echo_von_urgathon_deactivated.emit()

# ============================================================================
# UPDATE
# ============================================================================

func _process(delta: float) -> void:
	# Update duration timer
	if is_active:
		time_remaining -= delta

		# Update HUD
		EventBus.echo_timer_updated.emit(time_remaining)

		# Check if expired
		if time_remaining <= 0.0:
			_deactivate()

	# Update cooldown timer
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta

		# Update HUD
		EventBus.echo_cooldown_updated.emit(cooldown_remaining)

		if cooldown_remaining <= 0.0:
			print("[EchoVonUrgathon] Cooldown complete")
			EventBus.echo_ready.emit()

# ============================================================================
# HIT DETECTION
# ============================================================================

func _on_hit_registered(attacker: Node, target: Node, damage: int) -> void:
	"""Called when any hit is registered in the game"""

	# Only respond if Echo is active
	if not is_active:
		return

	# Only respond if player is the attacker
	if attacker != player:
		return

	# Calculate mana gain based on Resonance Mode
	var mana_gain: int = _calculate_mana_gain()

	# Restore mana
	if mana_component:
		mana_component.restore_mana(mana_gain)
		print("[EchoVonUrgathon] Hit! Restored %d mana" % mana_gain)

		# Emit signal
		mana_restored_from_hit.emit(mana_gain)
		EventBus.echo_mana_gained.emit(mana_gain)

		# Visual feedback
		_spawn_mana_gain_vfx()

func _calculate_mana_gain() -> int:
	"""Calculates mana gain based on Resonance Mode status"""

	# Check if Resonance Mode is active
	if resonance_system and resonance_system.is_mode_active():
		return MANA_PER_HIT_RESONANCE
	else:
		return MANA_PER_HIT_BASE

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _spawn_aura() -> void:
	"""Spawns green aura effect around player"""

	# Check if aura scene exists
	var aura_scene_path = "res://vfx/particles/echo_aura.tscn"

	if not ResourceLoader.exists(aura_scene_path):
		print("[EchoVonUrgathon] Aura VFX not found, creating placeholder")
		_create_placeholder_aura()
		return

	var aura_scene = load(aura_scene_path)
	aura_effect = aura_scene.instantiate()

	player.add_child(aura_effect)
	aura_effect.position = Vector2.ZERO
	aura_effect.emitting = true

func _create_placeholder_aura() -> void:
	"""Creates a simple placeholder aura using GPUParticles2D"""

	aura_effect = GPUParticles2D.new()
	aura_effect.name = "EchoAuraPlaceholder"

	# Configure particles
	aura_effect.amount = 32
	aura_effect.lifetime = 1.0
	aura_effect.explosiveness = 0.0
	aura_effect.randomness = 0.5
	aura_effect.visibility_rect = Rect2(-100, -100, 200, 200)

	# Create process material
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color = Color(0.2, 1.0, 0.3, 0.6)  # Green

	aura_effect.process_material = material
	aura_effect.emitting = true

	player.add_child(aura_effect)

func _remove_aura() -> void:
	"""Removes aura effect"""

	if aura_effect:
		aura_effect.emitting = false
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(aura_effect):
			aura_effect.queue_free()
		aura_effect = null

func _spawn_mana_gain_vfx() -> void:
	"""Spawns small VFX when mana is gained from a hit"""

	# TODO: Add mana gain particle effect
	# For now, we'll rely on the EventBus signal for UI feedback
	pass

# ============================================================================
# UI FEEDBACK
# ============================================================================

func _show_cooldown_message() -> void:
	"""Shows UI message when ability is on cooldown"""

	# TODO: Implement UI notification system
	# EventBus.show_notification.emit("Echo on cooldown: %.1fs" % cooldown_remaining)
	pass

func _show_insufficient_mana_message() -> void:
	"""Shows UI message when not enough mana"""

	# TODO: Implement UI notification system
	# EventBus.show_notification.emit("Not enough mana for Echo")
	pass

# ============================================================================
# UTILITY
# ============================================================================

func is_ability_active() -> bool:
	"""Returns true if Echo is currently active"""
	return is_active

func can_activate() -> bool:
	"""Returns true if can activate Echo"""
	return is_unlocked and not is_active and cooldown_remaining <= 0.0

func get_time_remaining() -> float:
	"""Returns remaining active time"""
	return time_remaining

func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return cooldown_remaining
