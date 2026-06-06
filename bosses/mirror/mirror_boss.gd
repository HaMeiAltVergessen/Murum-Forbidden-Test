extends CharacterBody2D
## MirrorBoss — The shadow Murum that runs ahead of the player
## Uses same movement constants as the player for a true mirror feel
class_name MirrorBoss

# ============ SIGNALS ============
signal finisher_hit(count: int)

# ============ STATES ============
enum State { RUNNING, ATTACKING_RANGED, ATTACKING_MELEE, VULNERABLE, DEFEATED, FALLING, KNOCKDOWN, AGGRESSIVE }

# ============ MOVEMENT ============
const MOVE_SPEED: float = 300.0  # Fallback only

# ============ AI CONFIG ============
const PREFERRED_DISTANCE: float = 300.0  # Normal distance ahead of player (x)
const MELEE_CHARGE_DISTANCE: float = 60.0  # X-distance during melee rush
const Y_SMOOTHING: float = 6.0            # How fast boss tracks player Y

# ============ ATTACK CONFIG ============
const RANGED_ATTACK_COOLDOWN: float = 1.8
const MELEE_ATTACK_RANGE: float = 350.0
const MELEE_ATTACK_COOLDOWN: float = 4.0
const STUN_DURATION: float = 5.0
const GROUND_Y: float = 800.0
const URTEIL_COOLDOWN: float = 12.0

# ============ PHASE 2+3 CONFIG ============
const GRAVITY: float = 800.0
const FALL_PREFERRED_Y_OFFSET: float = 250.0  # Boss stays this far below player
const FALL_X_SMOOTHING: float = 3.0
const FALL_Y_SMOOTHING: float = 4.0
const KNOCKDOWN_DURATION: float = 4.0
const AGGRESSIVE_DISTANCE: float = 150.0  # Boss stays close in Phase 3
const AGGRESSIVE_SPEED: float = 350.0

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
var boss_phase: int = 1
var controller: Node = null
var _attack_timer: float = 0.0
var _melee_timer: float = 0.0
var _current_waypoint: Marker2D = null
var _finisher_count: int = 0
var _facing_right: bool = true
var _urteil_timer: float = 0.0
var _stun_timer: float = 0.0
var _is_grounded: bool = false
var _knockdown_timer: float = 0.0
var _phase2_attack_timer: float = 0.0
var damage_resistance: float = 0.0  # 0 in Phase 1, 0.90 in Phase 2+3, 0 during knockdown

# ============ VISUAL ============
const DARK_TINT := Color(0.4, 0.2, 0.6, 0.9)

# ============ NODE REFS ============
@onready var _sprite: Node = $Sprite  # ColorRect initially, replaced with AnimatedSprite2D
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var _hurtbox: HurtboxComponent = $HurtboxArea
var _hitbox: Area2D = null


func _ready() -> void:
	add_to_group("enemies")

	if CombatManager:
		CombatManager.register_enemy(self)

	if _hurtbox:
		_hurtbox.damage_received.connect(_on_damage_received)

	# Setup HealthComponent (starts invulnerable, activated in Phase 2)
	if has_node("HealthComponent"):
		var hc: HealthComponentGeneric = get_node("HealthComponent")
		hc.set_invulnerable(true)
		hc.died.connect(_on_boss_died)

	# Setup animated sprite with Murum frames (dark tint)
	_setup_animated_sprite()

	set_process(false)
	set_physics_process(false)


func _setup_animated_sprite() -> void:
	"""Replace ColorRect with AnimatedSprite2D using Murum's frames"""
	var frames_path: String = "res://Assets/AIPlaceholder/Char/Murum/murum_frames.tres"
	if not ResourceLoader.exists(frames_path):
		print("[MirrorBoss] murum_frames.tres not found, keeping ColorRect")
		return

	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.name = "AnimatedSprite2D"
	_anim_sprite.sprite_frames = load(frames_path)
	_anim_sprite.scale = Vector2(0.268, 0.268)
	_anim_sprite.position = Vector2(0, -147)
	_anim_sprite.modulate = DARK_TINT
	_anim_sprite.play("idle")
	add_child(_anim_sprite)

	# Hide the old ColorRect and placeholder Sprite2D
	if _sprite:
		_sprite.visible = false
	if has_node("Sprite2D"):
		get_node("Sprite2D").visible = false


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

	if boss_phase == 1:
		_physics_phase_1(delta)
	else:
		_physics_phase_2_3(delta)

	move_and_slide()
	_clamp_to_camera()
	_update_facing()


