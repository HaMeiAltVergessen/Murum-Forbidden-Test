extends CharacterBody2D
## Lythrun - Player 2 Character (Modular Architecture)
## Shadow-themed co-op partner for Murum with unique shadow-based abilities
## Combat abilities are delegated to modular subsystems (like P1's architecture)
class_name Lythrun

# ============ COMPONENT REFERENCES ============
@onready var movement_controller: MovementController = $MovementController if has_node("MovementController") else null
@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var mana_component: ManaComponent = $ManaComponent if has_node("ManaComponent") else null
@onready var hurtbox: HurtboxComponent = $HurtboxComponent if has_node("HurtboxComponent") else null
@onready var sprite: Sprite2D = $Sprite2D
@onready var sense_sprite: Sprite2D = $SenseSprite if has_node("SenseSprite") else null
@onready var player_camera: PlayerCamera = $PlayerCamera if has_node("PlayerCamera") else null

# ============ COMBAT SUBSYSTEM REFERENCES ============
@onready var lythrun_combat: LythrunCombatSystem = $LythrunCombatSystem if has_node("LythrunCombatSystem") else null
@onready var void_parry_system: VoidParrySystem = $VoidParrySystem if has_node("VoidParrySystem") else null
@onready var shadow_scythe_system: ShadowScytheSystem = $ShadowScytheSystem if has_node("ShadowScytheSystem") else null
@onready var shadow_dash_system: ShadowDashSystem = $ShadowDashSystem if has_node("ShadowDashSystem") else null
@onready var void_rift_system: VoidRiftSystem = $VoidRiftSystem if has_node("VoidRiftSystem") else null
@onready var void_orbs_system: VoidOrbsSystem = $VoidOrbsSystem if has_node("VoidOrbsSystem") else null

# ============ SHADOW VFX ============
@onready var shadow_trail: GPUParticles2D = $ShadowTrail if has_node("ShadowTrail") else null
@onready var dark_aura: PointLight2D = $DarkAura if has_node("DarkAura") else null

# ============ PASSIVE ABILITIES ============
var myrkurs_echo: Node = null

# ============ PLAYER 2 IDENTITY ============
var is_player_2: bool = true
var player_name: String = "Lythrun"

# ============ STATS SCALING ============
var scaling_factor: float = 0.8
var base_stats: Dictionary = {}

# ============ STATE (shared with subsystems) ============
var is_dead: bool = false
var is_invulnerable: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var is_dodging: bool = false

# ============ PHYSICS ============
const GRAVITY: float = 980.0
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mana: float = 100.0
var max_mana: float = 100.0
var movement_speed: float = 300.0
var base_damage: float = 10.0

# ============ PHASE SHIFT (state kept here for take_damage override) ============
var phase_shift_active: bool = false
var phase_shift_armor: bool = false


func _ready() -> void:
	print("[Lythrun] Initializing Player 2 (modular)...")

	calculate_and_apply_scaled_stats()
	set_coop_collision()
	activate_shadow_aesthetic()
	_connect_signals()
	_setup_passive_abilities()

	if player_camera:
		player_camera.enabled = false

	_register_with_coop_camera()

	print("[Lythrun] Player 2 ready! Scaling: %.0f%% (%s)" % [scaling_factor * 100, LythrunStatsScaling.get_scaling_description(scaling_factor)])


# ============ PROCESS — INPUT ROUTING TO SUBSYSTEMS ============

