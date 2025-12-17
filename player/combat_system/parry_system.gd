extends Node
## ParrySystem - Handles parry timing, detection, and rewards
## Implements timing-based defensive mechanic with generous testing window
class_name ParrySystem

# ============================================================================
# CONSTANTS - TESTING VALUES
# ============================================================================

# TESTING VALUES (großzügig für Testing)
const PARRY_WINDOW_DURATION: float = 0.4  # 24 frames @ 60 FPS
const PARRY_ANTICIPATION: float = 0.1  # Startup delay

# Production values (später):
# const PARRY_WINDOW_DURATION: float = 0.133  # 8 frames

const PARRY_COOLDOWN_DURATION: float = 0.8  # Nach Failed Parry
const STUN_DURATION: float = 0.8  # Enemy stun auf Perfect Parry
const TIME_SLOW_SCALE: float = 0.3  # 30% speed
const TIME_SLOW_DURATION: float = 0.2  # Slow duration

const RESONANCE_GAIN_ON_PARRY: float = 12.5  # 2× normal hit

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, ANTICIPATION, PARRY_WINDOW, COOLDOWN }

var current_state: State = State.IDLE
var state_timer: float = 0.0
var cooldown_remaining: float = 0.0

var parry_active: bool = false

# ============================================================================
# SIGNALS
# ============================================================================

signal parry_started
signal parry_window_opened
signal perfect_parry(enemy: Node)
signal parry_failed
signal parry_cooldown_started(duration: float)

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D
var hurtbox: Area2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Get references in _ready() when owner is guaranteed to be set
	player = owner as CharacterBody2D

	# Get hurtbox from player's CombatSystem
	if player:
		hurtbox = player.get_node_or_null("CombatSystem/HurtboxComponent")

	# Connect to hurtbox for attack detection
	if hurtbox:
		hurtbox.area_entered.connect(_on_attack_detected)

	print("[ParrySystem] Initialized - Window: %.2fs, Cooldown: %.2fs" % [PARRY_WINDOW_DURATION, PARRY_COOLDOWN_DURATION])


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("block"):
		attempt_parry()


func attempt_parry() -> void:
	"""Attempts to start parry window"""

	# Check if can parry
	if not can_parry():
		print("[ParrySystem] Cannot parry (state: %s, cooldown: %.2fs)" % [get_state_name(), cooldown_remaining])
		return

	# Start parry sequence
	current_state = State.ANTICIPATION
	state_timer = PARRY_ANTICIPATION

	# Visual/Audio feedback
	_play_parry_anticipation()

	# Emit signal
	parry_started.emit()
	EventBus.parry_started.emit()

	print("[ParrySystem] Parry attempt started")


func can_parry() -> bool:
	"""Returns true if parry is available"""
	if current_state != State.IDLE:
		return false

	if cooldown_remaining > 0.0:
		return false

	# Player can always parry (no additional state checks needed)
	return true


# ============================================================================
# STATE MACHINE
# ============================================================================

func _process(delta: float) -> void:
	# Update cooldown
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta
		EventBus.parry_cooldown_updated.emit(cooldown_remaining)

	# State machine
	match current_state:
		State.ANTICIPATION:
			_process_anticipation(delta)

		State.PARRY_WINDOW:
			_process_parry_window(delta)

		State.COOLDOWN:
			_process_cooldown(delta)


func _process_anticipation(delta: float) -> void:
	"""Startup phase before window opens"""
	state_timer -= delta

	if state_timer <= 0.0:
		# Open parry window
		current_state = State.PARRY_WINDOW
		state_timer = PARRY_WINDOW_DURATION
		parry_active = true

		parry_window_opened.emit()
		EventBus.parry_window_opened.emit()
		print("[ParrySystem] Parry window OPEN (%.2fs)" % PARRY_WINDOW_DURATION)


func _process_parry_window(delta: float) -> void:
	"""Active parry window"""
	state_timer -= delta

	if state_timer <= 0.0:
		# Window expired without success
		_handle_failed_parry()


func _process_cooldown(delta: float) -> void:
	"""Cooldown after failed parry"""
	state_timer -= delta

	if state_timer <= 0.0:
		current_state = State.IDLE
		print("[ParrySystem] Cooldown ended, ready to parry")


# ============================================================================
# PARRY DETECTION
# ============================================================================

func _on_attack_detected(hitbox: Area2D) -> void:
	"""Called when enemy hitbox overlaps player hurtbox"""

	# Check if we're in parry window
	if current_state != State.PARRY_WINDOW:
		return  # Not parrying, normal damage

	# Check if it's an enemy attack
	if not hitbox.owner or not hitbox.owner.is_in_group("enemies"):
		return

	# PERFECT PARRY!
	_handle_perfect_parry(hitbox.owner)


