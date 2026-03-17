extends Area2D
## TimeFragment — Floating obstacle in Section 3 (Der gebrochene Abgrund)
## Slows the player briefly on contact, reducing momentum
class_name TimeFragment

# ============ CONFIG ============
@export var slow_duration: float = 1.5
@export var slow_factor: float = 0.4  # Player speed multiplied by this
@export var momentum_penalty: float = 8.0
@export var float_amplitude: float = 15.0
@export var float_speed: float = 2.0

# ============ STATE ============
var _base_y: float = 0.0
var _time: float = 0.0
var _triggered: bool = false

# ============ VISUAL ============
const FRAG_SIZE: float = 24.0
const FRAG_COLOR := Color(0.3, 0.6, 0.8, 0.7)
const FRAG_GLOW := Color(0.5, 0.8, 1.0, 0.3)


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU  # Random phase offset

	# Collision — detect player
	collision_layer = 0
	collision_mask = 2  # Player body layer

	# Create shape
	if not has_node("CollisionShape2D"):
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = FRAG_SIZE * 0.7
		shape.shape = circle
		add_child(shape)

	# Visual
	if not has_node("Visual"):
		var glow := ColorRect.new()
		glow.name = "Glow"
		glow.size = Vector2(FRAG_SIZE * 2.0, FRAG_SIZE * 2.0)
		glow.position = Vector2(-FRAG_SIZE, -FRAG_SIZE)
		glow.color = FRAG_GLOW
		add_child(glow)

		var core := ColorRect.new()
		core.name = "Visual"
		core.size = Vector2(FRAG_SIZE, FRAG_SIZE)
		core.position = Vector2(-FRAG_SIZE * 0.5, -FRAG_SIZE * 0.5)
		core.color = FRAG_COLOR
		add_child(core)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _triggered:
		return

	_time += delta
	# Float up and down
	position.y = _base_y + sin(_time * float_speed) * float_amplitude

	# Rotate visual slightly
	rotation = sin(_time * 1.5) * 0.15


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return

	if body.is_in_group("player") or body.is_in_group("player2"):
		_triggered = true
		_apply_slow(body)
		_shatter()


func _apply_slow(player: Node2D) -> void:
	"""Slow the player temporarily"""
	# Find movement controller
	var move_ctrl: Node = player.get_node_or_null("MovementController")
	if move_ctrl and move_ctrl.has("move_speed"):
		var original_speed: float = move_ctrl.move_speed
		move_ctrl.move_speed = original_speed * slow_factor

		# Restore after duration
		get_tree().create_timer(slow_duration).timeout.connect(func():
			if is_instance_valid(move_ctrl):
				move_ctrl.move_speed = original_speed
		)

	# Notify momentum system
	var momentum_nodes: Array = get_tree().get_nodes_in_group("momentum_system")
	if momentum_nodes.is_empty():
		# Try finding via controller
		EventBus.show_notification.emit("Zeitfragment! Verlangsamt...", 1.5)


func _shatter() -> void:
	"""Visual shatter effect"""
	# Flash white then fade
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
