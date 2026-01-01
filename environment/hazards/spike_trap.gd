extends Node2D
class_name SpikeTrap

## Spike trap that damages player on contact

# ============================================================================
# CONSTANTS
# ============================================================================

const DAMAGE: int = 20
const ACTIVE_DURATION: float = 2.0
const INACTIVE_DURATION: float = 3.0
const WARNING_DURATION: float = 0.5

# ============================================================================
# STATE
# ============================================================================

enum State { INACTIVE, WARNING, ACTIVE }

var current_state: State = State.INACTIVE
var state_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Node = get_node_or_null("AnimatedSprite2D")
@onready var visual: Node = get_node_or_null("Visual")
@onready var hitbox: Area2D = $HitboxComponent
@onready var warning_zone: Area2D = $WarningZone

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup hitbox
	if hitbox:
		hitbox.monitoring = false
		hitbox.body_entered.connect(_on_body_entered)

	# Setup warning zone
	if warning_zone:
		warning_zone.monitoring = false

	# Start cycle
	_start_cycle()

	add_to_group("hazards")

# ============================================================================
# CYCLE
# ============================================================================

func _start_cycle() -> void:
	"""Starts trap cycle"""
	current_state = State.INACTIVE
	state_timer = INACTIVE_DURATION

	_update_visual()

func _process(delta: float) -> void:
	state_timer -= delta

	if state_timer <= 0.0:
		_advance_state()

func _advance_state() -> void:
	"""Advances to next state"""
	match current_state:
		State.INACTIVE:
			_enter_warning()

		State.WARNING:
			_enter_active()

		State.ACTIVE:
			_enter_inactive()

func _enter_inactive() -> void:
	"""Enters inactive state (safe)"""
	current_state = State.INACTIVE
	state_timer = INACTIVE_DURATION

	# Disable hitbox
	if hitbox:
		hitbox.monitoring = false

	# Hide warning
	if warning_zone:
		warning_zone.monitoring = false

	_update_visual()

	print("[SpikeTrap] Inactive (%ds)" % INACTIVE_DURATION)

func _enter_warning() -> void:
	"""Enters warning state (telegraph)"""
	current_state = State.WARNING
	state_timer = WARNING_DURATION

	# Show warning
	if warning_zone:
		warning_zone.monitoring = true

	_update_visual()
	_play_warning_effect()

	# Audio
	if AudioManager:
		AudioManager.play_sfx("spike_extend", 0.1)

	print("[SpikeTrap] Warning (%ds)" % WARNING_DURATION)

func _enter_active() -> void:
	"""Enters active state (dangerous)"""
	current_state = State.ACTIVE
	state_timer = ACTIVE_DURATION

	# Enable hitbox
	if hitbox:
		hitbox.monitoring = true

	# Hide warning
	if warning_zone:
		warning_zone.monitoring = false

	_update_visual()
	_play_activation_effect()

	# Audio
	if AudioManager:
		AudioManager.play_sfx("spike_extend", 0.15)

	print("[SpikeTrap] Active (%ds)" % ACTIVE_DURATION)

# ============================================================================
# COLLISION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Damages player on contact"""
	if not body.is_in_group("player"):
		return

	if current_state != State.ACTIVE:
		return

	# Deal damage through HurtboxComponent
	var hurtbox = body.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		var knockback_direction = (body.global_position - global_position).normalized()
		var knockback = knockback_direction * 200.0  # Knockback force
		hurtbox.take_damage(DAMAGE, knockback, 0.3)
		print("[SpikeTrap] Hit player for %d damage" % DAMAGE)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	"""Updates sprite based on state"""
	var display_node = visual if visual else sprite
	if not display_node:
		return

	match current_state:
		State.INACTIVE:
			display_node.modulate = Color.WHITE

		State.WARNING:
			display_node.modulate = Color(1.5, 1.0, 0.5)  # Orange

		State.ACTIVE:
			display_node.modulate = Color(1.5, 0.5, 0.5)  # Red

func _play_warning_effect() -> void:
	"""Visual warning effect"""
	# Pulse warning zone
	if warning_zone:
		var tween = create_tween().set_loops(3)
		tween.tween_property(warning_zone, "modulate:a", 0.7, 0.15)
		tween.tween_property(warning_zone, "modulate:a", 0.3, 0.15)

func _play_activation_effect() -> void:
	"""Visual activation effect"""
	# Camera shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.15)
