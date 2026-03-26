extends StaticBody2D
class_name PhasePlatform

## F3.4 - Phasen-Plattform (W3 Kosmischer Horror)
## Platform that phases in and out of existence cyclically
## Supports group sync with offset for alternating patterns
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal platform_solidified()
signal platform_phased()

# ============================================================================
# ENUMS
# ============================================================================

enum State { SOLID, WARNING, PHASED }

# ============================================================================
# EXPORTS
# ============================================================================

@export var solid_duration: float = 3.0
@export var warning_duration: float = 1.0
@export var phased_duration: float = 2.0
@export var phase_group: String = ""       ## Platforms in same group sync together
@export var phase_offset: float = 0.0      ## Offset in seconds for staggered patterns
@export var platform_width: float = 96.0
@export var platform_height: float = 16.0

# ============================================================================
# STATE
# ============================================================================

var current_state: State = State.SOLID
var state_timer: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================

@onready var platform_visual: ColorRect = $PlatformVisual if has_node("PlatformVisual") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var phase_particles: GPUParticles2D = $PhaseParticles if has_node("PhaseParticles") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Start as solid
	collision_layer = 0
	set_collision_layer_value(1, true)   # World layer

	# Apply offset into cycle
	var total_cycle = solid_duration + warning_duration + phased_duration
	var offset = fmod(phase_offset, total_cycle)

	if offset < solid_duration:
		current_state = State.SOLID
		state_timer = solid_duration - offset
	elif offset < solid_duration + warning_duration:
		current_state = State.WARNING
		state_timer = warning_duration - (offset - solid_duration)
	else:
		current_state = State.PHASED
		state_timer = phased_duration - (offset - solid_duration - warning_duration)
		_apply_phased_state()

	_update_visual()

	add_to_group("traps")
	add_to_group("phase_platforms")
	if phase_group != "":
		add_to_group("phase_group_" + phase_group)

	print("[PhasePlatform] %s initialized (group: %s, offset: %.1f)" % [name, phase_group if phase_group != "" else "none", phase_offset])

# ============================================================================
# CYCLE
# ============================================================================

func _process(delta: float) -> void:
	state_timer -= delta

	if state_timer <= 0.0:
		_advance_state()

	# Warning flicker
	if current_state == State.WARNING and platform_visual:
		var flicker = sin(Time.get_ticks_msec() * 0.015) * 0.4 + 0.6
		platform_visual.modulate.a = flicker

func _advance_state() -> void:
	match current_state:
		State.SOLID:
			_enter_warning()
		State.WARNING:
			_enter_phased()
		State.PHASED:
			_enter_solid()

func _enter_solid() -> void:
	current_state = State.SOLID
	state_timer = solid_duration

	# Enable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	platform_solidified.emit()
	_update_visual()

	# Fade-in effect
	if platform_visual:
		platform_visual.modulate.a = 0.3
		var tween = create_tween()
		tween.tween_property(platform_visual, "modulate:a", 1.0, 0.2)

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/phase_solidify", global_position, 0.15)

func _enter_warning() -> void:
	current_state = State.WARNING
	state_timer = warning_duration

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/phase_warning", global_position, 0.1)

	_update_visual()

func _enter_phased() -> void:
	current_state = State.PHASED
	state_timer = phased_duration

	_apply_phased_state()

	platform_phased.emit()
	_update_visual()

	# Particles
	if phase_particles:
		phase_particles.restart()
		phase_particles.emitting = true

	# Audio
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/phase_vanish", global_position, 0.15)

func _apply_phased_state() -> void:
	"""Disable collision when phased"""
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

# ============================================================================
# VISUALS
# ============================================================================

func _update_visual() -> void:
	if not platform_visual:
		return

	match current_state:
		State.SOLID:
			platform_visual.visible = true
			platform_visual.color = Color(0.3, 0.2, 0.4, 1.0)  # Dark purple
			platform_visual.modulate.a = 1.0
		State.WARNING:
			platform_visual.color = Color(0.5, 0.2, 0.5, 0.8)  # Purple, flickering
		State.PHASED:
			platform_visual.visible = true
			platform_visual.color = Color(0.3, 0.15, 0.4, 0.15)  # Ghost outline
			platform_visual.modulate.a = 0.15
