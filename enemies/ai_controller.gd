extends Node
## AIController - State machine for enemy AI behavior
class_name AIController

# ============ AI STATES ============
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK
}

# ============ REFERENCES ============
@onready var enemy: BaseEnemy = get_parent() as BaseEnemy

# ============ STATE ============
var current_state: State = State.IDLE
var state_time: float = 0.0

# ============ CONFIGURATION ============
@export var idle_duration: float = 2.0
@export var attack_cooldown: float = 1.5

# ============ TIMERS ============
var attack_timer: float = 0.0


func _ready() -> void:
	if not enemy:
		push_error("[AIController] Parent must be BaseEnemy")
		return

	print("[AIController] Initialized for ", enemy.name)


func _process(delta: float) -> void:
	if not enemy or enemy.is_dead:
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
		State.ATTACK:
			_process_attack(delta)


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
	"""Enemy moves toward player"""
	# Check if player lost
	if not enemy.has_target():
		_change_state(State.IDLE)
		return

	var distance: float = enemy.get_distance_to_player()

	# Check if in attack range
	if distance <= enemy.attack_range:
		_change_state(State.ATTACK)
		return

	# Move toward player
	var direction: Vector2 = enemy.get_direction_to_player()
	enemy.velocity.x = direction.x * enemy.move_speed

	# Flip sprite based on direction
	if enemy.sprite and direction.x != 0:
		enemy.sprite.flip_h = direction.x < 0


# ============ STATE: ATTACK ============
func _process_attack(_delta: float) -> void:
	"""Enemy performs melee attack"""
	# Check if player moved out of range
	if not enemy.has_target():
		_change_state(State.IDLE)
		return

	var distance: float = enemy.get_distance_to_player()

	if distance > enemy.attack_range * 1.5:
		_change_state(State.CHASE)
		return

	# Stop movement
	enemy.velocity.x = 0

	# Perform attack if cooldown ready
	if attack_timer <= 0:
		_perform_attack()


func _perform_attack() -> void:
	"""Executes an attack"""
	attack_timer = attack_cooldown

	# Activate hitbox briefly
	if enemy.hitbox:
		enemy.hitbox.set_damage(enemy.attack_damage)
		enemy.hitbox.activate()

		# Deactivate after short duration
		await get_tree().create_timer(0.3).timeout
		if enemy.hitbox:
			enemy.hitbox.deactivate()

	# Play attack sound
	AudioManager.play_sfx("enemy_hurt", 0.2)  # Use hurt sound with pitch variation

	print("[AIController] ", enemy.name, " attacked!")


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
		State.ATTACK:
			enemy.velocity.x = 0


func _exit_state(_state: State) -> void:
	"""Called when exiting a state"""
	pass


func _state_to_string(state: State) -> String:
	"""Converts state enum to string"""
	match state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.CHASE: return "CHASE"
		State.ATTACK: return "ATTACK"
	return "UNKNOWN"
