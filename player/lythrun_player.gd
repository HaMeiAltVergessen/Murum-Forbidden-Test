extends CharacterBody2D
## Lythrun - Player 2 Character
## Shadow-themed co-op partner for Murum with unique shadow-based abilities (COMMIT 019.5)
class_name Lythrun

# ============ COMPONENT REFERENCES ============
@onready var movement_controller: MovementController = $MovementController if has_node("MovementController") else null
@onready var combat_system: CombatSystem = $CombatSystem if has_node("CombatSystem") else null
@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var mana_component: ManaComponent = $ManaComponent if has_node("ManaComponent") else null
@onready var hurtbox: HurtboxComponent = $HurtboxComponent if has_node("HurtboxComponent") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var player_camera: PlayerCamera = $PlayerCamera if has_node("PlayerCamera") else null
@onready var dodge_roll_system: DodgeRollSystem = $DodgeRollSystem if has_node("DodgeRollSystem") else null

# ============ SHADOW VFX ============
@onready var shadow_trail: GPUParticles2D = $ShadowTrail if has_node("ShadowTrail") else null
@onready var dark_aura: PointLight2D = $DarkAura if has_node("DarkAura") else null

# ============ PLAYER 2 IDENTITY ============
var is_player_2: bool = true
var player_name: String = "Lythrun"

# ============ STATS SCALING ============
var scaling_factor: float = 0.8
var base_stats: Dictionary = {}

# ============ STATE ============
var is_dead: bool = false
var is_invulnerable: bool = false
var is_attacking: bool = false
var is_dashing: bool = false

# ============ PHYSICS ============
const GRAVITY: float = 980.0
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mana: float = 100.0
var max_mana: float = 100.0
var movement_speed: float = 300.0
var base_damage: float = 10.0

# ============ SHADOW DASH (COMMIT 019.5) ============
const SHADOW_DASH_DURATION: float = 0.4  # P1: 0.3s
const SHADOW_DASH_SPEED: float = 450.0  # P1: 400.0
const SHADOW_DASH_COOLDOWN: float = 1.5  # P1: 1.0s (COMMIT 024: Reduced from 2.0s)
const AFTERIMAGE_LIFETIME: float = 1.0
const AFTERIMAGE_STUN_RADIUS: float = 80.0
var shadow_dash_active: bool = false
var shadow_dash_cooldown_active: bool = false

# ============ VOID STRIKE (COMMIT 019.5) ============
const VOID_STRIKE_COMBO_TIMEOUT: float = 1.5
const SHOCKWAVE_BASE_DAMAGE: float = 0.4  # COMMIT 024: Reduced from 0.5 (40% instead of 50%)
const SHOCKWAVE_RADIUS: float = 150.0
const ATTACK_RECOVERY: float = 0.5
const INPUT_BUFFER_TIME: float = 0.15  # COMMIT 024: Input buffer for combos (150ms)
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_stacks: int = 0
var buffered_action: String = ""
var buffer_timer: float = 0.0

# ============ SHADOW SCYTHE (COMMIT 019.5) ============
const SCYTHE_SPEED: float = 300.0  # COMMIT 024: Increased from 250.0 (faster travel)
const SCYTHE_MANA_COST: int = 30
var scythe_instance = null
var scythe_thrown: bool = false

# ============ VOID PARRY (COMMIT 019.5) ============
const VOID_PARRY_WINDOW: float = 0.4  # Total parry window
const PERFECT_PARRY_WINDOW: float = 0.12  # COMMIT 024: Perfect timing window (reduced from 0.15s)
const VOID_PARRY_COOLDOWN: float = 3.0
const PERFECT_PARRY_AOE_RADIUS: float = 220.0
const PERFECT_PARRY_DAMAGE: float = 40.0
const PERFECT_PARRY_STUN_DURATION: float = 1.5
var is_void_parrying: bool = false
var void_parry_cooldown_active: bool = false
var parry_start_time: float = 0.0

# ============ VOID RIFT (COMMIT 019.5) ============
const VOID_RIFT_MANA_COST: int = 40  # COMMIT 024: Reduced from 50 (more affordable)
const VOID_RIFT_DURATION: float = 3.0
const VOID_RIFT_MIN_RADIUS: float = 220.0
const VOID_RIFT_MAX_RADIUS: float = 650.0
const VOID_RIFT_DAMAGE: float = 80.0
var void_rift_active: bool = false

# ============ VOID ORBS (COMMIT 019.5) ============
const VOID_ORB_CHARGE_TIME: float = 3.0
const VOID_ORB_MANA_COST: int = 15
const VOID_ORB_SPEED: float = 200.0
const VOID_ORB_EXPLOSION_RADIUS: float = 150.0
const VOID_ORB_DAMAGE: float = 35.0
var is_charging_orb: bool = false
var orb_charge_time: float = 0.0
var movement_disabled_by_orb: bool = false
var charging_orb_vfx = null

# ============ PHASE-SHIFT (COMMIT 019.5) ============
const PHASE_SHIFT_MANA_COST: int = 60
const PHASE_SHIFT_DURATION: float = 5.0
const PHASE_SHIFT_COOLDOWN: float = 12.0  # COMMIT 024: Reduced from 15.0s (more frequent use)
var phase_shift_active: bool = false
var phase_shift_cooldown_active: bool = false
var phase_shift_armor: bool = false
var phase_shift_flicker_tween = null

