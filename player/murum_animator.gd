extends Node
## MurumAnimator - Controls Murum's AnimatedSprite2D animations
class_name MurumAnimator

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = null
@onready var movement_controller: MovementController = null
@onready var combat_system = null

var current_animation: String = "idle"
var is_attacking: bool = false

func _ready() -> void:
	await get_tree().process_frame

	animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		push_error("[MurumAnimator] No AnimatedSprite2D found")
		return

	movement_controller = player.get_node_or_null("MovementController")
	combat_system = player.get_node_or_null("CombatSystem")

	# Connect to combat signals if available
	if combat_system:
		if combat_system.has_signal("attack_started"):
			combat_system.attack_started.connect(_on_attack_started)
		if combat_system.has_signal("attack_ended"):
			combat_system.attack_ended.connect(_on_attack_ended)

	print("[MurumAnimator] Ready with AnimatedSprite2D")

func _process(_delta: float) -> void:
	if not animated_sprite:
		return

	_update_animation_state()
	_update_sprite_flip()

func _update_animation_state() -> void:
	var new_animation: String = "idle"

	# Priority: Attack > Dash > Jump/Fall > Walk > Idle
	if is_attacking:
		new_animation = "attack"
	elif movement_controller and movement_controller.is_dashing:
		new_animation = "dash"
	elif not player.is_on_floor():
		if player.velocity.y < 0:
			new_animation = "jump"
		else:
			new_animation = "fall"
	elif abs(player.velocity.x) > 50:
		new_animation = "walk"
	else:
		new_animation = "idle"

	# Only change if different
	if new_animation != current_animation:
		play_animation(new_animation)

func play_animation(anim_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	# Check if animation exists
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return

	current_animation = anim_name
	animated_sprite.play(anim_name)

func _update_sprite_flip() -> void:
	if not animated_sprite:
		return

	# Update facing based on movement
	if player.velocity.x < -10:
		animated_sprite.flip_h = true
	elif player.velocity.x > 10:
		animated_sprite.flip_h = false

func _on_attack_started() -> void:
	is_attacking = true
	play_animation("attack")

func _on_attack_ended() -> void:
	is_attacking = false
