extends Node
class_name GuardianStatueAI

## AI Controller for Wächterstatue (Guardian Statue)
## Dormant stone knight that activates when player enters range.
## 3 distance-based attacks:
##   - Shield Bash (close, <80px): Fast, stuns player 1s
##   - Horizontal Swing (medium, <150px): Standard attack, high knockback
##   - Overhead Slam (far, <200px): Slow, AoE ground wave

# ============================================================================
# CONSTANTS
# ============================================================================

const ATTACK_RANGE_SHIELD: float = 80.0   # Close range -> Shield Bash
const ATTACK_RANGE_HORIZONTAL: float = 150.0  # Medium range -> Horizontal Swing
const ATTACK_RANGE_OVERHEAD: float = 200.0  # Far range -> Overhead Slam

const ACTIVATION_TIME: float = 1.5  # Eyes glow -> awaken animation

# Shield Bash timing
const SHIELD_WINDUP: float = 0.8
const SHIELD_STRIKE: float = 0.2
const SHIELD_RECOVERY: float = 1.0

# Horizontal Swing timing
const HORIZONTAL_WINDUP: float = 1.2
const HORIZONTAL_STRIKE: float = 0.3
const HORIZONTAL_RECOVERY: float = 1.0

# Overhead Slam timing
const OVERHEAD_WINDUP: float = 1.8
const OVERHEAD_STRIKE: float = 0.4
const OVERHEAD_RECOVERY: float = 1.0
const OVERHEAD_AOE_DELAY: float = 0.2  # Delay before ground wave

const ATTACK_COOLDOWN: float = 1.5
const MIN_DISTANCE: float = 40.0
const RETURN_SPEED: float = 30.0  # Even slower when returning

# ============================================================================
# ENUMS
# ============================================================================

enum State {
	DORMANT,         # Standing still like decoration
	ACTIVATING,      # Eyes glow, awakening animation
	IDLE,            # Awake, looking for target
	CHASE,           # Moving toward player
	ATTACK_WINDUP,   # Telegraph current attack
	ATTACK_STRIKE,   # Active hitbox
	ATTACK_RECOVERY, # Post-attack vulnerable window
	ATTACK_COOLDOWN, # Waiting for next attack
	RETURNING        # Walking back to spawn position
}

enum AttackType {
	NONE,
	SHIELD_BASH,
	HORIZONTAL_SWING,
	OVERHEAD_SLAM
}

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.DORMANT
var current_attack: AttackType = AttackType.NONE
var state_timer: float = 0.0
var attack_cooldown_remaining: float = 0.0
var base_scale: Vector2 = Vector2.ONE

# Attack timing (set per attack type)
var current_windup: float = 0.0
var current_strike: float = 0.0
var current_recovery: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: GuardianStatue
var player: CharacterBody2D

# AoE hitbox for overhead slam ground wave
var aoe_hitbox: Area2D = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = get_parent() as GuardianStatue
	player = get_tree().get_first_node_in_group("player")

	call_deferred("_initialize_base_scale")

	# Register with CombatManager
	if player and owner_enemy:
		CombatManager.register_enemy(owner_enemy)


func _initialize_base_scale() -> void:
	if owner_enemy and owner_enemy.sprite:
		base_scale = owner_enemy.sprite.scale
		print("[GuardianStatueAI] Initialized with base_scale %v" % base_scale)


# ============================================================================
# AI UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or owner_enemy.is_dead:
		return

	if owner_enemy.is_stunned:
		owner_enemy.velocity.x = 0
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining -= delta

	state_timer += delta

	match current_state:
		State.DORMANT:
			_process_dormant()
		State.ACTIVATING:
			_process_activating()
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK_WINDUP:
			_process_attack_windup()
		State.ATTACK_STRIKE:
			_process_attack_strike()
		State.ATTACK_RECOVERY:
			_process_attack_recovery()
		State.ATTACK_COOLDOWN:
			_process_attack_cooldown()
		State.RETURNING:
			_process_returning()


