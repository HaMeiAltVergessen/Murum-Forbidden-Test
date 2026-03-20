extends Node
## MurumAnimator - Controls Murum's AnimatedSprite2D animations
## Handles sprite flipping, staff mirroring, attack stretch, and resonance glow
class_name MurumAnimator

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = null
@onready var movement_controller: MovementController = null
@onready var combat_system = null
@onready var staff_sprite: Sprite2D = null
@onready var staff_controller: StaffController = null
@onready var dodge_roll_system = null

var current_animation: String = "idle"
var is_attacking: bool = false
var facing_right: bool = true

# ============ STAFF VISUAL CONFIG ============
const STAFF_POS_RIGHT: Vector2 = Vector2(30, -5)
const STAFF_POS_LEFT: Vector2 = Vector2(-30, -5)
const STAFF_BASE_SCALE: float = 0.142  # Original scale from murum.tscn

# Attack rotation
var _attack_rotation_tween: Tween = null

# Resonance glow (orb at staff tip)
var _orb_glow: Sprite2D = null
var _orb_glow_tween: Tween = null
var _resonance_pct: float = 0.0
const ORB_COLOR: Color = Color(0.6, 0.8, 1.0)  # Blau-weiss
const ORB_OFFSET_RIGHT: Vector2 = Vector2(12, -28)  # Relativ zum StaffSprite
const ORB_OFFSET_LEFT: Vector2 = Vector2(-12, -28)

func _ready() -> void:
	await get_tree().process_frame

	animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		push_error("[MurumAnimator] No AnimatedSprite2D found")
		return

	movement_controller = player.get_node_or_null("MovementController")
	combat_system = player.get_node_or_null("CombatSystem")
	staff_sprite = player.get_node_or_null("StaffSprite")
	staff_controller = player.get_node_or_null("StaffController")
	dodge_roll_system = player.get_node_or_null("DodgeRollSystem")

	# Connect to attack signal via EventBus (CombatSystem has no local signals)
	if EventBus:
		EventBus.player_attacked.connect(_on_player_attacked)

	# Connect resonance signals
	if EventBus:
		EventBus.resonance_changed.connect(_on_resonance_changed)
		EventBus.resonance_mode_activated.connect(_on_resonance_mode_activated)
		EventBus.resonance_mode_deactivated.connect(_on_resonance_mode_deactivated)

	# Create orb glow light
	_create_orb_glow()

	print("[MurumAnimator] Ready with AnimatedSprite2D")

func _process(_delta: float) -> void:
	if not animated_sprite:
		return

	_update_animation_state()
	_update_sprite_flip()
	_update_orb_glow_position()

# ============ ANIMATION STATE ============
func _update_animation_state() -> void:
	var new_animation: String = "idle"

	# Priority: Attack > Roll > Dash > Climbing > Wall Slide > Jump/Fall > Walk > Idle
	if is_attacking:
		return  # Don't override attack animation
	if dodge_roll_system and dodge_roll_system.is_dodging():
		new_animation = "roll"
	elif movement_controller and movement_controller.is_dashing:
		new_animation = "dash"
	elif movement_controller and movement_controller.is_climbing:
		new_animation = "climb"
	elif movement_controller and movement_controller.is_wall_sliding:
		# Graceful fallback: use "fall" if "wall_slide" animation doesn't exist yet
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("wall_slide"):
			new_animation = "wall_slide"
		else:
			new_animation = "fall"
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

# ============ SPRITE FLIP + STAFF MIRROR ============
func _update_sprite_flip() -> void:
	if not animated_sprite:
		return

	var old_facing := facing_right

	# Update facing based on movement
	if player.velocity.x < -10:
		animated_sprite.flip_h = true
		facing_right = false
	elif player.velocity.x > 10:
		animated_sprite.flip_h = false
		facing_right = true

	# Mirror staff when direction changes
	if old_facing != facing_right:
		_update_staff_position()

func _update_staff_position() -> void:
	if not staff_sprite or not staff_sprite.get_parent() == player:
		return  # Staff is thrown (reparented to projectile)

	if facing_right:
		staff_sprite.position = STAFF_POS_RIGHT
		staff_sprite.scale = Vector2(STAFF_BASE_SCALE, STAFF_BASE_SCALE)
	else:
		staff_sprite.position = STAFF_POS_LEFT
		staff_sprite.scale = Vector2(-STAFF_BASE_SCALE, STAFF_BASE_SCALE)