# ============ ABGRUND (COMMIT 019.5) ============
const ABGRUND_CHARGE_TIME_MAX: float = 1.5  # COMMIT 024: Reduced from 2.0s (less vulnerable)
const ABGRUND_MIN_RADIUS: float = 220.0
const ABGRUND_MAX_RADIUS: float = 650.0
const ABGRUND_DURATION: float = 3.0
const ABGRUND_SUCTION_STRENGTH: float = 200.0
const ABGRUND_DAMAGE_PER_TICK: float = 5.0
var is_charging_abgrund: bool = false
var abgrund_charge_time: float = 0.0
var abgrund_charge_vfx = null

func _ready() -> void:
	print("[Lythrun] Initializing Player 2...")

	# Calculate and apply scaled stats
	calculate_and_apply_scaled_stats()

	# Set co-op collision layers
	set_coop_collision()

	# Activate shadow aesthetic
	activate_shadow_aesthetic()

	# Connect signals
	_connect_signals()

	# Disable P2's camera (P1's camera is active)
	if player_camera:
		player_camera.enabled = false

	# Register with CoopCamera (COMMIT 021)
	_register_with_coop_camera()

	print("[Lythrun] Player 2 ready! Scaling: %.0f%% (%s)" % [scaling_factor * 100, LythrunStatsScaling.get_scaling_description(scaling_factor)])

# ============ STATS SCALING ============

func calculate_and_apply_scaled_stats() -> void:
	"""Calculate P2's stats based on P1's shop item count and apply them"""
	# Get P1's base stats
	var p1_stats = get_p1_base_stats()

	# Calculate scaling factor
	scaling_factor = LythrunStatsScaling.calculate_scaling_factor()

	# Apply scaling
	var scaled_stats = LythrunStatsScaling.apply_scaling_to_stats(p1_stats, scaling_factor)

	# Apply to components
	if health_component:
		health_component.max_health = scaled_stats.max_hp
		health_component.current_health = scaled_stats.max_hp
		max_hp = scaled_stats.max_hp
		current_hp = scaled_stats.max_hp

	if mana_component:
		mana_component.max_mana = scaled_stats.max_mana
		mana_component.current_mana = scaled_stats.max_mana
		mana_component.regeneration_rate = scaled_stats.mana_regen
		max_mana = scaled_stats.max_mana
		current_mana = scaled_stats.max_mana

	if movement_controller:
		movement_controller.move_speed = scaled_stats.movement_speed
		movement_controller.dash_distance = scaled_stats.dash_speed * movement_controller.dash_duration
		movement_controller.jump_velocity = -scaled_stats.jump_force
		movement_speed = scaled_stats.movement_speed

	if combat_system:
		# Scale attack damages
		for i in range(combat_system.attack_damages.size()):
			combat_system.attack_damages[i] = int(combat_system.attack_damages[i] * scaling_factor)
		if combat_system.attack_damages.size() > 0:
			base_damage = combat_system.attack_damages[0]

	# Log scaled stats
	print_scaled_stats(p1_stats, scaled_stats)

func get_p1_base_stats() -> Dictionary:
	"""Get P1's base stats (or fallback to defaults)"""
	var p1 = CoopManager.p1_instance if CoopManager else null

	if not p1 or not is_instance_valid(p1):
		return get_default_stats()

	# Extract P1's stats
	var stats = {}

	if p1.has_node("HealthComponent"):
		var hp = p1.get_node("HealthComponent")
		stats["max_hp"] = hp.max_health if "max_health" in hp else 100

	if p1.has_node("ManaComponent"):
		var mana = p1.get_node("ManaComponent")
		stats["max_mana"] = mana.max_mana if "max_mana" in mana else 100
		stats["mana_regen"] = mana.regeneration_rate if "regeneration_rate" in mana else 10.0

	if p1.has_node("MovementController"):
		var movement = p1.get_node("MovementController")
		stats["movement_speed"] = movement.move_speed if "move_speed" in movement else 300.0
		stats["dash_speed"] = movement.dash_distance if "dash_distance" in movement else 800.0
		stats["jump_force"] = abs(movement.jump_velocity) if "jump_velocity" in movement else 800.0

	if p1.has_node("CombatSystem"):
		var combat = p1.get_node("CombatSystem")
		if "attack_damages" in combat and combat.attack_damages.size() > 0:
			stats["damage"] = combat.attack_damages[0]
		else:
			stats["damage"] = 10.0

	# Fill in missing values with defaults
	var defaults = get_default_stats()
	for key in defaults.keys():
		if not stats.has(key):
			stats[key] = defaults[key]

	return stats

func get_default_stats() -> Dictionary:
	"""Default stats if P1 is not available"""
	return {
		"max_hp": 100,
		"max_mana": 100,
		"damage": 10.0,
		"movement_speed": 300.0,
		"dash_speed": 800.0,
		"jump_force": 800.0,
		"parry_window": 0.3,
		"staff_throw_damage": 30.0,
		"urgathon_duration": 10.0,
		"mana_regen": 10.0
	}

func print_scaled_stats(p1_stats: Dictionary, scaled_stats: Dictionary) -> void:
	"""Print scaling comparison"""
	print("[Lythrun Stats] Scaling Factor: %.0f%%" % (scaling_factor * 100))
	print("  HP: %d (P1: %d)" % [scaled_stats.max_hp, p1_stats.get("max_hp", 0)])
	print("  Mana: %d (P1: %d)" % [scaled_stats.max_mana, p1_stats.get("max_mana", 0)])
	print("  Damage: %.1f (P1: %.1f)" % [scaled_stats.get("damage", 0), p1_stats.get("damage", 0)])
	print("  Speed: %.0f (P1: %.0f)" % [scaled_stats.movement_speed, p1_stats.get("movement_speed", 0)])

