extends Node
## DodgeRollSystem - Handles dodge roll mechanic with i-frames (cooldown-based, no cost)
class_name DodgeRollSystem

# ============================================================================
# CONSTANTS
# ============================================================================

const ROLL_DURATION: float = 0.35
const ROLL_DISTANCE: float = 440.0
const ROLL_SPEED: float = 1257.1  # 440 / 0.35

const STARTUP_DURATION: float = 0.03
const ACTIVE_DURATION: float = 0.3   # I-frames window (buffed from 0.25)
const RECOVERY_DURATION: float = 0.05

const COOLDOWN_DURATION: float = 0.7  # Reduced cooldown (from 1.0)

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, STARTUP, ACTIVE, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0

var roll_direction: Vector2 = Vector2.ZERO
var is_invincible: bool = false

var cooldown_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var player: CharacterBody2D = null
var hurtbox: Area2D = null

# ============================================================================
# SIGNALS
# ============================================================================

signal dodge_started(direction: Vector2)
signal dodge_active  # I-frames started
signal dodge_completed
signal dodge_failed(reason: String)


func _ready() -> void:
	# Get references (deferred to ensure nodes are ready)
	await get_tree().process_frame

	player = owner as CharacterBody2D
	if not player:
		push_error("[DodgeRollSystem] Owner must be CharacterBody2D")
		return

	hurtbox = player.get_node_or_null("HurtboxComponent")
	if not hurtbox:
		push_warning("[DodgeRollSystem] HurtboxComponent not found")

	print("[DodgeRollSystem] Initialized (cooldown-based, no cost)")


# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# CRITICAL: P1-only ability (COMMIT 022.5)
	if player and player.name == "LythrunPlayer":
		return  # P2 doesn't use dodge system

	# Use InputManager for proper device filtering
	if not InputManager:
		return

	# Check for dodge input (Shift key or B button)
	# IMPORTANT: Don't trigger dodge if RT is held (RT+B = Machtstoß combo)
	if InputManager.is_p1_action_just_pressed("dodge") and not InputManager.is_p1_rt_held():
		attempt_dodge()


# ============================================================================
# DODGE EXECUTION
# ============================================================================

func attempt_dodge() -> void:
	"""Attempts to execute dodge roll (FREE - only cooldown check)"""

	# Check state
	if current_state != State.IDLE:
		dodge_failed.emit("Already dodging")
		return

	# Check cooldown (ONLY limitation!)
	if cooldown_timer > 0.0:
		dodge_failed.emit("Cooldown active")
		return

	# Execute dodge (no cost!)
	_start_dodge()


func _start_dodge() -> void:
	"""Starts dodge roll sequence"""

	print("[DodgeRollSystem] Starting dodge (FREE)")

	# Determine direction
	roll_direction = _get_dodge_direction()

	# Disable collision with enemies during dodge (can pass through)
	# Must change BOTH layer and mask:
	# - Layer: 2 → 32 (enemies don't see player)
	# - Mask: 17 → 1 (player doesn't see enemies, only terrain)
	player.collision_layer = 32
	player.collision_mask = 1
	print("[DodgeRollSystem] Player collision disabled (layer=32, mask=1)")

	# Enter startup state
	current_state = State.STARTUP
	state_timer = STARTUP_DURATION

	# Play animation
	_play_dodge_animation()

	# Emit signal
	dodge_started.emit(roll_direction)
	EventBus.dodge_started.emit(roll_direction)


func _get_dodge_direction() -> Vector2:
	"""Determines dodge direction based on input"""

	# Get movement input (WASD)
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("jump", "crouch")  # W/S for vertical
	)

	if input_dir.length() > 0.1:
		# Use input direction
		return input_dir.normalized()

	# No input: Dodge backward (away from facing)
	# Use MovementController to get consistent facing direction
	var movement_controller = player.get_node_or_null("MovementController")
	if movement_controller and movement_controller.has_method("get_facing_direction"):
		var facing = movement_controller.get_facing_direction()
		print("[DodgeRollSystem] No input - dodging backward from facing: ", facing)
		return Vector2(-facing, 0)  # Opposite of facing

	# Fallback: Dodge left
	return Vector2(-1, 0)


# ============================================================================
# STATE MACHINE
# ============================================================================

func _physics_process(delta: float) -> void:
	# Update cooldown
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Process current state
	match current_state:
		State.STARTUP:
			_process_startup(delta)
		State.ACTIVE:
			_process_active(delta)
		State.RECOVERY:
			_process_recovery(delta)


