extends Node
class_name Wolkenbruch

## Aerial ground slam ability with AoE damage
## Costs mana for full power, weakened without

# ============================================================================
# CONSTANTS
# ============================================================================

const MANA_COST: int = 25

const FULL_DAMAGE: int = 30
const FULL_KNOCKBACK: float = 350.0
const FULL_KNOCKBACK_DURATION: float = 0.5
const FULL_CAMERA_TRAUMA: float = 0.6

const WEAK_DAMAGE: int = 15
const WEAK_KNOCKBACK: float = 175.0
const WEAK_KNOCKBACK_DURATION: float = 0.3
const WEAK_CAMERA_TRAUMA: float = 0.3

const AOE_RADIUS: float = 200.0  # ~2 Meter Radius
const SLAM_VELOCITY: float = 1200.0
const RECOVERY_DURATION: float = 0.4

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, SLAMMING, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0

var is_powered: bool = false  # Mit oder ohne Mana

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner
@onready var mana_component: ManaComponent = player.get_node("ManaComponent")

# ============================================================================
# SIGNALS
# ============================================================================

signal wolkenbruch_started(powered: bool)
signal wolkenbruch_impact(powered: bool)
signal wolkenbruch_completed

# ============================================================================
# INPUT
# ============================================================================

func _ready() -> void:
	print("[Wolkenbruch] Initialized")

func _input(event: InputEvent) -> void:
	# Trigger on wolkenbruch_slam (S) press (Attack must also be held)
	if event.is_action_pressed("wolkenbruch_slam"):
		_try_activate()

func _try_activate() -> void:
	"""Attempts to activate Wolkenbruch"""

	print("[Wolkenbruch] Try activate called")

	if current_state != State.IDLE:
		print("[Wolkenbruch] Not in IDLE state")
		return

	# Must be airborne (ONLY requirement for Wolkenbruch)
	if player.is_on_floor():
		print("[Wolkenbruch] Player is on floor")
		return

	# Must have Attack pressed
	if not Input.is_action_pressed("light_attack"):
		print("[Wolkenbruch] Attack not pressed")
		return

	# Don't activate if Air-Combo is active (Air Slam Finisher has priority)
	var air_combo_system = player.get_node_or_null("AirComboSystem")
	if air_combo_system and air_combo_system.has_method("is_in_air_combo"):
		if air_combo_system.is_in_air_combo():
			print("[Wolkenbruch] Air-Combo active - Air Slam has priority")
			return

	# Don't activate if Luftgott is active
	var luftgott_system = player.get_node_or_null("LuftgottSystem")
	if luftgott_system and luftgott_system.has_method("is_active"):
		if luftgott_system.is_active():
			print("[Wolkenbruch] Luftgott active - cannot use Wolkenbruch")
			return

	# Activate!
	_start_wolkenbruch()

# ============================================================================
# ACTIVATION
# ============================================================================

func _start_wolkenbruch() -> void:
	"""Starts Wolkenbruch slam"""

	print("[Wolkenbruch] Activated")

	# Check mana
	is_powered = _check_and_consume_mana()

	# Enter slamming state
	current_state = State.SLAMMING

	# Apply downward velocity
	player.velocity.y = SLAM_VELOCITY
	player.velocity.x = 0  # Stop horizontal movement

	# Play animation
	_play_slam_animation()

	# Emit signal
	wolkenbruch_started.emit(is_powered)
	EventBus.wolkenbruch_started.emit(is_powered)

func _check_and_consume_mana() -> bool:
	"""Checks and consumes mana if available"""

	if not mana_component:
		print("[Wolkenbruch] WEAKENED (no mana component)")
		return false

	# Try to use mana - returns true if successful
	if mana_component.use_mana(MANA_COST):
		# Consume mana → Full power
		print("[Wolkenbruch] POWERED (mana consumed)")
		return true
	else:
		# No mana → Weakened
		print("[Wolkenbruch] WEAKENED (no mana)")
		return false

func _play_slam_animation() -> void:
	"""Plays slam animation"""

	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		# TODO: Add wolkenbruch_slam animation when available
		# sprite.play("wolkenbruch_slam")
		pass

	# Audio (charge/wind-up sound)
	var sfx_name = "player/wolkenbruch_charge_full" if is_powered else "player/wolkenbruch_charge_weak"
	AudioManager.play_sfx_at_position(sfx_name, player.global_position, 0.15)

# ============================================================================
# STATE MACHINE
# ============================================================================

func _physics_process(delta: float) -> void:
	match current_state:
		State.SLAMMING:
			_process_slamming(delta)
		State.RECOVERY:
			_process_recovery(delta)

func _process_slamming(delta: float) -> void:
	"""Processes slamming phase"""

	# Continue downward movement (player handles move_and_slide in their own script)
	player.velocity.y = SLAM_VELOCITY
	player.velocity.x = 0  # Lock horizontal movement

	# Check ground impact
	if player.is_on_floor():
		_on_impact()