# ============ SHADOW AESTHETIC ============

func activate_shadow_aesthetic() -> void:
	"""Activate shadow-themed visual effects"""
	# Sprite modulation (dark violet) - Make it much darker/more purple for distinction
	if sprite:
		sprite.modulate = Color(0.4, 0.2, 0.7, 1.0)  # Much more purple and darker
		# Also flip sprite horizontally for visual distinction
		sprite.flip_h = not sprite.flip_h

	# Shadow trail particles
	if shadow_trail:
		shadow_trail.emitting = true
		shadow_trail.amount = 16

	# Dark aura
	if dark_aura:
		dark_aura.enabled = true
		dark_aura.color = Color(0.4, 0.2, 0.6, 1.0)
		dark_aura.energy = 0.3

	print("[Lythrun] Shadow aesthetic activated")

func _register_with_coop_camera() -> void:
	"""Register P2 with CoopCamera and HUD (COMMIT 021/022)"""
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame

	# Register with CoopCamera
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("set_player2"):
		camera.set_player2(self)
		print("[Lythrun] Registered with CoopCamera")

	# Register with HUD Manager (COMMIT 022)
	var hud_manager = get_node_or_null("/root/HUDManager")
	if hud_manager and hud_manager.has_method("set_p2_reference"):
		hud_manager.set_p2_reference(self)
		print("[Lythrun] Registered with HUD Manager")

# ============ COLLISION LAYERS ============

func set_coop_collision() -> void:
	"""Set collision layers for co-op mode"""
	# P2 is on Layer 3
	collision_layer = 0
	set_collision_layer_value(3, true)  # Player2 layer

	# P2 collides with:
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(4, true)   # Enemies
	set_collision_mask_value(5, true)   # P1 Projectiles (can be hit by P1)
	set_collision_mask_value(7, true)   # Pickups
	set_collision_mask_value(8, true)   # Hazards

	# Update hitbox collision (P2's attacks hit enemies and P1)
	if combat_system and combat_system.has_node("HitboxComponent"):
		var hitbox = combat_system.get_node("HitboxComponent")
		hitbox.collision_layer = 0
		hitbox.set_collision_layer_value(9, true)  # PlayerHitbox layer
		hitbox.collision_mask = 0
		hitbox.set_collision_mask_value(4, true)   # Enemies
		hitbox.set_collision_mask_value(2, true)   # P1 (can hit P1 in co-op)
		hitbox.set_collision_mask_value(10, true)  # PlayerHurtbox

	print("[Lythrun] Co-op collision layers set")

# ============ SIGNAL HANDLERS ============

func _connect_signals() -> void:
	"""Connect component signals"""
	# Health signals
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)

	# Mana signals
	if mana_component:
		mana_component.mana_changed.connect(_on_mana_changed)

	# Hurtbox signals
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Dodge signals
	if dodge_roll_system:
		dodge_roll_system.dodge_started.connect(_on_dodge_started)
		dodge_roll_system.dodge_completed.connect(_on_dodge_completed)

func _on_health_changed(new_health: int, max_health: int) -> void:
	"""Handle health changes"""
	print("[Lythrun] HP: %d/%d" % [new_health, max_health])
	# TODO: Emit P2-specific health change signal for UI

func _on_mana_changed(new_mana: int, max_mana: int) -> void:
	"""Handle mana changes"""
	print("[Lythrun] Mana: %d/%d" % [new_mana, max_mana])
	# TODO: Emit P2-specific mana change signal for UI

func _on_damage_taken(damage: int) -> void:
	"""Handle damage taken"""
	if is_invulnerable:
		return

	if AudioManager:
		AudioManager.play_sfx("player_hurt")

	# Camera shake (if camera exists)
	if player_camera and player_camera.enabled:
		player_camera.shake_light()

	# Visual feedback - shadow flash
	_flash_sprite_shadow()

func _on_damage_received(damage: int, knockback: Vector2, _hitstun: float) -> void:
	"""Handle damage from hurtbox"""
	if is_invulnerable:
		return

	# Apply knockback
	velocity = knockback

	print("[Lythrun] Took %d damage. Knockback: %s" % [damage, knockback])

func _on_health_depleted() -> void:
	"""Handle death"""
	if is_dead or is_invulnerable:
		return

	is_dead = true

	# Disable controls
	set_physics_process(false)
	set_process_input(false)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("player_hurt")

	# Shadow death VFX
	spawn_shadow_death_vfx()

	print("[Lythrun] Player 2 died")

	# CoopManager handles respawn logic (already connected in coop_manager.gd)

func _on_dodge_started(_direction: Vector2) -> void:
	"""Handle dodge roll start"""
	if combat_system:
		combat_system.set_combat_enabled(false)

func _on_dodge_completed() -> void:
	"""Handle dodge roll completion"""
	if combat_system:
		combat_system.set_combat_enabled(true)

# ============ VISUAL FEEDBACK ============

func _flash_sprite_shadow() -> void:
	"""Create shadow flash effect on damage (dark violet)"""
	if not sprite:
		return

	var original_modulate: Color = sprite.modulate

	# Flash dark violet
	sprite.modulate = Color(0.3, 0, 0.5, 1.0)

	# Tween back to normal
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)

func spawn_shadow_death_vfx() -> void:
	"""Spawn shadow death explosion VFX"""
	# Placeholder: Simple particle burst
	if shadow_trail:
		shadow_trail.emitting = false

	if dark_aura:
		dark_aura.enabled = false

	# TODO: Load and spawn shadow_death_explosion.tscn when created
	print("[Lythrun] Shadow death VFX spawned (placeholder)")

