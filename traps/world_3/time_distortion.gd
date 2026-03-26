extends Area2D
class_name TimeDistortion

## F3.5 - Zeitverzerrung (W3 Kosmischer Horror)
## Zone that drastically slows player movement (enemies/traps unaffected)
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal player_entered_distortion(player: Node2D)
signal player_exited_distortion(player: Node2D)

# ============================================================================
# EXPORTS
# ============================================================================

@export var speed_multiplier: float = 0.4    ## 0.4 = 40% speed
@export var affects_attack_speed: bool = true
@export var affects_dodge: bool = true
@export var pulse: bool = false              ## Zone grows/shrinks
@export var pulse_min_radius: float = 100.0
@export var pulse_max_radius: float = 300.0
@export var pulse_speed: float = 0.5         ## Cycles per second

# ============================================================================
# STATE
# ============================================================================

var affected_players: Dictionary = {}  # player -> original_speed_scale
var pulse_time: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var zone_visual: ColorRect = $ZoneVisual if has_node("ZoneVisual") else null
@onready var edge_particles: GPUParticles2D = $EdgeParticles if has_node("EdgeParticles") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	monitoring = true
	monitorable = false

	# Collision: Mask P1+P2
	collision_layer = 0
	set_collision_layer_value(7, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Start particles
	if edge_particles:
		edge_particles.emitting = true

	add_to_group("traps")
	add_to_group("time_distortions")

	print("[TimeDistortion] %s initialized (speed: %.0f%%)" % [name, speed_multiplier * 100])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	# Pulse effect
	if pulse and collision_shape and collision_shape.shape is CircleShape2D:
		pulse_time += delta * pulse_speed * TAU
		var t = (sin(pulse_time) + 1.0) / 2.0
		collision_shape.shape.radius = lerpf(pulse_min_radius, pulse_max_radius, t)

		# Scale visual to match
		if zone_visual:
			var scale_factor = collision_shape.shape.radius / pulse_max_radius
			zone_visual.scale = Vector2(scale_factor, scale_factor)

	# Visual ambiance
	if zone_visual:
		var drift = sin(Time.get_ticks_msec() * 0.002) * 0.1 + 0.4
		zone_visual.modulate.a = drift

	# Apply slow to players inside
	_apply_slow_effects()

# ============================================================================
# SLOW EFFECTS
# ============================================================================

func _apply_slow_effects() -> void:
	"""Continuously enforce slow on players inside zone"""
	for player in affected_players.keys():
		if not is_instance_valid(player):
			affected_players.erase(player)
			continue

		# Apply speed reduction to player
		if "speed_modifier" in player:
			player.speed_modifier = speed_multiplier
		elif "move_speed_multiplier" in player:
			player.move_speed_multiplier = speed_multiplier

		# Slow attack animation speed
		if affects_attack_speed:
			var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
			if anim_sprite:
				anim_sprite.speed_scale = speed_multiplier

func _remove_slow(player: Node2D) -> void:
	"""Remove slow effect from player"""
	if "speed_modifier" in player:
		player.speed_modifier = 1.0
	elif "move_speed_multiplier" in player:
		player.move_speed_multiplier = 1.0

	# Restore animation speed
	if affects_attack_speed:
		var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
		if anim_sprite:
			anim_sprite.speed_scale = 1.0

# ============================================================================
# ENTER / EXIT
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	affected_players[body] = 1.0  # Store original multiplier

	player_entered_distortion.emit(body)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/time_slow_enter", global_position, 0.2)

	print("[TimeDistortion] %s slowing %s to %.0f%%" % [name, body.name, speed_multiplier * 100])

func _on_body_exited(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Remove slow
	_remove_slow(body)
	affected_players.erase(body)

	player_exited_distortion.emit(body)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/time_slow_exit", global_position, 0.15)

	print("[TimeDistortion] %s released %s" % [name, body.name])

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Ensure slow is removed when zone is destroyed"""
	for player in affected_players.keys():
		if is_instance_valid(player):
			_remove_slow(player)
	affected_players.clear()
