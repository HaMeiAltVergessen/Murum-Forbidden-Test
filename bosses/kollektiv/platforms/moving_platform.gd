extends AnimatableBody2D
## Moving platform for Kollektiv boss arena
## Moves horizontally back and forth, can be electrified

var _move_speed: float = 0.0
var _move_range: float = 150.0
var _origin_x: float = 0.0
var _moving: bool = false
var _direction: float = 1.0

# Electrify state
var _electrified: bool = false
var _electrify_timer: float = 0.0
var _electrify_damage: int = 5
var _electrify_tick: float = 0.0

# Visual
var _visual: ColorRect
var _electrify_visual: ColorRect


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	add_to_group("kollektiv_platform")

	_origin_x = global_position.x

	# Create collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 20)
	col.shape = rect
	add_child(col)

	# Visual platform
	_visual = ColorRect.new()
	_visual.size = Vector2(200, 20)
	_visual.position = Vector2(-100, -10)
	_visual.color = Color(0.4, 0.4, 0.5)
	add_child(_visual)

	# Electrify overlay (hidden by default)
	_electrify_visual = ColorRect.new()
	_electrify_visual.size = Vector2(200, 20)
	_electrify_visual.position = Vector2(-100, -10)
	_electrify_visual.color = Color(0.2, 0.6, 1.0, 0.4)
	_electrify_visual.visible = false
	add_child(_electrify_visual)


func _physics_process(delta: float) -> void:
	# Platform movement
	if _moving and _move_speed > 0:
		var new_x: float = global_position.x + _direction * _move_speed * delta
		if abs(new_x - _origin_x) > _move_range:
			_direction *= -1.0
			new_x = _origin_x + _direction * _move_range
		global_position.x = new_x

	# Electrify damage tick
	if _electrified:
		_electrify_timer -= delta
		if _electrify_timer <= 0:
			_end_electrify()
			return

		_electrify_tick += delta
		if _electrify_tick >= 1.0:
			_electrify_tick = 0.0
			_damage_players_on_platform()

		# Flash effect
		_electrify_visual.modulate.a = 0.3 + 0.3 * sin(_electrify_tick * PI * 4)


func start_moving(speed: float, move_range: float) -> void:
	_move_speed = speed
	_move_range = move_range
	_moving = true


func stop_moving() -> void:
	_moving = false


func electrify(duration: float, damage: int) -> void:
	_electrified = true
	_electrify_timer = duration
	_electrify_damage = damage
	_electrify_tick = 0.0
	_electrify_visual.visible = true


func _end_electrify() -> void:
	_electrified = false
	_electrify_visual.visible = false


func _damage_players_on_platform() -> void:
	"""Check if any players are standing on this platform and damage them"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Simple proximity check (player above platform within range)
	var dist: Vector2 = player.global_position - global_position
	if abs(dist.x) < 110 and dist.y < -5 and dist.y > -60:
		var hurtbox = player.get_node_or_null("HurtboxComponent")
		if hurtbox and hurtbox is HurtboxComponent:
			hurtbox.take_damage(_electrify_damage, Vector2.UP * 50, 0.05)