# ============ SPAWN/DESPAWN ============

func play_spawn_animation() -> void:
	"""Play spawn-from-abyss animation"""
	print("[Lythrun] Playing spawn animation")

	# Set invulnerable during spawn
	set_invulnerable(true)

	# TODO: Play actual spawn animation when AnimatedSprite2D is set up
	# For now, just a simple fade-in
	if sprite:
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 1.0)
		tween.tween_callback(func(): set_invulnerable(false))

func set_invulnerable(invuln: bool) -> void:
	"""Set invulnerability state"""
	is_invulnerable = invuln

	# Disable/enable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", not invuln)

	print("[Lythrun] Invulnerable: ", invuln)

# ============ PUBLIC METHODS ============

func respawn(spawn_position: Vector2) -> void:
	"""Respawn at given position"""
	global_position = spawn_position
	is_dead = false

	# Re-enable controls
	set_physics_process(true)
	set_process_input(true)

	# Reactivate shadow aesthetic
	activate_shadow_aesthetic()

	print("[Lythrun] Player 2 respawned at ", spawn_position)

# ============ PROCESS LOOPS (COMMIT 019.5) ============

func _process(delta: float) -> void:
	"""Update timers and charge mechanics"""
	# Combo timer
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			combo_stacks = 0

	# Void Orb charging
	if is_charging_orb:
		orb_charge_time += delta
		orb_charge_time = min(orb_charge_time, VOID_ORB_CHARGE_TIME)
		update_charging_orb_vfx(orb_charge_time / VOID_ORB_CHARGE_TIME)

	# Abgrund charging
	if is_charging_abgrund:
		abgrund_charge_time += delta
		abgrund_charge_time = min(abgrund_charge_time, ABGRUND_CHARGE_TIME_MAX)
		update_abgrund_charge_vfx(abgrund_charge_time / ABGRUND_CHARGE_TIME_MAX)

func _physics_process(delta: float) -> void:
	"""Handle physics and movement (COMMIT 019.5 - custom movement)"""
	if is_dead:
		return

	# Update mana from component
	if mana_component:
		current_mana = mana_component.current_mana

	# Gravity
	if not is_on_floor() and not is_charging_abgrund:
		velocity.y += GRAVITY * delta

	# Movement during Void Orb charging (restricted)
	if movement_disabled_by_orb:
		var input_vector = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
		velocity.x = input_vector.x * movement_speed * 0.5  # 50% speed
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Normal movement (if not disabled by abilities)
	if not shadow_dash_active and not is_attacking and not is_charging_abgrund:
		if movement_controller:
			# Let movement controller handle movement
			pass
		else:
			# Manual movement fallback
			var input_vector = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
			velocity.x = input_vector.x * movement_speed
			move_and_slide()

func _input(event: InputEvent) -> void:
	"""Handle P2 input for unique abilities (COMMIT 019.5)"""
	if is_dead or not InputManager:
		return

	# Shadow Dash (Shift/B Button)
	if event.is_action_pressed("p2_dash"):
		shadow_dash()

	# Void Strike (Attack button)
	if event.is_action_pressed("p2_attack"):
		# Check for Abgrund (Down + Attack in air)
		if not is_on_floor() and InputManager.get_p2_input_vector().y > 0.5:
			start_charging_abgrund()
		else:
			void_strike()

	if event.is_action_released("p2_attack") and is_charging_abgrund:
		release_abgrund()

	# Shadow Scythe (Y button / Button 3)
	if event.is_action_pressed("p2_shadow_scythe"):
		if scythe_thrown and scythe_instance:
			recall_scythe()
		else:
			shadow_scythe()

	# Void Parry (LB button / Button 6)
	if event.is_action_pressed("p2_void_parry"):
		void_parry()

	# Void Rift (RB button / Button 5)
	if event.is_action_pressed("p2_void_rift"):
		void_rift()

	# Void Orbs (R3 button / Button 9 - charged attack)
	if event.is_action_pressed("p2_ultimate"):
		start_charging_orb()

	if event.is_action_released("p2_ultimate"):
		release_orb()

	# Phase-Shift (Ultimate + Dash modifier - R3 + B)
	if event.is_action_pressed("p2_ultimate") and Input.is_action_pressed("p2_dash"):
		phase_shift()

# ============ SHADOW DASH (COMMIT 019.5) ============

func shadow_dash() -> void:
	"""Enhanced dash with afterimage stun effect"""
	if shadow_dash_active or shadow_dash_cooldown_active:
		return

	if is_attacking or is_charging_orb or is_charging_abgrund:
		return

	shadow_dash_active = true
	shadow_dash_cooldown_active = true
	is_dashing = true

	# Dash direction
	var dash_direction = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT

	# Animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("shadow_dash"):
		sprite.play("shadow_dash")

	# VFX: Shadow trail
	if shadow_trail:
		shadow_trail.emitting = true

	# Movement with afterimages
	var dash_timer = 0.0
	var afterimage_spawn_timer = 0.0

	while dash_timer < SHADOW_DASH_DURATION:
		velocity.x = dash_direction.x * SHADOW_DASH_SPEED
		velocity.y = 0  # Disable gravity during dash
		move_and_slide()

		# Spawn afterimage every 0.05s
		afterimage_spawn_timer += get_process_delta_time()
		if afterimage_spawn_timer >= 0.05:
			afterimage_spawn_timer = 0.0
			spawn_stun_afterimage()

		dash_timer += get_process_delta_time()
		await get_tree().process_frame

	velocity.x = 0
	shadow_dash_active = false
	is_dashing = false

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("lythrun_shadow_dash")

	# Cooldown
	await get_tree().create_timer(SHADOW_DASH_COOLDOWN).timeout
	shadow_dash_cooldown_active = false
	print("[Shadow Dash] Cooldown complete")