# ============================================================================
# STATE: DORMANT
# ============================================================================

func _process_dormant() -> void:
	"""Standing still like a statue, waiting for player"""
	owner_enemy.velocity = Vector2.ZERO

	if owner_enemy.has_target():
		var distance = owner_enemy.get_distance_to_player()
		if distance <= owner_enemy.DETECTION_RANGE:
			_change_state(State.ACTIVATING)
			print("[GuardianStatueAI] Player detected! Activating...")


# ============================================================================
# STATE: ACTIVATING
# ============================================================================

func _process_activating() -> void:
	"""Eyes glow red, awakening animation (1.5s)"""
	owner_enemy.velocity = Vector2.ZERO

	# Visual: progressive red eye glow
	var progress = state_timer / ACTIVATION_TIME
	if owner_enemy.sprite:
		owner_enemy.sprite.modulate = Color(
			1.0 + progress * 1.0,  # Red glow increases
			1.0 - progress * 0.5,
			1.0 - progress * 0.5,
			1.0
		)

	if state_timer >= ACTIVATION_TIME:
		# Reset color
		if owner_enemy.sprite:
			owner_enemy.sprite.modulate = Color.WHITE
		_change_state(State.CHASE)
		print("[GuardianStatueAI] Awakened!")


# ============================================================================
# STATE: IDLE
# ============================================================================

func _process_idle() -> void:
	owner_enemy.velocity.x = 0

	if owner_enemy.has_target():
		_change_state(State.CHASE)
	elif owner_enemy.get_distance_to_spawn() > 10.0:
		_change_state(State.RETURNING)


# ============================================================================
# STATE: CHASE
# ============================================================================

func _process_chase() -> void:
	# Check deaggro
	if not owner_enemy.has_target():
		_change_state(State.RETURNING)
		return

	var distance = owner_enemy.get_distance_to_player()

	# Deaggro if player is too far
	if distance > owner_enemy.DEAGGRO_RANGE:
		_change_state(State.RETURNING)
		return

	# Check if in attack range (distance-based attack selection)
	if attack_cooldown_remaining <= 0:
		if distance <= ATTACK_RANGE_SHIELD:
			_start_attack(AttackType.SHIELD_BASH)
			return
		elif distance <= ATTACK_RANGE_HORIZONTAL:
			_start_attack(AttackType.HORIZONTAL_SWING)
			return
		elif distance <= ATTACK_RANGE_OVERHEAD:
			_start_attack(AttackType.OVERHEAD_SLAM)
			return

	# Move toward player (very slowly)
	if distance > MIN_DISTANCE:
		var direction = owner_enemy.get_direction_to_player()
		owner_enemy.velocity.x = direction.x * owner_enemy.MOVE_SPEED
		_face_direction(direction)
	else:
		owner_enemy.velocity.x = 0
		var direction = owner_enemy.get_direction_to_player()
		_face_direction(direction)


# ============================================================================
# STATE: ATTACK WINDUP
# ============================================================================

func _process_attack_windup() -> void:
	"""Telegraph phase - completely immobile"""
	owner_enemy.velocity = Vector2.ZERO

	# Face player during windup
	var direction = owner_enemy.get_direction_to_player()
	_face_direction(direction)

	# Visual telegraph based on attack type
	var progress = state_timer / current_windup
	_apply_windup_visual(progress)

	if state_timer >= current_windup:
		_change_state(State.ATTACK_STRIKE)


# ============================================================================
# STATE: ATTACK STRIKE
# ============================================================================

func _process_attack_strike() -> void:
	"""Active hitbox phase - immobile"""
	owner_enemy.velocity = Vector2.ZERO

	if state_timer >= current_strike:
		# Handle Overhead Slam AoE
		if current_attack == AttackType.OVERHEAD_SLAM:
			_spawn_ground_wave()

		_change_state(State.ATTACK_RECOVERY)


# ============================================================================
# STATE: ATTACK RECOVERY
# ============================================================================

