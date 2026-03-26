extends Area2D
class_name GravityAnomaly

## F2.3 - Gravitationsanomalie (W2 Sci-Fi Reskin des Treibsands)
## Sci-Fi pull zone with visible gravitational field
## Stronger pull and faster death than quicksand
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal player_entered_field(player: Node2D)
signal player_exited_field(player: Node2D)
signal player_killed(player: Node2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var pull_strength: float = 250.0
@export var damage_per_second: int = 12
@export var instant_death_time: float = 4.0
@export var distortion_intensity: float = 1.0  ## Visual intensity

# ============================================================================
# STATE
# ============================================================================

var players_inside: Dictionary = {}  # player -> time_inside
var pulse_time: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var field_visual: ColorRect = $FieldVisual if has_node("FieldVisual") else null
@onready var core_visual: ColorRect = $CoreVisual if has_node("CoreVisual") else null
@onready var pull_particles: GPUParticles2D = $PullParticles if has_node("PullParticles") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

var damage_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	monitoring = true
	monitorable = false

	# Ensure both P1 and P2 detected
	set_collision_mask_value(2, true)   # P1
	set_collision_mask_value(3, true)   # P2

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create damage timer
	damage_timer = Timer.new()
	damage_timer.one_shot = false
	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)
	damage_timer.start()

	# Start particles
	if pull_particles:
		pull_particles.emitting = true

	add_to_group("traps")
	add_to_group("gravity_anomalies")

	print("[GravityAnomaly] %s initialized (pull: %.0f, death: %.1fs)" % [name, pull_strength, instant_death_time])

# ============================================================================
# PHYSICS - PULL EFFECT
# ============================================================================

func _physics_process(delta: float) -> void:
	if players_inside.is_empty():
		return

	for player in players_inside.keys():
		if not is_instance_valid(player):
			players_inside.erase(player)
			continue

		# Increment time
		players_inside[player] += delta

		# Check instant death
		if players_inside[player] >= instant_death_time:
			_instant_death(player)
			continue

		# Apply pull force
		_apply_pull_force(player, delta)

	# Visual pulse
	pulse_time += delta
	_update_visual_pulse()

func _apply_pull_force(player: Node2D, delta: float) -> void:
	if not player is CharacterBody2D:
		return

	var center = global_position
	var direction = (center - player.global_position).normalized()
	var distance = global_position.distance_to(player.global_position)

	# Stronger pull as player gets closer to center
	var distance_factor = clampf(1.0 - (distance / 200.0), 0.3, 1.5)
	var force = pull_strength * distance_factor

	if "velocity" in player:
		player.velocity += direction * force * delta

# ============================================================================
# BODY ENTER/EXIT
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	players_inside[body] = 0.0
	player_entered_field.emit(body)

	if AudioManager:
		AudioManager.play_sfx_at_position("traps/gravity_pull", global_position, 0.3)

	print("[GravityAnomaly] %s entered by %s" % [name, body.name])

func _on_body_exited(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	if body in players_inside:
		players_inside.erase(body)

	player_exited_field.emit(body)

	if AudioManager:
		AudioManager.play_sfx_at_position("traps/gravity_release", global_position, 0.2)

	print("[GravityAnomaly] %s exited by %s" % [name, body.name])

# ============================================================================
# DAMAGE
# ============================================================================

func _apply_damage() -> void:
	if players_inside.is_empty():
		return

	for player in players_inside.keys():
		if not is_instance_valid(player):
			continue

		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage_per_second)

func _instant_death(player: Node2D) -> void:
	player_killed.emit(player)

	if player.has_method("die"):
		player.die()
		print("[GravityAnomaly] %s killed %s" % [name, player.name])
	else:
		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(9999)

	players_inside.erase(player)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual_pulse() -> void:
	"""Pulsing visual effect for gravitational field"""
	if field_visual:
		var pulse = sin(pulse_time * 2.0) * 0.15 + 0.55
		field_visual.modulate.a = pulse

	if core_visual:
		var core_pulse = sin(pulse_time * 3.0) * 0.2 + 0.8
		core_visual.modulate.a = core_pulse

# ============================================================================
# HELPERS
# ============================================================================

func is_player_inside(player: Node2D) -> bool:
	return player in players_inside

func get_time_in_field(player: Node2D) -> float:
	return players_inside.get(player, 0.0)