func spawn_stun_afterimage() -> void:
	"""Spawn afterimage with stun hitbox"""
	if not sprite:
		return

	# Create afterimage sprite
	var afterimage = Sprite2D.new()
	afterimage.texture = sprite.texture
	if sprite.hframes > 1:
		afterimage.hframes = sprite.hframes
	if sprite.vframes > 1:
		afterimage.vframes = sprite.vframes
	afterimage.frame = sprite.frame
	afterimage.flip_h = sprite.flip_h
	afterimage.modulate = Color(0.3, 0, 0.6, 0.7)  # Dark violet

	get_parent().add_child(afterimage)
	afterimage.global_position = global_position

	# Stun hitbox
	var stun_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = AFTERIMAGE_STUN_RADIUS

	collision.shape = shape
	stun_area.add_child(collision)
	afterimage.add_child(stun_area)

	# Collision setup
	stun_area.collision_layer = 0
	stun_area.collision_mask = 0
	stun_area.set_collision_mask_value(4, true)  # Enemies

	# Stun on contact
	stun_area.body_entered.connect(func(body):
		if body.has_method("apply_stun"):
			body.apply_stun(0.5)
			spawn_stun_vfx(body.global_position)
	)

	# Fade out
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tween.tween_callback(afterimage.queue_free)

# ============ VOID STRIKE (COMMIT 019.5) ============

func void_strike() -> void:
	"""3-hit combo attack with shockwave on 3rd hit"""
	if is_attacking or is_dashing:
		return

	is_attacking = true

	# Advance combo
	combo_count = (combo_count + 1) % 3

	# Reset combo timer
	combo_timer = VOID_STRIKE_COMBO_TIMEOUT

	# Execute attack based on combo step
	match combo_count:
		0:
			# Light 1
			print("[Void Strike] Combo 1/3")
			spawn_attack_hitbox(base_damage * 0.8)
		1:
			# Light 2
			print("[Void Strike] Combo 2/3")
			spawn_attack_hitbox(base_damage * 0.9)
		2:
			# Heavy with shockwave
			print("[Void Strike] Combo 3/3 - SHOCKWAVE!")
			spawn_attack_hitbox(base_damage * 1.2)

			# Shockwave after delay
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(self):
				spawn_void_shockwave()

			# Increase combo stacks (max 3)
			combo_stacks = min(combo_stacks + 1, 3)

	# VFX
	spawn_void_strike_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_strike")

	# Recovery
	await get_tree().create_timer(ATTACK_RECOVERY).timeout
	if is_instance_valid(self):
		is_attacking = false

func spawn_attack_hitbox(damage: float) -> void:
	"""Spawn basic attack hitbox"""
	# Simple hitbox in front of player
	var hitbox = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(60, 40)

	collision.shape = shape
	hitbox.add_child(collision)
	add_child(hitbox)

	# Position in front
	hitbox.position = Vector2(40 if not sprite.flip_h else -40, 0)

	# Collision setup
	hitbox.collision_layer = 0
	hitbox.set_collision_layer_value(6, true)  # P2 Projectiles
	hitbox.collision_mask = 0
	hitbox.set_collision_mask_value(4, true)  # Enemies
	hitbox.set_collision_mask_value(2, true)  # P1 (in PvP)

	# Damage on hit
	hitbox.body_entered.connect(func(body):
		if body.has_method("take_damage"):
			body.take_damage(damage)
	)

	# Remove after 0.1s
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func spawn_void_shockwave() -> void:
	"""Spawn AoE shockwave on 3rd combo hit"""
	# Calculate damage with combo stacks
	var stack_multiplier = 1.0 + (combo_stacks * 0.2)
	var shockwave_damage = base_damage * SHOCKWAVE_BASE_DAMAGE * stack_multiplier

	# Create shockwave area
	var shockwave = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = SHOCKWAVE_RADIUS

	collision.shape = shape
	shockwave.add_child(collision)
	get_parent().add_child(shockwave)

	shockwave.global_position = global_position + Vector2(0, 10)

	# Collision setup
	shockwave.collision_layer = 0
	shockwave.set_collision_layer_value(6, true)
	shockwave.collision_mask = 0
	shockwave.set_collision_mask_value(4, true)

	# Damage all overlapping enemies
	var enemies = shockwave.get_overlapping_bodies()
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(shockwave_damage)

	# VFX
	spawn_shockwave_vfx(shockwave.global_position)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_shockwave")

	# Camera shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(8.0 * stack_multiplier, 0.3)

	print("[Void Strike] Shockwave! Stacks: %d | Damage: %.1f" % [combo_stacks, shockwave_damage])

	# Remove shockwave
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(shockwave):
		shockwave.queue_free()

# ============ SHADOW SCYTHE (COMMIT 019.5) ============

