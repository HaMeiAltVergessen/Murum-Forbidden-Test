extends Node2D
class_name PendulumBlade

## F6 - Pendelklinge
## Swinging blade trap with two modes: RHYTHMIC (constant) and TRIGGERED (one-shot)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal blade_swing_started()
signal blade_hit(entity: Node2D)
signal blade_triggered()

# ============================================================================
# ENUMS
# ============================================================================

enum SwingMode {
	RHYTHMIC,    # Constant swinging back and forth
	TRIGGERED    # Hangs still, swings once on trigger, resets
}

enum State {
	IDLE,        # Not swinging (TRIGGERED mode only)
	SWINGING,    # Currently swinging
	RESETTING    # Returning to idle position (TRIGGERED mode only)
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var swing_mode: SwingMode = SwingMode.RHYTHMIC
@export var damage: int = 25
@export var knockback_force: float = 300.0
@export var swing_arc_degrees: float = 120.0  ## Total arc in degrees
@export var swing_duration: float = 2.0       ## Time for one full swing
@export var trigger_range: float = 150.0      ## Proximity range (TRIGGERED mode)
@export var reset_cooldown: float = 3.0       ## Cooldown after triggered swing

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.IDLE
var swing_time: float = 0.0
var swing_direction: float = 1.0  # 1 = right, -1 = left
var hit_entities: Array[Node2D] = []  # Prevent multi-hit per swing

# ============================================================================
# REFERENCES
# ============================================================================

@onready var pivot: Node2D = $Pivot if has_node("Pivot") else null
@onready var blade_hitbox: Area2D = $Pivot/BladeHitbox if has_node("Pivot/BladeHitbox") else null
@onready var proximity_detector: Area2D = $ProximityDetector if has_node("ProximityDetector") else null
@onready var chain_visual: Line2D = $ChainVisual if has_node("ChainVisual") else null
@onready var blade_visual: ColorRect = $Pivot/BladeVisual if has_node("Pivot/BladeVisual") else null
@onready var trail_particles: GPUParticles2D = $Pivot/TrailParticles if has_node("Pivot/TrailParticles") else null

var reset_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup blade hitbox
	if blade_hitbox:
		blade_hitbox.monitoring = true
		blade_hitbox.monitorable = false
		blade_hitbox.body_entered.connect(_on_blade_body_entered)

		# Collision: Layer 7 (Hazards), Mask 2+3 (P1+P2)
		blade_hitbox.collision_layer = 0
		blade_hitbox.set_collision_layer_value(7, true)
		blade_hitbox.collision_mask = 0
		blade_hitbox.set_collision_mask_value(2, true)
		blade_hitbox.set_collision_mask_value(3, true)

	# Setup proximity detector (TRIGGERED mode)
	if proximity_detector and swing_mode == SwingMode.TRIGGERED:
		proximity_detector.monitoring = true
		proximity_detector.monitorable = false
		proximity_detector.body_entered.connect(_on_proximity_entered)

		proximity_detector.collision_layer = 0
		proximity_detector.set_collision_layer_value(7, true)
		proximity_detector.collision_mask = 0
		proximity_detector.set_collision_mask_value(2, true)
		proximity_detector.set_collision_mask_value(3, true)

		# Set range
		var collision_shape = proximity_detector.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = trigger_range
	elif proximity_detector:
		proximity_detector.monitoring = false

	# Create reset timer (TRIGGERED mode)
	reset_timer = Timer.new()
	reset_timer.one_shot = true
	reset_timer.wait_time = reset_cooldown
	reset_timer.timeout.connect(_on_reset_complete)
	add_child(reset_timer)

	# Set initial state based on mode
	if swing_mode == SwingMode.RHYTHMIC:
		current_state = State.SWINGING
		# Disable hitbox during inactive swing phases (handled in _process)
	else:
		current_state = State.IDLE
		if blade_hitbox:
			blade_hitbox.monitoring = false

	# Set initial rotation
	if pivot:
		pivot.rotation_degrees = -swing_arc_degrees / 2.0

	add_to_group("traps")
	add_to_group("pendulum_blades")

	print("[PendulumBlade] %s initialized, mode: %s" % [name, SwingMode.keys()[swing_mode]])

# ============================================================================
# PROCESS - SWING ANIMATION
# ============================================================================

func _process(delta: float) -> void:
	if not pivot:
		return

	match current_state:
		State.SWINGING:
			_process_swing(delta)
		State.RESETTING:
			_process_reset(delta)

func _process_swing(delta: float) -> void:
	"""Process pendulum swing"""
	swing_time += delta

	var half_arc = swing_arc_degrees / 2.0

	if swing_mode == SwingMode.RHYTHMIC:
		# Sinusoidal swing: smoothly oscillates back and forth
		var phase = swing_time / swing_duration * TAU
		var swing_angle = sin(phase) * half_arc
		pivot.rotation_degrees = swing_angle

