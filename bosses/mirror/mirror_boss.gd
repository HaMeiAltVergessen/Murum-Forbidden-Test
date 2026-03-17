extends CharacterBody2D
## MirrorBoss — The shadow Murum that runs ahead of the player
## Uses same movement constants as the player for a true mirror feel
class_name MirrorBoss

# ============ SIGNALS ============
signal finisher_hit(count: int)

# ============ STATES ============
enum State { RUNNING, ATTACKING_RANGED, ATTACKING_MELEE, VULNERABLE, DEFEATED }

# ============ MOVEMENT (mirrors player/movement_controller.gd) ============
const MOVE_SPEED: float = 300.0
const JUMP_VELOCITY: float = -1600.0
const GRAVITY: float = 1800.0
const WALL_SLIDE_GRAVITY_SCALE: float = 0.15
const WALL_JUMP_H_VELOCITY: float = 450.0
const WALL_JUMP_V_VELOCITY: float = -1400.0

# ============ AI CONFIG ============
const PREFERRED_DISTANCE: float = 250.0  # Preferred distance ahead of player
const MIN_DISTANCE: float = 150.0
const MAX_DISTANCE: float = 400.0
const WAYPOINT_REACH_DISTANCE: float = 50.0
const JUMP_ANTICIPATION: float = 80.0  # How far ahead to check for gaps/platforms

# ============ ATTACK CONFIG ============
const RANGED_ATTACK_COOLDOWN: float = 4.0
const MELEE_ATTACK_RANGE: float = 120.0
const MELEE_ATTACK_COOLDOWN: float = 3.0
const VULNERABLE_DURATION: float = 5.0

# ============ VISUAL ============
const BOSS_COLOR := Color(0.4, 0.0, 0.6, 0.8)
const VULNERABLE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const DAMAGED_COLORS: Array[Color] = [
	Color(0.4, 0.0, 0.6, 0.8),  # 0 finishers
	Color(0.5, 0.1, 0.5, 0.7),  # 1 finisher
	Color(0.6, 0.2, 0.4, 0.6),  # 2 finishers
	Color(0.7, 0.3, 0.3, 0.5),  # 3 finishers
]

# ============ STATE ============
var current_state: int = State.RUNNING
var controller: Node = null  # MirrorController reference
var _attack_timer: float = 0.0
var _melee_timer: float = 0.0
var _current_waypoint: Marker2D = null
var _finisher_count: int = 0
var _facing_right: bool = true

# ============ NODE REFS ============
@onready var _sprite: ColorRect = $Sprite
@onready var _hurtbox: Area2D = $HurtboxArea
var _hitbox: Area2D = null


func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")

	# Register with CombatManager
	if CombatManager:
		CombatManager.register_enemy(self)

	# Connect hurtbox signal
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	set_process(false)
	set_physics_process(false)


# ============ ACTIVATION ============
func activate() -> void:
	"""Called by controller when fight starts"""
	current_state = State.RUNNING
	set_process(true)
	set_physics_process(true)


func deactivate() -> void:
	current_state = State.DEFEATED
	set_process(false)
	set_physics_process(false)


# ============ PHYSICS ============
func _physics_process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# State-specific movement
	match current_state:
		State.RUNNING:
			_process_running(delta)
		State.ATTACKING_RANGED:
			_process_attacking(delta)
		State.ATTACKING_MELEE:
			_process_melee(delta)
		State.VULNERABLE:
			_process_vulnerable(delta)

	move_and_slide()

	# Update facing direction
	if velocity.x > 10.0:
		_facing_right = true
	elif velocity.x < -10.0:
		_facing_right = false


func _process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return

	# Attack timers
	_attack_timer += delta
	_melee_timer += delta

	# Check for ranged attack opportunity
	if current_state == State.RUNNING and _attack_timer >= RANGED_ATTACK_COOLDOWN:
		if controller and controller.current_section >= MirrorController.Section.DER_FALL:
			_start_ranged_attack()


# ============ RUNNING AI ============
func _process_running(delta: float) -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		# Just run right
		velocity.x = MOVE_SPEED
		return

	# Calculate desired position (ahead of player)
	var distance_to_player: float = global_position.x - player.global_position.x
	var target_speed: float = MOVE_SPEED

	if distance_to_player < MIN_DISTANCE:
		# Too close — speed up
		target_speed = MOVE_SPEED * 1.5
	elif distance_to_player > MAX_DISTANCE:
		# Too far ahead — slow down slightly
		target_speed = MOVE_SPEED * 0.7
	else:
		# Good distance — match scroll speed + slight lead
		if controller and controller.runner_camera:
			target_speed = max(MOVE_SPEED, controller.get_scroll_speed() * 1.1)

	velocity.x = target_speed

	# Jump logic — check for gaps or platforms ahead
	_ai_jump_logic()

	# Check melee range
	if distance_to_player < MELEE_ATTACK_RANGE and _melee_timer >= MELEE_ATTACK_COOLDOWN:
		if controller and controller.current_section >= MirrorController.Section.DER_SPIEGELKAMPF:
			_start_melee_attack()