func shadow_scythe() -> void:
	"""Throw boomerang scythe projectile"""
	if current_mana < SCYTHE_MANA_COST:
		print("[Shadow Scythe] Not enough mana!")
		return

	if is_attacking or is_dashing:
		return

	# Consume mana
	consume_mana(SCYTHE_MANA_COST)

	# Check if scythe scene exists
	var scythe_path = "res://projectiles/shadow_scythe.tscn"
	if not ResourceLoader.exists(scythe_path):
		print("[Shadow Scythe] Scene not found, using placeholder")
		create_placeholder_scythe()
		return

	# Spawn scythe
	var scythe_scene = load(scythe_path)
	scythe_instance = scythe_scene.instantiate()
	get_tree().current_scene.add_child(scythe_instance)

	scythe_instance.global_position = global_position + Vector2(0, -20)
	if "direction" in scythe_instance:
		scythe_instance.direction = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
	if "damage" in scythe_instance:
		scythe_instance.damage = base_damage * 3.0
	if "owner_player" in scythe_instance:
		scythe_instance.owner_player = self
	if "can_pierce" in scythe_instance:
		scythe_instance.can_pierce = true

	scythe_thrown = true
	scythe_instance.tree_exiting.connect(_on_scythe_destroyed)

	print("[Shadow Scythe] Thrown!")

func create_placeholder_scythe() -> void:
	"""Create placeholder scythe if scene doesn't exist"""
	print("[Shadow Scythe] Creating placeholder scythe")
	# TODO: Implement placeholder or create actual scene
	scythe_thrown = false

func recall_scythe() -> void:
	"""Recall thrown scythe"""
	if not scythe_instance or not is_instance_valid(scythe_instance):
		return

	print("[Shadow Scythe] Recalling...")

	if scythe_instance.has_method("start_return_to_player"):
		scythe_instance.start_return_to_player(self)

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("scythe_recall")

func _on_scythe_destroyed() -> void:
	"""Handle scythe destruction"""
	scythe_instance = null
	scythe_thrown = false

func on_scythe_returned() -> void:
	"""Called when scythe returns to player"""
	print("[Shadow Scythe] Returned!")
	scythe_thrown = false

# ============ VOID PARRY (COMMIT 019.5) ============

func void_parry() -> void:
	"""Parry with perfect-parry AoE stun"""
	if is_attacking or is_dashing or void_parry_cooldown_active:
		return

	is_void_parrying = true
	void_parry_cooldown_active = true
	parry_start_time = Time.get_ticks_msec() / 1000.0

	print("[Void Parry] Activated!")

	# VFX
	spawn_void_parry_shield()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_parry_activate")

	# Parry window
	await get_tree().create_timer(VOID_PARRY_WINDOW).timeout
	if is_instance_valid(self):
		is_void_parrying = false

	# Cooldown
	await get_tree().create_timer(VOID_PARRY_COOLDOWN).timeout
	if is_instance_valid(self):
		void_parry_cooldown_active = false
		print("[Void Parry] Cooldown complete")

func _on_parry_hit(attacker) -> void:
	"""Called when parry successfully blocks attack"""
	if not is_void_parrying:
		return

	# Calculate if perfect parry
	var parry_time = (Time.get_ticks_msec() / 1000.0) - parry_start_time
	var is_perfect = parry_time <= PERFECT_PARRY_WINDOW  # COMMIT 024: Use constant (0.12s)

	if is_perfect:
		perform_perfect_parry()
	else:
		# Normal parry
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("void_parry_success")

func perform_perfect_parry() -> void:
	"""Execute perfect parry AoE"""
	print("[Void Parry] PERFECT PARRY!")

	# Screen flash
	spawn_perfect_parry_flash()

	# AoE damage + stun
	var aoe = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = PERFECT_PARRY_AOE_RADIUS

	collision.shape = shape
	aoe.add_child(collision)
	get_parent().add_child(aoe)

	aoe.global_position = global_position

	# Collision setup
	aoe.collision_layer = 0
	aoe.collision_mask = 0
	aoe.set_collision_mask_value(4, true)

	# Damage and stun all enemies in radius
	var enemies = aoe.get_overlapping_bodies()
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(PERFECT_PARRY_DAMAGE)
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(PERFECT_PARRY_STUN_DURATION)

	# VFX
	spawn_void_parry_explosion_vfx(aoe.global_position)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_parry_perfect")

	# Camera shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(12.0, 0.5)

	# Cleanup
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(aoe):
		aoe.queue_free()

# ============ VOID RIFT (COMMIT 019.5) ============

func void_rift() -> void:
	"""Create growing void rift that explodes"""
	if current_mana < VOID_RIFT_MANA_COST:
		print("[Void Rift] Not enough mana!")
		return

	if void_rift_active:
		print("[Void Rift] Already active!")
		return

	# Consume mana
	consume_mana(VOID_RIFT_MANA_COST)

	void_rift_active = true

	print("[Void Rift] Creating rift...")

	# Try to load rift scene
	var rift_path = "res://abilities/void_rift.tscn"
	if ResourceLoader.exists(rift_path):
		var rift_scene = load(rift_path)
		var rift = rift_scene.instantiate()
		get_tree().current_scene.add_child(rift)

		rift.global_position = global_position
		if rift.has_method("setup"):
			rift.setup(VOID_RIFT_MIN_RADIUS, VOID_RIFT_MAX_RADIUS, VOID_RIFT_DURATION, VOID_RIFT_DAMAGE)

		rift.tree_exiting.connect(func(): void_rift_active = false)
	else:
		# Placeholder rift
		print("[Void Rift] Scene not found, using placeholder")
		create_placeholder_rift()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_rift_cast")

