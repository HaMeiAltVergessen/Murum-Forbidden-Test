extends Node
class_name HermitAI

## AI Controller for Der Eremit (The Hermit) - Mini-Boss
## Phase 1: Arcane Bolt (homing), Triple Shot (spread), Teleport
## Phase 2: + Staff Combo (melee), faster projectiles, shorter teleport CD

# ============================================================================
# CONSTANTS
# ============================================================================

const ATTACK_RANGE_MELEE: float = 100.0
const ATTACK_RANGE_RANGED: float = 500.0
const MIN_DISTANCE: float = 150.0  # Preferred distance (ranged fighter)
const RETREAT_DISTANCE: float = 80.0  # Too close, back off

# Attack cooldowns
const ARCANE_BOLT_COOLDOWN: float = 2.5
const TRIPLE_SHOT_COOLDOWN: float = 4.0
const MELEE_COMBO_COOLDOWN: float = 3.0

# Melee timing
const MELEE_WINDUP: float = 0.5
const MELEE_STRIKE: float = 0.15
const MELEE_RECOVERY: float = 0.3
const MELEE_COMBO_COUNT: int = 3

# Teleport
const TELEPORT_FADE_TIME: float = 0.3
const TELEPORT_MIN_DISTANCE: float = 200.0
const TELEPORT_MAX_DISTANCE: float = 400.0

# Triple shot
const SPREAD_ANGLE: float = 15.0  # degrees

# ============================================================================
# ENUMS
# ============================================================================

enum State {
	IDLE,
	CHASE,
	RETREAT,
	ARCANE_BOLT,
	TRIPLE_SHOT,
	MELEE_WINDUP,
	MELEE_STRIKE,
	MELEE_RECOVERY,
	TELEPORT_OUT,
	TELEPORT_IN,
	COOLDOWN
}

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.IDLE
var state_timer: float = 0.0
var teleport_timer: float = 0.0
var attack_cooldowns: Dictionary = {
	"arcane_bolt": 0.0,
	"triple_shot": 0.0,
	"melee_combo": 0.0
}
var melee_combo_current: int = 0
var teleport_target: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE

# ============================================================================
# REFERENCES
# ============================================================================

var owner_enemy: Hermit
var player: CharacterBody2D

const VOID_ORB_SCENE = preload("res://projectiles/void_orb.tscn")

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	owner_enemy = get_parent() as Hermit
	player = get_tree().get_first_node_in_group("player")
	call_deferred("_init_scale")


func _init_scale() -> void:
	if owner_enemy and owner_enemy.sprite:
		base_scale = owner_enemy.sprite.scale


# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	if not owner_enemy or owner_enemy.is_dead:
		return
	if owner_enemy.current_mode != Hermit.Mode.FIGHTING:
		return
	if owner_enemy.is_stunned:
		owner_enemy.velocity.x = 0
		return

	# Find target
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	# Update cooldowns
	for key in attack_cooldowns:
		if attack_cooldowns[key] > 0:
			attack_cooldowns[key] -= delta

	# Teleport timer
	teleport_timer += delta
	var tp_interval = owner_enemy.get_teleport_interval()
	if teleport_timer >= tp_interval and current_state not in [State.TELEPORT_OUT, State.TELEPORT_IN]:
		_start_teleport()
		return

	state_timer += delta

	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.RETREAT:
			_process_retreat()
		State.ARCANE_BOLT:
			_process_arcane_bolt()
		State.TRIPLE_SHOT:
			_process_triple_shot()
		State.MELEE_WINDUP:
			_process_melee_windup()
		State.MELEE_STRIKE:
			_process_melee_strike()
		State.MELEE_RECOVERY:
			_process_melee_recovery()
		State.TELEPORT_OUT:
			_process_teleport_out()
		State.TELEPORT_IN:
			_process_teleport_in()
		State.COOLDOWN:
			_process_cooldown()


# ============================================================================
# STATES
# ============================================================================

func _process_idle() -> void:
	owner_enemy.velocity.x = 0
	if owner_enemy.has_target():
		_choose_action()