func _process_attack_recovery() -> void:
	"""Post-attack vulnerable window - immobile"""
	owner_enemy.velocity = Vector2.ZERO

	# Gradual visual reset
	var progress = state_timer / current_recovery
	_apply_recovery_visual(progress)

	if state_timer >= current_recovery:
		attack_cooldown_remaining = ATTACK_COOLDOWN
		_change_state(State.ATTACK_COOLDOWN)


# ============================================================================
# STATE: ATTACK COOLDOWN
# ============================================================================

func _process_attack_cooldown() -> void:
	if not owner_enemy.has_target():
		_change_state(State.RETURNING)
		return

	var distance = owner_enemy.get_distance_to_player()

	if distance > owner_enemy.DEAGGRO_RANGE:
		_change_state(State.RETURNING)
		return

	# Slow chase during cooldown
	if distance > MIN_DISTANCE:
		var direction = owner_enemy.get_direction_to_player()
		owner_enemy.velocity.x = direction.x * owner_enemy.MOVE_SPEED * 0.5
		_face_direction(direction)
	else:
		owner_enemy.velocity.x = 0

	if attack_cooldown_remaining <= 0:
		_change_state(State.CHASE)


# ============================================================================
# STATE: RETURNING
# ============================================================================

func _process_returning() -> void:
	"""Walking back to spawn position"""
	var distance_to_spawn = owner_enemy.get_distance_to_spawn()

	if distance_to_spawn < 10.0:
		owner_enemy.velocity.x = 0
		_change_state(State.DORMANT)
		print("[GuardianStatueAI] Returned to spawn, going dormant")
		return

	# Check if player re-entered range
	if owner_enemy.has_target():
		var dist_to_player = owner_enemy.get_distance_to_player()
		if dist_to_player <= owner_enemy.DETECTION_RANGE:
			_change_state(State.ACTIVATING)
			return

	# Move toward spawn
	var direction = (owner_enemy.spawn_position - owner_enemy.global_position).normalized()
	owner_enemy.velocity.x = direction.x * RETURN_SPEED
	_face_direction(direction)


# ============================================================================
# ATTACK LOGIC
# ============================================================================

func _start_attack(attack_type: AttackType) -> void:
	current_attack = attack_type

	match attack_type:
		AttackType.SHIELD_BASH:
			current_windup = SHIELD_WINDUP
			current_strike = SHIELD_STRIKE
			current_recovery = SHIELD_RECOVERY
			if owner_enemy.hitbox:
				owner_enemy.hitbox.set_damage(owner_enemy.DAMAGE_SHIELD_BASH)
				owner_enemy.hitbox.knockback_force = 150.0
				owner_enemy.hitbox.hitstun_duration = 1.0  # Stuns player for 1s
			print("[GuardianStatueAI] Shield Bash!")

		AttackType.HORIZONTAL_SWING:
			current_windup = HORIZONTAL_WINDUP
			current_strike = HORIZONTAL_STRIKE
			current_recovery = HORIZONTAL_RECOVERY
			if owner_enemy.hitbox:
				owner_enemy.hitbox.set_damage(owner_enemy.DAMAGE_HORIZONTAL)
				owner_enemy.hitbox.knockback_force = 400.0  # High knockback
				owner_enemy.hitbox.hitstun_duration = 0.3
			print("[GuardianStatueAI] Horizontal Swing!")

		AttackType.OVERHEAD_SLAM:
			current_windup = OVERHEAD_WINDUP
			current_strike = OVERHEAD_STRIKE
			current_recovery = OVERHEAD_RECOVERY
			if owner_enemy.hitbox:
				owner_enemy.hitbox.set_damage(owner_enemy.DAMAGE_OVERHEAD)
				owner_enemy.hitbox.knockback_force = 300.0
				owner_enemy.hitbox.hitstun_duration = 0.4
			print("[GuardianStatueAI] Overhead Slam!")

	_change_state(State.ATTACK_WINDUP)
	AudioManager.play_sfx("enemy_attack_windup", 0.1)


