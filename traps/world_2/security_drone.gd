extends CharacterBody2D
class_name SecurityDrone

## F2.6 - Sicherheitsdrohne (W2 Sci-Fi)
## Patrols area, fires on sight, destroyable (respawns)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal drone_alert(target: Node2D)
signal drone_fired()
signal drone_destroyed()
signal drone_respawned()

# ============================================================================
# ENUMS
# ============================================================================

enum State {
	PATROL,      # Following patrol path
	ALERT,       # Player spotted, charging
	ATTACK,      # Firing burst
	STUNNED,     # Hit by player, grounded
	DESTROYED,   # Dead, waiting for respawn
	RESPAWNING   # Coming back
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var hp: int = 25
@export var max_hp: int = 25
@export var damage: int = 12
@export var patrol_speed: float = 80.0
@export var detection_range: float = 250.0
@export var alert_duration: float = 1.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.3
@export var stun_duration: float = 3.0
@export var respawn_time: float = 10.0
@export var patrol_path: NodePath = ""

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.PATROL
var current_target: Node2D = null
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var burst_shots_fired: int = 0
var spawn_position: Vector2 = Vector2.ZERO

# ============================================================================
# REFERENCES
# ============================================================================

@onready var drone_visual: AnimatedSprite2D = $DroneVisual if has_node("DroneVisual") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var hurtbox_area: Area2D = $HurtboxArea if has_node("HurtboxArea") else null
@onready var fire_point: Marker2D = $FirePoint if has_node("FirePoint") else null
@onready var alert_indicator: Node2D = $AlertIndicator if has_node("AlertIndicator") else null

var stun_timer: Timer = null
var respawn_timer: Timer = null
var burst_timer: Timer = null
var bolt_scene: PackedScene = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	spawn_position = global_position
	bolt_scene = preload("res://traps/world_2/scenes/energy_bolt.tscn")

	# Setup collision (Drone body)
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)   # World geometry

	# Detection area
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

		var shape = detection_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = detection_range

	# Hurtbox (receives player attacks)
	if hurtbox_area:
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true
		hurtbox_area.area_entered.connect(_on_hit_by_attack)

		hurtbox_area.collision_layer = 0
		hurtbox_area.set_collision_layer_value(4, true)   # Enemy layer
		hurtbox_area.collision_mask = 0
		hurtbox_area.set_collision_mask_value(16, true)   # Hitbox layer

	# Alert indicator hidden initially
	if alert_indicator:
		alert_indicator.visible = false

	# Timers
	stun_timer = Timer.new()
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_end)
	add_child(stun_timer)

	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_respawn)
	add_child(respawn_timer)

	burst_timer = Timer.new()
	burst_timer.one_shot = true
	burst_timer.wait_time = burst_interval
	burst_timer.timeout.connect(_fire_burst_shot)
	add_child(burst_timer)

	# Setup patrol path
	_setup_patrol()

	add_to_group("traps")
	add_to_group("security_drones")

	print("[SecurityDrone] %s initialized (HP: %d, range: %.0f)" % [name, hp, detection_range])

# ============================================================================
# PATROL SETUP
# ============================================================================

func _setup_patrol() -> void:
	"""Setup patrol points from Path2D or default back-and-forth"""
	if patrol_path != "":
		var path_node = get_node_or_null(patrol_path)
		if path_node is Path2D:
			for i in path_node.curve.point_count:
				patrol_points.append(path_node.curve.get_point_position(i) + path_node.global_position)

	# Default: horizontal patrol if no path
	if patrol_points.is_empty():
		patrol_points = [
			global_position + Vector2(-100, 0),
			global_position + Vector2(100, 0)
		]

# ============================================================================
# PROCESS
# ============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.STUNNED:
			# Apply gravity when stunned
			velocity.y += 400.0 * delta
			move_and_slide()

func _process_patrol(delta: float) -> void:
	"""Move along patrol path"""
	if patrol_points.is_empty():
		return

	var target = patrol_points[current_patrol_index]
	var direction = (target - global_position).normalized()
	var distance = global_position.distance_to(target)

	if distance < 5.0:
		# Reached waypoint, go to next
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		velocity = direction * patrol_speed
		move_and_slide()

		# Flip visual based on direction
		if drone_visual:
			drone_visual.scale.x = -1.0 if direction.x < 0 else 1.0

# ============================================================================
# DETECTION
# ============================================================================

func _on_player_detected(body: Node2D) -> void:
	if current_state != State.PATROL:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	current_target = body
	_enter_alert()

func _on_player_lost(body: Node2D) -> void:
	if body == current_target and current_state == State.PATROL:
		current_target = null

# ============================================================================
# ALERT STATE
# ============================================================================

