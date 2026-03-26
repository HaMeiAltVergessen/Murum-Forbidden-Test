extends Node2D
class_name CosmicEye

## F3.2 - Kosmisches Auge (W3 Kosmischer Horror)
## Wall/ceiling eye that fires DoT beam while player is in line of sight
## Destroyable (HP=40). Slow rotation tracking.
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal eye_opened()
signal eye_locked_on(target: Node2D)
signal eye_beam_started()
signal eye_beam_stopped()
signal eye_destroyed()

# ============================================================================
# ENUMS
# ============================================================================

enum State { CLOSED, OPENING, OPEN, TRACKING, FIRING, DESTROYED }

# ============================================================================
# EXPORTS
# ============================================================================

@export var hp: int = 40
@export var max_hp: int = 40
@export var damage_per_second: float = 8.0
@export var rotation_speed: float = 60.0       ## Degrees/s
@export var activation_range: float = 500.0
@export var open_delay: float = 1.0

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.CLOSED
var current_target: Node2D = null
var has_line_of_sight: bool = false
var damage_accumulator: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var eye_visual: ColorRect = $EyeVisual if has_node("EyeVisual") else null
@onready var pupil_visual: ColorRect = $PupilVisual if has_node("PupilVisual") else null
@onready var iris_visual: ColorRect = $IrisVisual if has_node("IrisVisual") else null
@onready var beam_visual: Line2D = $BeamVisual if has_node("BeamVisual") else null
@onready var raycast: RayCast2D = $RayCast2D if has_node("RayCast2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var hurtbox_area: Area2D = $HurtboxArea if has_node("HurtboxArea") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Detection area
	if detection_area:
		detection_area.monitoring = true
		detection_area.monitorable = false
		detection_area.body_entered.connect(_on_player_in_range)
		detection_area.body_exited.connect(_on_player_out_of_range)

		detection_area.collision_layer = 0
		detection_area.set_collision_layer_value(7, true)
		detection_area.collision_mask = 0
		detection_area.set_collision_mask_value(2, true)
		detection_area.set_collision_mask_value(3, true)

		var shape = detection_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = activation_range

	# Hurtbox (receives damage from players)
	if hurtbox_area:
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true
		hurtbox_area.area_entered.connect(_on_hit_by_attack)

		hurtbox_area.collision_layer = 0
		hurtbox_area.set_collision_layer_value(4, true)
		hurtbox_area.collision_mask = 0
		hurtbox_area.set_collision_mask_value(16, true)

	# Raycast for LoS
	if raycast:
		raycast.enabled = false
		raycast.collide_with_areas = false
		raycast.collide_with_bodies = true
		# Detect world geometry only
		raycast.collision_mask = 0
		raycast.set_collision_mask_value(1, true)   # World

	# Beam hidden
	if beam_visual:
		beam_visual.visible = false

	# Start closed
	_set_closed_visual()

	add_to_group("traps")
	add_to_group("cosmic_eyes")

	print("[CosmicEye] %s initialized (HP: %d, range: %.0f)" % [name, hp, activation_range])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	match current_state:
		State.OPEN, State.TRACKING:
			_process_tracking(delta)
		State.FIRING:
			_process_firing(delta)

func _process_tracking(delta: float) -> void:
	"""Rotate towards target and check LoS"""
	if not current_target or not is_instance_valid(current_target):
		current_target = _find_nearest_player()
		if not current_target:
			_stop_beam()
			return

	# Rotate pupil towards target
	_rotate_towards_target(delta)

	# Check line of sight
	_check_line_of_sight()

	if has_line_of_sight and current_state == State.TRACKING:
		_start_beam()

func _process_firing(delta: float) -> void:
	"""Apply damage via beam"""
	if not current_target or not is_instance_valid(current_target):
		_stop_beam()
		return

	# Continue tracking
	_rotate_towards_target(delta)
	_check_line_of_sight()

	if not has_line_of_sight:
		_stop_beam()
		return

	# Apply DoT
	damage_accumulator += damage_per_second * delta
	if damage_accumulator >= 1.0:
		var dmg = int(damage_accumulator)
		damage_accumulator -= dmg

		var health_comp = current_target.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(dmg)

	# Update beam visual
	_update_beam_visual()

	# Pupil pulse
	if pupil_visual:
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
		pupil_visual.modulate = Color(1.0, pulse * 0.3, pulse * 0.3)

func _rotate_towards_target(delta: float) -> void:
	"""Slowly rotate towards target"""
	if not current_target or not is_instance_valid(current_target):
		return

	var target_dir = (current_target.global_position - global_position).normalized()
	var desired_angle = target_dir.angle()

	# Current look direction (from raycast or pupil offset)
	var current_angle = 0.0
	if raycast:
		current_angle = raycast.rotation

	var angle_diff = wrapf(desired_angle - current_angle, -PI, PI)
	var max_rot = deg_to_rad(rotation_speed) * delta
	var new_angle = current_angle + clampf(angle_diff, -max_rot, max_rot)

	if raycast:
		raycast.rotation = new_angle

	# Move pupil visual to show tracking
	if pupil_visual:
		var pupil_offset = Vector2.from_angle(new_angle) * 8.0
		pupil_visual.position = pupil_offset

func _check_line_of_sight() -> void:
	"""Check if raycast can see target"""
	if not raycast or not current_target or not is_instance_valid(current_target):
		has_line_of_sight = false
		return

	raycast.enabled = true
	raycast.target_position = raycast.to_local(current_target.global_position)
	raycast.force_raycast_update()

	# If ray hits nothing or hits past the target, we have LoS
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var dist_to_wall = global_position.distance_to(collision_point)
		var dist_to_target = global_position.distance_to(current_target.global_position)
		has_line_of_sight = dist_to_wall > dist_to_target * 0.9
	else:
		has_line_of_sight = true

# ============================================================================
# BEAM
# ============================================================================

func _start_beam() -> void:
	"""Start firing beam at target"""
	current_state = State.FIRING
	damage_accumulator = 0.0

	if beam_visual:
		beam_visual.visible = true

	eye_beam_started.emit()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/eye_beam_start", global_position, 0.25)

	print("[CosmicEye] %s beam started on %s" % [name, current_target.name if current_target else "?"])

func _stop_beam() -> void:
	"""Stop beam"""
	if current_state == State.FIRING:
		current_state = State.TRACKING if current_target else State.OPEN

	if beam_visual:
		beam_visual.visible = false

	eye_beam_stopped.emit()

func _update_beam_visual() -> void:
	"""Update beam line from eye to target"""
	if not beam_visual or not current_target or not is_instance_valid(current_target):
		return

	beam_visual.clear_points()
	beam_visual.add_point(Vector2.ZERO)
	beam_visual.add_point(to_local(current_target.global_position))

# ============================================================================
# DETECTION
# ============================================================================

func _on_player_in_range(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	if current_state == State.CLOSED:
		_open_eye()

	if current_target == null:
		current_target = body

func _on_player_out_of_range(body: Node2D) -> void:
	if body == current_target:
		_stop_beam()
		current_target = _find_nearest_player()

func _find_nearest_player() -> Node2D:
	if not detection_area:
		return null

	var nearest: Node2D = null
	var nearest_dist: float = INF

	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player") or body.is_in_group("player2"):
			var dist = global_position.distance_to(body.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = body

	return nearest

# ============================================================================
# OPEN / CLOSE
# ============================================================================

func _open_eye() -> void:
	current_state = State.OPENING

	# Open animation
	if eye_visual:
		eye_visual.modulate.a = 0.3
		var tween = create_tween()
		tween.tween_property(eye_visual, "modulate:a", 1.0, open_delay)

	if pupil_visual:
		pupil_visual.visible = true
		pupil_visual.scale = Vector2(0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(pupil_visual, "scale", Vector2.ONE, open_delay)

	eye_opened.emit()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/eye_open", global_position, 0.3)

	await get_tree().create_timer(open_delay).timeout
	if current_state == State.OPENING:
		current_state = State.TRACKING

func _set_closed_visual() -> void:
	if pupil_visual:
		pupil_visual.visible = false
	if eye_visual:
		eye_visual.modulate.a = 0.3

# ============================================================================
# DAMAGE (Destroyable)
# ============================================================================

func _on_hit_by_attack(area: Area2D) -> void:
	if current_state == State.DESTROYED or current_state == State.CLOSED:
		return

	if not (area.is_in_group("hitbox") or area.name == "HitboxComponent" or "hitbox" in area.name.to_lower()):
		return

	var hit_damage = 10
	if area.has_method("get_damage"):
		hit_damage = area.get_damage()
	elif "damage" in area:
		hit_damage = area.damage

	hp -= hit_damage

	# Hit flash
	if eye_visual:
		var tween = create_tween()
		tween.tween_property(eye_visual, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		tween.tween_property(eye_visual, "modulate", Color.WHITE, 0.1)

	print("[CosmicEye] %s hit! HP: %d/%d" % [name, hp, max_hp])

	if hp <= 0:
		_destroy()

func _destroy() -> void:
	"""Eye permanently destroyed"""
	current_state = State.DESTROYED

	_stop_beam()

	eye_destroyed.emit()

	# Disable all areas
	if detection_area:
		detection_area.monitoring = false
	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	# Explosion visual
	if eye_visual:
		var tween = create_tween()
		tween.tween_property(eye_visual, "modulate", Color(2.0, 0.5, 1.0), 0.1)
		tween.tween_property(eye_visual, "scale", Vector2(1.5, 1.5), 0.3)
		tween.parallel().tween_property(eye_visual, "modulate:a", 0.0, 0.3)

	if pupil_visual:
		pupil_visual.visible = false

	# Camera shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.25)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/eye_destroy", global_position, 0.4)

	print("[CosmicEye] %s destroyed!" % name)