func _process_startup(delta: float) -> void:
	"""Processes startup phase"""

	state_timer -= delta

	# Apply movement
	player.velocity = roll_direction * ROLL_SPEED
	player.move_and_slide()

	if state_timer <= 0.0:
		_enter_active()


func _process_active(delta: float) -> void:
	"""Processes active phase (i-frames)"""

	state_timer -= delta

	# Apply movement
	player.velocity = roll_direction * ROLL_SPEED
	player.move_and_slide()

	if state_timer <= 0.0:
		_enter_recovery()


func _process_recovery(delta: float) -> void:
	"""Processes recovery phase"""

	state_timer -= delta

	# Slow down
	var slow_factor = state_timer / RECOVERY_DURATION
	player.velocity = roll_direction * ROLL_SPEED * slow_factor * 0.5
	player.move_and_slide()

	if state_timer <= 0.0:
		_complete_dodge()


# ============================================================================
# STATE TRANSITIONS
# ============================================================================

func _enter_active() -> void:
	"""Enters active phase with i-frames"""

	current_state = State.ACTIVE
	state_timer = ACTIVE_DURATION

	# Activate i-frames
	_activate_invincibility()

	print("[DodgeRollSystem] Active (i-frames)")

	dodge_active.emit()


func _enter_recovery() -> void:
	"""Enters recovery phase"""

	current_state = State.RECOVERY
	state_timer = RECOVERY_DURATION

	# Deactivate i-frames
	_deactivate_invincibility()

	print("[DodgeRollSystem] Recovery")


func _complete_dodge() -> void:
	"""Completes dodge roll"""

	current_state = State.IDLE
	cooldown_timer = COOLDOWN_DURATION  # Start cooldown

	# Re-enable collision with enemies after dodge
	# Restore BOTH layer and mask:
	# - Layer: 32 → 2 (normal player layer)
	# - Mask: 1 → 17 (terrain + enemies)
	player.collision_layer = 2
	player.collision_mask = 17
	print("[DodgeRollSystem] Player collision restored (layer=2, mask=17)")

	# Stop movement
	player.velocity = Vector2.ZERO

	print("[DodgeRollSystem] Completed - Cooldown: %.1fs" % COOLDOWN_DURATION)

	dodge_completed.emit()
	EventBus.dodge_completed.emit()


# ============================================================================
# INVINCIBILITY
# ============================================================================

func _activate_invincibility() -> void:
	"""Activates i-frames (no damage taken)"""

	is_invincible = true

	# Disable hurtbox collision
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	# Visual feedback (flash)
	_start_invincibility_visual()


func _deactivate_invincibility() -> void:
	"""Deactivates i-frames"""

	is_invincible = false

	# Re-enable hurtbox collision
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)

	# Stop visual feedback
	_stop_invincibility_visual()


func _start_invincibility_visual() -> void:
	"""Visual feedback for i-frames (flashing)"""

	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Flash effect (repeating)
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.4, 0.08)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.08)

	# Store tween reference
	set_meta("invincibility_tween", tween)


func _stop_invincibility_visual() -> void:
	"""Stops visual feedback"""

	if has_meta("invincibility_tween"):
		var tween = get_meta("invincibility_tween") as Tween
		if tween:
			tween.kill()
		remove_meta("invincibility_tween")

	# Reset alpha
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate.a = 1.0


# ============================================================================
# ANIMATION
# ============================================================================

func _play_dodge_animation() -> void:
	"""Plays dodge roll animation"""

	# Audio
	AudioManager.play_sfx_at_position("player/dodge_roll", player.global_position, 0.12)

	# VFX (dust trail)
	# _spawn_dodge_trail()  # TODO: Add VFX particle scene


# ============================================================================
# UTILITY
# ============================================================================

func is_dodging() -> bool:
	"""Returns true if currently in dodge"""
	return current_state in [State.STARTUP, State.ACTIVE, State.RECOVERY]


func get_is_invincible() -> bool:
	"""Returns true if invincible"""
	return is_invincible


func can_dodge() -> bool:
	"""Returns true if can execute dodge"""
	return current_state == State.IDLE and cooldown_timer <= 0.0


func get_cooldown_percent() -> float:
	"""Returns cooldown progress (0-1)"""
	if cooldown_timer <= 0.0:
		return 0.0
	return cooldown_timer / COOLDOWN_DURATION


func get_cooldown_remaining() -> float:
	"""Returns cooldown time remaining"""
	return cooldown_timer
