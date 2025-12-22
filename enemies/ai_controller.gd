extends Node
## AIController - State machine for enemy AI behavior
class_name AIController

# ============ AI STATES ============
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK_WINDUP,  # Telegraph before attack
	ATTACK_STRIKE,  # Actual attack with hitbox
	RECOVERY,       # After attack recovery
	ATTACK_COOLDOWN # Cooldown while continuing to chase
}

# ============ REFERENCES ============
@onready var enemy: BaseEnemy = get_parent() as BaseEnemy

# ============ STATE ============
var current_state: State = State.IDLE
var state_time: float = 0.0

# ============ CONFIGURATION ============
@export var idle_duration: float = 2.0
@export var attack_cooldown: float = 1.5
@export var min_distance: float = 60.0  # Stop moving when closer than this

# ============ ATTACK TIMING ============
@export var windup_duration: float = 0.6  # Telegraph duration (extended for spatial parry system)
@export var strike_duration: float = 0.2  # Hitbox active time
@export var recovery_duration: float = 0.3  # Post-attack recovery

# ============ TIMERS ============
var attack_timer: float = 0.0
var attack_hitbox_active: bool = false


func _ready() -> void:
	if not enemy:
		push_error("[AIController] Parent must be BaseEnemy")
		return

	print("[AIController] Initialized for ", enemy.name)


