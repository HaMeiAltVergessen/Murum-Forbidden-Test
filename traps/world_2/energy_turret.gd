extends Node2D
class_name EnergyTurret

## F2.1 - Energieturret (W2 Sci-Fi Reskin der Pfeilfalle)
## Stationary turret that rotates towards player and fires energy bolts
## Can be stunned by attacks: retracts into ground, re-emerges after cooldown
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal turret_fired()
signal turret_stunned()
signal turret_emerged()
signal turret_hit(entity: Node2D)

# ============================================================================
# ENUMS
# ============================================================================

enum State {
	ACTIVE,       # Tracking and firing
	RETRACTING,   # Sinking into ground (stunned)
	RETRACTED,    # Hidden underground
	EMERGING,     # Rising back up
	WARNING       # About to re-emerge (blink warning)
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 18
@export var fire_rate: float = 1.5
@export var bolt_speed: float = 350.0
@export var detection_range: float = 400.0
@export var rotation_speed: float = 90.0       ## Degrees/s turret head rotation
@export var retract_duration: float = 6.0       ## Time hidden underground
@export var warning_duration: float = 1.0       ## Blink warning before re-emerge
@export var stun_hp: int = 1                    ## Hits needed to stun (1 = any hit)

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.ACTIVE
var current_target: Node2D = null
var hits_taken: int = 0
var original_position: Vector2 = Vector2.ZERO
var turret_height: float = 48.0  # Visual height for retract animation

# ============================================================================
# REFERENCES
# ============================================================================

@onready var turret_head: Node2D = $TurretHead if has_node("TurretHead") else null
@onready var fire_point: Marker2D = $TurretHead/FirePoint if has_node("TurretHead/FirePoint") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var hurtbox: Area2D = $HurtboxArea if has_node("HurtboxArea") else null
@onready var turret_visual: AnimatedSprite2D = $TurretVisual if has_node("TurretVisual") else null
@onready var head_visual: Sprite2D = $TurretHead/HeadVisual if has_node("TurretHead/HeadVisual") else null

var fire_timer: Timer = null
var retract_timer: Timer = null
var bolt_scene: PackedScene = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	original_position = position
	bolt_scene = preload("res://traps/world_2/scenes/energy_bolt.tscn")

	# Fire timer
	fire_timer = Timer.new()
	fire_timer.one_shot = false
	fire_timer.wait_time = fire_rate
	fire_timer.timeout.connect(_on_fire_timer)
	add_child(fire_timer)

	# Retract timer
	retract_timer = Timer.new()
	retract_timer.one_shot = true
	retract_timer.timeout.connect(_on_retract_timer)
	add_child(retract_timer)

	# Setup detection area
	if detection_area:
		detection_area.monitoring = true
		detection_area.monitorable = false
		detection_area.body_entered.connect(_on_player_detected)
		detection_area.body_exited.connect(_on_player_lost)

		detection_area.collision_layer = 0
		detection_area.set_collision_layer_value(7, true)
		detection_area.collision_mask = 0
		detection_area.set_collision_mask_value(2, true)
		detection_area.set_collision_mask_value(3, true)

		# Set range
		var shape = detection_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = detection_range

	# Setup hurtbox (receives player attacks for stunning)
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		hurtbox.area_entered.connect(_on_hit_by_attack)

		hurtbox.collision_layer = 0
		hurtbox.set_collision_layer_value(4, true)   # Enemy layer (so player hitbox hits it)
		hurtbox.collision_mask = 0
		hurtbox.set_collision_mask_value(16, true)   # Hitbox layer (player attacks)

	add_to_group("traps")
	add_to_group("energy_turrets")

	print("[EnergyTurret] %s initialized (range: %.0f, fire_rate: %.1fs)" % [name, detection_range, fire_rate])

# ============================================================================
# PROCESS - TRACKING
# ============================================================================

func _process(delta: float) -> void:
	if current_state != State.ACTIVE:
		return

	if not turret_head:
		return

	# Track current target
	if current_target and is_instance_valid(current_target):
		var target_pos = current_target.global_position
		var desired_angle = (target_pos - global_position).angle()
		var current_angle = turret_head.rotation

