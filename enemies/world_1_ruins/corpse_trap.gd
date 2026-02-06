extends StaticBody2D
class_name CorpseTrap

## Destructible corpse trap that spawns Glimmerseeds when destroyed.
## Place these in levels as hidden traps - looks like a dead body on the ground.
## When the player attacks it, it breaks and spawns 1-3 Glimmerseeds.

# ============================================================================
# CONFIGURATION
# ============================================================================

## Chance to spawn a Glimmerseed per attempt (0.0 - 1.0)
@export var spawn_chance: float = 0.4
## Minimum number of Glimmerseeds to spawn
@export var min_spawns: int = 1
## Maximum number of Glimmerseeds to spawn
@export var max_spawns: int = 2
## HP of the corpse before it breaks
@export var max_hp: int = 1

# ============================================================================
# STATE
# ============================================================================

var current_hp: int
var is_destroyed: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

const GLIMMERSEED_SCENE: String = "res://enemies/world_1_ruins/glimmerseed.tscn"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	current_hp = max_hp
	add_to_group("destructible")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	print("[CorpseTrap] Ready at %v, HP: %d" % [global_position, current_hp])


# ============================================================================
# DAMAGE
# ============================================================================

func _on_damage_received(_damage: int, _knockback: Vector2, _hitstun: float) -> void:
	if is_destroyed:
		return

	current_hp -= 1
	print("[CorpseTrap] Hit! HP: %d" % current_hp)

	# Visual feedback
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if current_hp <= 0:
		_destroy()


func _destroy() -> void:
	"""Destroys the corpse and potentially spawns Glimmerseeds"""
	is_destroyed = true

	# Disable hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)

	# Spawn Glimmerseeds based on chance
	var glimmerseed_scene = load(GLIMMERSEED_SCENE)
	if glimmerseed_scene:
		var spawn_count = 0
		for i in range(randi_range(min_spawns, max_spawns)):
			if randf() <= spawn_chance:
				var seed_enemy = glimmerseed_scene.instantiate()
				var offset = Vector2(randf_range(-30, 30), -20)
				seed_enemy.global_position = global_position + offset
				get_tree().current_scene.call_deferred("add_child", seed_enemy)
				spawn_count += 1
				print("[CorpseTrap] Spawned Glimmerseed at %v" % (global_position + offset))

		if spawn_count == 0:
			print("[CorpseTrap] Destroyed but no Glimmerseeds spawned (bad luck)")
	else:
		push_warning("[CorpseTrap] Could not load Glimmerseed scene!")

	# Death animation
	AudioManager.play_sfx("enemy_death")

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "scale:y", 0.3, 0.5)
	await tween.finished

	queue_free()