func _process_recovery(delta: float) -> void:
	"""Processes recovery phase"""

	state_timer -= delta

	# Lock in place
	player.velocity = Vector2.ZERO

	if state_timer <= 0.0:
		_complete_wolkenbruch()

# ============================================================================
# IMPACT
# ============================================================================

func _on_impact() -> void:
	"""Called when slam hits ground"""

	print("[Wolkenbruch] IMPACT! (powered: %s)" % is_powered)

	# Enter recovery
	current_state = State.RECOVERY
	state_timer = RECOVERY_DURATION

	# Apply AoE effects
	_apply_aoe_damage()
	_apply_aoe_knockback()

	# Visual effects
	_spawn_impact_effects()

	# Audio
	var sfx_name = "player/wolkenbruch_impact_full" if is_powered else "player/wolkenbruch_impact_weak"
	AudioManager.play_sfx_at_position(sfx_name, player.global_position, 0.0)

	# Camera shake
	var trauma = FULL_CAMERA_TRAUMA if is_powered else WEAK_CAMERA_TRAUMA
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(trauma)

	# Hitstop
	var hitstop_duration = 0.2 if is_powered else 0.1
	GlobalTimeEffects.hit_stop(hitstop_duration)

	# Emit signal
	wolkenbruch_impact.emit(is_powered)
	EventBus.wolkenbruch_impact.emit(is_powered)

# ============================================================================
# AOE DAMAGE
# ============================================================================

func _apply_aoe_damage() -> void:
	"""Applies AoE damage to enemies in radius"""

	var damage = FULL_DAMAGE if is_powered else WEAK_DAMAGE

	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	for enemy in enemies:
		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= AOE_RADIUS:
			# Apply damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, player)
				hit_count += 1
			elif enemy.has_node("HealthComponent"):
				var health = enemy.get_node("HealthComponent")
				health.take_damage(damage)
				hit_count += 1

	print("[Wolkenbruch] Hit %d enemies for %d damage each" % [hit_count, damage])

func _apply_aoe_knockback() -> void:
	"""Applies radial knockback to enemies"""

	var knockback_force = FULL_KNOCKBACK if is_powered else WEAK_KNOCKBACK
	var knockback_duration = FULL_KNOCKBACK_DURATION if is_powered else WEAK_KNOCKBACK_DURATION

	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= AOE_RADIUS:
			# Calculate radial direction (away from impact)
			var radial_direction = (enemy.global_position - player.global_position).normalized()

			# Create knockback direction: slam enemies DOWN and AWAY
			# Keep horizontal component (outward), add strong downward force
			var direction = Vector2(radial_direction.x, abs(radial_direction.y) + 0.6).normalized()

			# Apply knockback
			if enemy.has_node("KnockbackComponent"):
				var kb = enemy.get_node("KnockbackComponent")
				kb.apply_knockback(direction, knockback_force, knockback_duration)
			elif enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction, knockback_force, knockback_duration)

# ============================================================================
# COMPLETION
# ============================================================================

func _complete_wolkenbruch() -> void:
	"""Completes Wolkenbruch"""

	current_state = State.IDLE
	is_powered = false

	print("[Wolkenbruch] Completed")

	wolkenbruch_completed.emit()

# ============================================================================
# EFFECTS
# ============================================================================

func _spawn_impact_effects() -> void:
	"""Spawns impact VFX"""

	# Crater effect
	var crater_scene_path = "res://vfx/particles/wolkenbruch_crater_full.tscn" if is_powered else "res://vfx/particles/wolkenbruch_crater_weak.tscn"

	if ResourceLoader.exists(crater_scene_path):
		var crater_scene = load(crater_scene_path)
		if crater_scene:
			var crater = crater_scene.instantiate()
			get_tree().root.add_child(crater)
			crater.global_position = player.global_position
			if crater.has_method("emit_particles"):
				crater.emit_particles()
			elif crater.has_property("emitting"):
				crater.emitting = true

	# Shockwave ring
	if is_powered:
		_spawn_shockwave()

func _spawn_shockwave() -> void:
	"""Spawns expanding shockwave ring (only full power)"""

	var shockwave_scene_path = "res://vfx/particles/wolkenbruch_shockwave.tscn"

	if not ResourceLoader.exists(shockwave_scene_path):
		return

	var shockwave_scene = load(shockwave_scene_path)
	var shockwave = shockwave_scene.instantiate()

	get_tree().root.add_child(shockwave)
	shockwave.global_position = player.global_position

	# Animate expansion
	var tween = create_tween()
	tween.tween_property(shockwave, "scale", Vector2(3.0, 3.0), 0.5)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.3)

	await tween.finished
	shockwave.queue_free()

# ============================================================================
# UTILITY
# ============================================================================

func is_active() -> bool:
	"""Returns true if Wolkenbruch is active"""
	return current_state in [State.SLAMMING, State.RECOVERY]

func can_activate() -> bool:
	"""Returns true if can activate"""
	return current_state == State.IDLE and not player.is_on_floor()
