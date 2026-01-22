extends RigidBody2D
class_name FallingRock

## F2 - Fallende Steine
## Rock falls when player enters proximity, deals damage on landing
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal rock_triggered()
signal rock_warning()
signal rock_landed()

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 35
@export var trigger_range: float = 100.0
@export var warning_duration: float = 0.5
@export var damage_radius: float = 50.0
@export var destroy_after_landing: bool = false
@export var destroy_delay: float = 5.0

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, WARNING, FALLING, LANDED }
var current_state: State = State.IDLE

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var proximity_detector: Area2D = $ProximityDetector if has_node("ProximityDetector") else null
@onready var damage_area: Area2D = $DamageArea if has_node("DamageArea") else null
@onready var warning_particles: GPUParticles2D = $WarningParticles if has_node("WarningParticles") else null
@onready var impact_particles: GPUParticles2D = $ImpactParticles if has_node("ImpactParticles") else null

var warning_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Godot 4.4: Explicitly set RigidBody2D properties
	contact_monitor = true
	max_contacts_reported = 4
	freeze = true

	# Connect collision signal
	body_entered.connect(_on_body_collision)

	# Setup proximity detector
	if proximity_detector:
		proximity_detector.monitoring = true
		proximity_detector.monitorable = false
		proximity_detector.body_entered.connect(_on_proximity_entered)

		# COMMIT 018: Set collision mask for both P1 and P2
		proximity_detector.collision_layer = 0
		proximity_detector.set_collision_layer_value(7, true)  # Hazards (Layer 7)

		proximity_detector.collision_mask = 0
		proximity_detector.set_collision_mask_value(2, true)   # P1 Body (Layer 2)
		proximity_detector.set_collision_mask_value(3, true)   # P2 Body (Layer 3)

		print("[FallingRock] Proximity collision setup - Layer: %d, Mask: %d" % [proximity_detector.collision_layer, proximity_detector.collision_mask])

	# Setup damage area
	if damage_area:
		damage_area.monitoring = false
		damage_area.monitorable = false

	# Create warning timer
	warning_timer = Timer.new()
	warning_timer.one_shot = true
	warning_timer.wait_time = warning_duration
	warning_timer.timeout.connect(_on_warning_complete)
	add_child(warning_timer)

	add_to_group("traps")
	add_to_group("falling_rocks")

	print("[FallingRock] %s initialized at %v" % [name, global_position])

# ============================================================================
# TRIGGER
# ============================================================================

func _on_proximity_entered(body: Node2D) -> void:
	"""Player enters proximity - start warning"""
	if current_state != State.IDLE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	print("[FallingRock] %s proximity triggered by %s" % [name, body.name])
	_start_warning()

func _start_warning() -> void:
	"""Start warning phase"""
	current_state = State.WARNING
	rock_warning.emit()

	# Visual feedback
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.2)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# Particles
	if warning_particles:
		warning_particles.emitting = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/stone_rumble", global_position, 0.3)

	# Camera shake
	_apply_camera_shake(0.1)

	# Start timer
	warning_timer.start()

	print("[FallingRock] %s warning started" % name)

func _on_warning_complete() -> void:
	"""Warning complete - start falling"""
	_start_falling()

# ============================================================================
# FALLING
# ============================================================================

func _start_falling() -> void:
	"""Start falling"""
	current_state = State.FALLING
	rock_triggered.emit()

	# Unfreeze
	freeze = false
	gravity_scale = 2.0

	# Stop warning particles
	if warning_particles:
		warning_particles.emitting = false

	print("[FallingRock] %s falling" % name)

# ============================================================================
# LANDING
# ============================================================================

func _on_body_collision(body: Node) -> void:
	"""Rock collides with something"""
	if current_state != State.FALLING:
		return

	# Check if collision is with floor/wall
	if body is TileMap or body is StaticBody2D or body.is_in_group("world"):
		_land()

func _land() -> void:
	"""Rock lands"""
	current_state = State.LANDED
	rock_landed.emit()

	# Freeze in place
	freeze = true

	# Check for players in damage radius
	_check_damage_on_landing()

	# Visual feedback
	if impact_particles:
		impact_particles.restart()
		impact_particles.emitting = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/rock_impact", global_position, 0.5)

	# Camera shake
	_apply_camera_shake(0.3)

	# Destroy after delay
	if destroy_after_landing:
		await get_tree().create_timer(destroy_delay).timeout
		queue_free()

	print("[FallingRock] %s landed" % name)

# ============================================================================
# DAMAGE
# ============================================================================

func _check_damage_on_landing() -> void:
	"""Check if any players are in damage radius and deal damage"""
	var players = get_tree().get_nodes_in_group("player")
	players.append_array(get_tree().get_nodes_in_group("player2"))

	for player in players:
		if not is_instance_valid(player):
			continue

		var distance = global_position.distance_to(player.global_position)
		if distance <= damage_radius:
			_deal_damage(player)

func _deal_damage(player: Node2D) -> void:
	"""Deal damage to player with knockback"""
	# Calculate knockback direction (away from rock center)
	var knockback_direction = (player.global_position - global_position).normalized()
	var knockback_force = 300.0

	# Apply knockback to player velocity
	if player is CharacterBody2D and "velocity" in player:
		player.velocity = knockback_direction * knockback_force
		player.velocity.y = -200.0  # Upward pop
		print("[FallingRock] %s applied knockback to %s (force: %.0f)" % [name, player.name, knockback_force])

	# Deal damage via HurtboxComponent (respects invulnerability)
	var hurtbox = player.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, knockback_direction * knockback_force, 0.3)
		print("[FallingRock] %s dealt %d damage to %s (via Hurtbox)" % [name, damage, player.name])
	else:
		# Fallback: Direct HealthComponent damage
		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage)
			print("[FallingRock] %s dealt %d damage to %s (direct)" % [name, damage, player.name])

# ============================================================================
# HELPERS
# ============================================================================

func _apply_camera_shake(trauma: float) -> void:
	"""Apply camera shake"""
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_node("PlayerCamera"):
			player.get_node("PlayerCamera").add_trauma(trauma)
