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

	# Jump logic — check for gaps or platforms ahead
	_ai_jump_logic()

	# Check melee range (only when close enough)
	if distance_to_player < MELEE_ATTACK_RANGE and distance_to_player > -50.0:
		if _melee_timer >= MELEE_ATTACK_COOLDOWN:
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


func _process_vulnerable(_delta: float) -> void:
	# Stumble / slow movement — but still keep up with camera minimum
	var scroll_speed: float = 200.0
	if controller:
		scroll_speed = controller.get_scroll_speed()
	velocity.x = scroll_speed * 0.6


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
