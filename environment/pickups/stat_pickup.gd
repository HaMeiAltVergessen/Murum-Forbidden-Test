extends Area2D
class_name StatPickup

## Pickup that grants run-volatile HP or Mana bonus
## Auto-collects on contact (like gold coins)
## Bonuses are lost on death/run end

enum StatType { HP, MANA }

# ============================================================================
# EXPORTS
# ============================================================================

@export var stat_type: StatType = StatType.HP
@export var bonus_amount: int = 15
@export var pickup_radius: float = 80.0
@export var magnet_speed: float = 250.0

# ============================================================================
# STATE
# ============================================================================

var player: Node2D = null
var is_being_attracted: bool = false
var lifetime: float = 0.0
var _collected: bool = false

# ============================================================================
# VISUAL
# ============================================================================

var _rect: ColorRect = null
var _label: Label = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("pickups")

	collision_layer = 0
	collision_mask = 2  # Player layer

	_create_visual()
	_play_spawn_animation()

	# Add collision shape if missing
	if not has_node("CollisionShape2D"):
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		add_child(col)


func _create_visual() -> void:
	"""Creates placeholder visual (colored rect + label)"""
	_rect = ColorRect.new()
	_rect.size = Vector2(28, 28)
	_rect.position = Vector2(-14, -14)

	if stat_type == StatType.HP:
		_rect.color = Color(0.9, 0.2, 0.2, 0.9)  # Red for HP
	else:
		_rect.color = Color(0.2, 0.4, 0.9, 0.9)  # Blue for Mana

	add_child(_rect)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(40, 20)
	_label.position = Vector2(-20, -30)
	_label.text = "+HP" if stat_type == StatType.HP else "+MP"
	add_child(_label)


# ============================================================================
# PHYSICS
# ============================================================================

func _physics_process(delta: float) -> void:
	if _collected:
		return

	lifetime += delta

	if lifetime > 30.0:
		_despawn()
		return

	# Hover animation
	if _rect:
		_rect.position.y = -14 + sin(lifetime * 3.0) * 3.0

	# Magnet
	if not is_being_attracted:
		_check_for_player()

	if is_being_attracted and player and is_instance_valid(player):
		var direction := (player.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta
		if global_position.distance_to(player.global_position) < 20.0:
			_collect()


func _check_for_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var closest_dist: float = pickup_radius
	for p in players:
		if not p or not is_instance_valid(p):
			continue
		var dist := global_position.distance_to(p.global_position)
		if dist < closest_dist:
			player = p
			closest_dist = dist
			is_being_attracted = true


# ============================================================================
# COLLECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	if _collected:
		return
	_collected = true

	if not RunManager or not RunManager.is_run_active():
		queue_free()
		return

	if stat_type == StatType.HP:
		RunManager.add_run_bonus_hp(bonus_amount)
		EventBus.show_notification.emit("+%d Max Leben" % bonus_amount, 2.0)
	else:
		RunManager.add_run_bonus_mana(bonus_amount)
		EventBus.show_notification.emit("+%d Max Mana" % bonus_amount, 2.0)

	if AudioManager:
		AudioManager.play_sfx("pickup_coin", 0.1)

	_play_collect_effects()


func _play_collect_effects() -> void:
	if _rect:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_rect, "scale", Vector2(2.0, 2.0), 0.2)
		tween.tween_property(_rect, "modulate:a", 0.0, 0.2)
		if _label:
			tween.tween_property(_label, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _play_spawn_animation() -> void:
	if _rect:
		_rect.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(_rect, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _despawn() -> void:
	if _rect:
		var tween := create_tween()
		tween.tween_property(_rect, "modulate:a", 0.0, 0.5)
		if _label:
			tween.tween_property(_label, "modulate:a", 0.0, 0.5)
		await tween.finished
	queue_free()
