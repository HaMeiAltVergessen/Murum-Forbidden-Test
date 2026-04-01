extends Node2D
class_name ForceField

## F2.5 - Kraftfeld-Barriere (W2 Sci-Fi)
## Energy shield that blocks passage and damages on contact
## Must be deactivated via switch/puzzle. Optionally reactivates after time.
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal field_activated()
signal field_deactivated()
signal field_hit(entity: Node2D)

# ============================================================================
# ENUMS
# ============================================================================

enum State { ACTIVE, DEACTIVATING, INACTIVE, REACTIVATING }

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage_per_second: int = 10
@export var reactivate_time: float = 0.0    ## 0 = stays off permanently
@export var linked_switch_path: NodePath = ""
@export var field_width: float = 16.0
@export var field_height: float = 128.0

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.ACTIVE
var contact_players: Dictionary = {}  # player -> true

# ============================================================================
# REFERENCES
# ============================================================================

@onready var blocker: StaticBody2D = $Blocker if has_node("Blocker") else null
@onready var damage_area: Area2D = $DamageArea if has_node("DamageArea") else null
@onready var field_visual: AnimatedSprite2D = $FieldVisual if has_node("FieldVisual") else null

var damage_timer: Timer = null
var reactivate_timer: Timer = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup damage area
	if damage_area:
		damage_area.monitoring = true
		damage_area.monitorable = false
		damage_area.body_entered.connect(_on_body_entered)
		damage_area.body_exited.connect(_on_body_exited)

		damage_area.collision_layer = 0
		damage_area.set_collision_layer_value(7, true)
		damage_area.collision_mask = 0
		damage_area.set_collision_mask_value(2, true)
		damage_area.set_collision_mask_value(3, true)

	# Setup blocker collision
	if blocker:
		blocker.collision_layer = 0
		blocker.set_collision_layer_value(1, true)   # World layer (blocks movement)

	# Damage timer (DoT while touching)
	damage_timer = Timer.new()
	damage_timer.one_shot = false
	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_apply_contact_damage)
	add_child(damage_timer)
	damage_timer.start()

	# Reactivate timer
	reactivate_timer = Timer.new()
	reactivate_timer.one_shot = true
	reactivate_timer.timeout.connect(_reactivate)
	add_child(reactivate_timer)

	# Connect linked switch
	if linked_switch_path != NodePath(""):
		var switch_node = get_node_or_null(linked_switch_path)
		if switch_node and switch_node.has_signal("switch_activated"):
			switch_node.switch_activated.connect(deactivate)
		elif switch_node and switch_node.has_signal("puzzle_solved"):
			switch_node.puzzle_solved.connect(deactivate)
		elif switch_node and switch_node.has_signal("plate_pressed"):
			switch_node.plate_pressed.connect(func(_a): deactivate())

	_update_visual()

	add_to_group("traps")
	add_to_group("force_fields")

	print("[ForceField] %s initialized (reactivate: %.1fs)" % [name, reactivate_time])

# ============================================================================
# ACTIVATION / DEACTIVATION
# ============================================================================

func activate() -> void:
	"""Activate force field"""
	if current_state == State.ACTIVE:
		return

	current_state = State.ACTIVE

	# Enable blocker
	if blocker:
		blocker.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		var col = blocker.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", false)

	# Enable damage area
	if damage_area:
		damage_area.monitoring = true

	field_activated.emit()
	_update_visual()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/forcefield_activate", global_position, 0.25)

	print("[ForceField] %s activated" % name)

func deactivate() -> void:
	"""Deactivate force field"""
	if current_state == State.INACTIVE:
		return

	current_state = State.DEACTIVATING
	contact_players.clear()

	# Disable blocker
	if blocker:
		var col = blocker.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)

	# Disable damage area
	if damage_area:
		damage_area.monitoring = false

	# Deactivation animation
	if field_visual:
		var tween = create_tween()
		tween.tween_property(field_visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): current_state = State.INACTIVE)
	else:
		current_state = State.INACTIVE

	field_deactivated.emit()

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/forcefield_deactivate", global_position, 0.25)

	# Start reactivation timer if configured
	if reactivate_time > 0.0:
		reactivate_timer.wait_time = reactivate_time
		reactivate_timer.start()

	print("[ForceField] %s deactivated" % name)

func _reactivate() -> void:
	"""Reactivate after timer"""
	current_state = State.REACTIVATING

	# Warning before reactivation
	if field_visual:
		field_visual.modulate.a = 0.0
		var tween = create_tween().set_loops(3)
		tween.tween_property(field_visual, "modulate:a", 0.5, 0.2)
		tween.tween_property(field_visual, "modulate:a", 0.1, 0.2)
		tween.finished.connect(activate)

		# Green → Red transition
		field_visual.modulate = Color(0.2, 0.8, 0.2, 0.6)
	else:
		activate()

# ============================================================================
# CONTACT DAMAGE
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if current_state != State.ACTIVE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	contact_players[body] = true

	# Immediate first hit
	_damage_player(body)

func _on_body_exited(body: Node2D) -> void:
	if body in contact_players:
		contact_players.erase(body)

func _apply_contact_damage() -> void:
	"""Apply DoT to all touching players"""
	if current_state != State.ACTIVE:
		return

	for player in contact_players.keys():
		if is_instance_valid(player):
			_damage_player(player)
		else:
			contact_players.erase(player)

func _damage_player(player: Node2D) -> void:
	var hurtbox = player.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		var knockback_dir = (player.global_position - global_position).normalized()
		hurtbox.take_damage(damage_per_second, knockback_dir * 100.0, 0.1)

	field_hit.emit(player)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	if not field_visual:
		return

	match current_state:
		State.ACTIVE:
			field_visual.visible = true
			field_visual.modulate = Color(1.0, 0.2, 0.2, 0.6)  # Red
		State.INACTIVE:
			field_visual.visible = false

func _process(_delta: float) -> void:
	# Active shimmer effect
	if current_state == State.ACTIVE and field_visual:
		var shimmer = sin(Time.get_ticks_msec() * 0.005) * 0.15 + 0.85
		field_visual.modulate.a = shimmer

# ============================================================================
# HELPERS
# ============================================================================

func is_active() -> bool:
	return current_state == State.ACTIVE
