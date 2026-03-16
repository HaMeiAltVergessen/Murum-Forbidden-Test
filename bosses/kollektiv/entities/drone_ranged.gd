extends CharacterBody2D
## Ranged Drone — Keeps distance and fires projectiles
## 25 HP, 6 DMG projectile, Speed 80

# ============ CONFIG ============
var max_hp: float = 25.0
var current_hp: float = 25.0
var move_speed: float = 80.0
var projectile_damage: int = 6
var fire_rate: float = 2.5
var preferred_range: float = 250.0
var gravity: float = 980.0

var _fire_timer: float = 0.0
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

	if not _has_visual():
		var visual := ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(24, 24)
		visual.position = Vector2(-12, -12)
		visual.color = Color(0.3, 0.3, 0.9)
		add_child(visual)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		velocity.x = 0
		move_and_slide()
		return

	var dir: Vector2 = player.global_position - global_position
	var distance: float = dir.length()

	# Maintain preferred range
	if distance < preferred_range - 50:
		velocity.x = -sign(dir.x) * move_speed  # Back away
	elif distance > preferred_range + 50:
		velocity.x = sign(dir.x) * move_speed  # Approach
	else:
		velocity.x = 0

	# Flip
	if sprite:
		sprite.flip_h = dir.x < 0

	# Fire
	_fire_timer += delta
	if _fire_timer >= fire_rate and distance < preferred_range + 100:
		_fire_timer = 0.0
		_fire_projectile(dir.normalized())

	move_and_slide()


func _fire_projectile(dir: Vector2) -> void:
	var proj_scene_path: String = "res://bosses/kollektiv/entities/kollektiv_projectile.tscn"
	if ResourceLoader.exists(proj_scene_path):
		var scene: PackedScene = load(proj_scene_path)
		var proj = scene.instantiate()
		proj.global_position = global_position + dir * 15
		proj.direction = dir
		proj.damage = projectile_damage
		proj.speed = 220.0
		get_parent().add_child(proj)
	else:
		# Fallback: direct hitbox
		var hitbox := HitboxComponent.new()
		hitbox.damage = projectile_damage
		hitbox.knockback_force = 100.0
		hitbox.hitstun_duration = 0.1
		hitbox.collision_layer = 128
		hitbox.collision_mask = 1024
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		hitbox.add_child(shape)
		hitbox.global_position = global_position + dir * 30
		get_parent().add_child(hitbox)
		hitbox.activate()
		await get_tree().create_timer(0.2).timeout
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