func _process_chase() -> void:
	"""Move toward preferred range"""
	var distance = owner_enemy.get_distance_to_player()

	if distance <= ATTACK_RANGE_RANGED:
		_choose_action()
		return

	var direction = owner_enemy.get_direction_to_player()
	owner_enemy.velocity.x = direction.x * owner_enemy.MOVE_SPEED
	_face_direction(direction)


func _process_retreat() -> void:
	"""Back away from player"""
	var distance = owner_enemy.get_distance_to_player()

	if distance >= MIN_DISTANCE:
		_choose_action()
		return

	var direction = -owner_enemy.get_direction_to_player()
	owner_enemy.velocity.x = direction.x * owner_enemy.MOVE_SPEED * 0.8
	_face_direction(-direction)  # Still face player


func _process_arcane_bolt() -> void:
	owner_enemy.velocity.x = 0
	if state_timer >= 0.4:  # Brief cast time
		_fire_arcane_bolt()
		_change_state(State.COOLDOWN)


func _process_triple_shot() -> void:
	owner_enemy.velocity.x = 0
	if state_timer >= 0.6:  # Longer cast time
		_fire_triple_shot()
		_change_state(State.COOLDOWN)


func _process_melee_windup() -> void:
	owner_enemy.velocity.x = 0
	_face_player()

	# Visual telegraph
	var progress = state_timer / MELEE_WINDUP
	if owner_enemy.sprite:
		owner_enemy.sprite.modulate = Color(1.0 + progress * 0.5, 1.0, 1.0 - progress * 0.3)

	if state_timer >= MELEE_WINDUP:
		_change_state(State.MELEE_STRIKE)


func _process_melee_strike() -> void:
	owner_enemy.velocity.x = 0

	if state_timer >= MELEE_STRIKE:
		melee_combo_current += 1
		_deactivate_hitbox()

		if melee_combo_current < MELEE_COMBO_COUNT:
			# Next swing
			_change_state(State.MELEE_RECOVERY)
		else:
			# Combo done
			melee_combo_current = 0
			attack_cooldowns["melee_combo"] = MELEE_COMBO_COOLDOWN
			_change_state(State.COOLDOWN)


func _process_melee_recovery() -> void:
	owner_enemy.velocity.x = 0

	# Reset visual
	var progress = state_timer / MELEE_RECOVERY
	if owner_enemy.sprite:
		owner_enemy.sprite.modulate = owner_enemy.sprite.modulate.lerp(Color.WHITE, progress)

	if state_timer >= MELEE_RECOVERY:
		# Continue combo
		_change_state(State.MELEE_WINDUP)


func _process_teleport_out() -> void:
	owner_enemy.velocity.x = 0
	if state_timer >= TELEPORT_FADE_TIME:
		# Move to target position
		owner_enemy.global_position = teleport_target
		_change_state(State.TELEPORT_IN)


func _process_teleport_in() -> void:
	owner_enemy.velocity.x = 0
	if state_timer >= TELEPORT_FADE_TIME:
		# Restore visual
		if owner_enemy.sprite:
			owner_enemy.sprite.modulate = Color.WHITE
		_face_player()
		_change_state(State.IDLE)


func _process_cooldown() -> void:
	"""Brief pause between attacks"""
	owner_enemy.velocity.x = 0
	if state_timer >= 0.8:
		_choose_action()


# ============================================================================
# ACTION SELECTION
# ============================================================================

func _choose_action() -> void:
	var distance = owner_enemy.get_distance_to_player()

	# Too close? Retreat or melee
	if distance < RETREAT_DISTANCE:
		if owner_enemy.can_melee() and attack_cooldowns["melee_combo"] <= 0:
			_start_melee_combo()
			return
		_change_state(State.RETREAT)
		return

	# In melee range and Phase 2?
	if distance <= ATTACK_RANGE_MELEE and owner_enemy.can_melee() and attack_cooldowns["melee_combo"] <= 0:
		_start_melee_combo()
		return

	# Ranged attacks
	if distance <= ATTACK_RANGE_RANGED:
		# Prefer triple shot if available (less frequent, more impactful)
		if attack_cooldowns["triple_shot"] <= 0 and randf() < 0.4:
			_start_triple_shot()
			return
		if attack_cooldowns["arcane_bolt"] <= 0:
			_start_arcane_bolt()
			return

	# Nothing available, chase or idle
	if distance > ATTACK_RANGE_RANGED:
		_change_state(State.CHASE)
	else:
		_change_state(State.IDLE)