# ============ ATTACK ROTATION ============
func _on_player_attacked(attack_number: int) -> void:
	# Play attack sprite animation
	is_attacking = true
	play_animation("attack")
	_play_attack_rotation(attack_number)

func _play_attack_rotation(attack_number: int) -> void:
	if not staff_sprite or not staff_sprite.get_parent() == player:
		return  # Staff is thrown

	if _attack_rotation_tween and _attack_rotation_tween.is_valid():
		_attack_rotation_tween.kill()

	var dir: float = 1.0 if facing_right else -1.0

	_attack_rotation_tween = create_tween()
	match attack_number:
		1:  # Overhead swing
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				-PI / 3.0 * dir, 0.06)
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				PI / 6.0 * dir, 0.12)
		2:  # Side swing
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				PI / 4.0 * dir, 0.06)
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				-PI / 6.0 * dir, 0.12)
		_:  # Upward thrust / finisher
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				-PI / 4.0 * dir, 0.05)
			_attack_rotation_tween.tween_property(staff_sprite, "rotation",
				PI / 3.0 * dir, 0.10)
	# Return to idle
	_attack_rotation_tween.tween_property(staff_sprite, "rotation", 0.0, 0.08)
	_attack_rotation_tween.tween_callback(func(): is_attacking = false)

func _reset_staff_rotation() -> void:
	if _attack_rotation_tween and _attack_rotation_tween.is_valid():
		_attack_rotation_tween.kill()
		_attack_rotation_tween = null

	if not staff_sprite or not staff_sprite.get_parent() == player:
		return

	staff_sprite.rotation = 0.0

# ============ RESONANCE ORB GLOW ============
func _create_orb_glow() -> void:
	# Sprite2D statt PointLight2D — kein Einfluss auf andere Sprites
	_orb_glow = Sprite2D.new()
	_orb_glow.name = "StaffOrbGlow"
	_orb_glow.modulate = ORB_COLOR
	_orb_glow.modulate.a = 0.0  # Unsichtbar am Start
	_orb_glow.scale = Vector2(0.3, 0.3)
	_orb_glow.z_index = 5
	# Gradient-Textur fuer weichen Glow
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = grad
	_orb_glow.texture = tex
	player.add_child(_orb_glow)

func _update_orb_glow_position() -> void:
	if not _orb_glow:
		return

	if staff_sprite and staff_sprite.get_parent() == player:
		_orb_glow.position = staff_sprite.position + (ORB_OFFSET_RIGHT if facing_right else ORB_OFFSET_LEFT)
	else:
		_orb_glow.modulate.a = 0.0

func _on_resonance_changed(current: float, maximum: float, percentage: float) -> void:
	_resonance_pct = percentage / 100.0  # 0.0 - 1.0

	if not _orb_glow:
		return

	# Glow erst ab 25% sichtbar (ueber Alpha)
	if _resonance_pct < 0.25:
		_orb_glow.modulate.a = 0.0
		return

	var t: float = (_resonance_pct - 0.25) / 0.75  # Normalize to 0-1
	_orb_glow.modulate = ORB_COLOR.lerp(Color(1.0, 0.95, 0.7), t)
	_orb_glow.modulate.a = t * 0.8  # Max 80% opak
	_orb_glow.scale = Vector2(0.3 + t * 0.4, 0.3 + t * 0.4)

func _on_resonance_mode_activated() -> void:
	if not _orb_glow:
		return

	if _orb_glow_tween and _orb_glow_tween.is_valid():
		_orb_glow_tween.kill()

	_orb_glow.modulate = Color(1.0, 0.9, 0.5)  # Gold
	_orb_glow.modulate.a = 1.0
	_orb_glow.scale = Vector2(0.7, 0.7)

	_orb_glow_tween = create_tween().set_loops()
	_orb_glow_tween.tween_property(_orb_glow, "modulate:a", 1.0, 0.4)
	_orb_glow_tween.tween_property(_orb_glow, "modulate:a", 0.5, 0.4)

func _on_resonance_mode_deactivated() -> void:
	if not _orb_glow:
		return

	if _orb_glow_tween and _orb_glow_tween.is_valid():
		_orb_glow_tween.kill()
		_orb_glow_tween = null

	_orb_glow.modulate.a = 0.0
	_resonance_pct = 0.0
