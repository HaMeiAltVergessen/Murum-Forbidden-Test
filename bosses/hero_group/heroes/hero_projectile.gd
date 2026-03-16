extends Area2D
## Simple projectile for hero group members
class_name HeroProjectile

var proj_speed: float = 250.0
var proj_dir: Vector2 = Vector2.RIGHT
var proj_damage: int = 10
var proj_knockback: float = 200.0
var proj_hitstun: float = 0.2
var proj_max_range: float = 350.0
var proj_owner: Node = null
var _traveled: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var move: Vector2 = proj_dir * proj_speed * delta
	global_position += move
	_traveled += move.length()
	if _traveled >= proj_max_range:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox_owner: Node = area.owner if area.owner else area.get_parent()
		if hurtbox_owner and (hurtbox_owner.is_in_group("player") or hurtbox_owner.is_in_group("player2")):
			area.take_damage(proj_damage, proj_dir * proj_knockback, proj_hitstun, proj_owner)
			queue_free()
