extends Area2D
## Laser wall that sweeps through the arena — spawned by Mobility/Defense Core

var damage: int = 10
var move_speed: float = 200.0
var is_horizontal: bool = true
var _warning_phase: bool = true
var _has_hit: Dictionary = {}  # Track already hit players


func _ready() -> void:
	collision_layer = 128
	collision_mask = 1024
	monitoring = false  # Start disabled (warning phase)
	monitorable = false
	add_to_group("laser_wall")

	# Setup collision
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if is_horizontal:
		rect.size = Vector2(2800, 16)
		global_position = Vector2(1400, -20)
	else:
		rect.size = Vector2(16, 2800)
		global_position = Vector2(-20, 1400)
	shape.shape = rect
	add_child(shape)

	# Visual
	var visual := ColorRect.new()
	visual.name = "Visual"
	if is_horizontal:
		visual.size = Vector2(2800, 10)
		visual.position = Vector2(-1400, -5)
	else:
		visual.size = Vector2(10, 2800)
		visual.position = Vector2(-5, -1400)
	visual.color = Color(1.0, 0.3, 0.3, 0.6)
	add_child(visual)

	area_entered.connect(_on_area_entered)

	# Warning → Active → Move → Destroy
	_start_warning()


func _start_warning() -> void:
	var visual = get_node_or_null("Visual")
	if visual:
		var tween: Tween = create_tween()
		tween.tween_property(visual, "modulate:a", 0.2, 0.25)
		tween.tween_property(visual, "modulate:a", 1.0, 0.25)
		tween.tween_callback(_activate_and_move)


func _activate_and_move() -> void:
	_warning_phase = false
	monitoring = true

	var tween: Tween = create_tween()
	if is_horizontal:
		tween.tween_property(self, "global_position:y", 2800.0, 2800.0 / move_speed)
	else:
		tween.tween_property(self, "global_position:x", 2800.0, 2800.0 / move_speed)
	tween.tween_callback(queue_free)


func _on_area_entered(area: Area2D) -> void:
	if _warning_phase:
		return
	if area is HurtboxComponent:
		var hurtbox: HurtboxComponent = area
		var hurtbox_owner = hurtbox.get_parent()
		if not hurtbox_owner:
			return

		# Only hit players
		if not (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
			return

		# Don't double-hit same player
		var id: int = hurtbox_owner.get_instance_id()
		if _has_hit.has(id):
			return
		_has_hit[id] = true

		var kb_dir: Vector2 = Vector2.UP * 80 if is_horizontal else Vector2.RIGHT * 80
		hurtbox.take_damage(damage, kb_dir, 0.15)