func _physics_phase_1(delta: float) -> void:
	"""Phase 1 (Runner) — horizontal movement, ground tracking"""
	var target_y: float = GROUND_Y - 120.0
	var player_ref: Node2D = GameManager.player if GameManager else null
	if current_state == State.VULNERABLE:
		target_y = GROUND_Y
	elif current_state == State.ATTACKING_MELEE and player_ref and is_instance_valid(player_ref):
		target_y = player_ref.global_position.y
	elif player_ref and is_instance_valid(player_ref):
		var player_y: float = player_ref.global_position.y
		target_y = clampf(player_y, GROUND_Y - 300.0, GROUND_Y - 40.0)
	global_position.y = lerpf(global_position.y, target_y, Y_SMOOTHING * delta)
	velocity.y = 0.0

	match current_state:
		State.RUNNING:
			_process_running(delta)
		State.ATTACKING_RANGED:
			_process_attacking(delta)
		State.ATTACKING_MELEE:
			_process_melee(delta)
		State.VULNERABLE:
			_process_vulnerable(delta)


func _physics_phase_2_3(delta: float) -> void:
	"""Phase 2+3 — vertical fall with gravity, platform landing"""
	var player_ref: Node2D = GameManager.player if GameManager else null

	match current_state:
		State.FALLING:
			_process_falling(delta, player_ref)
		State.KNOCKDOWN:
			_process_knockdown(delta)
		State.AGGRESSIVE:
			_process_aggressive(delta, player_ref)
		State.ATTACKING_RANGED:
			_process_attacking_vertical(delta)
		State.ATTACKING_MELEE:
			_process_melee_vertical(delta, player_ref)


func _process_falling(delta: float, player: Node2D) -> void:
	"""Phase 2: Boss falls, staying below player, occasional attacks"""
	# Gravity
	velocity.y += GRAVITY * delta

	# If on floor, reduce downward velocity
	if is_on_floor():
		velocity.y = 0.0

	if player and is_instance_valid(player):
		# Target: below player by FALL_PREFERRED_Y_OFFSET
		var target_y: float = player.global_position.y + FALL_PREFERRED_Y_OFFSET
		var y_diff: float = target_y - global_position.y
		velocity.y += y_diff * FALL_Y_SMOOTHING * delta

		# X: loosely track player
		var x_diff: float = player.global_position.x - global_position.x
		velocity.x = x_diff * FALL_X_SMOOTHING

	# Clamp fall speed
	velocity.y = clampf(velocity.y, -200.0, 600.0)


func _process_knockdown(delta: float) -> void:
	"""Phase 2+3: Boss is stunned but keeps falling with gravity"""
	velocity.x = 0.0
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.y = 0.0
	# Clamp fall speed same as falling state
	velocity.y = clampf(velocity.y, -200.0, 600.0)

	_knockdown_timer -= delta
	if _knockdown_timer <= 0.0:
		exit_knockdown_state()


func _process_aggressive(delta: float, player: Node2D) -> void:
	"""Phase 3: Boss actively chases player"""
	# Gravity
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.y = 0.0

	if player and is_instance_valid(player):
		# Move toward player aggressively
		var dir: Vector2 = (player.global_position - global_position)
		velocity.x = dir.x * 5.0
		velocity.x = clampf(velocity.x, -AGGRESSIVE_SPEED, AGGRESSIVE_SPEED)

		# Y: stay at same level as player
		var y_diff: float = player.global_position.y - global_position.y
		velocity.y += y_diff * FALL_Y_SMOOTHING * delta

	velocity.y = clampf(velocity.y, -300.0, 600.0)


func _process_attacking_vertical(_delta: float) -> void:
	"""Brief pause during ranged attack in Phase 2+3"""
	velocity.y += GRAVITY * _delta
	if is_on_floor():
		velocity.y = 0.0
	velocity.x *= 0.9


func _process_melee_vertical(delta: float, player: Node2D) -> void:
	"""Melee attack during Phase 2+3"""
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.y = 0.0

	if player and is_instance_valid(player):
		var dir_x: float = player.global_position.x - global_position.x
		velocity.x = clampf(dir_x * 6.0, -AGGRESSIVE_SPEED, AGGRESSIVE_SPEED)


func _clamp_to_camera() -> void:
	"""Keep boss within camera viewport"""
	if not controller or not controller.runner_camera:
		return

	var cam: RunnerCamera = controller.runner_camera
	if boss_phase == 1:
		# Horizontal: stay in right ~60% of screen
		var min_x: float = cam.get_left_edge() + 400.0
		var max_x: float = cam.get_right_edge() - 100.0
		if global_position.x > max_x:
			global_position.x = max_x
			velocity.x = min(velocity.x, controller.get_scroll_speed())
		elif global_position.x < min_x:
			global_position.x = min_x
			velocity.x = controller.get_scroll_speed()
	else:
		# Vertical: stay within viewport bounds
		var margin: float = 80.0
		global_position.x = clampf(global_position.x, cam.get_left_edge() + margin, cam.get_right_edge() - margin)
		global_position.y = clampf(global_position.y, cam.get_top_edge() + margin, cam.get_bottom_edge() - margin)


