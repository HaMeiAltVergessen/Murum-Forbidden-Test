extends Node
class_name GeistAI

## AI Controller for Geist (Ranged Kiter)
## Maintains preferred distance and fires projectiles

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 400.0
const PREFERRED_DISTANCE: float = 200.0
const MIN_DISTANCE: float = 150.0
const MAX_DISTANCE: float = 300.0
const ATTACK_RANGE: float = 350.0
const ATTACK_COOLDOWN: float = 2.5
const CHARGE_DURATION: float = 0.6

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	APPROACH,
	KITE,
	ATTACK_CHARGE,
	ATTACK_SHOOT,
	ATTACK_COOLDOWN
}

var current_state: State = State.IDLE
var attack_cooldown_remaining: float = 0.0
var charge_progress: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: CharacterBody2D
var player: CharacterBody2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = owner as CharacterBody2D
	player = get_tree().get_first_node_in_group("player")

	# Register with CombatManager
	if player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)

	print("[GeistAI] Initialized for %s" % (owner_enemy.name if owner_enemy else "unknown"))

# ============================================================================
# AI UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or not player:
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
		State.APPROACH:
			_process_approach(delta)
		State.KITE:
			_process_kite(delta)
		State.ATTACK_CHARGE:
			_process_attack_charge(delta)
		State.ATTACK_SHOOT:
			_process_attack_shoot(delta)
		State.ATTACK_COOLDOWN:
			_process_attack_cooldown(delta)

# ============================================================================
# STATE PROCESSING
# ============================================================================

func _process_idle(delta: float) -> void:
	"""Idle state - determines next action"""

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	if distance > DETECTION_RANGE:
		# Out of range, stay idle
		owner_enemy.velocity = Vector2.ZERO
		return

	# Determine state based on distance
	if distance < MIN_DISTANCE:
		# Too close, kite away
		current_state = State.KITE
		print("[GeistAI] Player too close (%.0fpx), kiting" % distance)
	elif distance > MAX_DISTANCE:
		# Too far, approach
		current_state = State.APPROACH
		print("[GeistAI] Player too far (%.0fpx), approaching" % distance)
	elif can_attack():
		# In range and can attack
		current_state = State.ATTACK_CHARGE
		_start_charging()
	else:
		# In range but on cooldown
		owner_enemy.velocity = Vector2.ZERO

func _process_approach(delta: float) -> void:
	"""Moves closer to player"""

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	# Check if in range now
	if distance <= PREFERRED_DISTANCE:
		current_state = State.IDLE
		owner_enemy.velocity = Vector2.ZERO
		return

	# Move toward player
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()

	# Face player
	_face_direction(direction)

func _process_kite(delta: float) -> void:
	"""Moves away from player (kiting)"""

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	# Check if safe distance reached
	if distance >= PREFERRED_DISTANCE:
		current_state = State.IDLE
		owner_enemy.velocity = Vector2.ZERO
		return

	# Move away from player
	var direction = (owner_enemy.global_position - player.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()

	# Face player (still look at target while backing away)
	var look_direction = (player.global_position - owner_enemy.global_position).normalized()
	_face_direction(look_direction)

func _process_attack_charge(delta: float) -> void:
	"""Charging attack"""

	charge_progress += delta

	# Update glow intensity
	var intensity = charge_progress / CHARGE_DURATION
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(
			1.0 + intensity * 0.5,
			1.0 + intensity * 0.5,
			1.5,
			0.7
		)

	# Stay in place while charging
	owner_enemy.velocity = Vector2.ZERO

	# Face player
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	_face_direction(direction)

	# Check if charge complete
	if charge_progress >= CHARGE_DURATION:
		_shoot_projectile()

func _process_attack_shoot(delta: float) -> void:
	"""Projectile shot, brief pause"""

	# This state is brief, immediately go to cooldown
	current_state = State.ATTACK_COOLDOWN
	attack_cooldown_remaining = ATTACK_COOLDOWN

	print("[GeistAI] Entering cooldown (%.1fs)" % ATTACK_COOLDOWN)

func _process_attack_cooldown(delta: float) -> void:
	"""Waiting for cooldown - can still move"""

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	# Still maintain distance during cooldown
	if distance < MIN_DISTANCE:
		# Too close, kite
		var direction = (owner_enemy.global_position - player.global_position).normalized()
		owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
		owner_enemy.move_and_slide()
		_face_direction(-direction)
	elif distance > MAX_DISTANCE:
		# Too far, approach
		var direction = (player.global_position - owner_enemy.global_position).normalized()
		owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
		owner_enemy.move_and_slide()
		_face_direction(direction)
	else:
		# In range, stay put
		owner_enemy.velocity = Vector2.ZERO

	# Check if cooldown done
	if attack_cooldown_remaining <= 0.0:
		current_state = State.IDLE
		print("[GeistAI] Cooldown finished, returning to IDLE")

# ============================================================================
# ATTACK LOGIC
# ============================================================================

func can_attack() -> bool:
	"""Returns true if can attack"""
	if attack_cooldown_remaining > 0.0:
		return false

	var distance = owner_enemy.global_position.distance_to(player.global_position)
	if distance > ATTACK_RANGE:
		return false

	return true

func _start_charging() -> void:
	"""Starts attack charge"""
	charge_progress = 0.0

	# Animation
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.play("attack_charge")

	# Audio
	AudioManager.play_sfx("enemies/geist_charge", 0.1)

	print("[GeistAI] Charging attack (%.1fs)" % CHARGE_DURATION)

func _shoot_projectile() -> void:
	"""Fires projectile"""

	print("[GeistAI] Shooting projectile!")

	# Reset glow
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

	# Calculate direction to player
	var direction = (player.global_position - owner_enemy.global_position).normalized()

	# Spawn projectile
	var projectile_scene = load("res://enemies/projectile.tscn")
	if not projectile_scene:
		print("[GeistAI] ERROR: Could not load projectile scene!")
		current_state = State.IDLE
		return

	var projectile = projectile_scene.instantiate()

	# Setup projectile
	projectile.global_position = owner_enemy.global_position
	projectile.direction = direction
	projectile.speed = 250.0
	projectile.damage = owner_enemy.DAMAGE
	projectile.shooter = owner_enemy

	# Add to scene tree
	get_tree().root.add_child(projectile)

	# Audio
	AudioManager.play_sfx("enemies/geist_shoot", 0.15)

	# State transition
	current_state = State.ATTACK_SHOOT

# ============================================================================
# UTILITY
# ============================================================================

func _face_direction(direction: Vector2) -> void:
	"""Flips sprite based on direction"""
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.flip_h = direction.x < 0

func cancel_attack() -> void:
	"""Cancels current attack (called by stun)"""
	if current_state in [State.ATTACK_CHARGE, State.ATTACK_SHOOT]:
		print("[GeistAI] Attack canceled (stun)")
		current_state = State.IDLE
		charge_progress = 0.0

		# Reset glow
		if owner_enemy.animated_sprite:
			owner_enemy.animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

func get_state_name() -> String:
	"""Returns state name (debug)"""
	match current_state:
		State.IDLE: return "IDLE"
		State.APPROACH: return "APPROACH"
		State.KITE: return "KITE"
		State.ATTACK_CHARGE: return "ATTACK_CHARGE"
		State.ATTACK_SHOOT: return "ATTACK_SHOOT"
		State.ATTACK_COOLDOWN: return "ATTACK_COOLDOWN"
		_: return "UNKNOWN"
