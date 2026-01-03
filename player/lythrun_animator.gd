extends Node
## LythrunAnimator handles Lythrun's sprite animations (5x4 grid, 20 frames total)
class_name LythrunAnimator

@onready var player: CharacterBody2D = get_parent()
@onready var sprite: Sprite2D = null
@onready var movement_controller: MovementController = null

# Animation settings
@export var animation_speed: float = 0.08

# Animation state
var current_animation: String = "idle"
var current_frame_index: int = 0
var animation_timer: float = 0.0
var is_attacking: bool = false
var is_dashing: bool = false

# Lythrun's animations (5 columns x 4 rows = 20 frames)
# Based on the sprite sheet layout (dark character with scythe):
# Row 0 (0-4): Idle and walking
# Row 1 (5-9): Attack animations
# Row 2 (10-14): More combat/action poses
# Row 3 (15-19): Special abilities and additional actions
var animations: Dictionary = {
	"idle": [0, 1],                  # Idle frames
	"walk": [0, 1, 2, 3],           # Walking
	"run": [0, 1, 2, 3, 4],         # Running
	"jump": [5],                     # Jump
	"fall": [6],                     # Falling
	"land": [7],                     # Landing
	"attack_1": [5, 6],              # Void Strike 1
	"attack_2": [7, 8],              # Void Strike 2
	"attack_3": [9],                 # Void Strike 3 (with shockwave)
	"dash": [10, 11],                # Shadow Dash
	"scythe_throw": [12, 13],        # Shadow Scythe throw
	"parry": [14],                   # Void Parry
	"ultimate": [15, 16, 17],        # Phase-Shift / Ultimate
	"special_1": [18],               # Void Rift
	"special_2": [19],               # Void Orbs
	"hurt": [14]                     # Taking damage
}

func _ready() -> void:
	await get_tree().process_frame

	sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		push_error("[LythrunAnimator] No Sprite2D found")
		return

	movement_controller = player.get_node_or_null("MovementController")

	# Listen for Lythrun's shadow ability calls
	if player.has_method("_process"):
		# Lythrun handles abilities in _process, so we monitor state
		pass

	print("[LythrunAnimator] Initialized with 20 frames (5x4)")

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

	# Check Lythrun-specific states
	if player.has("shadow_dash_active") and player.shadow_dash_active:
		new_animation = "dash"
	elif player.has("is_attacking") and player.is_attacking:
		if current_animation.begins_with("attack"):
			return
		new_animation = "attack_1"
	elif player.has("is_void_parrying") and player.is_void_parrying:
		new_animation = "parry"
	elif player.has("scythe_thrown") and player.scythe_thrown:
		new_animation = "scythe_throw"
	elif player.has("is_charging_orb") and player.is_charging_orb:
		new_animation = "special_2"
	elif player.has("phase_shift_active") and player.phase_shift_active:
		new_animation = "ultimate"
	elif player.has("void_rift_active") and player.void_rift_active:
		new_animation = "special_1"
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

	# Lythrun already handles flip_h in lythrun_player.gd
	# But we can also update based on velocity as backup
	if player.velocity.x < -10:
		sprite.flip_h = true
	elif player.velocity.x > 10:
		sprite.flip_h = false

# Public methods for triggering specific animations
func play_void_strike(combo: int) -> void:
	is_attacking = true
	match combo:
		0:
			play_animation("attack_1")
		1:
			play_animation("attack_2")
		2:
			play_animation("attack_3")

	# Reset attacking flag after animation duration
	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func play_shadow_dash() -> void:
	play_animation("dash")

func play_scythe() -> void:
	play_animation("scythe_throw")

func play_parry() -> void:
	play_animation("parry")

func play_ultimate() -> void:
	play_animation("ultimate")
