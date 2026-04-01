extends Node2D
class_name ArrowTrap

## F3 - Pfeilfallen
## Fires arrows at regular intervals when triggered
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal trap_activated()
signal trap_deactivated()
signal arrow_fired()

# ============================================================================
# EXPORTS
# ============================================================================

@export var arrow_damage: int = 15
@export var fire_rate: float = 1.0
@export var arrow_speed: float = 400.0
@export var arrow_direction: Vector2 = Vector2.RIGHT
@export var trigger_mode: TriggerMode = TriggerMode.PRESSURE_PLATE
@export var proximity_range: float = 300.0

enum TriggerMode {
	PRESSURE_PLATE,  # Activate via pressure plate
	PROXIMITY,       # Activate when player in range
	ALWAYS_ACTIVE    # Always firing
}

# ============================================================================
# STATE
# ============================================================================

var is_active: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: AnimatedSprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var fire_point: Marker2D = $FirePoint if has_node("FirePoint") else null
@onready var pressure_plate: Area2D = $PressurePlate if has_node("PressurePlate") else null
@onready var proximity_detector: Area2D = $ProximityDetector if has_node("ProximityDetector") else null

var fire_timer: Timer = null
var arrow_scene: PackedScene = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Load arrow scene
	arrow_scene = preload("res://traps/scenes/arrow_projectile.tscn")

	# Create fire timer
	fire_timer = Timer.new()
	fire_timer.one_shot = false
	fire_timer.wait_time = fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	# Setup trigger mode
	_setup_trigger_mode()

	# If always active, start firing
	if trigger_mode == TriggerMode.ALWAYS_ACTIVE:
		activate()

	add_to_group("traps")
	add_to_group("arrow_traps")

	print("[ArrowTrap] %s initialized, mode: %s" % [name, TriggerMode.keys()[trigger_mode]])

# ============================================================================
# TRIGGER SETUP
# ============================================================================

func _setup_trigger_mode() -> void:
	"""Setup trigger based on mode"""
	match trigger_mode:
		TriggerMode.PRESSURE_PLATE:
			if pressure_plate:
				pressure_plate.monitoring = true
				pressure_plate.monitorable = true
				pressure_plate.body_entered.connect(_on_plate_entered)
				pressure_plate.body_exited.connect(_on_plate_exited)

				# COMMIT 018: Set collision mask for both P1 and P2
				pressure_plate.collision_layer = 0
				pressure_plate.set_collision_layer_value(7, true)  # Hazards (Layer 7)

				pressure_plate.collision_mask = 0
				pressure_plate.set_collision_mask_value(2, true)   # P1 Body (Layer 2)
				pressure_plate.set_collision_mask_value(3, true)   # P2 Body (Layer 3)

				print("[ArrowTrap] Pressure plate mode enabled (Mask: %d)" % pressure_plate.collision_mask)

		TriggerMode.PROXIMITY:
			if proximity_detector:
				proximity_detector.monitoring = true
				proximity_detector.monitorable = false
				proximity_detector.body_entered.connect(_on_proximity_entered)
				proximity_detector.body_exited.connect(_on_proximity_exited)

				# COMMIT 018: Set collision mask for both P1 and P2
				proximity_detector.collision_layer = 0
				proximity_detector.set_collision_layer_value(7, true)  # Hazards (Layer 7)

				proximity_detector.collision_mask = 0
				proximity_detector.set_collision_mask_value(2, true)   # P1 Body (Layer 2)
				proximity_detector.set_collision_mask_value(3, true)   # P2 Body (Layer 3)

				# Set proximity range
				var collision_shape = proximity_detector.get_node_or_null("CollisionShape2D")
				if collision_shape and collision_shape.shape is CircleShape2D:
					collision_shape.shape.radius = proximity_range

				print("[ArrowTrap] Proximity mode enabled (range: %.0f, Mask: %d)" % [proximity_range, proximity_detector.collision_mask])

		TriggerMode.ALWAYS_ACTIVE:
			print("[ArrowTrap] Always active mode")

# ============================================================================
# ACTIVATION
# ============================================================================

func activate() -> void:
	"""Activate the trap"""
	if is_active:
		return

	is_active = true
	fire_timer.start()
	trap_activated.emit()

	print("[ArrowTrap] %s activated" % name)

func deactivate() -> void:
	"""Deactivate the trap"""
	if not is_active:
		return

	is_active = false
	fire_timer.stop()
	trap_deactivated.emit()

	print("[ArrowTrap] %s deactivated" % name)

# ============================================================================
# TRIGGER HANDLERS
# ============================================================================

func _on_plate_entered(body: Node2D) -> void:
	"""Pressure plate entered"""
	if body.is_in_group("player") or body.is_in_group("player2"):
		activate()

func _on_plate_exited(body: Node2D) -> void:
	"""Pressure plate exited"""
	if body.is_in_group("player") or body.is_in_group("player2"):
		# Check if any players still on plate
		var bodies = pressure_plate.get_overlapping_bodies()
		var has_player = false
		for b in bodies:
			if b.is_in_group("player") or b.is_in_group("player2"):
				has_player = true
				break

		if not has_player:
			deactivate()

func _on_proximity_entered(body: Node2D) -> void:
	"""Player enters proximity"""
	if body.is_in_group("player") or body.is_in_group("player2"):
		activate()

func _on_proximity_exited(body: Node2D) -> void:
	"""Player exits proximity"""
	if body.is_in_group("player") or body.is_in_group("player2"):
		# Check if any players still in range
		var bodies = proximity_detector.get_overlapping_bodies()
		var has_player = false
		for b in bodies:
			if b.is_in_group("player") or b.is_in_group("player2"):
				has_player = true
				break

		if not has_player:
			deactivate()

# ============================================================================
# FIRING
# ============================================================================

func _on_fire_timer_timeout() -> void:
	"""Timer timeout - fire arrow"""
	if is_active:
		fire_arrow()

func fire_arrow() -> void:
	"""Fire an arrow"""
	if not arrow_scene:
		push_warning("[ArrowTrap] No arrow scene loaded!")
		return

	# Instantiate arrow
	var arrow: ArrowProjectile = arrow_scene.instantiate()

	# Set arrow properties
	arrow.damage = arrow_damage
	arrow.speed = arrow_speed
	arrow.direction = arrow_direction.normalized()

	# Position arrow at fire point
	if fire_point:
		arrow.global_position = fire_point.global_position
	else:
		arrow.global_position = global_position

	# Add to scene
	get_parent().add_child(arrow)

	# Signal
	arrow_fired.emit()

	# Visual feedback
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/arrow_fire", global_position, 0.25)

	print("[ArrowTrap] %s fired arrow" % name)
