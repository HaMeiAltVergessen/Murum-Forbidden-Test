extends Node2D
class_name LaserWallTrap

## F2.4 - Laserwand (W2 Raum-Version der Boss-Mechanik)
## Laser line that sweeps through room with warning phase
## Supports horizontal, vertical, and rotating modes
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal laser_warning_started()
signal laser_activated()
signal laser_hit(entity: Node2D)
signal laser_completed()

# ============================================================================
# ENUMS
# ============================================================================

enum LaserDirection {
	HORIZONTAL,  # Sweeps top to bottom (or bottom to top)
	VERTICAL,    # Sweeps left to right (or right to left)
	ROTATING     # Rotates around center point
}

enum State { IDLE, WARNING, ACTIVE, COOLDOWN }

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 15
@export var knockback_force: float = 150.0
@export var sweep_speed: float = 200.0
@export var warning_duration: float = 2.0
@export var cooldown_duration: float = 3.0
@export var direction: LaserDirection = LaserDirection.HORIZONTAL
@export var laser_length: float = 1920.0   ## Length of laser beam
@export var laser_width: float = 12.0
@export var loop: bool = true
@export var reverse_sweep: bool = false     ## Sweep in opposite direction
@export var rotation_speed: float = 45.0    ## Degrees/s (ROTATING mode)

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.IDLE
var has_hit: Dictionary = {}  # Prevent double-hit per sweep

# ============================================================================
# REFERENCES
# ============================================================================

@onready var laser_beam: Area2D = $LaserBeam if has_node("LaserBeam") else null
@onready var laser_visual: ColorRect = $LaserBeam/LaserVisual if has_node("LaserBeam/LaserVisual") else null
@onready var warning_visual: ColorRect = $LaserBeam/WarningVisual if has_node("LaserBeam/WarningVisual") else null

var cooldown_timer: Timer = null
var sweep_tween: Tween = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup laser beam Area2D
	if laser_beam:
		laser_beam.monitoring = false
		laser_beam.monitorable = false
		laser_beam.body_entered.connect(_on_body_entered)

		laser_beam.collision_layer = 0
		laser_beam.set_collision_layer_value(7, true)
		laser_beam.collision_mask = 0
		laser_beam.set_collision_mask_value(2, true)
		laser_beam.set_collision_mask_value(3, true)

	# Cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = cooldown_duration
	cooldown_timer.timeout.connect(_on_cooldown_complete)
	add_child(cooldown_timer)

	# Hide laser initially
	if laser_visual:
		laser_visual.visible = false
	if warning_visual:
		warning_visual.visible = false

	# Setup visual sizes based on direction
	_setup_visuals()

	add_to_group("traps")
	add_to_group("laser_walls")

	# Auto-start first cycle
	_start_warning()

	print("[LaserWallTrap] %s initialized (dir: %s, speed: %.0f)" % [name, LaserDirection.keys()[direction], sweep_speed])

# ============================================================================
# PROCESS (ROTATING mode)
# ============================================================================

func _process(delta: float) -> void:
	if current_state != State.ACTIVE:
		return

	if direction == LaserDirection.ROTATING and laser_beam:
		laser_beam.rotation_degrees += rotation_speed * delta

# ============================================================================
# CYCLE: WARNING → ACTIVE → COOLDOWN → (repeat)
# ============================================================================

func _start_warning() -> void:
	current_state = State.WARNING
	has_hit.clear()

	laser_warning_started.emit()

	# Position laser at start
	_position_laser_at_start()

	# Show warning line (thin, blinking)
	if warning_visual:
		warning_visual.visible = true
		var tween = create_tween().set_loops(int(warning_duration / 0.4))
		tween.tween_property(warning_visual, "modulate:a", 0.3, 0.2)
		tween.tween_property(warning_visual, "modulate:a", 0.8, 0.2)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/laser_charge", global_position, 0.2)

	# Timer to activate
	await get_tree().create_timer(warning_duration).timeout
	if current_state == State.WARNING:
		_start_active()

