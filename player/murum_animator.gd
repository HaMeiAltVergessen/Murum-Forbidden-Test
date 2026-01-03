extends Node
## MurumAnimator handles Murum's sprite animations (5x3 grid, 15 frames total)
class_name MurumAnimator

@onready var player: CharacterBody2D = get_parent()
@onready var sprite: Sprite2D = null
@onready var movement_controller: MovementController = null
@onready var combat_system = null

# Animation settings
@export var animation_speed: float = 0.08  # Faster for smoother animation

# Animation state
var current_animation: String = "idle"
var current_frame_index: int = 0
var animation_timer: float = 0.0
var is_attacking: bool = false

# Murum's animations (5 columns x 3 rows = 15 frames)
# Based on the sprite sheet layout:
# Row 0 (0-4): Idle and walking poses
# Row 1 (5-9): Attack animations and combat poses
# Row 2 (10-14): Jumping, special abilities, other actions
var animations: Dictionary = {
	"idle": [0, 1],                  # Idle frames
	"walk": [0, 1, 2, 3],           # Walking animation
	"run": [0, 1, 2, 3, 4],         # Running (use all row 0)
	"jump": [10],                    # Jump start
	"fall": [11],                    # Falling
	"land": [12],                    # Landing
	"attack_1": [5, 6],              # First attack
	"attack_2": [7, 8],              # Second attack
	"attack_3": [9],                 # Third attack (finisher)
	"dash": [13],                    # Dashing
	"hurt": [14],                    # Taking damage
	"special": [10, 11, 12]          # Special ability animation
}

func _ready() -> void:
	await get_tree().process_frame

	sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		push_error("[MurumAnimator] No Sprite2D found")
		return

	movement_controller = player.get_node_or_null("MovementController")
	combat_system = player.get_node_or_null("CombatSystem")

	# Connect to combat signals
	if combat_system:
		if combat_system.has_signal("attack_started"):
			combat_system.attack_started.connect(_on_attack_started)
		if combat_system.has_signal("attack_ended"):
			combat_system.attack_ended.connect(_on_attack_ended)
		if combat_system.has_signal("combo_advanced"):
			combat_system.combo_advanced.connect(_on_combo_advanced)

	print("[MurumAnimator] Initialized with 15 frames (5x3)")

func _process(delta: float) -> void:
	if not sprite:
		return

	animation_timer += delta
	_update_animation_state()

	if animation_timer >= animation_speed:
		animation_timer = 0.0
		_advance_frame()

	_update_sprite_flip()

func _update_animation_state() -> void:
	var new_animation: String = "idle"

	# Priority: Attack > Dash > Jump/Fall > Walk > Idle
	if is_attacking:
		if current_animation.begins_with("attack"):
			return
		new_animation = "attack_1"
	elif movement_controller and movement_controller.is_dashing:
		new_animation = "dash"
	elif not player.is_on_floor():
		if player.velocity.y < -100:
			new_animation = "jump"
		elif player.velocity.y > 100:
			new_animation = "fall"
		else:
			new_animation = "jump"
	elif abs(player.velocity.x) > 50:
		new_animation = "walk"
	else:
		new_animation = "idle"

	if new_animation != current_animation:
		play_animation(new_animation)

func play_animation(anim_name: String) -> void:
	if not animations.has(anim_name):
		return

	current_animation = anim_name
	current_frame_index = 0
	animation_timer = 0.0
	_update_sprite_frame()

func _advance_frame() -> void:
	if not animations.has(current_animation):
		return

	var frames = animations[current_animation]
	current_frame_index = (current_frame_index + 1) % frames.size()
	_update_sprite_frame()

func _update_sprite_frame() -> void:
	if not sprite or not animations.has(current_animation):
		return

	var frames = animations[current_animation]
	if current_frame_index < frames.size():
		sprite.frame = frames[current_frame_index]

func _update_sprite_flip() -> void:
	if not sprite:
		return

	# Update facing based on movement
	if player.velocity.x < -10:
		sprite.flip_h = true
	elif player.velocity.x > 10:
		sprite.flip_h = false

func _on_attack_started() -> void:
	is_attacking = true
	play_animation("attack_1")

func _on_attack_ended() -> void:
	is_attacking = false

func _on_combo_advanced(combo_count: int) -> void:
	# Play different attack animation based on combo
	match combo_count:
		1:
			play_animation("attack_1")
		2:
			play_animation("attack_2")
		3:
			play_animation("attack_3")