func _ai_jump_logic() -> void:
	"""Simple AI: jump when near edges or to reach platforms"""
	if not is_on_floor():
		return

	# Check for gap ahead (raycast down-forward)
	var check_pos: Vector2 = global_position + Vector2(JUMP_ANTICIPATION, 0)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		check_pos, check_pos + Vector2(0, 200), 1  # World collision mask
	)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		# No ground ahead — jump
		velocity.y = JUMP_VELOCITY
		return

	# Check for wall ahead
	var wall_query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -40), global_position + Vector2(JUMP_ANTICIPATION, -40), 1
	)
	var wall_result: Dictionary = space_state.intersect_ray(wall_query)
	if not wall_result.is_empty():
		# Wall ahead — jump
		velocity.y = JUMP_VELOCITY


# ============ ATTACK STATES ============
func _start_ranged_attack() -> void:
	"""Fire a dark orb backward at the player"""
	_attack_timer = 0.0
	current_state = State.ATTACKING_RANGED

	# Brief pause
	velocity.x *= 0.5

	# Spawn dark orb (will be implemented in Commit 5)
	_spawn_dark_orb()

	# Return to running after short delay
	get_tree().create_timer(0.5).timeout.connect(func():
		if current_state == State.ATTACKING_RANGED:
			current_state = State.RUNNING
	)


func _start_melee_attack() -> void:
	_melee_timer = 0.0
	current_state = State.ATTACKING_MELEE

	# Turn toward player
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		_facing_right = player.global_position.x > global_position.x

	# Melee hitbox activation (placeholder — Commit 6)
	_do_melee_combo()

	# Return to running after combo
	get_tree().create_timer(1.2).timeout.connect(func():
		if current_state == State.ATTACKING_MELEE:
			current_state = State.RUNNING
	)


func _process_attacking(_delta: float) -> void:
	# Slow down during ranged attack but keep moving
	velocity.x = MOVE_SPEED * 0.3


func _process_melee(_delta: float) -> void:
	# Stop during melee
	velocity.x = 0.0


func _process_vulnerable(_delta: float) -> void:
	# Stumble / slow movement
	velocity.x = MOVE_SPEED * 0.2


# ============ VULNERABILITY (Finisher System) ============
func enter_vulnerable_state() -> void:
	"""Called by MomentumSystem when momentum hits MAX"""
	print("[MirrorBoss] Entering VULNERABLE state!")
	current_state = State.VULNERABLE

	# Visual feedback
	if _sprite:
		_sprite.color = VULNERABLE_COLOR

	# Flash effect
	var tween := create_tween().set_loops()
	tween.tween_property(_sprite, "modulate:a", 0.4, 0.2)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.2)
	set_meta("_vulnerable_tween", tween)


func exit_vulnerable_state() -> void:
	"""Called when finisher window closes without landing"""
	print("[MirrorBoss] Exiting VULNERABLE state")
	current_state = State.RUNNING

	# Stop flash
	var tween = get_meta("_vulnerable_tween") if has_meta("_vulnerable_tween") else null
	if tween and tween is Tween:
		tween.kill()
	if _sprite:
		_sprite.modulate.a = 1.0
		_sprite.color = DAMAGED_COLORS[min(_finisher_count, DAMAGED_COLORS.size() - 1)]


func on_finisher_hit(count: int) -> void:
	"""Called by controller when finisher lands"""
	_finisher_count = count
	print("[MirrorBoss] Finisher hit! (%d total)" % count)

	# Visual degradation
	if _sprite:
		_sprite.color = DAMAGED_COLORS[min(count, DAMAGED_COLORS.size() - 1)]

	# Brief stagger
	current_state = State.RUNNING

	# Stop any vulnerability tween
	var tween = get_meta("_vulnerable_tween") if has_meta("_vulnerable_tween") else null
	if tween and tween is Tween:
		tween.kill()
	if _sprite:
		_sprite.modulate.a = 1.0

	# Hitstop
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(0.3)

	finisher_hit.emit(count)


func enter_defeated_state() -> void:
	"""Called when all finishers landed — boss falls"""
	print("[MirrorBoss] DEFEATED!")
	current_state = State.DEFEATED
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)

	# Unregister
	if CombatManager:
		CombatManager.unregister_enemy(self)

	EventBus.enemy_died.emit(self, global_position)


# ============ DAMAGE HANDLING ============
func _on_hurtbox_area_entered(area: Area2D) -> void:
	"""Handle being hit by player attacks"""
	if current_state == State.DEFEATED:
		return

	if current_state == State.VULNERABLE:
		# Check if this is a finisher-capable hit
		# MomentumSystem handles the finisher logic via EventBus
		pass

	# Boss doesn't take traditional damage — momentum system handles progression


func take_damage(amount: float, _attacker: Node = null) -> void:
	"""Interface compatibility — boss doesn't use HP"""
	if current_state == State.VULNERABLE:
		# Damage during vulnerability = potential finisher (handled by momentum system)
		pass


# ============ PLACEHOLDER ATTACKS ============
func _spawn_dark_orb() -> void:
	"""Placeholder — will be replaced in Commit 5"""
	print("[MirrorBoss] Dark Orb fired! (placeholder)")
	# TODO: Instantiate dark_orb.tscn


func _do_melee_combo() -> void:
	"""Placeholder — will be replaced in Commit 6"""
	print("[MirrorBoss] Melee combo! (placeholder)")
	# TODO: Activate hitbox, play animation


# ============ UTILITY ============
func is_alive() -> bool:
	return current_state != State.DEFEATED


func get_facing_direction() -> float:
	return 1.0 if _facing_right else -1.0