# ============================================================================
# ATTACKS
# ============================================================================

func _start_arcane_bolt() -> void:
	_face_player()
	_change_state(State.ARCANE_BOLT)
	attack_cooldowns["arcane_bolt"] = ARCANE_BOLT_COOLDOWN

	# Visual: charge glow
	if owner_enemy.sprite:
		var tween = create_tween()
		tween.tween_property(owner_enemy.sprite, "modulate", Color(0.6, 0.4, 1.5, 1.0), 0.3)

	AudioManager.play_sfx("enemy_attack_windup", 0.1)


func _fire_arcane_bolt() -> void:
	"""Fires a homing void orb"""
	if not VOID_ORB_SCENE:
		return

	var orb = VOID_ORB_SCENE.instantiate()
	orb.global_position = owner_enemy.global_position + Vector2(0, -20)
	orb.speed = owner_enemy.get_projectile_speed()
	orb.damage = owner_enemy.PROJECTILE_DAMAGE
	orb.homing_strength = 0.8
	orb.lifetime = 6.0
	orb.set_target(player)

	var direction = owner_enemy.get_direction_to_player()
	orb.set_direction(direction)

	get_tree().current_scene.add_child(orb)

	# Reset visual
	if owner_enemy.sprite:
		owner_enemy.sprite.modulate = Color.WHITE

	AudioManager.play_sfx("enemy_attack", 0.15)
	print("[HermitAI] Fired Arcane Bolt (speed: %.0f)" % orb.speed)


func _start_triple_shot() -> void:
	_face_player()
	_change_state(State.TRIPLE_SHOT)
	attack_cooldowns["triple_shot"] = TRIPLE_SHOT_COOLDOWN

	# Visual: stronger charge
	if owner_enemy.sprite:
		var tween = create_tween()
		tween.tween_property(owner_enemy.sprite, "modulate", Color(1.5, 0.4, 0.6, 1.0), 0.4)

	AudioManager.play_sfx("enemy_attack_windup", 0.1)


func _fire_triple_shot() -> void:
	"""Fires 3 straight-line projectiles in a spread"""
	if not VOID_ORB_SCENE:
		return

	var base_direction = owner_enemy.get_direction_to_player()
	var angles = [-SPREAD_ANGLE, 0.0, SPREAD_ANGLE]

	for angle_deg in angles:
		var orb = VOID_ORB_SCENE.instantiate()
		orb.global_position = owner_enemy.global_position + Vector2(0, -20)
		orb.speed = owner_enemy.get_projectile_speed()
		orb.damage = owner_enemy.PROJECTILE_DAMAGE
		orb.homing_strength = 0.0  # Straight line!
		orb.lifetime = 4.0

		var angle_rad = deg_to_rad(angle_deg)
		var rotated_dir = base_direction.rotated(angle_rad)
		orb.set_direction(rotated_dir)

		get_tree().current_scene.add_child(orb)

	# Reset visual
	if owner_enemy.sprite:
		owner_enemy.sprite.modulate = Color.WHITE

	AudioManager.play_sfx("enemy_attack", 0.15)
	print("[HermitAI] Fired Triple Shot (speed: %.0f)" % owner_enemy.get_projectile_speed())


func _start_melee_combo() -> void:
	melee_combo_current = 0
	_change_state(State.MELEE_WINDUP)
	AudioManager.play_sfx("enemy_attack_windup", 0.1)
	print("[HermitAI] Starting melee combo!")


# ============================================================================
# TELEPORT
# ============================================================================