func _process(delta: float) -> void:
	if is_dead:
		return

	if not InputManager or not InputManager.p2_active:
		return

	# Void Parry state machine update (must run every frame for timer)
	if void_parry_system:
		void_parry_system.process_parry(delta)

	# Void Orbs charge update
	if void_orbs_system and void_orbs_system.is_charging():
		void_orbs_system.process_charge(delta)

	# ===== INPUT ROUTING =====

	# Dodge (B Button)
	if InputManager.is_p2_action_just_pressed("dodge"):
		if shadow_dash_system:
			shadow_dash_system.dodge()

	# Shadow Dash (LB) — only if RT not held (RT+LB = Phase Shift)
	if InputManager.is_p2_action_just_pressed("dash") and not InputManager.is_p2_rt_held():
		if shadow_dash_system:
			shadow_dash_system.shadow_dash()

	# Phase Shift (RT+LB)
	if InputManager.is_p2_action_just_pressed("dash") and InputManager.is_p2_rt_held():
		_activate_phase_shift()

	# Void Rift (Attack + Down in air)
	var input_vector = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
	if not is_on_floor() and input_vector.y > 0.5:
		if InputManager.is_p2_action_just_pressed("attack"):
			if void_rift_system:
				void_rift_system.activate()

	# Void Strike / Charged Void Strike (Attack button)
	if InputManager.is_p2_action_just_pressed("attack") and (is_on_floor() or input_vector.y <= 0.5):
		if InputManager.is_p2_rt_held():
			if lythrun_combat:
				lythrun_combat.charged_attack()
		else:
			if lythrun_combat:
				lythrun_combat.request_attack()

	# Shadow Scythe (RT+Y)
	if InputManager.is_p2_action_just_pressed("shadow_scythe") and InputManager.is_p2_rt_held():
		if shadow_scythe_system:
			shadow_scythe_system.toggle_scythe()

	# Void Parry (LT — hold-based)
	if InputManager.is_p2_action_just_pressed("void_parry"):
		if void_parry_system:
			void_parry_system.start_parry()

	# Void Orbs (RB — charge/release)
	if InputManager.is_p2_action_just_pressed("void_orbs"):
		if void_orbs_system:
			void_orbs_system.start_charging()

	if void_orbs_system and void_orbs_system.is_charging() and not InputManager.is_p2_action_pressed("void_orbs"):
		void_orbs_system.release()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update mana from component
	if mana_component:
		current_mana = mana_component.current_mana

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Movement during Void Orb charging (restricted)
	if void_orbs_system and void_orbs_system.is_charging():
		var orb_input = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO
		velocity.x = orb_input.x * movement_speed * 0.5
		move_and_slide()
		return

	# Normal movement (if not disabled by abilities)
	if not is_dashing and not is_attacking and not is_dodging:
		var move_input = InputManager.get_p2_input_vector() if InputManager else Vector2.ZERO

		if move_input.x != 0:
			velocity.x = move_input.x * movement_speed
			if sprite:
				sprite.flip_h = move_input.x < 0
		else:
			velocity.x = move_toward(velocity.x, 0, movement_speed * delta * 10)

		move_and_slide()


# ============ STATS SCALING ============

func calculate_and_apply_scaled_stats() -> void:
	var p1_stats = get_p1_base_stats()
	scaling_factor = LythrunStatsScaling.calculate_scaling_factor()
	var scaled_stats = LythrunStatsScaling.apply_scaling_to_stats(p1_stats, scaling_factor)

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

	base_damage = int(base_damage * scaling_factor)
	print_scaled_stats(p1_stats, scaled_stats)


func get_p1_base_stats() -> Dictionary:
	var p1 = CoopManager.p1_instance if CoopManager else null
	if not p1 or not is_instance_valid(p1):
		return get_default_stats()

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

	var defaults = get_default_stats()
	for key in defaults.keys():
		if not stats.has(key):
			stats[key] = defaults[key]
	return stats


func get_default_stats() -> Dictionary:
	return {
		"max_hp": 100, "max_mana": 100, "damage": 10.0,
		"movement_speed": 300.0, "dash_speed": 800.0, "jump_force": 800.0,
		"parry_window": 0.3, "staff_throw_damage": 30.0,
		"urgathon_duration": 10.0, "mana_regen": 10.0
	}


func print_scaled_stats(p1_stats: Dictionary, scaled_stats: Dictionary) -> void:
	print("[Lythrun Stats] Scaling Factor: %.0f%%" % (scaling_factor * 100))
	print("  HP: %d (P1: %d)" % [scaled_stats.max_hp, p1_stats.get("max_hp", 0)])
	print("  Mana: %d (P1: %d)" % [scaled_stats.max_mana, p1_stats.get("max_mana", 0)])


# ============ SHADOW AESTHETIC ============

func activate_shadow_aesthetic() -> void:
	if sprite:
		sprite.modulate = Color(0.4, 0.2, 0.7, 1.0)
	if shadow_trail:
		shadow_trail.emitting = true
		shadow_trail.amount = 16
	if dark_aura:
		dark_aura.enabled = true
		dark_aura.color = Color(0.4, 0.2, 0.6, 1.0)
		dark_aura.energy = 0.3


func _register_with_coop_camera() -> void:
	await get_tree().process_frame
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("set_player2"):
		camera.set_player2(self)
	var hud_manager = get_node_or_null("/root/HUDManager")
	if hud_manager and hud_manager.has_method("set_p2_reference"):
		hud_manager.set_p2_reference(self)


# ============ COLLISION LAYERS ============

func set_coop_collision() -> void:
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(1, true)   # World
	set_collision_mask_value(4, true)   # Enemies
	set_collision_mask_value(5, true)   # P1 Projectiles
	set_collision_mask_value(7, true)   # Pickups
	set_collision_mask_value(8, true)   # Hazards


# ============ SIGNAL HANDLERS ============

