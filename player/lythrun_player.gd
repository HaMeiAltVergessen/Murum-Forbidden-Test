extends CharacterBody2D
## Lythrun - Player 2 Character
## Shadow-themed co-op partner for Murum with adaptive stats scaling
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

	if mana_component:
		mana_component.max_mana = scaled_stats.max_mana
		mana_component.current_mana = scaled_stats.max_mana
		mana_component.regeneration_rate = scaled_stats.mana_regen

	if movement_controller:
		movement_controller.move_speed = scaled_stats.movement_speed
		movement_controller.dash_distance = scaled_stats.dash_speed * movement_controller.dash_duration
		movement_controller.jump_velocity = -scaled_stats.jump_force

	if combat_system:
		# Scale attack damages
		for i in range(combat_system.attack_damages.size()):
			combat_system.attack_damages[i] = int(combat_system.attack_damages[i] * scaling_factor)

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
		stats["max_hp"] = hp.max_health if hp.has("max_health") else 100

	if p1.has_node("ManaComponent"):
		var mana = p1.get_node("ManaComponent")
		stats["max_mana"] = mana.max_mana if mana.has("max_mana") else 100
		stats["mana_regen"] = mana.regeneration_rate if mana.has("regeneration_rate") else 10.0

	if p1.has_node("MovementController"):
		var movement = p1.get_node("MovementController")
		stats["movement_speed"] = movement.move_speed if movement.has("move_speed") else 300.0
		stats["dash_speed"] = movement.dash_distance if movement.has("dash_distance") else 800.0
		stats["jump_force"] = abs(movement.jump_velocity) if movement.has("jump_velocity") else 800.0

	if p1.has_node("CombatSystem"):
		var combat = p1.get_node("CombatSystem")
		if combat.has("attack_damages") and combat.attack_damages.size() > 0:
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
	# Sprite modulation (dark violet)
	if sprite:
		sprite.modulate = Color(0.7, 0.5, 0.9, 1.0)

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
