extends Area2D
## Energy pulse from the Energy Core — expands outward, damages player

var damage: int = 10
var _lifetime: float = 0.0
const MAX_LIFETIME: float = 0.8
const EXPAND_SPEED: float = 600.0

# Visual
var _warning_rect: ColorRect
var _pulse_rect: ColorRect


func _ready() -> void:
	# Setup collision
	collision_layer = 128
	collision_mask = 1024
	monitoring = true
	monitorable = false

	add_to_group("energy_pulse")

	# Warning indicator (shows before pulse)
	_warning_rect = ColorRect.new()
	_warning_rect.size = Vector2(200, 40)
	_warning_rect.position = Vector2(-100, -20)
	_warning_rect.color = Color(1.0, 0.5, 0.0, 0.3)
	add_child(_warning_rect)

	# Pulse visual
	_pulse_rect = ColorRect.new()
	_pulse_rect.size = Vector2(40, 200)
	_pulse_rect.position = Vector2(-20, -100)
	_pulse_rect.color = Color(1.0, 0.7, 0.0, 0.6)
	add_child(_pulse_rect)

	# Collision shape
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160, 160)
	shape.shape = rect
	add_child(shape)

	# Connect
	area_entered.connect(_on_area_entered)

	# Auto-destroy
	await get_tree().create_timer(MAX_LIFETIME).timeout
	if is_instance_valid(self):
		queue_free()


func _process(delta: float) -> void:
	_lifetime += delta
	# Fade out
	var alpha: float = 1.0 - (_lifetime / MAX_LIFETIME)
	if _pulse_rect:
		_pulse_rect.modulate.a = alpha
	if _warning_rect:
		_warning_rect.modulate.a = alpha * 0.5


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox: HurtboxComponent = area
		var hurtbox_owner = hurtbox.get_parent()
		if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
			hurtbox.take_damage(damage, Vector2.UP * 100, 0.1)
