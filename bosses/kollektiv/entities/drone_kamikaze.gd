extends CharacterBody2D
## Kamikaze Drone — Flies toward player and explodes on contact
## 15 HP, 15 DMG AoE, Speed 200

# ============ CONFIG ============
var max_hp: float = 15.0
var current_hp: float = 15.0
var move_speed: float = 200.0
var explosion_damage: int = 15
var explosion_radius: float = 80.0

var _is_dead: bool = false
var _fabricator: Node = null
var _fuse_timer: float = 8.0  # Max lifetime before auto-explode

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
		visual.size = Vector2(20, 20)
		visual.position = Vector2(-10, -10)
		visual.color = Color(1.0, 0.6, 0.0)
		add_child(visual)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_fuse_timer -= delta
	if _fuse_timer <= 0:
		_explode()
		return

	# Fly toward player (no gravity — floating drone)
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var dir: Vector2 = (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

	# Flip
	if sprite:
		sprite.flip_h = dir.x < 0

	# Check proximity for explosion
	if global_position.distance_to(player.global_position) < 30:
		_explode()

	# Flash faster as fuse runs out
	if _fuse_timer < 2.0:
		var flash: float = abs(sin(_fuse_timer * 10))
		var visual = get_node_or_null("Visual")
		if visual:
			visual.color = Color(1.0, flash, 0.0)


func _explode() -> void:
	if _is_dead:
		return
	_is_dead = true

	# AoE damage
	var hitbox := HitboxComponent.new()
	hitbox.damage = explosion_damage
	hitbox.knockback_force = 250.0
	hitbox.hitstun_duration = 0.25
	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	shape.shape = circle
	hitbox.add_child(shape)

	# Explosion visual
	var explosion := ColorRect.new()
	explosion.size = Vector2(explosion_radius * 2, explosion_radius * 2)
	explosion.position = Vector2(-explosion_radius, -explosion_radius)
	explosion.color = Color(1.0, 0.5, 0.0, 0.6)
	hitbox.add_child(explosion)

	hitbox.global_position = global_position
	get_parent().add_child(hitbox)
	hitbox.owner = self
	hitbox.activate()

	# Cleanup
	EventBus.enemy_died.emit(self, global_position)
	if CombatManager:
		CombatManager.unregister_enemy(self)

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

	if is_instance_valid(self):
		queue_free()


func _on_damage_received(damage: int, _knockback: Vector2, _hitstun: float) -> void:
	if _is_dead:
		return
	current_hp -= damage
	if current_hp <= 0:
		_explode()
	else:
		_flash_damage()


func _flash_damage() -> void:
	var visual = get_node_or_null("Visual")
	if visual:
		visual.modulate = Color(2.0, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and is_instance_valid(visual):
			visual.modulate = Color.WHITE


func die() -> void:
	_explode()


func explode() -> void:
	_explode()


func set_fabricator(fab: Node) -> void:
	_fabricator = fab


func take_damage(amount: float, _attacker: Node = null) -> void:
	_on_damage_received(int(amount), Vector2.ZERO, 0.0)


func _has_visual() -> bool:
	for child in get_children():
		if child is ColorRect or child is Sprite2D:
			return true
	return false
