extends Node2D
class_name ElectroPanel

## F2.2 - Elektropanel (W2 Sci-Fi Reskin der Stachelfalle)
## Floor panels that cyclically electrify with neon glow
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal panel_activated()
signal panel_deactivated()
signal panel_hit(entity: Node2D)

# ============================================================================
# ENUMS
# ============================================================================

enum State { OFF, WARNING, ACTIVE }

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 20
@export var knockback_force: float = 150.0
@export var hitstun: float = 0.2
@export var cycle_off: float = 3.0
@export var cycle_warning: float = 0.5
@export var cycle_active: float = 2.0
@export var sync_group: String = ""  ## Panels in same group activate together
@export var start_offset: float = 0.0  ## Offset into cycle at start

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.OFF
var state_timer: float = 0.0
var hit_entities_this_cycle: Array[Node2D] = []

# ============================================================================
# REFERENCES
# ============================================================================

@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var panel_visual: AnimatedSprite2D = $PanelVisual if has_node("PanelVisual") else null
@onready var spark_particles: GPUParticles2D = $SparkParticles if has_node("SparkParticles") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Setup hitbox
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		hitbox.body_entered.connect(_on_body_entered)

		hitbox.collision_layer = 0
		hitbox.set_collision_layer_value(7, true)   # Hazards
		hitbox.collision_mask = 0
		hitbox.set_collision_mask_value(2, true)    # P1
		hitbox.set_collision_mask_value(3, true)    # P2

	# Apply start offset
	if start_offset > 0.0:
		var total_cycle = cycle_off + cycle_warning + cycle_active
		var offset = fmod(start_offset, total_cycle)
		if offset < cycle_off:
			current_state = State.OFF
			state_timer = cycle_off - offset
		elif offset < cycle_off + cycle_warning:
			current_state = State.WARNING
			state_timer = cycle_warning - (offset - cycle_off)
		else:
			current_state = State.ACTIVE
			state_timer = cycle_active - (offset - cycle_off - cycle_warning)
			if hitbox:
				hitbox.monitoring = true
	else:
		current_state = State.OFF
		state_timer = cycle_off

	_update_visual()

	add_to_group("traps")
	add_to_group("electro_panels")
	if sync_group != "":
		add_to_group("electro_sync_" + sync_group)

	print("[ElectroPanel] %s initialized (sync: %s)" % [name, sync_group if sync_group != "" else "none"])

# ============================================================================
# CYCLE
# ============================================================================

func _process(delta: float) -> void:
	state_timer -= delta

	if state_timer <= 0.0:
		_advance_state()

	# Warning flicker effect
	if current_state == State.WARNING and glow_visual:
		var flicker = sin(Time.get_ticks_msec() * 0.02) * 0.5 + 0.5
		glow_visual.modulate.a = flicker

func _advance_state() -> void:
	match current_state:
		State.OFF:
			_enter_warning()
		State.WARNING:
			_enter_active()
		State.ACTIVE:
			_enter_off()

func _enter_off() -> void:
	current_state = State.OFF
	state_timer = cycle_off
	hit_entities_this_cycle.clear()

	if hitbox:
		hitbox.monitoring = false

	panel_deactivated.emit()
	_update_visual()

func _enter_warning() -> void:
	current_state = State.WARNING
	state_timer = cycle_warning

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/electro_charge", global_position, 0.15)

	_update_visual()

func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = cycle_active

	if hitbox:
		hitbox.monitoring = true

	# Particles
	if spark_particles:
		spark_particles.emitting = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/electro_zap", global_position, 0.25)

	panel_activated.emit()
	_update_visual()

	# Check for players already on panel
	if hitbox:
		for body in hitbox.get_overlapping_bodies():
			_on_body_entered(body)

# ============================================================================
# DAMAGE
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if current_state != State.ACTIVE:
		return

	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return

	if body in hit_entities_this_cycle:
		return

	hit_entities_this_cycle.append(body)

	# Deal damage via HurtboxComponent
	var hurtbox = body.get_node_or_null("HurtboxComponent")
	if hurtbox and hurtbox.has_method("take_damage"):
		var knockback_dir = (body.global_position - global_position).normalized()
		hurtbox.take_damage(damage, knockback_dir * knockback_force, hitstun)
		print("[ElectroPanel] %s shocked %s for %d damage" % [name, body.name, damage])
	else:
		var health_comp = body.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_method("take_damage"):
			health_comp.take_damage(damage)

	panel_hit.emit(body)

	# Camera shake
	_apply_camera_shake(0.15)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	if not panel_visual:
		return

	match current_state:
		State.OFF:
			panel_visual.modulate = Color(0.1, 0.15, 0.3, 1.0)  # Dark blue
			if spark_particles:
				spark_particles.emitting = false

		State.WARNING:
			panel_visual.modulate = Color(0.15, 0.3, 0.5, 1.0)  # Medium blue

		State.ACTIVE:
			panel_visual.modulate = Color(0.2, 0.7, 1.0, 1.0)  # Bright cyan

# ============================================================================
# HELPERS
# ============================================================================

func _apply_camera_shake(trauma: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_node("PlayerCamera"):
			player.get_node("PlayerCamera").add_trauma(trauma)