func _update_facing() -> void:
	var player_ref: Node2D = GameManager.player if GameManager else null
	if boss_phase >= 2 and player_ref and is_instance_valid(player_ref):
		_facing_right = player_ref.global_position.x > global_position.x
	else:
		if velocity.x > 10.0:
			_facing_right = true
		elif velocity.x < -10.0:
			_facing_right = false

	# Update sprite flip
	if _anim_sprite:
		_anim_sprite.flip_h = not _facing_right  # Sprite faces right by default

	_update_animation()


func _process(delta: float) -> void:
	if current_state == State.DEFEATED:
		return

	# Attack timers
	_attack_timer += delta
	_melee_timer += delta
	_phase2_attack_timer += delta
	if _grav_schnitt_timer > 0.0:
		_grav_schnitt_timer -= delta
	if _urteil_timer > 0.0:
		_urteil_timer -= delta

	if boss_phase == 1:
		_process_phase_1_ai(delta)
	else:
		_process_phase_2_3_ai(delta)


func _process_phase_1_ai(_delta: float) -> void:
	"""Phase 1 AI: ranged attacks, gravitaetsschnitt, urteil"""
	if current_state == State.RUNNING and _attack_timer >= RANGED_ATTACK_COOLDOWN:
		if controller and controller.current_section >= MirrorController.Section.DER_FALL:
			_start_ranged_attack()

	if current_state == State.RUNNING:
		try_gravitaetsschnitt()

	if current_state == State.RUNNING:
		_try_urteil_spiegel()


func _process_phase_2_3_ai(delta: float) -> void:
	"""Phase 2+3 AI: attacks during falling/aggressive states"""
	if current_state == State.KNOCKDOWN or current_state == State.DEFEATED:
		return

	# Decrement dark attack cooldowns
	if _dark_machtbruch_timer > 0.0:
		_dark_machtbruch_timer -= delta
	if _dark_wolkenbruch_timer > 0.0:
		_dark_wolkenbruch_timer -= delta
	if _dark_machtstoss_timer > 0.0:
		_dark_machtstoss_timer -= delta

	var attack_cooldown: float = RANGED_ATTACK_COOLDOWN
	var melee_cooldown: float = MELEE_ATTACK_COOLDOWN
	if boss_phase == 3:
		attack_cooldown *= 0.5
		melee_cooldown *= 0.5

	if current_state != State.FALLING and current_state != State.AGGRESSIVE:
		return

	# Pick attack based on priority and cooldowns
	var player: Node2D = GameManager.player if GameManager else null
	var dist: float = 9999.0
	if player and is_instance_valid(player):
		dist = global_position.distance_to(player.global_position)

	# Wolkenbruch (Phase 3 only, ranged priority)
	if boss_phase == 3 and _dark_wolkenbruch_timer <= 0.0 and dist > 200.0:
		_try_dark_wolkenbruch()
		return

	# Melee when close
	if dist < MELEE_ATTACK_RANGE and _melee_timer >= melee_cooldown:
		_start_melee_attack_vertical()
		return

	# Machtbruch (medium range)
	if dist < 300.0 and _dark_machtbruch_timer <= 0.0:
		_try_dark_machtbruch()
		return

	# Machtstoss (medium range knockback)
	if dist < 350.0 and _dark_machtstoss_timer <= 0.0:
		_try_dark_machtstoss()
		return

	# Dark Orb (long range fallback)
	if _attack_timer >= attack_cooldown:
		_start_ranged_attack_vertical()


# ============ RUNNING AI ============
func _process_running(delta: float) -> void:
	# Get camera scroll speed as our base reference
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		velocity.x = scroll_speed
		return

	# Distance: positive = boss is ahead of player (desired)
	var distance_to_player: float = global_position.x - player.global_position.x

	# Boss speed is based on CAMERA speed, with proportional adjustment
	# to maintain PREFERRED_DISTANCE ahead of player
	var distance_error: float = distance_to_player - PREFERRED_DISTANCE
	# Negative error = too close to player, need to speed up
	# Positive error = too far ahead, need to slow down
	var speed_adjustment: float = -distance_error * 2.0

	var target_speed: float = scroll_speed + speed_adjustment

	# Clamp: never slower than 60% of scroll speed (or boss falls behind camera)
	# Never faster than scroll_speed + 150 (reasonable catch-up)
	target_speed = clampf(target_speed, scroll_speed * 0.6, scroll_speed + 150.0)

	velocity.x = target_speed

	# Melee trigger: wenn Boss nah genug am Spieler und Cooldown fertig
	if _melee_timer >= MELEE_ATTACK_COOLDOWN:
		var dist: float = abs(distance_to_player)
		if dist < MELEE_ATTACK_RANGE:
			_start_melee_attack()


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
	_melee_phase = MeleePhase.RUSH
	print("[MirrorBoss] Melee attack — rushing player!")

	_do_melee_combo()


