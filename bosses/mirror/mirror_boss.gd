extends CharacterBody2D
## MirrorBoss — The shadow Murum that runs ahead of the player
## Uses same movement constants as the player for a true mirror feel
class_name MirrorBoss

# ============ SIGNALS ============
signal finisher_hit(count: int)

# ============ STATES ============
enum State { RUNNING, ATTACKING_RANGED, ATTACKING_MELEE, VULNERABLE, DEFEATED }

# ============ MOVEMENT ============
const MOVE_SPEED: float = 300.0  # Fallback only

# ============ AI CONFIG ============
const PREFERRED_DISTANCE: float = 250.0  # Preferred distance ahead of player
const MIN_DISTANCE: float = 150.0
const MAX_DISTANCE: float = 400.0
const WAYPOINT_REACH_DISTANCE: float = 50.0
const HOVER_Y_OFFSET: float = -200.0  # Hover this far above ground level
const HOVER_Y_SMOOTHING: float = 3.0

# ============ ATTACK CONFIG ============
const RANGED_ATTACK_COOLDOWN: float = 4.0
const MELEE_ATTACK_RANGE: float = 120.0
const MELEE_ATTACK_COOLDOWN: float = 3.0
const STUN_DURATION: float = 5.0       # How long boss stays grounded before rising again
const GROUND_Y: float = 800.0          # Match chunk_spawner GROUND_Y
const URTEIL_COOLDOWN: float = 12.0

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
var _urteil_timer: float = 0.0
var _stun_timer: float = 0.0
var _is_grounded: bool = false  # True while boss is stunned on the floor

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

	# Vertical positioning: hover normally, sink to ground when vulnerable
	var target_y: float = global_position.y
	if current_state == State.VULNERABLE:
		# Sink to ground
		target_y = GROUND_Y
		global_position.y = lerpf(global_position.y, target_y, 6.0 * delta)
	else:
		# Hover above player
		var player: Node2D = GameManager.player if GameManager else null
		if player and is_instance_valid(player):
			target_y = player.global_position.y + HOVER_Y_OFFSET
		elif controller and controller.runner_camera:
			target_y = controller.runner_camera.global_position.y + HOVER_Y_OFFSET
		global_position.y = lerpf(global_position.y, target_y, HOVER_Y_SMOOTHING * delta)
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

	# Safety: keep boss within camera view
	if controller and controller.runner_camera:
		var cam_left: float = controller.runner_camera.get_left_edge()
		var cam_right: float = controller.runner_camera.get_right_edge()
		# Boss should stay in the right ~60% of screen
		var min_x: float = cam_left + 400.0
		var max_x: float = cam_right - 100.0
		if global_position.x > max_x:
			global_position.x = max_x
			velocity.x = min(velocity.x, controller.get_scroll_speed())
		elif global_position.x < min_x:
			# Boss fell behind — teleport forward
			global_position.x = min_x
			velocity.x = controller.get_scroll_speed()

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
	if _grav_schnitt_timer > 0.0:
		_grav_schnitt_timer -= delta
	if _urteil_timer > 0.0:
		_urteil_timer -= delta

	# Check for ranged attack opportunity
	if current_state == State.RUNNING and _attack_timer >= RANGED_ATTACK_COOLDOWN:
		if controller and controller.current_section >= MirrorController.Section.DER_FALL:
			_start_ranged_attack()

	# Gravitaetsschnitt check (section 2+)
	if current_state == State.RUNNING:
		try_gravitaetsschnitt()

	# Urteil-Spiegel check (section 3+)
	if current_state == State.RUNNING:
		_try_urteil_spiegel()


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

	# Boss hovers — no jump logic needed

	# Check melee range (only when close enough)
	if distance_to_player < MELEE_ATTACK_RANGE and distance_to_player > -50.0:
		if _melee_timer >= MELEE_ATTACK_COOLDOWN:
			if controller and controller.current_section >= MirrorController.Section.DER_SPIEGELKAMPF:
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
	# Slow down during ranged attack but still keep up with camera
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()
	velocity.x = scroll_speed * 0.8


func _process_melee(_delta: float) -> void:
	# Slow down during melee but don't stop (camera is still moving!)
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()
	velocity.x = scroll_speed * 0.5


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
	if _sprite:
		_sprite.color = VULNERABLE_COLOR
	var tween := create_tween().set_loops()
	tween.tween_property(_sprite, "modulate:a", 0.4, 0.25)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.25)
	set_meta("_vulnerable_tween", tween)


func exit_vulnerable_state() -> void:
	"""Boss rises back up and resumes running after stun"""
	print("[MirrorBoss] Stun over — returning to RUNNING")
	current_state = State.RUNNING
	_is_grounded = false

	var tween = get_meta("_vulnerable_tween") if has_meta("_vulnerable_tween") else null
	if tween and tween is Tween:
		tween.kill()
	if _sprite:
		_sprite.modulate.a = 1.0
		_sprite.color = DAMAGED_COLORS[min(_finisher_count, DAMAGED_COLORS.size() - 1)]


func on_finisher_hit(count: int) -> void:
	"""Called by controller when finisher lands — immediately end stun"""
	_finisher_count = count
	_stun_timer = 0.0
	_is_grounded = false
	print("[MirrorBoss] Finisher hit! (%d total)" % count)

	# Visual degradation
	if _sprite:
		_sprite.color = DAMAGED_COLORS[min(count, DAMAGED_COLORS.size() - 1)]

	current_state = State.RUNNING

	# Stop vulnerability tween
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


# ============ ATTACKS ============
const DARK_ORB_SCENE: PackedScene = preload("res://bosses/mirror/entities/dark_orb.tscn")

func _spawn_dark_orb() -> void:
	"""Fire a dark orb backward toward the player"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var orb: DarkOrb = DARK_ORB_SCENE.instantiate()
	orb.global_position = global_position + Vector2(-30, -50)  # Spawn from hand area

	# Direction toward player (slightly behind boss)
	var dir: Vector2 = (player.global_position - global_position).normalized()
	orb.direction = dir
	orb.shooter = self

	get_tree().current_scene.add_child(orb)
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
	_hitbox.collision_mask = 2  # Layer 2 — Player body
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


# ============ UTILITY ============
func is_alive() -> bool:
	return current_state != State.DEFEATED


func get_facing_direction() -> float:
	return 1.0 if _facing_right else -1.0