func _activate_hitbox() -> void:
	"""Activates the attack hitbox"""
	if owner_enemy.hitbox:
		owner_enemy.hitbox.activate()
	AudioManager.play_sfx("enemy_attack", 0.15)


func _deactivate_hitbox() -> void:
	"""Deactivates the attack hitbox"""
	if owner_enemy.hitbox:
		owner_enemy.hitbox.deactivate()


func _spawn_ground_wave() -> void:
	"""Spawns AoE ground wave for Overhead Slam"""
	# Screen shake
	# (Would call camera shake here if available)

	# Create temporary AoE damage area
	var aoe = Area2D.new()
	aoe.collision_layer = 128  # Same as hitbox
	aoe.collision_mask = 1024  # Hurtbox layer
	aoe.global_position = owner_enemy.global_position

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 100.0
	shape.shape = circle
	aoe.add_child(shape)

	get_tree().current_scene.add_child(aoe)

	# Deal AoE damage
	await get_tree().create_timer(OVERHEAD_AOE_DELAY).timeout
	if is_instance_valid(aoe):
		var bodies = aoe.get_overlapping_areas()
		for area in bodies:
			if area is HurtboxComponent:
				var hurtbox_owner = area.get_parent()
				# Don't damage self
				if hurtbox_owner != owner_enemy:
					var kb_dir = (area.global_position - owner_enemy.global_position).normalized()
					area.take_damage(owner_enemy.DAMAGE_OVERHEAD_AOE, kb_dir * 200.0, 0.2, owner_enemy)

		# Visual: ground particle burst
		if owner_enemy.sprite:
			# Brief screen-shake-like effect on sprite
			var shake_tween = create_tween()
			shake_tween.tween_property(owner_enemy, "position:x",
				owner_enemy.position.x + 5, 0.05)
			shake_tween.tween_property(owner_enemy, "position:x",
				owner_enemy.position.x - 5, 0.05)
			shake_tween.tween_property(owner_enemy, "position:x",
				owner_enemy.position.x, 0.05)

		aoe.queue_free()

	print("[GuardianStatueAI] Ground wave triggered!")


# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _apply_windup_visual(progress: float) -> void:
	"""Applies visual telegraph during windup"""
	if not owner_enemy.sprite:
		return

	match current_attack:
		AttackType.SHIELD_BASH:
			# Shield forward: sprite compresses horizontally
			owner_enemy.sprite.scale = Vector2(
				base_scale.x * (1.0 + progress * 0.2),
				base_scale.y * (1.0 - progress * 0.1)
			)
			owner_enemy.sprite.modulate = Color(
				1.0 + progress * 0.5, 1.0, 1.0 - progress * 0.3
			)

		AttackType.HORIZONTAL_SWING:
			# Pull weapon side: sprite offset and grow
			var pull_dir = -1.0 if owner_enemy.sprite.flip_h else 1.0
			owner_enemy.sprite.position.x = pull_dir * -12.0 * progress
			owner_enemy.sprite.scale = Vector2(
				base_scale.x * (1.0 + progress * 0.15),
				base_scale.y * (1.0 + progress * 0.15)
			)
			owner_enemy.sprite.modulate = Color(
				1.0 + progress * 0.3, 0.9, 0.9 - progress * 0.2
			)

		AttackType.OVERHEAD_SLAM:
			# Raise weapon overhead: sprite rises up
			owner_enemy.sprite.position.y = -20.0 * progress
			owner_enemy.sprite.scale = Vector2(
				base_scale.x * (1.0 + progress * 0.2),
				base_scale.y * (1.0 + progress * 0.3)
			)
			owner_enemy.sprite.modulate = Color(
				1.0 + progress * 0.8, 0.8, 0.8 - progress * 0.5
			)