enum MeleePhase { RUSH, RETREAT }
var _melee_phase: int = MeleePhase.RUSH
var _melee_phase_timer: float = 0.0


func _process_attacking(_delta: float) -> void:
	# Slow down during ranged attack but still keep up with camera
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()
	velocity.x = scroll_speed * 0.8


func _process_melee(delta: float) -> void:
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()

	var player: Node2D = GameManager.player if GameManager else null
	_melee_phase_timer += delta

	match _melee_phase:
		MeleePhase.RUSH:
			# Rush toward player X
			if player and is_instance_valid(player):
				var target_x: float = player.global_position.x + MELEE_CHARGE_DISTANCE
				var diff: float = target_x - global_position.x
				velocity.x = clampf(diff * 8.0, scroll_speed * 0.5, scroll_speed + 300.0)
				# Switch to retreat once close enough or after 0.8s
				if abs(diff) < 40.0 or _melee_phase_timer > 0.8:
					_melee_phase = MeleePhase.RETREAT
					_melee_phase_timer = 0.0
			else:
				velocity.x = scroll_speed
		MeleePhase.RETREAT:
			# Pull back to PREFERRED_DISTANCE ahead of player
			if player and is_instance_valid(player):
				var target_x: float = player.global_position.x + PREFERRED_DISTANCE
				var diff: float = target_x - global_position.x
				velocity.x = clampf(diff * 5.0 + scroll_speed, scroll_speed * 0.6, scroll_speed + 200.0)
				# Done retreating after 1s or when back at preferred distance
				if _melee_phase_timer > 1.0:
					current_state = State.RUNNING
			else:
				velocity.x = scroll_speed


func _process_vulnerable(delta: float) -> void:
	# Keep up with camera while grounded
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()
	velocity.x = scroll_speed * 0.8

	# Stun timer — count down once boss has reached the ground
	var near_ground: bool = abs(global_position.y - GROUND_Y) < 30.0
	if near_ground:
		if not _is_grounded:
			_is_grounded = true
			print("[MirrorBoss] Grounded! Stun timer started (%.1fs)" % STUN_DURATION)
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			# Stun expired without finisher — notify momentum system to close window
			if controller and controller.momentum_system:
				controller.momentum_system._close_finisher_window()


# ============ VULNERABILITY (Finisher System) ============
func enter_vulnerable_state() -> void:
	"""Called by MomentumSystem when momentum hits MAX — boss sinks stunned to ground"""
	print("[MirrorBoss] Entering VULNERABLE state — sinking to ground!")
	current_state = State.VULNERABLE
	_stun_timer = STUN_DURATION
	_is_grounded = false

	# Visual: white + pulsing flash
	_set_sprite_color(VULNERABLE_COLOR)
	var target: Node = _anim_sprite if _anim_sprite else _sprite
	if target:
		var tween := create_tween().set_loops()
		tween.tween_property(target, "modulate:a", 0.4, 0.25)
		tween.tween_property(target, "modulate:a", 1.0, 0.25)
		set_meta("_vulnerable_tween", tween)


func exit_vulnerable_state() -> void:
	"""Boss rises back up and resumes running after stun"""
	print("[MirrorBoss] Stun over — returning to RUNNING")
	current_state = State.RUNNING
	_is_grounded = false

	var tween = get_meta("_vulnerable_tween") if has_meta("_vulnerable_tween") else null
	if tween and tween is Tween:
		tween.kill()
	_restore_sprite_color()


func on_finisher_hit(count: int) -> void:
	"""Called by controller when finisher lands — immediately end stun"""
	_finisher_count = count
	_stun_timer = 0.0
	_is_grounded = false
	print("[MirrorBoss] Finisher hit! (%d total)" % count)

	# Visual degradation
	if _sprite and _sprite is ColorRect:
		_sprite.color = DAMAGED_COLORS[min(count, DAMAGED_COLORS.size() - 1)]

	current_state = State.RUNNING

	# Stop vulnerability tween
	var tween = get_meta("_vulnerable_tween") if has_meta("_vulnerable_tween") else null
	if tween and tween is Tween:
		tween.kill()
	_restore_sprite_color()

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
func _on_damage_received(_damage: int, _knockback: Vector2, _hitstun: float) -> void:
	"""Called by HurtboxComponent when a hit lands"""
	if current_state == State.DEFEATED:
		return

	# Flash sprite white as hit feedback
	_flash_hit()

	if boss_phase == 1:
		# Phase 1: finisher check
		if current_state == State.VULNERABLE:
			if controller and controller.momentum_system:
				controller.momentum_system.on_finisher_landed()
	else:
		# Phase 2+3: apply HP damage with resistance
		_apply_hp_damage(_damage)


