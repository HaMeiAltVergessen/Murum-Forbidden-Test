extends Node
class_name GeistAI

## AI Controller for Geist (Melee Aggressor)
## Always chases player and attacks when in melee range

# ============================================================================
# CONSTANTS
# ============================================================================

const DETECTION_RANGE: float = 400.0
const ATTACK_RANGE: float = 80.0  # Melee range (will be extended by sprite stretch)
const MIN_DISTANCE: float = 60.0  # Stop moving when closer than this
const ATTACK_WINDUP: float = 0.3  # Wind-up before attack
const ATTACK_DURATION: float = 0.2  # Active attack hitbox
const ATTACK_RECOVERY: float = 0.2  # Recovery after attack
const ATTACK_COOLDOWN: float = 1.5  # Cooldown between attacks

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
var attack_timer: float = 0.0  # Timer for attack phases

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: CharacterBody2D
var player: CharacterBody2D
var base_scale: Vector2 = Vector2.ONE  # Store original sprite scale

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = owner as CharacterBody2D
	player = get_tree().get_first_node_in_group("player")

	# Defer base scale reading to next frame (scene properties need to be applied first)
	call_deferred("_initialize_base_scale")

	# Register with CombatManager
	if player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)


func _initialize_base_scale() -> void:
	"""Initialize base scale after scene is fully loaded"""
	# Store base scale from sprite (now that scene properties are applied)
	if owner_enemy and owner_enemy.animated_sprite:
		base_scale = owner_enemy.animated_sprite.scale
		print("[GeistAI] Initialized for %s with base_scale %v" % [owner_enemy.name, base_scale])
	else:
		print("[GeistAI] WARNING: Could not read base_scale, using default Vector2.ONE")

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

func _process_idle(delta: float) -> void:
	"""Idle state - determines next action"""

	# Ensure sprite is at base scale when idle
	if owner_enemy.animated_sprite and owner_enemy.animated_sprite.scale != base_scale:
		owner_enemy.animated_sprite.scale = base_scale

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	if distance > DETECTION_RANGE:
		# Out of range, stay idle
		owner_enemy.velocity = Vector2.ZERO
		return

	# Always chase player (melee aggressor behavior)
	current_state = State.CHASE
	print("[GeistAI] Player detected, chasing")

func _process_chase(delta: float) -> void:
	"""Chases player aggressively"""

	# Ensure sprite is at base scale when not attacking
	if owner_enemy.animated_sprite and owner_enemy.animated_sprite.scale != base_scale:
		owner_enemy.animated_sprite.scale = base_scale

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	# Check if in attack range
	if distance <= ATTACK_RANGE and can_attack():
		_start_attack()
		return

	# Stop if too close (within min_distance) - prevents running into player
	if distance < MIN_DISTANCE:
		owner_enemy.velocity = Vector2.ZERO
		# Still face the player
		var direction = (player.global_position - owner_enemy.global_position).normalized()
		_face_direction(direction)
		return

	# Move toward player
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()

	# Face player
	_face_direction(direction)

func _process_attack_windup(delta: float) -> void:
	"""Wind-up before attack - telegraphing"""

	attack_timer += delta

	# Visual feedback - glow intensity increases
	var intensity = attack_timer / ATTACK_WINDUP
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(
			1.0 + intensity * 0.5,
			1.0 + intensity * 0.5,
			1.0,
			0.7 + intensity * 0.3
		)

	# Stay in place while winding up
	owner_enemy.velocity = Vector2.ZERO

	# Face player
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	_face_direction(direction)

	# Check if windup complete
	if attack_timer >= ATTACK_WINDUP:
		_activate_attack()

func _process_attack_active(delta: float) -> void:
	"""Active attack phase - hitbox is active"""

	attack_timer += delta

	# Stretch sprite horizontally for extended reach
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.scale.x = base_scale.x * 2.0  # 2x stretch for more range
		owner_enemy.animated_sprite.scale.y = base_scale.y

	# Move slightly forward during attack
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * (owner_enemy.MOVE_SPEED * 1.5)
	owner_enemy.move_and_slide()

	# Enable hitbox
	if owner_enemy.hitbox:
		owner_enemy.hitbox.monitoring = true

	# Check if attack complete
	if attack_timer >= ATTACK_DURATION:
		_end_attack()