		# Smooth rotation towards target
		var angle_diff = wrapf(desired_angle - current_angle, -PI, PI)
		var max_rotation = deg_to_rad(rotation_speed) * delta
		turret_head.rotation += clampf(angle_diff, -max_rotation, max_rotation)

# ============================================================================
# DETECTION
# ============================================================================

func _on_player_detected(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	if current_state != State.ACTIVE:
		return

	if current_target == null:
		current_target = body
		fire_timer.start()
		print("[EnergyTurret] %s targeting %s" % [name, body.name])

func _on_player_lost(body: Node2D) -> void:
	if body == current_target:
		# Check if other players in range
		current_target = _find_nearest_player()
		if current_target == null:
			fire_timer.stop()

func _find_nearest_player() -> Node2D:
	"""Find nearest player in detection range"""
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
# FIRING
# ============================================================================

func _on_fire_timer() -> void:
	if current_state != State.ACTIVE:
		return

	if current_target and is_instance_valid(current_target):
		_fire_bolt()

func _fire_bolt() -> void:
	if not bolt_scene:
		return

	var bolt: EnergyBolt = bolt_scene.instantiate()
	bolt.damage = damage
	bolt.speed = bolt_speed

	# Direction towards target
	if current_target and is_instance_valid(current_target):
		bolt.direction = (current_target.global_position - global_position).normalized()
	else:
		bolt.direction = Vector2.RIGHT.rotated(turret_head.rotation) if turret_head else Vector2.RIGHT

	get_parent().add_child(bolt)
	# Position at fire point (after add_child so global_position applies correctly)
	if fire_point:
		bolt.global_position = fire_point.global_position
	else:
		bolt.global_position = global_position
	turret_fired.emit()

	# Visual recoil
	if head_visual:
		var tween = create_tween()
		tween.tween_property(head_visual, "modulate", Color(1.5, 1.5, 1.5), 0.05)
		tween.tween_property(head_visual, "modulate", Color.WHITE, 0.1)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/turret_fire", global_position, 0.25)

	print("[EnergyTurret] %s fired bolt" % name)

# ============================================================================
# STUN SYSTEM (Hit → Retract → Emerge)
# ============================================================================

func _on_hit_by_attack(area: Area2D) -> void:
	"""Turret hit by player attack"""
	if current_state != State.ACTIVE:
		return

	# Check if it's a player hitbox
	if not (area.is_in_group("hitbox") or area.name == "HitboxComponent" or "hitbox" in area.name.to_lower()):
		return

	hits_taken += 1

	if hits_taken >= stun_hp:
		_start_retract()

func _start_retract() -> void:
	"""Turret retracts into ground"""
	current_state = State.RETRACTING
	hits_taken = 0

	fire_timer.stop()
	current_target = null

	# Disable hitbox
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false

	turret_stunned.emit()

	# Retract animation: sink into ground
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_position.y + turret_height, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_fully_retracted)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/turret_retract", global_position, 0.3)

	print("[EnergyTurret] %s stunned, retracting" % name)

func _on_fully_retracted() -> void:
	"""Turret is fully hidden"""
	current_state = State.RETRACTED
	visible = false

	# Disable detection
	if detection_area:
		detection_area.monitoring = false

	# Start retract timer (minus warning duration)
	retract_timer.wait_time = maxf(retract_duration - warning_duration, 1.0)
	retract_timer.start()

func _on_retract_timer() -> void:
	"""Time to start warning before emerging"""
	_start_warning()

func _start_warning() -> void:
	"""Blink warning before emerging"""
	current_state = State.WARNING
	visible = true

	# Warning blink animation
	var tween = create_tween().set_loops(int(warning_duration / 0.2))
	tween.tween_property(self, "modulate:a", 0.3, 0.1)
	tween.tween_property(self, "modulate:a", 0.7, 0.1)
	tween.finished.connect(_start_emerge)

	# Audio warning
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/turret_warning", global_position, 0.2)

func _start_emerge() -> void:
	"""Turret rises back from ground"""
	current_state = State.EMERGING
	modulate.a = 1.0

	# Emerge animation: rise from ground
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_position.y, 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale:y", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_fully_emerged)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/turret_emerge", global_position, 0.3)

func _on_fully_emerged() -> void:
	"""Turret is fully active again"""
	current_state = State.ACTIVE

	# Re-enable everything
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true

	if detection_area:
		detection_area.monitoring = true

	# Find target
	current_target = _find_nearest_player()
	if current_target:
		fire_timer.start()

	turret_emerged.emit()
	print("[EnergyTurret] %s emerged and active" % name)