func _start_teleport() -> void:
	teleport_timer = 0.0

	# Calculate target: away from player
	var away_dir = -owner_enemy.get_direction_to_player()
	var distance = randf_range(TELEPORT_MIN_DISTANCE, TELEPORT_MAX_DISTANCE)
	teleport_target = owner_enemy.global_position + away_dir * distance

	# Clamp to room bounds (approximate)
	teleport_target.x = clamp(teleport_target.x, 50.0, 1550.0)
	teleport_target.y = owner_enemy.global_position.y  # Same height

	_change_state(State.TELEPORT_OUT)
	print("[HermitAI] Teleporting away!")


# ============================================================================
# HITBOX
# ============================================================================

func _activate_hitbox() -> void:
	if owner_enemy.hitbox:
		owner_enemy.hitbox.set_damage(owner_enemy.MELEE_DAMAGE)
		owner_enemy.hitbox.knockback_force = 250.0
		owner_enemy.hitbox.activate()
	AudioManager.play_sfx("enemy_attack", 0.15)


func _deactivate_hitbox() -> void:
	if owner_enemy.hitbox:
		owner_enemy.hitbox.deactivate()


# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	_exit_state(current_state)
	current_state = new_state
	state_timer = 0.0
	_enter_state(new_state)


func _enter_state(state: State) -> void:
	match state:
		State.MELEE_STRIKE:
			_activate_hitbox()
			# Visual: lunge
			if owner_enemy.sprite:
				var dir = 1.0 if owner_enemy.sprite.flip_h else -1.0
				owner_enemy.sprite.position.x = dir * -20.0
				owner_enemy.sprite.scale = Vector2(base_scale.x * 1.5, base_scale.y * 0.9)
				owner_enemy.sprite.modulate = Color(1.8, 1.2, 1.0)
		State.TELEPORT_OUT:
			# Fade out
			if owner_enemy.sprite:
				var tween = create_tween()
				tween.tween_property(owner_enemy.sprite, "modulate:a", 0.0, TELEPORT_FADE_TIME)
			# Disable hurtbox during teleport
			if owner_enemy.hurtbox:
				owner_enemy.hurtbox.set_deferred("monitorable", false)
		State.TELEPORT_IN:
			# Fade in
			if owner_enemy.sprite:
				owner_enemy.sprite.modulate.a = 0.0
				var tween = create_tween()
				tween.tween_property(owner_enemy.sprite, "modulate", Color.WHITE, TELEPORT_FADE_TIME)
			# Re-enable hurtbox
			if owner_enemy.hurtbox:
				owner_enemy.hurtbox.set_deferred("monitorable", true)
		State.MELEE_RECOVERY:
			_deactivate_hitbox()
			# Reset sprite
			if owner_enemy.sprite:
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(owner_enemy.sprite, "position", Vector2.ZERO, MELEE_RECOVERY)
				tween.tween_property(owner_enemy.sprite, "scale", base_scale, MELEE_RECOVERY)


func _exit_state(state: State) -> void:
	match state:
		State.MELEE_STRIKE:
			_deactivate_hitbox()


func cancel_attack() -> void:
	if current_state in [State.MELEE_WINDUP, State.MELEE_STRIKE, State.MELEE_RECOVERY,
			State.ARCANE_BOLT, State.TRIPLE_SHOT]:
		_deactivate_hitbox()
		melee_combo_current = 0
		if owner_enemy.sprite:
			owner_enemy.sprite.position = Vector2.ZERO
			owner_enemy.sprite.scale = base_scale
			owner_enemy.sprite.modulate = Color.WHITE
		_change_state(State.IDLE)


# ============================================================================
# UTILITY
# ============================================================================

func _face_player() -> void:
	if not player or not is_instance_valid(player):
		return
	var dir = (player.global_position - owner_enemy.global_position).normalized()
	_face_direction(dir)


func _face_direction(direction: Vector2) -> void:
	if owner_enemy.sprite and direction.x != 0:
		owner_enemy.sprite.flip_h = direction.x < 0
