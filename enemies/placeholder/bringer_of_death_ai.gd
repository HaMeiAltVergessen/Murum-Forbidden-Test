extends Node
class_name BringerOfDeathAI

## AI Controller for Bringer of Death (Melee Aggressor)
## Chases both P1 and P2, attacks when in range
## Godot 4.4 compatible

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 400.0
const ATTACK_RANGE: float = 80.0
const MIN_DISTANCE: float = 60.0
const ATTACK_WINDUP: float = 0.4
const ATTACK_DURATION: float = 0.3
const ATTACK_RECOVERY: float = 0.3
const ATTACK_COOLDOWN: float = 2.0

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	ATTACK_COOLDOWN
}

var current_state: State = State.IDLE
var attack_cooldown_remaining: float = 0.0
var attack_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: CharacterBody2D
var target_player: CharacterBody2D
var base_scale: Vector2 = Vector2.ONE

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = owner as CharacterBody2D
	call_deferred("_find_player")

func _find_player() -> void:
	"""Finds closest player (P1 or P2)"""
	# Try P1 first
	target_player = get_tree().get_first_node_in_group("player")

	# If no P1, try P2
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player2")

	# Register with CombatManager
	if target_player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)

	# Store base scale
	if owner_enemy and owner_enemy.animated_sprite:
		base_scale = owner_enemy.animated_sprite.scale

	print("[BringerOfDeathAI] Initialized, target: %s" % (target_player.name if target_player else "none"))

# ============================================================================
# AI UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or not target_player:
		# Try to find player again
		if not target_player:
			_find_player()
		return

	# Skip when owner stunned
	if owner_enemy.is_stunned:
		owner_enemy.velocity = Vector2.ZERO
		return

	# Update cooldown
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining -= delta

	# State machine
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_ACTIVE:
			_process_attack_active(delta)
		State.ATTACK_RECOVERY:
			_process_attack_recovery(delta)
		State.ATTACK_COOLDOWN:
			_process_attack_cooldown(delta)

# ============================================================================
# STATE PROCESSING
# ============================================================================

func _process_idle(_delta: float) -> void:
	"""Idle state"""
	if owner_enemy.animated_sprite and owner_enemy.animated_sprite.scale != base_scale:
		owner_enemy.animated_sprite.scale = base_scale

	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	if distance > DETECTION_RANGE:
		owner_enemy.velocity = Vector2.ZERO
		return

	current_state = State.CHASE

func _process_chase(_delta: float) -> void:
	"""Chases player"""
	if owner_enemy.animated_sprite and owner_enemy.animated_sprite.scale != base_scale:
		owner_enemy.animated_sprite.scale = base_scale

	var distance = owner_enemy.global_position.distance_to(target_player.global_position)

	# Check if in attack range
	if distance <= ATTACK_RANGE and can_attack():
		_start_attack()
		return

	# Stop if too close
	if distance < MIN_DISTANCE:
		owner_enemy.velocity = Vector2.ZERO
		var direction = (target_player.global_position - owner_enemy.global_position).normalized()
		_face_direction(direction)
		return

	# Move toward player
	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()
	_face_direction(direction)

func _process_attack_windup(delta: float) -> void:
	"""Wind-up before attack"""
	attack_timer += delta

	# Visual feedback
	var intensity = attack_timer / ATTACK_WINDUP
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(
			1.0 + intensity * 0.5,
			1.0,
			1.0,
			1.0
		)

	owner_enemy.velocity = Vector2.ZERO

	# Face player
	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	_face_direction(direction)

	if attack_timer >= ATTACK_WINDUP:
		_activate_attack()

func _process_attack_active(delta: float) -> void:
	"""Active attack phase"""
	attack_timer += delta

	# Stretch sprite for reach
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.scale.x = base_scale.x * 2.0
		owner_enemy.animated_sprite.scale.y = base_scale.y

	# Move forward during attack
	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * (owner_enemy.MOVE_SPEED * 1.5)
	owner_enemy.move_and_slide()

	# Enable hitbox
	if owner_enemy.hitbox:
		owner_enemy.hitbox.monitoring = true

	if attack_timer >= ATTACK_DURATION:
		_end_attack()

func _process_attack_recovery(delta: float) -> void:
	"""Recovery phase"""
	attack_timer += delta

	# Reset sprite scale
	if owner_enemy.animated_sprite:
		var t = attack_timer / ATTACK_RECOVERY
		owner_enemy.animated_sprite.scale.x = lerp(base_scale.x * 2.0, base_scale.x, t)
		owner_enemy.animated_sprite.scale.y = base_scale.y

	owner_enemy.velocity = owner_enemy.velocity * 0.9

	if attack_timer >= ATTACK_RECOVERY:
		_enter_cooldown()

func _process_attack_cooldown(_delta: float) -> void:
	"""Cooldown - continue chasing"""
	var direction = (target_player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()
	_face_direction(direction)

	if attack_cooldown_remaining <= 0.0:
		current_state = State.CHASE

# ============================================================================
# ATTACK LOGIC
# ============================================================================

func can_attack() -> bool:
	return attack_cooldown_remaining <= 0.0

func _start_attack() -> void:
	current_state = State.ATTACK_WINDUP
	attack_timer = 0.0

	if AudioManager:
		AudioManager.play_sfx("enemies/geist_attack_windup", 0.12)

func _activate_attack() -> void:
	current_state = State.ATTACK_ACTIVE
	attack_timer = 0.0

	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(1.5, 1.0, 1.0, 1.0)

	if AudioManager:
		AudioManager.play_sfx("enemies/geist_attack", 0.15)

func _end_attack() -> void:
	current_state = State.ATTACK_RECOVERY
	attack_timer = 0.0

	if owner_enemy.hitbox:
		owner_enemy.hitbox.monitoring = false

	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color.WHITE

func _enter_cooldown() -> void:
	current_state = State.ATTACK_COOLDOWN
	attack_cooldown_remaining = ATTACK_COOLDOWN
	attack_timer = 0.0

	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.scale = base_scale
		owner_enemy.animated_sprite.modulate = Color.WHITE

# ============================================================================
# UTILITY
# ============================================================================

func _face_direction(direction: Vector2) -> void:
	if owner_enemy.animated_sprite and "flip_h" in owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.flip_h = direction.x < 0

func cancel_attack() -> void:
	if current_state in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY]:
		current_state = State.IDLE
		attack_timer = 0.0

		if owner_enemy.hitbox:
			owner_enemy.hitbox.monitoring = false

		if owner_enemy.animated_sprite:
			owner_enemy.animated_sprite.scale = base_scale
			owner_enemy.animated_sprite.modulate = Color.WHITE