func _connect_signals() -> void:
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.health_depleted.connect(_on_health_depleted)
	if mana_component:
		mana_component.mana_changed.connect(_on_mana_changed)
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)


func _setup_passive_abilities() -> void:
	var myrkurs_echo_script = load("res://player/abilities/myrkurs_echo.gd")
	if myrkurs_echo_script:
		myrkurs_echo = Node.new()
		myrkurs_echo.set_script(myrkurs_echo_script)
		myrkurs_echo.name = "MyrkursEcho"
		add_child(myrkurs_echo)


func _on_health_changed(new_health: int, _max_health: int) -> void:
	print("[Lythrun] HP: %d/%d" % [new_health, _max_health])

func _on_mana_changed(new_mana: int, _max_mana: int) -> void:
	current_mana = new_mana

func _on_damage_taken(damage: int) -> void:
	if is_invulnerable:
		return
	if AudioManager:
		AudioManager.play_sfx("player_hurt")
	if player_camera and player_camera.enabled:
		player_camera.shake_light()
	_flash_sprite_shadow()

func _on_damage_received(damage: int, knockback: Vector2, _hitstun: float) -> void:
	if is_invulnerable:
		return
	velocity = knockback

func _on_health_depleted() -> void:
	if is_dead or is_invulnerable:
		return
	is_dead = true
	set_physics_process(false)
	set_process_input(false)
	if AudioManager:
		AudioManager.play_sfx("player_hurt")
	spawn_shadow_death_vfx()


# ============ VISUAL FEEDBACK ============

func _flash_sprite_shadow() -> void:
	if not sprite:
		return
	var original_modulate: Color = sprite.modulate
	sprite.modulate = Color(0.3, 0, 0.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)

func spawn_shadow_death_vfx() -> void:
	if shadow_trail:
		shadow_trail.emitting = false
	if dark_aura:
		dark_aura.enabled = false


# ============ SPAWN/DESPAWN ============

func play_spawn_animation() -> void:
	set_invulnerable(true)
	if sprite:
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 1.0)
		tween.tween_callback(func(): set_invulnerable(false))

func set_invulnerable(invuln: bool) -> void:
	is_invulnerable = invuln
	if hurtbox:
		hurtbox.set_deferred("monitoring", not invuln)

func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	is_dead = false
	set_physics_process(true)
	set_process_input(true)
	activate_shadow_aesthetic()


# ============ DAMAGE & PHASE SHIFT ============

func take_damage(damage: float) -> void:
	# Phase-Shift armor check (delegated from PhaseShiftSystem)
	if phase_shift_armor:
		print("[Phase-Shift] 1-Hit absorbed!")
		phase_shift_armor = false
		phase_shift_active = false
		_spawn_phase_shift_absorb_vfx()
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("phase_shift_absorb")
		return

	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage)


func _activate_phase_shift() -> void:
	# Phase Shift: RT+LB — 1-hit armor
	const PHASE_SHIFT_MANA_COST: int = 60
	const PHASE_SHIFT_DURATION: float = 5.0
	const PHASE_SHIFT_COOLDOWN: float = 12.0

	if phase_shift_active or current_mana < PHASE_SHIFT_MANA_COST:
		return

	consume_mana(PHASE_SHIFT_MANA_COST)
	phase_shift_active = true
	phase_shift_armor = true

	# Flicker effect
	if sprite:
		var flicker_tween = create_tween()
		flicker_tween.set_loops()
		flicker_tween.tween_property(sprite, "modulate:a", 0.5, 0.15)
		flicker_tween.tween_property(sprite, "modulate:a", 0.8, 0.15)

		# Duration timer
		await get_tree().create_timer(PHASE_SHIFT_DURATION).timeout
		if is_instance_valid(self):
			flicker_tween.kill()
			sprite.modulate.a = 1.0
			phase_shift_active = false
			phase_shift_armor = false

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("phase_shift")
	print("[Lythrun] Phase Shift activated (%.0fs)" % PHASE_SHIFT_DURATION)


func _spawn_phase_shift_absorb_vfx() -> void:
	var flash = Sprite2D.new()
	flash.texture = PlaceholderTexture2D.new()
	if flash.texture is PlaceholderTexture2D:
		flash.texture.size = Vector2(80, 80)
	flash.modulate = Color(0.5, 0.1, 0.8, 0.8)
	flash.global_position = global_position
	get_parent().add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.3)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


# ============ UTILITY ============

func consume_mana(amount: int) -> void:
	if mana_component and mana_component.has_method("use_mana"):
		mana_component.use_mana(amount)
	current_mana = mana_component.current_mana if mana_component else current_mana - amount