func create_placeholder_rift() -> void:
	"""Create placeholder rift"""
	# Simple growing circle
	var rift = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = VOID_RIFT_MIN_RADIUS

	collision.shape = shape
	rift.add_child(collision)
	get_parent().add_child(rift)

	rift.global_position = global_position

	# Grow over time
	var elapsed = 0.0
	while elapsed < VOID_RIFT_DURATION:
		elapsed += get_process_delta_time()
		var growth_factor = elapsed / VOID_RIFT_DURATION
		shape.radius = lerp(VOID_RIFT_MIN_RADIUS, VOID_RIFT_MAX_RADIUS, growth_factor)
		await get_tree().process_frame

	# Explode
	var enemies = rift.get_overlapping_bodies()
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(VOID_RIFT_DAMAGE)

	rift.queue_free()
	void_rift_active = false

# ============ VOID ORBS (COMMIT 019.5) ============

func start_charging_orb() -> void:
	"""Start charging void orb"""
	if current_mana < VOID_ORB_MANA_COST:
		print("[Void Orb] Not enough mana!")
		return

	if is_charging_orb or is_attacking or is_dashing:
		return

	is_charging_orb = true
	orb_charge_time = 0.0
	movement_disabled_by_orb = true

	print("[Void Orb] Charging...")

	# VFX
	spawn_charging_orb_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_orb_charge_start")

func release_orb() -> void:
	"""Release charged void orb"""
	if not is_charging_orb:
		return

	# Consume mana
	consume_mana(VOID_ORB_MANA_COST)

	is_charging_orb = false
	movement_disabled_by_orb = false

	# Calculate damage based on charge time
	var charge_factor = orb_charge_time / VOID_ORB_CHARGE_TIME
	var orb_damage = VOID_ORB_DAMAGE * (1.0 + charge_factor)

	print("[Void Orb] Released! Charge: %.1f%% | Damage: %.1f" % [charge_factor * 100, orb_damage])

	# Spawn orb (simplified projectile)
	spawn_void_orb_projectile(orb_damage, charge_factor)

	# Clear VFX
	clear_charging_orb_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("void_orb_release")

func spawn_void_orb_projectile(damage: float, charge_factor: float) -> void:
	"""Spawn void orb projectile"""
	# Simple projectile
	var orb = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0 + (charge_factor * 10.0)

	collision.shape = shape
	orb.add_child(collision)
	get_parent().add_child(orb)

	orb.global_position = global_position + Vector2(0, -40)

	# Collision setup
	orb.collision_layer = 0
	orb.set_collision_layer_value(6, true)
	orb.collision_mask = 0
	orb.set_collision_mask_value(4, true)
	orb.set_collision_mask_value(1, true)

	# Movement
	var direction = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
	var orb_velocity = direction * VOID_ORB_SPEED

	# Hit detection
	var hit = false
	orb.body_entered.connect(func(body):
		if not hit:
			hit = true
			# Explosion
			if body.has_method("take_damage"):
				body.take_damage(damage)
			# AoE explosion
			var explosion_enemies = orb.get_overlapping_bodies()
			for enemy in explosion_enemies:
				if enemy != body and enemy.has_method("take_damage"):
					enemy.take_damage(damage * 0.5)
			orb.queue_free()
	)

	# Move orb
	var lifetime = 0.0
	while lifetime < 5.0 and not hit:
		orb.global_position += orb_velocity * get_process_delta_time()
		lifetime += get_process_delta_time()
		await get_tree().process_frame

	if is_instance_valid(orb):
		orb.queue_free()

# ============ PHASE-SHIFT (COMMIT 019.5) ============

func phase_shift() -> void:
	"""1-hit armor ultimate"""
	if current_mana < PHASE_SHIFT_MANA_COST:
		print("[Phase-Shift] Not enough mana!")
		return

	if phase_shift_active or phase_shift_cooldown_active:
		return

	# Consume mana
	consume_mana(PHASE_SHIFT_MANA_COST)

	phase_shift_active = true
	phase_shift_armor = true
	phase_shift_cooldown_active = true

	print("[Phase-Shift] Activated! 1-Hit Armor")

	# Visual: Semi-transparent
	var original_modulate = sprite.modulate if sprite else Color.WHITE
	if sprite:
		sprite.modulate.a = 0.5

	# Flicker effect
	start_phase_shift_flicker()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("phase_shift_activate")

	# Duration or until hit
	var timer = 0.0
	while timer < PHASE_SHIFT_DURATION and phase_shift_armor:
		timer += get_process_delta_time()
		await get_tree().process_frame

	# Deactivate
	phase_shift_active = false
	phase_shift_armor = false
	if sprite:
		sprite.modulate = original_modulate
	stop_phase_shift_flicker()

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("phase_shift_deactivate")

	# Cooldown
	await get_tree().create_timer(PHASE_SHIFT_COOLDOWN).timeout
	if is_instance_valid(self):
		phase_shift_cooldown_active = false
		print("[Phase-Shift] Cooldown complete")

func start_phase_shift_flicker() -> void:
	"""Start flicker effect"""
	if not sprite:
		return

	phase_shift_flicker_tween = create_tween()
	phase_shift_flicker_tween.set_loops()
	phase_shift_flicker_tween.tween_property(sprite, "modulate:a", 0.8, 0.3)
	phase_shift_flicker_tween.tween_property(sprite, "modulate:a", 0.5, 0.3)

func stop_phase_shift_flicker() -> void:
	"""Stop flicker effect"""
	if phase_shift_flicker_tween:
		phase_shift_flicker_tween.kill()
		phase_shift_flicker_tween = null

	# COMMIT 024: Reset opacity to prevent stuck transparency
	if sprite:
		sprite.modulate.a = 1.0

