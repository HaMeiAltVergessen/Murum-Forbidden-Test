extends CharacterBody2D
## Repair Bot — Flies to damaged cores and heals them
## 20 HP, heals cores 5 HP/s, Speed 80

# ============ CONFIG ============
var max_hp: float = 20.0
var current_hp: float = 20.0
var move_speed: float = 80.0
var heal_rate: float = 5.0  # HP per second
var heal_range: float = 80.0

var _is_dead: bool = false
var _fabricator: Node = null
var _heal_target: Node = null

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var hurtbox: HurtboxComponent = $HurtboxComponent if has_node("HurtboxComponent") else null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("kollektiv_drone")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	if CombatManager:
		CombatManager.register_enemy(self)

	if not _has_visual():
		var visual := ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(24, 24)
		visual.position = Vector2(-12, -12)
		visual.color = Color(0.3, 0.9, 0.3)
		add_child(visual)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# No gravity — floating repair bot
	# Find damaged core to heal
	if not _heal_target or not is_instance_valid(_heal_target) or _heal_target.is_destroyed:
		_find_heal_target()

	if not _heal_target:
		# No target — idle float
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir: Vector2 = _heal_target.global_position - global_position
	var distance: float = dir.length()

	if distance > heal_range:
		# Move toward target
		velocity = dir.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
		# Heal the target
		_heal_target.current_hp = min(_heal_target.current_hp + heal_rate * delta, _heal_target.max_hp)
		_heal_target.health_changed.emit(_heal_target.current_hp, _heal_target.max_hp)

		# Heal visual
		var visual = get_node_or_null("Visual")
		if visual:
			visual.color = Color(0.3, 1.0, 0.3, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005))

	if sprite:
		sprite.flip_h = dir.x < 0

	move_and_slide()


func _find_heal_target() -> void:
	"""Find the most damaged alive core"""
	_heal_target = null
	var lowest_pct: float = 1.0

	for core in get_tree().get_nodes_in_group("kollektiv_core"):
		if not is_instance_valid(core) or core.is_destroyed:
			continue
		var pct: float = core.get_hp_percent()
		if pct < lowest_pct and pct < 0.95:  # Only heal if under 95%
			lowest_pct = pct
			_heal_target = core


func _on_damage_received(damage: int, _knockback: Vector2, _hitstun: float) -> void:
	if _is_dead:
		return
	current_hp -= damage
	_flash_damage()
	if current_hp <= 0:
		die()


func _flash_damage() -> void:
	var visual = get_node_or_null("Visual")
	if visual:
		visual.modulate = Color(2.0, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and is_instance_valid(visual):
			visual.modulate = Color.WHITE


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	EventBus.enemy_died.emit(self, global_position)
	if CombatManager:
		CombatManager.unregister_enemy(self)
	queue_free()


func explode() -> void:
	die()


func set_fabricator(fab: Node) -> void:
	_fabricator = fab


func take_damage(amount: float, _attacker: Node = null) -> void:
	_on_damage_received(int(amount), Vector2.ZERO, 0.0)


func _has_visual() -> bool:
	for child in get_children():
		if child is ColorRect or child is Sprite2D:
			return true
	return false