# ============================================================================
# PARRY SUCCESS
# ============================================================================

func _handle_perfect_parry(enemy: Node) -> void:
	"""Handles successful perfect parry"""

	print("[ParrySystem] PERFECT PARRY on %s" % enemy.name)

	# Reset state
	current_state = State.IDLE
	parry_active = false
	state_timer = 0.0

	# Cancel enemy attack (no damage)
	# This is handled by not calling player.take_damage()

	# Stun enemy
	if enemy.has_method("stun"):
		enemy.stun(STUN_DURATION)
		print("[ParrySystem] Enemy stunned for %.2fs" % STUN_DURATION)

	# Time slow effect
	GlobalTimeEffects.slow_motion(TIME_SLOW_SCALE, TIME_SLOW_DURATION)
	print("[ParrySystem] Time slow: %.1f× for %.2fs" % [TIME_SLOW_SCALE, TIME_SLOW_DURATION])

	# Add resonance
	var resonance = player.get_node_or_null("CombatSystem/ResonanceSystem")
	if resonance:
		resonance.add_resonance(RESONANCE_GAIN_ON_PARRY)
		print("[ParrySystem] +%.1f resonance" % RESONANCE_GAIN_ON_PARRY)

	# Visual effects
	_play_perfect_parry_vfx(enemy)

	# Audio
	AudioManager.play_sfx("player_parry_success", 0.2)

	# Camera shake
	var camera = player.get_node_or_null("PlayerCamera")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.25)

	# Emit signal
	perfect_parry.emit(enemy)
	EventBus.perfect_parry.emit(enemy)


# ============================================================================
# PARRY FAILURE
# ============================================================================

func _handle_failed_parry() -> void:
	"""Handles failed parry (timeout)"""

	print("[ParrySystem] Parry FAILED (timeout)")

	# Reset state
	parry_active = false

	# Enter cooldown
	current_state = State.COOLDOWN
	state_timer = PARRY_COOLDOWN_DURATION
	cooldown_remaining = PARRY_COOLDOWN_DURATION

	# Movement penalty (optional, slight slowdown)
	# player.apply_movement_penalty(0.2)

	# Visual feedback
	_play_failed_parry_vfx()

	# Audio
	AudioManager.play_sfx("player_parry_failed", 0.05)

	# Emit signals
	parry_failed.emit()
	parry_cooldown_started.emit(PARRY_COOLDOWN_DURATION)
	EventBus.parry_failed.emit()
	EventBus.parry_cooldown_started.emit(PARRY_COOLDOWN_DURATION)


# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _play_parry_anticipation() -> void:
	"""Visual feedback for parry startup"""
	# Optional: Flash player sprite
	if not player:
		return

	if player.has_node("Sprite2D"):
		var sprite = player.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.8, 1.2), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)


func _play_perfect_parry_vfx(enemy: Node) -> void:
	"""Spawns VFX for perfect parry"""
	# Check if parry flash scene exists
	if not ResourceLoader.exists("res://vfx/particles/parry_flash.tscn"):
		print("[ParrySystem] Parry flash VFX not found, skipping")

		# Fallback: Simple sprite flash
		if player and player.has_node("Sprite2D"):
			var sprite = player.get_node("Sprite2D")
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		return

	# Spawn flash effect
	var flash_scene = preload("res://vfx/particles/parry_flash.tscn")
	var flash = flash_scene.instantiate()

	# Position between player and enemy
	var midpoint = (player.global_position + enemy.global_position) / 2.0

	get_tree().root.add_child(flash)
	flash.global_position = midpoint

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if flash:
		flash.queue_free()


func _play_failed_parry_vfx() -> void:
	"""Visual feedback for failed parry"""
	# Gray flash on player
	if not player:
		return

	if player.has_node("Sprite2D"):
		var sprite = player.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.6, 0.6, 0.6), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


# ============================================================================
# UTILITY
# ============================================================================

func is_parrying() -> bool:
	"""Returns true if currently in parry window"""
	return current_state == State.PARRY_WINDOW


func get_cooldown_remaining() -> float:
	"""Returns remaining cooldown time"""
	return cooldown_remaining


func get_state_name() -> String:
	"""Returns current state as string (for debugging)"""
	match current_state:
		State.IDLE: return "IDLE"
		State.ANTICIPATION: return "ANTICIPATION"
		State.PARRY_WINDOW: return "PARRY_WINDOW"
		State.COOLDOWN: return "COOLDOWN"
		_: return "UNKNOWN"


# ============================================================================
# DEBUG
# ============================================================================

func get_debug_info() -> Dictionary:
	"""Returns debug information"""
	return {
		"state": get_state_name(),
		"state_timer": state_timer,
		"cooldown_remaining": cooldown_remaining,
		"parry_active": parry_active,
		"can_parry": can_parry()
	}