func _enter_alert() -> void:
	current_state = State.ALERT
	velocity = Vector2.ZERO

	drone_alert.emit(current_target)

	# Visual: Red blink
	if alert_indicator:
		alert_indicator.visible = true

	if drone_visual:
		var tween = create_tween().set_loops(int(alert_duration / 0.2))
		tween.tween_property(drone_visual, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(drone_visual, "modulate", Color.WHITE, 0.1)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/drone_alert", global_position, 0.25)

	await get_tree().create_timer(alert_duration).timeout
	if current_state == State.ALERT:
		_enter_attack()

# ============================================================================
# ATTACK STATE
# ============================================================================

func _enter_attack() -> void:
	current_state = State.ATTACK
	burst_shots_fired = 0

	if alert_indicator:
		alert_indicator.visible = false

	_fire_burst_shot()

func _fire_burst_shot() -> void:
	if current_state != State.ATTACK:
		return

	if burst_shots_fired >= burst_count:
		_attack_complete()
		return

	# Fire bolt
	if bolt_scene and current_target and is_instance_valid(current_target):
		var bolt: EnergyBolt = bolt_scene.instantiate()
		bolt.damage = damage
		bolt.speed = 300.0
		bolt.direction = (current_target.global_position - global_position).normalized()

		if fire_point:
			bolt.global_position = fire_point.global_position
		else:
			bolt.global_position = global_position

		get_parent().add_child(bolt)
		drone_fired.emit()

		# Audio
		if AudioManager:
			AudioManager.play_sfx_at_position("traps/drone_fire", global_position, 0.2)

	burst_shots_fired += 1
	burst_timer.start()

func _attack_complete() -> void:
	"""Return to patrol after burst"""
	current_state = State.PATROL
	current_target = null

	# Check if player still in range
	if detection_area:
		for body in detection_area.get_overlapping_bodies():
			if body.is_in_group("player") or body.is_in_group("player2"):
				current_target = body
				# Short delay before re-alert
				await get_tree().create_timer(1.0).timeout
				if current_state == State.PATROL and current_target:
					_enter_alert()
				return

# ============================================================================
# DAMAGE / STUN
# ============================================================================

func _on_hit_by_attack(area: Area2D) -> void:
	"""Drone hit by player attack"""
	if current_state == State.DESTROYED or current_state == State.RESPAWNING:
		return

	if not (area.is_in_group("hitbox") or area.name == "HitboxComponent" or "hitbox" in area.name.to_lower()):
		return

	# Get damage from hitbox
	var hit_damage = 10  # Default
	if area.has_method("get_damage"):
		hit_damage = area.get_damage()
	elif "damage" in area:
		hit_damage = area.damage

	hp -= hit_damage

	# Visual hit flash
	if drone_visual:
		var tween = create_tween()
		tween.tween_property(drone_visual, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		tween.tween_property(drone_visual, "modulate", Color.WHITE, 0.1)

	if hp <= 0:
		_destroy()
	else:
		_stun()

func _stun() -> void:
	"""Drone stunned - falls to ground"""
	current_state = State.STUNNED
	current_target = null

	if alert_indicator:
		alert_indicator.visible = false

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/drone_stun", global_position, 0.25)

	stun_timer.wait_time = stun_duration
	stun_timer.start()

	print("[SecurityDrone] %s stunned (HP: %d)" % [name, hp])

func _on_stun_end() -> void:
	"""Recover from stun"""
	current_state = State.PATROL

	# Float back to patrol height
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", patrol_points[current_patrol_index].y, 0.5)

	print("[SecurityDrone] %s recovered" % name)

func _destroy() -> void:
	"""Drone destroyed"""
	current_state = State.DESTROYED
	hp = 0

	drone_destroyed.emit()

	# Explosion effect
	if drone_visual:
		var tween = create_tween()
		tween.tween_property(drone_visual, "modulate", Color(2.0, 1.0, 0.3), 0.1)
		tween.tween_property(drone_visual, "scale", Vector2(1.5, 1.5), 0.2)
		tween.parallel().tween_property(drone_visual, "modulate:a", 0.0, 0.2)

	# Disable collision
	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false
	if detection_area:
		detection_area.monitoring = false

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/drone_explode", global_position, 0.35)

	# Camera shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.15)

	# Start respawn timer
	respawn_timer.wait_time = respawn_time
	respawn_timer.start()

	# Hide after explosion
	await get_tree().create_timer(0.3).timeout
	visible = false

	print("[SecurityDrone] %s destroyed, respawn in %.0fs" % [name, respawn_time])

func _respawn() -> void:
	"""Respawn drone at original position"""
	current_state = State.RESPAWNING

	# Reset
	hp = max_hp
	global_position = spawn_position
	visible = true

	if drone_visual:
		drone_visual.scale = Vector2.ONE
		drone_visual.modulate = Color.WHITE

	# Re-enable
	if hurtbox_area:
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true
	if detection_area:
		detection_area.monitoring = true

	# Spawn-in effect
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		current_state = State.PATROL
		drone_respawned.emit()
	)

	print("[SecurityDrone] %s respawned" % name)
