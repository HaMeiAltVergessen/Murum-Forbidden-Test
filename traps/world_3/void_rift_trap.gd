extends Area2D
class_name VoidRiftTrap

## F3.1 - Void-Riss (W3 Kosmischer Horror)
## Reality rift that teleports player to random point in room
## Not destroyable — purely avoidable
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal player_teleported(player: Node2D, destination: Vector2)
signal rift_cooldown_started()
signal rift_reactivated()

# ============================================================================
# ENUMS
# ============================================================================

enum State { ACTIVE, TELEPORTING, COOLDOWN }

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 10
@export var teleport_delay: float = 0.5
@export var cooldown: float = 3.0
@export var teleport_targets: Array[NodePath] = []  ## Marker2D positions

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.ACTIVE
var pulse_time: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var rift_visual: AnimatedSprite2D = $RiftVisual if has_node("RiftVisual") else null
@onready var vortex_particles: GPUParticles2D = $VortexParticles if has_node("VortexParticles") else null

var cooldown_timer: Timer = null
var target_positions: Array[Vector2] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	monitoring = true
	monitorable = false

	collision_layer = 0
	set_collision_layer_value(7, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

	body_entered.connect(_on_body_entered)

	# Collect teleport target positions
	for path in teleport_targets:
		var node = get_node_or_null(path)
		if node:
			target_positions.append(node.global_position)

	# Cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = cooldown
	cooldown_timer.timeout.connect(_on_cooldown_end)
	add_child(cooldown_timer)

	# Start particles
	if vortex_particles:
		vortex_particles.emitting = true

	add_to_group("traps")
	add_to_group("void_rifts")

	print("[VoidRiftTrap] %s initialized (%d targets)" % [name, target_positions.size()])

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float) -> void:
	# Visual pulse
	if rift_visual and current_state == State.ACTIVE:
		pulse_time += _delta
		var pulse = sin(pulse_time * 3.0) * 0.2 + 0.8
		rift_visual.modulate.a = pulse
	elif rift_visual and current_state == State.COOLDOWN:
		rift_visual.modulate.a = 0.2

# ============================================================================
# TELEPORT
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if current_state != State.ACTIVE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	_start_teleport(body)

func _start_teleport(player: Node2D) -> void:
	"""Begin teleport sequence"""
	current_state = State.TELEPORTING

	# Disable further triggers
	monitoring = false

	# Visual distortion on player (modulate flash)
	if player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 0.0, 1.0, 0.6), teleport_delay * 0.5)
		tween.tween_property(sprite, "modulate", Color.WHITE, teleport_delay * 0.5)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/void_rift_activate", global_position, 0.3)

	# Wait for delay
	await get_tree().create_timer(teleport_delay).timeout

	# Teleport
	var destination = _get_teleport_destination()
	player.global_position = destination

	# Damage
	var hurtbox = player.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, Vector2.ZERO, 0.2)
		print("[VoidRiftTrap] %s teleported %s for %d damage" % [name, player.name, damage])

	player_teleported.emit(player, destination)

	# Camera shake at destination
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.3)

	# Audio at destination
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/void_rift_arrive", destination, 0.3)

	# Enter cooldown
	_enter_cooldown()

func _get_teleport_destination() -> Vector2:
	"""Get random destination from target list or random in room"""
	if target_positions.size() > 0:
		# Pick random target that's not too close to rift
		var valid_targets: Array[Vector2] = []
		for pos in target_positions:
			if global_position.distance_to(pos) > 100.0:
				valid_targets.append(pos)

		if valid_targets.size() > 0:
			return valid_targets[randi() % valid_targets.size()]

	# Fallback: random offset from rift position
	var random_offset = Vector2(
		randf_range(-300, 300),
		randf_range(-200, 200)
	)
	return global_position + random_offset

# ============================================================================
# COOLDOWN
# ============================================================================

func _enter_cooldown() -> void:
	current_state = State.COOLDOWN
	rift_cooldown_started.emit()

	# Dim visual
	if rift_visual:
		rift_visual.modulate.a = 0.2
	if vortex_particles:
		vortex_particles.emitting = false

	cooldown_timer.start()

func _on_cooldown_end() -> void:
	current_state = State.ACTIVE
	monitoring = true

	rift_reactivated.emit()

	# Restore visual
	if vortex_particles:
		vortex_particles.emitting = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/void_rift_reactivate", global_position, 0.15)

	print("[VoidRiftTrap] %s reactivated" % name)
