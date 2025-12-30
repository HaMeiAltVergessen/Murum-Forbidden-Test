extends CharacterBody2D
## Lythrun - Player 2 Character
## Shadow-themed co-op partner for Murum
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

# ============ P2-SPECIFIC ============
var is_player_2: bool = true
var input_prefix: String = "p2_"
var is_invulnerable: bool = false

# ============ SHADOW VFX ============
@onready var shadow_trail: GPUParticles2D = $ShadowTrail if has_node("ShadowTrail") else null
@onready var dark_aura: PointLight2D = $DarkAura if has_node("DarkAura") else null

# ============ STATE ============
var is_dead: bool = false

func _ready() -> void:
	print("[Lythrun] Player 2 initialized")

	# Set co-op collision layers
	set_coop_collision()

	# Enable shadow VFX
	if shadow_trail:
		shadow_trail.emitting = true

	if dark_aura:
		dark_aura.enabled = true

	# Connect signals
	_connect_signals()

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

# ============ COLLISION LAYERS (CO-OP MODE) ============
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

	# Does NOT collide with Player1 (layer 2)
	print("[Lythrun] Co-op collision layers set")

func set_pvp_collision() -> void:
	"""Set collision layers for PvP mode (future)"""
	# Add collision with P1
	set_collision_mask_value(2, true)  # Player1 layer
	print("[Lythrun] PvP collision layers set")

# ============ SPAWN/DESPAWN ============
func play_spawn_animation() -> void:
	"""Play spawn-from-abyss animation"""
	print("[Lythrun] Playing spawn animation")

	# Set invulnerable during spawn
	is_invulnerable = true

	# TODO: Play actual spawn animation when AnimatedSprite2D is set up
	# For now, just a simple fade-in
	if sprite:
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 1.0)

func set_invulnerable(invuln: bool) -> void:
	"""Set invulnerability state"""
	is_invulnerable = invuln

	# Disable/enable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitoring", not invuln)

	print("[Lythrun] Invulnerable: ", invuln)

# ============ SIGNAL HANDLERS ============
func _on_health_changed(new_health: int, max_health: int) -> void:
	"""Handle health changes"""
	# TODO: Emit P2-specific health change signal
	print("[Lythrun] HP: %d/%d" % [new_health, max_health])

func _on_mana_changed(new_mana: int, max_mana: int) -> void:
	"""Handle mana changes"""
	# TODO: Emit P2-specific mana change signal
	print("[Lythrun] Mana: %d/%d" % [new_mana, max_mana])

func _on_damage_taken(damage: int) -> void:
	"""Handle damage taken"""
	if is_invulnerable:
		return

	if AudioManager:
		AudioManager.play_sfx("player_hurt")

	# Camera shake (if camera exists)
	if player_camera:
		player_camera.shake_light()

	# Visual feedback
	_flash_sprite()

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

	print("[Lythrun] Player 2 died")

	# CoopManager handles respawn logic

func _on_dodge_started(_direction: Vector2) -> void:
	"""Handle dodge roll start"""
	if combat_system:
		combat_system.set_combat_enabled(false)

func _on_dodge_completed() -> void:
	"""Handle dodge roll completion"""
	if combat_system:
		combat_system.set_combat_enabled(true)

# ============ VISUAL FEEDBACK ============
func _flash_sprite() -> void:
	"""Create white flash effect on damage"""
	if not sprite:
		return

	var original_modulate: Color = sprite.modulate

	# Flash white
	sprite.modulate = Color(2, 2, 2, 1)

	# Tween back to normal
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.1)

# ============ PUBLIC METHODS ============
func respawn(spawn_position: Vector2) -> void:
	"""Respawn at given position"""
	global_position = spawn_position
	is_dead = false

	# Re-enable controls
	set_physics_process(true)
	set_process_input(true)

	print("[Lythrun] Player 2 respawned at ", spawn_position)