		# Clear hit list at extremes (allow re-hit per swing direction)
		var normalized_phase = fmod(swing_time / swing_duration, 1.0)
		if normalized_phase < delta / swing_duration or absf(normalized_phase - 0.5) < delta / swing_duration:
			hit_entities.clear()

		# Enable hitbox when blade is moving fast (middle of swing)
		var angular_velocity = absf(cos(phase))
		if blade_hitbox:
			blade_hitbox.monitoring = angular_velocity > 0.3

	elif swing_mode == SwingMode.TRIGGERED:
		# Single swing: goes from one side to the other
		var progress = clampf(swing_time / (swing_duration * 0.5), 0.0, 1.0)
		# Ease-in-out for natural feel
		var eased = _ease_in_out(progress)
		var start_angle = -half_arc * swing_direction
		var end_angle = half_arc * swing_direction
		pivot.rotation_degrees = lerpf(start_angle, end_angle, eased)

		# Swing complete
		if progress >= 1.0:
			_on_triggered_swing_complete()

	# Update chain visual
	_update_chain_visual()

func _process_reset(delta: float) -> void:
	"""Return blade to idle position (TRIGGERED mode)"""
	swing_time += delta
	var progress = clampf(swing_time / 0.5, 0.0, 1.0)  # 0.5s reset
	var current_rot = pivot.rotation_degrees
	pivot.rotation_degrees = lerpf(current_rot, -swing_arc_degrees / 2.0, progress * 0.1)

	if absf(pivot.rotation_degrees - (-swing_arc_degrees / 2.0)) < 1.0:
		pivot.rotation_degrees = -swing_arc_degrees / 2.0
		current_state = State.IDLE
		if blade_hitbox:
			blade_hitbox.monitoring = false
		print("[PendulumBlade] %s reset complete" % name)

# ============================================================================
# TRIGGERED MODE
# ============================================================================

func _on_proximity_entered(body: Node2D) -> void:
	"""Player enters proximity - trigger swing"""
	if current_state != State.IDLE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	_trigger_swing()

func _trigger_swing() -> void:
	"""Start a single triggered swing"""
	current_state = State.SWINGING
	swing_time = 0.0
	hit_entities.clear()

	# Randomize swing direction
	swing_direction = 1.0 if randf() > 0.5 else -1.0

	if blade_hitbox:
		blade_hitbox.monitoring = true

	blade_triggered.emit()
	blade_swing_started.emit()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/blade_swing", global_position, 0.3)

	print("[PendulumBlade] %s triggered swing (dir: %.0f)" % [name, swing_direction])

func _on_triggered_swing_complete() -> void:
	"""Triggered swing finished"""
	current_state = State.RESETTING
	swing_time = 0.0

	if blade_hitbox:
		blade_hitbox.monitoring = false

	# Start cooldown
	reset_timer.wait_time = reset_cooldown
	reset_timer.start()

func _on_reset_complete() -> void:
	"""Cooldown complete, ready to trigger again"""
	# Reset will finish via _process_reset
	pass

# ============================================================================
# DAMAGE
# ============================================================================

func _on_blade_body_entered(body: Node2D) -> void:
	"""Blade hits a body"""
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Prevent multi-hit in same swing
	if body in hit_entities:
		return

	hit_entities.append(body)

	# Calculate knockback in swing direction
	var swing_angle_rad = deg_to_rad(pivot.rotation_degrees)
	var knockback_dir = Vector2(cos(swing_angle_rad), sin(swing_angle_rad)).normalized()
	if knockback_dir.length() < 0.1:
		knockback_dir = (body.global_position - global_position).normalized()

	# Deal damage via HurtboxComponent
	var hurtbox = body.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, knockback_dir * knockback_force, 0.3)
		print("[PendulumBlade] %s hit %s for %d damage" % [name, body.name, damage])
	else:
		# Fallback: HealthComponent
		var health_comp = body.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage)

	blade_hit.emit(body)

	# Camera shake
	_apply_camera_shake(0.2)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/blade_hit", global_position, 0.4)

# ============================================================================
# VISUALS
# ============================================================================

func _update_chain_visual() -> void:
	"""Update chain line from pivot to blade"""
	if chain_visual and pivot:
		chain_visual.clear_points()
		chain_visual.add_point(Vector2.ZERO)  # Pivot point (local)
		# Calculate blade tip position relative to this node
		if blade_visual:
			var blade_pos = blade_visual.global_position - global_position
			chain_visual.add_point(blade_pos)

# ============================================================================
# HELPERS
# ============================================================================

func _ease_in_out(t: float) -> float:
	"""Smooth ease-in-out curve"""
	return t * t * (3.0 - 2.0 * t)

func _apply_camera_shake(trauma: float) -> void:
	"""Apply camera shake to nearest player"""
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_node("PlayerCamera"):
			player.get_node("PlayerCamera").add_trauma(trauma)
