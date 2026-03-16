extends CharacterBody2D
## Melee Drone — Chases player and attacks at close range
## 20 HP, 8 DMG, Speed 120

# ============ CONFIG ============
var max_hp: float = 20.0
var current_hp: float = 20.0
var move_speed: float = 120.0
var attack_damage: int = 8
var attack_cooldown: float = 1.5
var gravity: float = 980.0

var _attack_timer: float = 0.0
var _is_dead: bool = false
var _fabricator: Node = null

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var hurtbox: HurtboxComponent = $HurtboxComponent if has_node("HurtboxComponent") else null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("kollektiv_drone")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	if CombatManager:
		CombatManager.register_enemy(self)

	# Visual if no sprite
	if not _has_visual():
		var visual := ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(24, 24)
		visual.position = Vector2(-12, -12)
		visual.color = Color(0.9, 0.3, 0.3)
		add_child(visual)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Find and chase player
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		velocity.x = 0
		move_and_slide()
		return

	var dir: Vector2 = player.global_position - global_position
	var distance: float = dir.length()

	# Attack cooldown
	_attack_timer = max(0, _attack_timer - delta)

	if distance < 50 and _attack_timer <= 0:
		_attack(player)
	elif distance > 40:
		velocity.x = sign(dir.x) * move_speed
		# Flip visual
		if sprite:
			sprite.flip_h = dir.x < 0
	else:
		velocity.x = 0

	move_and_slide()


func _attack(player: Node2D) -> void:
	_attack_timer = attack_cooldown

	var hitbox := HitboxComponent.new()
	hitbox.damage = attack_damage
	hitbox.knockback_force = 150.0
	hitbox.hitstun_duration = 0.15
	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 30)
	shape.shape = rect
	shape.position = Vector2(sign(player.global_position.x - global_position.x) * 20, 0)
	hitbox.add_child(shape)

	add_child(hitbox)
	hitbox.owner = self
	hitbox.activate()

	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _on_damage_received(damage: int, _knockback: Vector2, _hitstun: float) -> void:
	if _is_dead:
		return
	current_hp -= damage
	_flash_damage()
	if current_hp <= 0:
		die()


func _flash_damage() -> void:
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color.WHITE
	else:
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
	"""Called when fabricator is destroyed"""
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
