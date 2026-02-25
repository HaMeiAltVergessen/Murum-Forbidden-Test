extends Node
## LythrunAnimator - Controls Lythrun's AnimatedSprite2D animations
class_name LythrunAnimator

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = null
@onready var movement_controller: MovementController = null

var current_animation: String = "idle"

func _ready() -> void:
	await get_tree().process_frame

	animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		push_error("[LythrunAnimator] No AnimatedSprite2D found")
		return

	movement_controller = player.get_node_or_null("MovementController")

	print("[LythrunAnimator] Ready with AnimatedSprite2D")

func _process(_delta: float) -> void:
	if not animated_sprite:
		return

	_update_animation_state()
	_update_sprite_flip()

func _update_animation_state() -> void:
	var new_animation: String = "idle"

	# Check Lythrun-specific states
	if "shadow_dash_active" in player and player.shadow_dash_active:
		new_animation = "dash"
	elif "is_attacking" in player and player.is_attacking:
		new_animation = "attack"
	elif "is_void_parrying" in player and player.is_void_parrying:
		new_animation = "parry"
	elif "scythe_thrown" in player and player.scythe_thrown:
		new_animation = "scythe"
	elif "is_charging_orb" in player and player.is_charging_orb:
		new_animation = "special_2"
	elif "phase_shift_active" in player and player.phase_shift_active:
		new_animation = "ultimate"
	elif "void_rift_active" in player and player.void_rift_active:
		new_animation = "special_1"
	elif movement_controller and movement_controller.is_climbing:
		new_animation = "climb"
	elif movement_controller and movement_controller.is_wall_sliding:
		# Graceful fallback: use "fall" if "wall_slide" animation doesn't exist yet
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("wall_slide"):
			new_animation = "wall_slide"
		else:
			new_animation = "fall"
	elif not player.is_on_floor():
		if player.velocity.y < -100:
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
