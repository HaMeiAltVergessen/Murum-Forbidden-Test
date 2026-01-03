extends Node
## SpriteAnimator handles sprite frame animations based on player state
class_name SpriteAnimator

# ============ REFERENCES ============
@onready var player: CharacterBody2D = get_parent()
@onready var sprite: Sprite2D = null
@onready var movement_controller: MovementController = null
@onready var combat_system = null

# ============ ANIMATION CONFIGURATION ============
@export var animation_speed: float = 0.1  # Time between frames

# ============ ANIMATION STATE ============
var current_animation: String = "idle"
var current_frame_index: int = 0
var animation_timer: float = 0.0

# ============ ANIMATION DEFINITIONS ============
# Format: "animation_name": [frame_indices]
var animations: Dictionary = {
	"idle": [0, 1, 2, 3],           # Row 0: Idle/standing
	"walk": [0, 1, 2, 3, 4],        # Row 0: Walking
	"jump": [5],                     # Row 1: Jump start
	"fall": [6],                     # Row 1: Falling
	"attack_1": [5, 6],              # Row 1: First attack
	"attack_2": [7, 8],              # Row 1: Second attack
	"attack_3": [9],                 # Row 1: Third attack
	"crouch": [10],                  # Row 2: Crouching
	"dash": [11, 12],                # Row 2: Dashing
	"hurt": [13],                    # Row 2: Taking damage
	"special": [14]                  # Row 2: Special ability
}

# ============ STATE TRACKING ============
var is_attacking: bool = false
var was_on_floor: bool = true

func _ready() -> void:
	# Wait one frame for all nodes to be ready
	await get_tree().process_frame

	# Get sprite reference
	sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		push_error("[SpriteAnimator] No Sprite2D found on player")
		return

	# Get movement controller
	movement_controller = player.get_node_or_null("MovementController")

	# Get combat system
	combat_system = player.get_node_or_null("CombatSystem")
	if combat_system:
		# Connect to combat signals if available
		if combat_system.has_signal("attack_started"):
			combat_system.attack_started.connect(_on_attack_started)
		if combat_system.has_signal("attack_ended"):
			combat_system.attack_ended.connect(_on_attack_ended)

	print("[SpriteAnimator] Ready for %s" % player.name)

func _process(delta: float) -> void:
	if not sprite:
		return

	# Update animation timer
	animation_timer += delta

	# Determine current state and play appropriate animation
	_update_animation_state()

	# Advance frame if enough time has passed
	if animation_timer >= animation_speed:
		animation_timer = 0.0
		_advance_frame()

	# Update sprite flip based on velocity/facing
	_update_sprite_flip()

func _update_animation_state() -> void:
	"""Determine which animation should play based on player state"""
	var new_animation: String = "idle"

	# Priority: Attack > Jump/Fall > Dash > Crouch > Walk > Idle

	# Check if attacking
	if is_attacking:
		# Keep current attack animation
		if current_animation.begins_with("attack"):
			return
		new_animation = "attack_1"

	# Check if dashing
	elif movement_controller and movement_controller.is_dashing:
		new_animation = "dash"

	# Check if crouching
	elif movement_controller and movement_controller.is_crouching:
		new_animation = "crouch"

	# Check if in air
	elif not player.is_on_floor():
		if player.velocity.y < 0:
			new_animation = "jump"
		else:
			new_animation = "fall"

	# Check if moving
	elif abs(player.velocity.x) > 10:
		new_animation = "walk"

	# Default to idle
	else:
		new_animation = "idle"

	# Change animation if different
	if new_animation != current_animation:
		play_animation(new_animation)

func play_animation(anim_name: String) -> void:
	"""Play a specific animation by name"""
	if not animations.has(anim_name):
		push_warning("[SpriteAnimator] Unknown animation: " + anim_name)
		return

	current_animation = anim_name
	current_frame_index = 0
	animation_timer = 0.0

	# Immediately update to first frame
	_update_sprite_frame()

func _advance_frame() -> void:
	"""Advance to next frame in current animation"""
	if not animations.has(current_animation):
		return

	var frames = animations[current_animation]
	current_frame_index = (current_frame_index + 1) % frames.size()

	_update_sprite_frame()

func _update_sprite_frame() -> void:
	"""Update the sprite to show the current frame"""
	if not sprite or not animations.has(current_animation):
		return

	var frames = animations[current_animation]
	if current_frame_index < frames.size():
		sprite.frame = frames[current_frame_index]

func _update_sprite_flip() -> void:
	"""Update sprite horizontal flip based on movement direction"""
	if not sprite or not movement_controller:
		return

	# Don't flip during attacks (unless you want to)
	if is_attacking:
		return

	# Flip based on velocity
	if player.velocity.x < -10:
		sprite.flip_h = true
	elif player.velocity.x > 10:
		sprite.flip_h = false

# ============ SIGNAL HANDLERS ============

func _on_attack_started() -> void:
	"""Called when player starts an attack"""
	is_attacking = true
	play_animation("attack_1")

func _on_attack_ended() -> void:
	"""Called when attack finishes"""
	is_attacking = false

# ============ PUBLIC METHODS ============

func play_special_animation(anim_name: String) -> void:
	"""Play a specific animation (for abilities, etc.)"""
	play_animation(anim_name)

func set_custom_frame(frame: int) -> void:
	"""Manually set sprite to specific frame"""
	if sprite:
		sprite.frame = frame