func _start_active() -> void:
	current_state = State.ACTIVE

	# Show laser
	if laser_visual:
		laser_visual.visible = true
	if warning_visual:
		warning_visual.visible = false

	# Enable hitbox
	if laser_beam:
		laser_beam.monitoring = true

	laser_activated.emit()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/laser_fire", global_position, 0.3)

	# Start sweep (non-rotating modes)
	if direction != LaserDirection.ROTATING:
		_start_sweep()
	else:
		# Rotating mode: auto-stop after full rotation(s)
		await get_tree().create_timer(360.0 / rotation_speed).timeout
		if current_state == State.ACTIVE:
			_sweep_complete()

func _start_sweep() -> void:
	"""Sweep laser across room"""
	var sweep_distance = 1080.0 if direction == LaserDirection.HORIZONTAL else 1920.0
	var sweep_time = sweep_distance / sweep_speed

	sweep_tween = create_tween()
	if direction == LaserDirection.HORIZONTAL:
		var target_y = sweep_distance if not reverse_sweep else -sweep_distance
		sweep_tween.tween_property(laser_beam, "position:y", laser_beam.position.y + target_y, sweep_time)
	else:
		var target_x = sweep_distance if not reverse_sweep else -sweep_distance
		sweep_tween.tween_property(laser_beam, "position:x", laser_beam.position.x + target_x, sweep_time)

	sweep_tween.tween_callback(_sweep_complete)

func _sweep_complete() -> void:
	"""Sweep finished"""
	current_state = State.COOLDOWN

	# Hide laser
	if laser_visual:
		laser_visual.visible = false
	if laser_beam:
		laser_beam.monitoring = false

	laser_completed.emit()

	if loop:
		cooldown_timer.start()
	else:
		current_state = State.IDLE

func _on_cooldown_complete() -> void:
	_start_warning()

# ============================================================================
# POSITIONING
# ============================================================================

func _position_laser_at_start() -> void:
	"""Position laser at starting position based on direction"""
	if not laser_beam:
		return

	match direction:
		LaserDirection.HORIZONTAL:
			laser_beam.position = Vector2(0, -100 if not reverse_sweep else 1180)
			laser_beam.rotation_degrees = 0
		LaserDirection.VERTICAL:
			laser_beam.position = Vector2(-100 if not reverse_sweep else 2020, 0)
			laser_beam.rotation_degrees = 0
		LaserDirection.ROTATING:
			laser_beam.position = Vector2.ZERO
			laser_beam.rotation_degrees = 0

func _setup_visuals() -> void:
	"""Setup visual sizes based on laser dimensions"""
	if laser_visual:
		match direction:
			LaserDirection.HORIZONTAL, LaserDirection.ROTATING:
				laser_visual.size = Vector2(laser_length, laser_width)
				laser_visual.position = Vector2(-laser_length / 2.0, -laser_width / 2.0)
			LaserDirection.VERTICAL:
				laser_visual.size = Vector2(laser_width, laser_length)
				laser_visual.position = Vector2(-laser_width / 2.0, -laser_length / 2.0)

		laser_visual.color = Color(1.0, 0.2, 0.2, 0.9)

	if warning_visual:
		match direction:
			LaserDirection.HORIZONTAL, LaserDirection.ROTATING:
				warning_visual.size = Vector2(laser_length, 4)
				warning_visual.position = Vector2(-laser_length / 2.0, -2)
			LaserDirection.VERTICAL:
				warning_visual.size = Vector2(4, laser_length)
				warning_visual.position = Vector2(-2, -laser_length / 2.0)

		warning_visual.color = Color(1.0, 0.3, 0.3, 0.5)

# ============================================================================
# DAMAGE
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if current_state != State.ACTIVE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	# Prevent double hit per sweep
	var id = body.get_instance_id()
	if has_hit.has(id):
		return
	has_hit[id] = true

	# Calculate knockback perpendicular to laser
	var knockback_dir: Vector2
	match direction:
		LaserDirection.HORIZONTAL:
			knockback_dir = Vector2.DOWN if not reverse_sweep else Vector2.UP
		LaserDirection.VERTICAL:
			knockback_dir = Vector2.RIGHT if not reverse_sweep else Vector2.LEFT
		LaserDirection.ROTATING:
			knockback_dir = (body.global_position - global_position).normalized()

	# Deal damage
	var hurtbox = body.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		hurtbox.take_damage(damage, knockback_dir * knockback_force, 0.2)
		print("[LaserWallTrap] %s hit %s for %d damage" % [name, body.name, damage])

	laser_hit.emit(body)

	# Camera shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.2)