func _apply_strike_visual() -> void:
	"""Applies visual effect during strike"""
	if not owner_enemy.sprite:
		return

	match current_attack:
		AttackType.SHIELD_BASH:
			# Quick forward lunge
			var lunge_dir = 1.0 if owner_enemy.sprite.flip_h else -1.0
			owner_enemy.sprite.position.x = lunge_dir * -20.0
			owner_enemy.sprite.scale = Vector2(base_scale.x * 1.3, base_scale.y * 0.9)
			owner_enemy.sprite.modulate = Color(1.8, 1.5, 1.0)

		AttackType.HORIZONTAL_SWING:
			# Wide horizontal stretch
			var swing_dir = 1.0 if owner_enemy.sprite.flip_h else -1.0
			owner_enemy.sprite.position.x = swing_dir * -25.0
			owner_enemy.sprite.scale = Vector2(base_scale.x * 2.0, base_scale.y * 0.85)
			owner_enemy.sprite.modulate = Color(2.0, 1.2, 1.0)

		AttackType.OVERHEAD_SLAM:
			# Smash down
			owner_enemy.sprite.position.y = 10.0
			owner_enemy.sprite.scale = Vector2(base_scale.x * 1.4, base_scale.y * 0.7)
			owner_enemy.sprite.modulate = Color(2.0, 0.8, 0.5)


func _apply_recovery_visual(progress: float) -> void:
	"""Gradually returns sprite to normal during recovery"""
	if not owner_enemy.sprite:
		return

	owner_enemy.sprite.position = owner_enemy.sprite.position.lerp(Vector2.ZERO, progress)
	owner_enemy.sprite.scale = owner_enemy.sprite.scale.lerp(base_scale, progress)
	owner_enemy.sprite.modulate = owner_enemy.sprite.modulate.lerp(Color.WHITE, progress)


# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	# Exit current state
	_exit_state(current_state)

	current_state = new_state
	state_timer = 0.0

	# Enter new state
	_enter_state(new_state)


func _enter_state(state: State) -> void:
	match state:
		State.DORMANT:
			# Reset visual to stone look
			if owner_enemy.sprite:
				owner_enemy.sprite.modulate = Color(0.8, 0.8, 0.8, 1.0)  # Slightly grey (stone)
		State.ATTACK_STRIKE:
			_activate_hitbox()
			_apply_strike_visual()
		State.ATTACK_RECOVERY:
			_deactivate_hitbox()
			current_attack = AttackType.NONE


func _exit_state(state: State) -> void:
	match state:
		State.ATTACK_STRIKE:
			_deactivate_hitbox()
		State.DORMANT:
			# Wake up - return to normal color
			pass


func cancel_attack() -> void:
	"""Cancels current attack (called by stun)"""
	if current_state in [State.ATTACK_WINDUP, State.ATTACK_STRIKE, State.ATTACK_RECOVERY]:
		print("[GuardianStatueAI] Attack cancelled (stun)")
		_deactivate_hitbox()
		current_attack = AttackType.NONE

		# Reset sprite
		if owner_enemy.sprite:
			owner_enemy.sprite.position = Vector2.ZERO
			owner_enemy.sprite.scale = base_scale

		_change_state(State.IDLE)


# ============================================================================
# UTILITY
# ============================================================================

func _face_direction(direction: Vector2) -> void:
	if owner_enemy.sprite and direction.x != 0:
		owner_enemy.sprite.flip_h = direction.x < 0


func get_state_name() -> String:
	match current_state:
		State.DORMANT: return "DORMANT"
		State.ACTIVATING: return "ACTIVATING"
		State.IDLE: return "IDLE"
		State.CHASE: return "CHASE"
		State.ATTACK_WINDUP: return "ATTACK_WINDUP"
		State.ATTACK_STRIKE: return "ATTACK_STRIKE"
		State.ATTACK_RECOVERY: return "ATTACK_RECOVERY"
		State.ATTACK_COOLDOWN: return "ATTACK_COOLDOWN"
		State.RETURNING: return "RETURNING"
		_: return "UNKNOWN"