func take_damage(damage: float) -> void:
	"""Override take_damage to handle phase-shift armor"""
	# Phase-Shift armor check
	if phase_shift_armor:
		print("[Phase-Shift] 1-Hit absorbed!")

		phase_shift_armor = false
		phase_shift_active = false

		# VFX
		spawn_phase_shift_absorb_vfx()

		# Audio
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("phase_shift_absorb")

		# No damage taken
		return

	# Normal damage (delegate to health component)
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage)

# ============ ABGRUND (COMMIT 019.5) ============

func start_charging_abgrund() -> void:
	"""Start charging aerial slam"""
	if is_charging_abgrund or is_attacking or is_dashing:
		return

	if is_on_floor():
		return

	is_charging_abgrund = true
	abgrund_charge_time = 0.0

	print("[Abgrund] Charging...")

	# Freeze in air
	velocity.y = 0

	# VFX
	spawn_abgrund_charge_vfx()

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("abgrund_charge")

func release_abgrund() -> void:
	"""Release aerial slam"""
	if not is_charging_abgrund:
		return

	is_charging_abgrund = false

	print("[Abgrund] Slamming!")

	# Slam downward
	velocity.y = 1200.0

	# Wait until ground hit
	while not is_on_floor():
		move_and_slide()
		await get_tree().process_frame

	# Impact
	perform_abgrund_impact()

	# Clear VFX
	clear_abgrund_charge_vfx()

func perform_abgrund_impact() -> void:
	"""Execute abgrund impact"""
	var charge_factor = abgrund_charge_time / ABGRUND_CHARGE_TIME_MAX
	var abgrund_radius = lerp(ABGRUND_MIN_RADIUS, ABGRUND_MAX_RADIUS, charge_factor)

	print("[Abgrund] IMPACT! Charge: %.1f%% | Radius: %.0fpx" % [charge_factor * 100, abgrund_radius])

	# Try to load abgrund scene
	var abgrund_path = "res://abilities/abgrund.tscn"
	if ResourceLoader.exists(abgrund_path):
		var abgrund_scene = load(abgrund_path)
		var abgrund = abgrund_scene.instantiate()
		get_tree().current_scene.add_child(abgrund)

		abgrund.global_position = global_position + Vector2(0, 20)
		if abgrund.has_method("setup"):
			abgrund.setup(abgrund_radius, ABGRUND_DURATION, ABGRUND_SUCTION_STRENGTH, ABGRUND_DAMAGE_PER_TICK)
	else:
		print("[Abgrund] Scene not found, using placeholder")
		create_placeholder_abgrund(abgrund_radius)

	# Audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("abgrund_impact")

	# Camera shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(20.0 * charge_factor, 0.8)

func create_placeholder_abgrund(radius: float) -> void:
	"""Create placeholder abgrund"""
	# Simple suction area
	print("[Abgrund] Creating placeholder abgrund with radius %.0f" % radius)
	# TODO: Implement placeholder

# ============ HELPER FUNCTIONS (COMMIT 019.5) ============

func consume_mana(amount: int) -> void:
	"""Consume mana"""
	if mana_component and mana_component.has_method("consume_mana"):
		mana_component.consume_mana(amount)
	else:
		current_mana = max(0, current_mana - amount)

# ============ VFX HELPER FUNCTIONS (COMMIT 019.5) ============

func spawn_stun_vfx(pos: Vector2) -> void:
	"""Spawn stun effect VFX"""
	# Placeholder: Simple particle burst
	print("[VFX] Stun effect at ", pos)

func spawn_void_strike_vfx() -> void:
	"""Spawn void strike slash VFX"""
	# Placeholder
	print("[VFX] Void strike slash")

func spawn_shockwave_vfx(pos: Vector2) -> void:
	"""Spawn shockwave VFX"""
	# Placeholder
	print("[VFX] Shockwave at ", pos)

func spawn_void_parry_shield() -> void:
	"""Spawn void parry shield VFX"""
	# Placeholder
	print("[VFX] Void parry shield")

func spawn_perfect_parry_flash() -> void:
	"""Spawn perfect parry screen flash"""
	# Placeholder violet flash
	var flash = ColorRect.new()
	flash.color = Color(0.6, 0, 1.0)
	flash.modulate.a = 0.6
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)

		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(flash.queue_free)

func spawn_void_parry_explosion_vfx(pos: Vector2) -> void:
	"""Spawn void parry explosion VFX"""
	# Placeholder
	print("[VFX] Void parry explosion at ", pos)

func spawn_charging_orb_vfx() -> void:
	"""Spawn charging orb VFX"""
	# Placeholder
	print("[VFX] Void orb charging started")

func update_charging_orb_vfx(charge_factor: float) -> void:
	"""Update charging orb VFX"""
	# Placeholder
	pass

func clear_charging_orb_vfx() -> void:
	"""Clear charging orb VFX"""
	# Placeholder
	print("[VFX] Void orb charging cleared")

func spawn_phase_shift_absorb_vfx() -> void:
	"""Spawn phase-shift absorb VFX"""
	# Screen flash
	var flash = ColorRect.new()
	flash.color = Color(0.5, 0, 0.8)
	flash.modulate.a = 0.8
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(flash)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)

		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)

func spawn_abgrund_charge_vfx() -> void:
	"""Spawn abgrund charging VFX"""
	# Placeholder
	print("[VFX] Abgrund charging started")

func update_abgrund_charge_vfx(charge_factor: float) -> void:
	"""Update abgrund charging VFX"""
	# Placeholder
	pass

func clear_abgrund_charge_vfx() -> void:
	"""Clear abgrund charging VFX"""
	# Placeholder
	print("[VFX] Abgrund charging cleared")