func take_damage(amount: float, _attacker: Node = null) -> void:
	"""Called by Wolkenbruch and other direct-damage systems"""
	if current_state == State.DEFEATED:
		return

	_flash_hit()

	if boss_phase == 1:
		if current_state == State.VULNERABLE:
			if controller and controller.momentum_system:
				controller.momentum_system.on_finisher_landed()
	else:
		_apply_hp_damage(int(amount))


func _apply_hp_damage(raw_damage: int) -> void:
	"""Apply damage to HP with resistance. Also feeds knockdown meter."""
	if not has_node("HealthComponent"):
		return

	var hc: HealthComponentGeneric = get_node("HealthComponent")
	if hc.is_invulnerable:
		return

	# Apply resistance
	var effective_damage: float = raw_damage * (1.0 - damage_resistance)
	if effective_damage > 0:
		hc.take_damage(effective_damage)

	# Raw damage feeds knockdown meter (no resistance applied)
	if controller and controller.momentum_system:
		controller.momentum_system.add_knockdown_meter(raw_damage * MomentumSystem.KD_GAIN_PER_DAMAGE_POINT)


func _flash_hit() -> void:
	var target: Node = _anim_sprite if _anim_sprite else _sprite
	if target:
		var base_color: Color = DARK_TINT if _anim_sprite else Color.WHITE
		var tween := create_tween()
		tween.tween_property(target, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
		tween.tween_property(target, "modulate", base_color, 0.15)


func _set_sprite_color(color: Color) -> void:
	"""Set visual state — works with both ColorRect and AnimatedSprite2D"""
	if _anim_sprite:
		_anim_sprite.modulate = color
	elif _sprite and _sprite is ColorRect:
		_sprite.color = color


func _restore_sprite_color() -> void:
	"""Restore normal visual — works with both ColorRect and AnimatedSprite2D"""
	if _anim_sprite:
		_anim_sprite.modulate = DARK_TINT
	elif _sprite and _sprite is ColorRect:
		_sprite.modulate.a = 1.0
		_sprite.color = DAMAGED_COLORS[min(_finisher_count, DAMAGED_COLORS.size() - 1)]


func _on_boss_died() -> void:
	"""Called when HealthComponent.died signal fires"""
	if current_state == State.DEFEATED:
		return
	print("[MirrorBoss] HP depleted!")
	if controller and controller.has_method("on_boss_hp_depleted"):
		controller.on_boss_hp_depleted()


# ============ ATTACKS ============
const DARK_ORB_SCENE: PackedScene = preload("res://bosses/mirror/entities/dark_orb.tscn")

func _spawn_dark_orb() -> void:
	"""Fire a dark orb backward toward the player"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var orb: DarkOrb = DARK_ORB_SCENE.instantiate()

	# Direction toward player (slightly behind boss)
	var dir: Vector2 = (player.global_position - global_position).normalized()
	orb.direction = dir
	orb.shooter = self

	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector2(-30, -50)  # Spawn from hand area
	print("[MirrorBoss] Dark Orb fired!")


func _do_melee_combo() -> void:
	"""3-hit melee combo — each hit is parry-able"""
	print("[MirrorBoss] Melee combo start!")

	# Create melee hitbox if not present
	if not _hitbox:
		_setup_melee_hitbox()

	# 3-hit combo with delays
	for i in range(3):
		if current_state != State.ATTACKING_MELEE:
			break
		_activate_melee_hitbox(i)
		await get_tree().create_timer(0.35).timeout

	_deactivate_melee_hitbox()


func _setup_melee_hitbox() -> void:
	"""Create a melee hitbox Area2D for the boss"""
	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.collision_layer = 128  # Layer 8 — Enemy hitbox (parry-able)
	_hitbox.collision_mask = 4  # Layer 3 — Player HurtboxComponent (NICHT Body!)
	_hitbox.monitoring = false
	_hitbox.monitorable = true  # So parry BlockArea can detect us

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 70)
	shape.shape = rect
	shape.position = Vector2(40, -40)  # In front of boss
	_hitbox.add_child(shape)

	# Add to hitbox group for parry detection
	_hitbox.add_to_group("hitbox")

	# Connect for damage dealing
	_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)

	add_child(_hitbox)


const MELEE_DAMAGE: Array[int] = [10, 10, 18]  # 3rd hit is stronger

func _activate_melee_hitbox(hit_index: int) -> void:
	"""Flash the hitbox on for a brief window"""
	if not _hitbox:
		return

	# Update hitbox position based on facing
	var facing: float = get_facing_direction()
	for child in _hitbox.get_children():
		if child is CollisionShape2D:
			child.position.x = 40 * facing

	_hitbox.set_meta("current_damage", MELEE_DAMAGE[mini(hit_index, MELEE_DAMAGE.size() - 1)])
	_hitbox.monitoring = true

	# Visual flash (brief weapon swing indicator)
	var swing := ColorRect.new()
	swing.name = "SwingVisual"
	swing.size = Vector2(50, 60)
	swing.position = Vector2(20 * facing - 25, -80)
	swing.color = Color(0.8, 0.3, 1.0, 0.6)
	add_child(swing)

	# Deactivate after brief window
	await get_tree().create_timer(0.15).timeout
	_hitbox.monitoring = false
	if is_instance_valid(swing):
		swing.queue_free()


func _deactivate_melee_hitbox() -> void:
	if _hitbox:
		_hitbox.monitoring = false


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	"""Melee hit detection"""
	if area is HurtboxComponent:
		var owner_node: Node = area.get_parent()
		if owner_node and (owner_node.is_in_group("player") or owner_node.is_in_group("player2")):
			if area.is_invulnerable:
				return  # Player is blocking/parrying
			var dmg: int = _hitbox.get_meta("current_damage", 10)
			var knockback: Vector2 = Vector2(get_facing_direction() * 200, -100)
			area.take_damage(dmg, knockback, 0.3, self)
			print("[MirrorBoss] Melee hit for %d damage!" % dmg)


# ============ GRAVITAETSSCHNITT ============
const GRAV_SCHNITT_COOLDOWN: float = 8.0
const GRAV_SCHNITT_RANGE: float = 500.0
var _grav_schnitt_timer: float = 0.0

func try_gravitaetsschnitt() -> void:
	"""Attempt to split a platform under the player (called from _process)"""
	if _grav_schnitt_timer > 0.0:
		return

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Only in section 2+
	if not controller or controller.current_section < MirrorController.Section.DER_SPIEGELKAMPF:
		return

	# Check distance
	var dist: float = abs(global_position.x - player.global_position.x)
	if dist > GRAV_SCHNITT_RANGE:
		return

	# Find platform under player via raycast
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		player.global_position, player.global_position + Vector2(0, 100), 1
	)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return

	var collider: Node = result["collider"]
	if collider is SplittingPlatform:
		_grav_schnitt_timer = GRAV_SCHNITT_COOLDOWN
		collider.start_split()
		print("[MirrorBoss] Gravitaetsschnitt! Splitting platform under player!")


# ============ URTEIL-SPIEGEL ============
func _try_urteil_spiegel() -> void:
	"""Mark the player with Urteil-Spiegel (section 3+)"""
	if _urteil_timer > 0.0:
		return
	if not controller or controller.current_section < MirrorController.Section.DER_GEBROCHENE_ABGRUND:
		return

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	_urteil_timer = URTEIL_COOLDOWN
	var mark: UrteilMark = UrteilMark.create_on_target(player)
	get_tree().current_scene.add_child(mark)
	print("[MirrorBoss] Urteil-Spiegel! Player marked!")


# ============ PHASE SWITCHING ============
func switch_to_phase_2() -> void:
	"""Called by controller when transitioning to Phase 2 (Free Fall)"""
	print("[MirrorBoss] Switching to Phase 2 — FALLING")
	boss_phase = 2
	current_state = State.FALLING
	damage_resistance = 0.90
	_attack_timer = 0.0
	_melee_timer = 0.0

	# Activate HP system
	if has_node("HealthComponent"):
		var hc: HealthComponentGeneric = get_node("HealthComponent")
		hc.set_invulnerable(false)


func switch_to_phase_3() -> void:
	"""Called by controller when transitioning to Phase 3 (Finaler Kampf)"""
	print("[MirrorBoss] Switching to Phase 3 — AGGRESSIVE")
	boss_phase = 3
	current_state = State.AGGRESSIVE
	damage_resistance = 0.90
	_attack_timer = 0.0
	_melee_timer = 0.0

	# Reset HP to full
	if has_node("HealthComponent"):
		var hc: HealthComponentGeneric = get_node("HealthComponent")
		hc.reset_health()


func enter_knockdown_state() -> void:
	"""Boss enters knockdown — 4s of full vulnerability"""
	print("[MirrorBoss] KNOCKDOWN! (%.1fs)" % KNOCKDOWN_DURATION)
	current_state = State.KNOCKDOWN
	_knockdown_timer = KNOCKDOWN_DURATION
	damage_resistance = 0.0  # Full damage during knockdown
	velocity = Vector2.ZERO

	# Visual feedback
	_set_sprite_color(VULNERABLE_COLOR)
	var target: Node = _anim_sprite if _anim_sprite else _sprite
	if target:
		var tween := create_tween().set_loops()
		tween.tween_property(target, "modulate:a", 0.4, 0.25)
		tween.tween_property(target, "modulate:a", 1.0, 0.25)
		set_meta("_knockdown_tween", tween)


func exit_knockdown_state() -> void:
	"""Boss recovers from knockdown"""
	print("[MirrorBoss] Knockdown ended — resuming")
	damage_resistance = 0.90

	var tween = get_meta("_knockdown_tween") if has_meta("_knockdown_tween") else null
	if tween and tween is Tween:
		tween.kill()
	_restore_sprite_color()

	# Return to appropriate state
	if boss_phase == 3:
		current_state = State.AGGRESSIVE
	else:
		current_state = State.FALLING

	# Notify controller
	if controller and controller.has_method("on_knockdown_ended"):
		if controller.momentum_system:
			controller.on_knockdown_ended(controller.momentum_system.knockdown_count)


func set_temp_invulnerable(duration: float) -> void:
	"""Briefly make boss invulnerable (during transitions)"""
	if has_node("HealthComponent"):
		var hc: HealthComponentGeneric = get_node("HealthComponent")
		hc.start_invulnerability(duration)


# ============ PHASE 2+3 ATTACKS ============
const DARK_MACHTBRUCH_COOLDOWN: float = 10.0
const DARK_WOLKENBRUCH_COOLDOWN: float = 12.0
const DARK_MACHTSTOSS_COOLDOWN: float = 6.0
var _dark_machtbruch_timer: float = 0.0
var _dark_wolkenbruch_timer: float = 0.0
var _dark_machtstoss_timer: float = 0.0


func _start_ranged_attack_vertical() -> void:
	"""Fire dark orb toward player in vertical mode"""
	_attack_timer = 0.0
	var prev_state: int = current_state
	current_state = State.ATTACKING_RANGED

	_spawn_dark_orb()

	get_tree().create_timer(0.5).timeout.connect(func():
		if current_state == State.ATTACKING_RANGED:
			current_state = prev_state
	)


func _start_melee_attack_vertical() -> void:
	"""Melee combo in Phase 2+3 with adjusted damage"""
	_melee_timer = 0.0
	var prev_state: int = current_state
	current_state = State.ATTACKING_MELEE

	if not _hitbox:
		_setup_melee_hitbox()

	var combo_damage: Array[int] = [10, 12, 15]
	var combo_timing: Array[float] = [0.3, 0.35, 0.4]

	for i in range(3):
		if current_state != State.ATTACKING_MELEE:
			break
		_hitbox.set_meta("current_damage", combo_damage[mini(i, combo_damage.size() - 1)])
		_activate_melee_hitbox(i)
		await get_tree().create_timer(combo_timing[mini(i, combo_timing.size() - 1)]).timeout

	_deactivate_melee_hitbox()

	if current_state == State.ATTACKING_MELEE:
		current_state = prev_state


func _try_dark_machtbruch() -> void:
	"""Dark Machtbruch — AoE explosion around boss"""
	if _dark_machtbruch_timer > 0.0:
		return

	var cd: float = DARK_MACHTBRUCH_COOLDOWN
	if boss_phase == 3:
		cd *= 0.5
	_dark_machtbruch_timer = cd

	# Determine tier based on phase
	var tier: int = 1 if boss_phase == 2 else randi_range(1, 3)
	var damage_values: Array[int] = [20, 35, 50]
	var radius_values: Array[float] = [100.0, 150.0, 200.0]
	var dmg: int = damage_values[mini(tier - 1, 2)]
	var radius: float = radius_values[mini(tier - 1, 2)]

	print("[MirrorBoss] Dark Machtbruch Stufe %d! (%d dmg, %.0f radius)" % [tier, dmg, radius])

	# Visual: expanding ring
	var ring := ColorRect.new()
	ring.name = "MachtbruchRing"
	ring.size = Vector2(radius * 2, radius * 2)
	ring.position = Vector2(-radius, -radius - 120)
	ring.color = Color(0.6, 0.1, 0.8, 0.4)
	add_child(ring)

	# Damage players in range
	_deal_aoe_damage(dmg, radius)

	# Fade out ring
	var tween := create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)


func _try_dark_wolkenbruch() -> void:
	"""Dark Wolkenbruch — Boss jumps up and slams down on player position (Phase 3 only)"""
	if boss_phase < 3:
		return
	if _dark_wolkenbruch_timer > 0.0:
		return

	_dark_wolkenbruch_timer = DARK_WOLKENBRUCH_COOLDOWN * 0.5  # Halved in Phase 3

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var target_pos: Vector2 = player.global_position
	var dmg: int = randi_range(40, 80)
	var aoe_radius: float = 150.0

	print("[MirrorBoss] Dark Wolkenbruch! Target: (%.0f, %.0f)" % [target_pos.x, target_pos.y])

	# Jump up briefly
	velocity.y = -400.0
	await get_tree().create_timer(0.4).timeout

	# Slam down to target
	global_position = target_pos + Vector2(0, -200)
	velocity.y = 800.0
	await get_tree().create_timer(0.3).timeout

	# Impact
	velocity = Vector2.ZERO
	_deal_aoe_damage(dmg, aoe_radius)

	# Shockwave visual
	var shockwave := ColorRect.new()
	shockwave.name = "WolkenbruchShockwave"
	shockwave.size = Vector2(aoe_radius * 2, 32)
	shockwave.position = Vector2(-aoe_radius, -16)
	shockwave.color = Color(0.8, 0.2, 1.0, 0.5)
	add_child(shockwave)

	var tween := create_tween()
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.4)
	tween.tween_callback(shockwave.queue_free)

	if controller and controller.runner_camera:
		controller.runner_camera.shake(8.0, 4.0)


func _try_dark_machtstoss() -> void:
	"""Dark Machtstoss — Knockback wave toward player"""
	if _dark_machtstoss_timer > 0.0:
		return

	var cd: float = DARK_MACHTSTOSS_COOLDOWN
	if boss_phase == 3:
		cd *= 0.5
	_dark_machtstoss_timer = cd

	var tier: int = 1 if boss_phase == 2 else randi_range(1, 3)
	var damage_values: Array[int] = [20, 30, 40]
	var dmg: int = damage_values[mini(tier - 1, 2)]

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var dir: Vector2 = (player.global_position - global_position).normalized()
	var knockback: Vector2 = dir * 300.0

	print("[MirrorBoss] Dark Machtstoss Stufe %d! (%d dmg)" % [tier, dmg])

	# Visual: wave effect
	var wave := ColorRect.new()
	wave.name = "MachtstossWave"
	wave.size = Vector2(80, 60)
	wave.position = Vector2(dir.x * 50 - 40, -90)
	wave.color = Color(0.5, 0.1, 0.9, 0.6)
	add_child(wave)

	# Damage and knockback player if in range
	var dist: float = global_position.distance_to(player.global_position)
	if dist < 250.0:
		var hurtbox := player.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if hurtbox and not hurtbox.is_invulnerable:
			hurtbox.take_damage(dmg, knockback, 0.3, self)

	var tween := create_tween()
	tween.tween_property(wave, "position:x", wave.position.x + dir.x * 200, 0.3)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.3)
	tween.tween_callback(wave.queue_free)


func _deal_aoe_damage(damage: int, radius: float) -> void:
	"""Deal damage to all players within radius"""
	var center: Vector2 = global_position + Vector2(0, -120)

	for target_group in ["player", "player2"]:
		for node in get_tree().get_nodes_in_group(target_group):
			if not is_instance_valid(node):
				continue
			var dist: float = center.distance_to(node.global_position)
			if dist <= radius:
				var hurtbox := node.get_node_or_null("HurtboxComponent") as HurtboxComponent
				if hurtbox and not hurtbox.is_invulnerable:
					var kb: Vector2 = (node.global_position - center).normalized() * 200.0
					hurtbox.take_damage(damage, kb, 0.2, self)


# ============ ANIMATION ============
func _update_animation() -> void:
	if not _anim_sprite:
		return

	var anim: String = "idle"
	match current_state:
		State.RUNNING:
			anim = "walk"
		State.FALLING:
			anim = "fall"
		State.ATTACKING_MELEE:
			anim = "attack"
		State.ATTACKING_RANGED:
			anim = "special"
		State.VULNERABLE, State.KNOCKDOWN:
			anim = "hurt"
		State.AGGRESSIVE:
			anim = "walk"
		State.DEFEATED:
			anim = "hurt"

	if _anim_sprite.animation != anim:
		_anim_sprite.play(anim)


# ============ UTILITY ============
func is_alive() -> bool:
	return current_state != State.DEFEATED


func get_facing_direction() -> float:
	return 1.0 if _facing_right else -1.0