func _process_attack_recovery(delta: float) -> void:
	"""Recovery phase after attack"""

	attack_timer += delta

	# Reset sprite scale gradually
	if owner_enemy.animated_sprite:
		var t = attack_timer / ATTACK_RECOVERY
		owner_enemy.animated_sprite.scale.x = lerp(base_scale.x * 2.0, base_scale.x, t)
		owner_enemy.animated_sprite.scale.y = base_scale.y

	# Slow down
	owner_enemy.velocity = owner_enemy.velocity * 0.9

	# Check if recovery complete
	if attack_timer >= ATTACK_RECOVERY:
		_enter_cooldown()

func _process_attack_cooldown(delta: float) -> void:
	"""Waiting for cooldown - continue chasing"""

	var distance = owner_enemy.global_position.distance_to(player.global_position)

	# Continue chasing even during cooldown
	var direction = (player.global_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity = direction * owner_enemy.MOVE_SPEED
	owner_enemy.move_and_slide()
	_face_direction(direction)

	# Check if cooldown done
	if attack_cooldown_remaining <= 0.0:
		current_state = State.CHASE
		print("[GeistAI] Cooldown finished, resuming chase")

# ============================================================================
# ATTACK LOGIC
# ============================================================================

func can_attack() -> bool:
	"""Returns true if can attack"""
	return attack_cooldown_remaining <= 0.0

func _start_attack() -> void:
	"""Starts melee attack"""

	print("[GeistAI] Starting melee attack!")

	current_state = State.ATTACK_WINDUP
	attack_timer = 0.0

	# Animation
	if owner_enemy.animated_sprite and owner_enemy.animated_sprite.has_method("play"):
		owner_enemy.animated_sprite.play("attack")

	# Audio (wind-up sound)
	AudioManager.play_sfx("enemies/geist_attack_windup", 0.12)

func _activate_attack() -> void:
	"""Activates the attack hitbox"""

	print("[GeistAI] Attack active!")

	current_state = State.ATTACK_ACTIVE
	attack_timer = 0.0

	# Reset glow, brighten for active attack
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)

	# Audio (attack swing)
	AudioManager.play_sfx("enemies/geist_attack", 0.15)

func _end_attack() -> void:
	"""Ends active attack phase"""

	print("[GeistAI] Attack ending, entering recovery")

	current_state = State.ATTACK_RECOVERY
	attack_timer = 0.0

	# Disable hitbox
	if owner_enemy.hitbox:
		owner_enemy.hitbox.monitoring = false

	# Reset glow
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

func _enter_cooldown() -> void:
	"""Enters attack cooldown"""

	print("[GeistAI] Entering cooldown (%.1fs)" % ATTACK_COOLDOWN)

	current_state = State.ATTACK_COOLDOWN
	attack_cooldown_remaining = ATTACK_COOLDOWN
	attack_timer = 0.0

	# Ensure sprite is fully reset to base scale
	if owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.scale = base_scale
		owner_enemy.animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

# ============================================================================
# UTILITY
# ============================================================================

func _face_direction(direction: Vector2) -> void:
	"""Flips sprite based on direction"""
	if owner_enemy.animated_sprite and "flip_h" in owner_enemy.animated_sprite:
		owner_enemy.animated_sprite.flip_h = direction.x < 0

func cancel_attack() -> void:
	"""Cancels current attack (called by stun)"""
	if current_state in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY]:
		print("[GeistAI] Attack canceled (stun)")
		current_state = State.IDLE
		attack_timer = 0.0

		# Disable hitbox
		if owner_enemy.hitbox:
			owner_enemy.hitbox.monitoring = false

		# Reset sprite to base scale
		if owner_enemy.animated_sprite:
			owner_enemy.animated_sprite.scale = base_scale
			owner_enemy.animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)

func get_state_name() -> String:
	"""Returns state name (debug)"""
	match current_state:
		State.IDLE: return "IDLE"
		State.CHASE: return "CHASE"
		State.ATTACK_WINDUP: return "ATTACK_WINDUP"
		State.ATTACK_ACTIVE: return "ATTACK_ACTIVE"
		State.ATTACK_RECOVERY: return "ATTACK_RECOVERY"
		State.ATTACK_COOLDOWN: return "ATTACK_COOLDOWN"
		_: return "UNKNOWN"