func _process(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return

	# Skip AI wenn stunned
	if enemy.is_stunned:
		return

	state_time += delta

	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta

	# Process current state
	match current_state:
		State.IDLE:
			_process_idle()
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_STRIKE:
			_process_attack_strike(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.ATTACK_COOLDOWN:
			_process_attack_cooldown(delta)


# ============ STATE: IDLE ============
func _process_idle() -> void:
	"""Enemy stands still, looking for player"""
	# Check for player
	if enemy.has_target():
		_change_state(State.CHASE)
		return

	# Stay idle
	enemy.velocity.x = 0


# ============ STATE: PATROL ============
func _process_patrol(_delta: float) -> void:
	"""Enemy walks back and forth (optional for vertical slice)"""
	# Check for player
	if enemy.has_target():
		_change_state(State.CHASE)
		return

	# For vertical slice, just stay idle
	_change_state(State.IDLE)


# ============ STATE: CHASE ============
func _process_chase(_delta: float) -> void:
	"""Enemy moves toward player aggressively"""
	# Check if player lost
	if not enemy.has_target():
		_change_state(State.IDLE)
		return

	var distance: float = enemy.get_distance_to_player()

	# Check if in attack range and cooldown ready
	if distance <= enemy.attack_range and attack_timer <= 0:
		_change_state(State.ATTACK_WINDUP)
		return

	# Stop if too close (within min_distance) - prevents running into player
	if distance < min_distance:
		enemy.velocity.x = 0
		# Still face the player
		var direction: Vector2 = enemy.get_direction_to_player()
		if enemy.sprite and direction.x != 0:
			enemy.sprite.flip_h = direction.x < 0
		return

	# Always chase player (even if on cooldown)
	var direction: Vector2 = enemy.get_direction_to_player()
	enemy.velocity.x = direction.x * enemy.move_speed

	# Flip sprite based on direction
	if enemy.sprite and direction.x != 0:
		enemy.sprite.flip_h = direction.x < 0


# ============ STATE: ATTACK WINDUP ============
func _process_attack_windup(_delta: float) -> void:
	"""Enemy telegraphs attack (windup animation)"""
	# Stop movement
	enemy.velocity.x = 0

	# Check if windup complete
	if state_time >= windup_duration:
		_change_state(State.ATTACK_STRIKE)


# ============ STATE: ATTACK STRIKE ============
func _process_attack_strike(_delta: float) -> void:
	"""Enemy executes attack (hitbox active)"""
	# Stop movement
	enemy.velocity.x = 0

	# Check if strike complete
	if state_time >= strike_duration:
		_change_state(State.RECOVERY)


# ============ STATE: RECOVERY ============
func _process_recovery(_delta: float) -> void:
	"""Enemy recovers after attack while continuing to chase"""
	# Continue chasing even during recovery (aggressive behavior)
	if enemy.has_target():
		var direction: Vector2 = enemy.get_direction_to_player()
		enemy.velocity.x = direction.x * enemy.move_speed * 0.5  # Half speed during recovery
	else:
		enemy.velocity.x = 0

	# Check if recovery complete
	if state_time >= recovery_duration:
		# Start attack cooldown
		attack_timer = attack_cooldown
		_change_state(State.ATTACK_COOLDOWN)  # Enter cooldown state


# ============ STATE: ATTACK_COOLDOWN ============
func _process_attack_cooldown(_delta: float) -> void:
	"""Cooldown after attack - continue chasing player"""
	# Check if player lost
	if not enemy.has_target():
		_change_state(State.IDLE)
		return

	var distance: float = enemy.get_distance_to_player()

	# Continue chasing even during cooldown (aggressive like Geist)
	# Stop if too close (within min_distance)
	if distance < min_distance:
		enemy.velocity.x = 0
		# Still face the player
		var direction: Vector2 = enemy.get_direction_to_player()
		if enemy.sprite and direction.x != 0:
			enemy.sprite.flip_h = direction.x < 0
	else:
		# Move toward player
		var direction: Vector2 = enemy.get_direction_to_player()
		enemy.velocity.x = direction.x * enemy.move_speed

		# Flip sprite based on direction
		if enemy.sprite and direction.x != 0:
			enemy.sprite.flip_h = direction.x < 0

	# Check if cooldown complete
	if attack_timer <= 0.0:
		_change_state(State.CHASE)
		print("[AIController] %s cooldown finished, resuming chase" % enemy.name)


# ============ STATE MANAGEMENT ============
func _change_state(new_state: State) -> void:
	"""Changes to a new state"""
	if current_state == new_state:
		return

	# Exit current state
	_exit_state(current_state)

	# Enter new state
	current_state = new_state
	state_time = 0.0
	_enter_state(new_state)

	print("[AIController] ", enemy.name, " -> ", _state_to_string(new_state))


func _enter_state(state: State) -> void:
	"""Called when entering a state"""
	match state:
		State.IDLE:
			enemy.velocity.x = 0
		State.ATTACK_WINDUP:
			enemy.velocity.x = 0
			_start_attack_windup()
		State.ATTACK_STRIKE:
			_activate_attack_hitbox()
		State.RECOVERY:
			_deactivate_attack_hitbox()


func _exit_state(_state: State) -> void:
	"""Called when exiting a state"""
	pass


func _state_to_string(state: State) -> String:
	"""Converts state enum to string"""
	match state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.CHASE: return "CHASE"
		State.ATTACK_WINDUP: return "ATTACK_WINDUP"
		State.ATTACK_STRIKE: return "ATTACK_STRIKE"
		State.RECOVERY: return "RECOVERY"
		State.ATTACK_COOLDOWN: return "ATTACK_COOLDOWN"
	return "UNKNOWN"


# ============ ATTACK EXECUTION ============
func _start_attack_windup() -> void:
	"""Starts attack windup (telegraph)"""
	print("[AIController] %s starting attack windup" % enemy.name)

	# Play windup sound
	AudioManager.play_sfx("enemy_attack_windup", 0.1)

	# Windup animation: Pull back and grow slightly
	if enemy.sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		# Pull back (offset position)
		var pull_direction = -1 if enemy.sprite.flip_h else 1
		tween.tween_property(enemy.sprite, "position:x", pull_direction * -8, windup_duration * 0.6)
		# Grow slightly (charge up)
		tween.tween_property(enemy.sprite, "scale", Vector2(1.15, 1.15), windup_duration * 0.6)
		# Flash color (charging)
		tween.tween_property(enemy.sprite, "modulate", Color(1.3, 0.9, 0.9), windup_duration * 0.5)


func _activate_attack_hitbox() -> void:
	"""Activates attack hitbox (strike phase)"""
	print("[AIController] %s executing attack strike" % enemy.name)

	# Activate hitbox
	if enemy.hitbox:
		enemy.hitbox.set_damage(enemy.attack_damage)
		enemy.hitbox.activate()
		attack_hitbox_active = true

	# Play attack sound
	AudioManager.play_sfx("enemy_attack", 0.15)

	# Strike animation: Lunge forward with 2x horizontal stretch
	if enemy.sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		# Lunge forward (offset position)
		var lunge_direction = 1 if enemy.sprite.flip_h else -1
		tween.tween_property(enemy.sprite, "position:x", lunge_direction * -15, strike_duration)
		# STRETCH 2x horizontally for extended range (like Geist)
		tween.tween_property(enemy.sprite, "scale", Vector2(2.0, 1.0), strike_duration * 0.5)
		# Flash bright (impact)
		tween.tween_property(enemy.sprite, "modulate", Color(1.5, 1.2, 1.2), strike_duration * 0.3)

	# Move forward during attack for extra reach
	var direction: Vector2 = enemy.get_direction_to_player()
	enemy.velocity.x = direction.x * enemy.move_speed * 1.5


func _deactivate_attack_hitbox() -> void:
	"""Deactivates attack hitbox (recovery phase)"""
	print("[AIController] %s entering recovery" % enemy.name)

	# Deactivate hitbox
	if enemy.hitbox and attack_hitbox_active:
		enemy.hitbox.deactivate()
		attack_hitbox_active = false

	# Recovery animation: Return to neutral position
	if enemy.sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		# Return to center position
		tween.tween_property(enemy.sprite, "position:x", 0.0, recovery_duration)
		# Return to normal size
		tween.tween_property(enemy.sprite, "scale", Vector2(1.0, 1.0), recovery_duration)
		# Return to normal color
		tween.tween_property(enemy.sprite, "modulate", Color.WHITE, recovery_duration)


func cancel_attack() -> void:
	"""Cancels current attack (called by stun)"""
	if current_state in [State.ATTACK_WINDUP, State.ATTACK_STRIKE, State.RECOVERY]:
		print("[AIController] %s attack cancelled" % enemy.name)

		# Deactivate hitbox
		if enemy.hitbox and attack_hitbox_active:
			enemy.hitbox.deactivate()
			attack_hitbox_active = false

		# Return to idle
		_change_state(State.IDLE)
