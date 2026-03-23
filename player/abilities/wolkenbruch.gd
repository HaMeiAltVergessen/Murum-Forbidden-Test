extends Node
class_name Wolkenbruch

## Aerial ground slam ability with charging mechanic
## Hold S + Attack to charge, becomes stronger the longer you charge (max 8 seconds)
## Player glows brighter and hovers during charge

# ============================================================================
# CONSTANTS - Charging System
# ============================================================================

const MAX_CHARGE_TIME: float = 8.0  # Maximum charge time in seconds
const CHARGE_LEVELS: int = 8  # One level per second

# Base damage/knockback per charge level
const BASE_DAMAGE_PER_LEVEL: int = 20  # Level 1: 20, Level 8: 160
const BASE_KNOCKBACK_PER_LEVEL: float = 100.0  # Level 1: 100, Level 8: 800
const BASE_RADIUS_PER_LEVEL: float = 50.0  # Level 1: 50, Level 8: 400

const MANA_COST_PER_LEVEL: int = 10  # Level 1: 10, Level 8: 80 mana

# Visual
const MIN_BRIGHTNESS: float = 1.0  # Normal brightness
const MAX_BRIGHTNESS: float = 3.0  # Max brightness at level 8

# Physics
const SLAM_VELOCITY: float = 1500.0
const ENEMY_PULL_VELOCITY_MAX: float = 3000.0  # Halved from 6000 - more reasonable
const PULL_RADIUS: float = 128.0  # Doubled from 64
const PLAYER_SLAM_DELAY: float = 0.4  # Delay before player slams down
const RECOVERY_DURATION: float = 0.5
const CAMERA_TRAUMA_PER_LEVEL: float = 0.1

# Sideways push to prevent floor glitching
const SIDEWAYS_PUSH_FORCE: float = 1500.0  # Strong horizontal push (2 meters)
const LANDING_CHECK_RADIUS: float = 200.0  # Large check radius for enemies (must be bigger than impact radius)

# ============================================================================
# STATE
# ============================================================================

enum State { IDLE, CHARGING, SLAMMING, RECOVERY }

var current_state: State = State.IDLE
var state_timer: float = 0.0
var ability_disabled: bool = false  # Set by MirrorController during Phase 2

# Charging
var charge_time: float = 0.0
var charge_level: int = 0  # 1-8
var charging_position: Vector2 = Vector2.ZERO  # Position where charging started
var is_auto_releasing: bool = false  # Flag to prevent input interference during auto-release

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player: CharacterBody2D = owner
@onready var mana_component: ManaComponent = player.get_node("ManaComponent")
@onready var movement_controller: Node = player.get_node_or_null("MovementController")

# Screen darkening overlay
var darkening_overlay: ColorRect = null

# ============================================================================
# SIGNALS
# ============================================================================

signal wolkenbruch_charge_started()
signal wolkenbruch_charge_level_up(level: int)
signal wolkenbruch_released(level: int)
signal wolkenbruch_impact(level: int, damage: int)
signal wolkenbruch_completed()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[Wolkenbruch] Initialized (Charging System)")

# ============================================================================
# INPUT
# ============================================================================

# NOTE: Input handling moved to main _process() function below to avoid duplicate _process() functions

# ============================================================================
# CHARGING
# ============================================================================

func _try_start_charge() -> void:
	"""Attempts to start charging Wolkenbruch"""

	print("[Wolkenbruch] Try start charge")

	if ability_disabled:
		return

	if current_state != State.IDLE:
		print("[Wolkenbruch] Not in IDLE state")
		return

	# Must be airborne
	if player.is_on_floor():
		print("[Wolkenbruch] Player is on floor")
		return

	# Must have Attack pressed (through InputManager)
	if not InputManager:
		print("[Wolkenbruch] InputManager not available")
		return

	if not InputManager.is_p1_action_pressed("attack"):
		print("[Wolkenbruch] Attack not pressed")
		return

	# WOLKENBRUCH HAS HIGHEST PRIORITY - Cancel other systems if active
	# Cancel Air-Combo if active (Wolkenbruch is the finisher)
	var air_combo_system = player.get_node_or_null("AirComboSystem")
	if air_combo_system and air_combo_system.has_method("is_in_air_combo"):
		if air_combo_system.is_in_air_combo():
			print("[Wolkenbruch] Cancelling Air-Combo to start Wolkenbruch (finisher priority)")
			if air_combo_system.has_method("force_end_combo"):
				air_combo_system.force_end_combo()

	# Cancel Luftgott if active (Wolkenbruch is the finisher)
	var luftgott_system = player.get_node_or_null("LuftgottSystem")
	if luftgott_system and luftgott_system.has_method("is_active"):
		if luftgott_system.is_active():
			print("[Wolkenbruch] Cancelling Luftgott to start Wolkenbruch (finisher priority)")
			if luftgott_system.has_method("force_end"):
				luftgott_system.force_end()

	# Check minimum mana
	if not _check_minimum_mana():
		print("[Wolkenbruch] Insufficient mana (need at least %d)" % MANA_COST_PER_LEVEL)
		return

	# Start charging!
	_start_charge()


func _check_minimum_mana() -> bool:
	"""Checks if player has at least level 1 mana"""
	if not mana_component:
		return false

	if not mana_component.has_method("has_mana"):
		return false

	return mana_component.has_mana(MANA_COST_PER_LEVEL)


func _start_charge() -> void:
	"""Starts charging Wolkenbruch"""

	print("[Wolkenbruch] Charging started!")

	current_state = State.CHARGING
	charge_time = 0.0
	charge_level = 1  # Start at level 1

	# Store position where charging started
	charging_position = player.global_position

	# Enable hover mode (player floats in place)
	if movement_controller:
		movement_controller.is_hovering = true
		print("[Wolkenbruch] Player hovering during charge")

	# Set initial brightness
	_update_brightness()

	# Slow down time by 80% (time_scale = 0.2)
	Engine.time_scale = 0.2
	print("[Wolkenbruch] Time slowed to 20%")

	# Darken screen by 30%
	_apply_screen_darkening()

	# Audio
	AudioManager.play_sfx_at_position("player/wolkenbruch_charge_full", player.global_position, 0.2)

	# Emit signal
	wolkenbruch_charge_started.emit()
	EventBus.emit_signal("wolkenbruch_started", false)  # false = not instant


func _release_charge() -> void:
	"""Releases charge and performs slam"""

	if current_state != State.CHARGING:
		return

	print("[Wolkenbruch] Charge released! Level: %d (%.1fs)" % [charge_level, charge_time])

	# Consume mana based on final charge level
	_consume_charge_mana()

	# Disable hover
	if movement_controller:
		movement_controller.is_hovering = false

	# Reset brightness
	_reset_brightness()

	# Restore time scale
	Engine.time_scale = 1.0

	# Remove screen darkening
	_remove_screen_darkening()

	# Enter slamming state
	current_state = State.SLAMMING

	# PULL ENEMIES DOWN FIRST (before player)
	_pull_enemies_down()

	# Wait 0.4 seconds before player slams down
	# This gives enemies time to start falling first
	await get_tree().create_timer(PLAYER_SLAM_DELAY).timeout

	# Now apply downward velocity to player
	if current_state == State.SLAMMING:  # Safety check
		player.velocity.y = SLAM_VELOCITY
		player.velocity.x = 0
		print("[Wolkenbruch] Player now slamming down (delayed by %.1fs)" % PLAYER_SLAM_DELAY)

	# Emit signal
	wolkenbruch_released.emit(charge_level)

	# Audio
	AudioManager.play_sfx_at_position("player/wolkenbruch_release", player.global_position, 0.3)


func _consume_charge_mana() -> void:
	"""Consumes mana based on charge level"""
	if not mana_component:
		return

	var mana_cost = charge_level * MANA_COST_PER_LEVEL
	mana_component.use_mana(mana_cost)
	print("[Wolkenbruch] Consumed %d mana (Level %d)" % [mana_cost, charge_level])


func _pull_enemies_down() -> void:
	"""Pulls all nearby enemies down with the player during slam"""
	# All enemies in radius get pulled with SAME force

	var enemies = get_tree().get_nodes_in_group("enemies")
	var pulled_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= PULL_RADIUS:
			# Pull enemy down with FULL force (no distance scaling)
			if enemy is CharacterBody2D:
				enemy.velocity.y = ENEMY_PULL_VELOCITY_MAX
				pulled_count += 1
				print("[Wolkenbruch] Pulling %s down (dist: %.1f, force: %.0f)" % [
					enemy.name, distance, ENEMY_PULL_VELOCITY_MAX
				])

			# Set juggled state if available
			if enemy.has_method("set_juggled_state"):
				enemy.set_juggled_state(true)

	print("[Wolkenbruch] Pulled %d enemies down with player (radius: %.0f)" % [pulled_count, PULL_RADIUS])


func _push_enemies_sideways() -> void:
	"""Pushes enemies directly below player to the side to prevent floor glitching"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var pushed_count = 0
	var checked_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		checked_count += 1
		var distance = player.global_position.distance_to(enemy.global_position)
		var direction_to_enemy = (enemy.global_position - player.global_position)

		# Debug: Log each enemy check
		if distance <= LANDING_CHECK_RADIUS:
			print("[Wolkenbruch] Enemy %s in range: dist=%.1f, dx=%.1f, dy=%.1f" % [
				enemy.name, distance, direction_to_enemy.x, direction_to_enemy.y
			])

		# Push ALL enemies in landing zone (not just below, also at same level)
		# This prevents collision from any angle
		if distance <= LANDING_CHECK_RADIUS and direction_to_enemy.y > -50.0:
			# Determine push direction (left or right based on horizontal position)
			var push_direction = sign(direction_to_enemy.x)
			if push_direction == 0:
				push_direction = 1  # Default to right if directly under

			# Apply strong horizontal push
			if enemy is CharacterBody2D:
				enemy.velocity.x = push_direction * SIDEWAYS_PUSH_FORCE
				pushed_count += 1
				print("[Wolkenbruch] ✓ PUSHED %s sideways (dir: %.0f, force: %.0f)" % [
					enemy.name, push_direction, SIDEWAYS_PUSH_FORCE
				])

	print("[Wolkenbruch] Sideways push: checked %d enemies, pushed %d" % [checked_count, pushed_count])

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta: float) -> void:
	# CRITICAL: P1-only ability - check inputs every frame via InputManager
	if player and player.name == "Lythrun":
		return  # P2 doesn't use Wolkenbruch

	# Check for charge start/release in IDLE or CHARGING states
	if not is_auto_releasing:
		if not InputManager:
			return  # Can't check input without InputManager

		# Down check: Use p1_wolkenbruch action (handles both keyboard and controller)
		var down_pressed = InputManager.is_p1_action_pressed("wolkenbruch")
		var attack_pressed = InputManager.is_p1_action_pressed("attack")

		# Start charging when both are pressed and we're in IDLE
		if down_pressed and attack_pressed and current_state == State.IDLE:
			if not player.is_on_floor():
				_try_start_charge()

		# Release charge when either is released
		if current_state == State.CHARGING:
			if not down_pressed or not attack_pressed:
				_release_charge()

	# State processing
	match current_state:
		State.CHARGING:
			_process_charging(delta)


func _physics_process(delta: float) -> void:
	match current_state:
		State.SLAMMING:
			_process_slamming(delta)
		State.RECOVERY:
			_process_recovery(delta)


func _process_charging(delta: float) -> void:
	"""Processes charging state"""

	# Use REAL time (unaffected by time_scale) for charging progression
	# Otherwise with time_scale = 0.2, it would take 40 real seconds to reach 8 seconds
	var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
	charge_time += real_delta

	# Calculate current charge level (1 level per second)
	var new_level = min(int(charge_time) + 1, CHARGE_LEVELS)

	# Check if leveled up
	if new_level > charge_level:
		charge_level = new_level
		_on_charge_level_up()

	# Auto-release at max charge
	if charge_time >= MAX_CHARGE_TIME:
		print("[Wolkenbruch] MAX CHARGE REACHED - Auto-releasing!")
		is_auto_releasing = true
		_release_charge()

	# Keep player at charging position (hover)
	# Position will be maintained by movement_controller.is_hovering


func _on_charge_level_up() -> void:
	"""Called when charge level increases"""

	print("[Wolkenbruch] Charge Level UP! → Level %d" % charge_level)

	# Update brightness
	_update_brightness()

	# Audio feedback (pitch increases with level)
	var pitch = 1.0 + (charge_level - 1) * 0.1  # 1.0 to 1.7
	AudioManager.play_sfx_at_position("player/wolkenbruch_level_up", player.global_position, 0.2)

	# Emit signal
	wolkenbruch_charge_level_up.emit(charge_level)


func _process_slamming(delta: float) -> void:
	"""Processes slamming phase"""

	# Check if already on floor FIRST
	if player.is_on_floor():
		_on_impact()
		return

	# CRITICAL: Push enemies sideways BEFORE they can cause collision glitch
	_push_enemies_sideways()

	# Apply controlled downward movement
	# Cap velocity to prevent extreme speeds that cause glitching
	player.velocity.y = min(SLAM_VELOCITY, 1800.0)  # Safety cap
	player.velocity.x = 0

	# Store position before move
	var position_before = player.global_position
	print("[Wolkenbruch] Before move_and_slide: pos=(%.1f, %.1f), vel=(%.1f, %.1f)" % [
		position_before.x, position_before.y, player.velocity.x, player.velocity.y
	])

	# MUST call move_and_slide() to apply velocity and check collisions
	player.move_and_slide()

	print("[Wolkenbruch] After move_and_slide: pos=(%.1f, %.1f), vel=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y, player.velocity.x, player.velocity.y
	])

	# CRITICAL: Check for invalid position immediately after move_and_slide
	if is_nan(player.global_position.x) or is_nan(player.global_position.y):
		print("[Wolkenbruch] ERROR: NaN position detected AFTER move_and_slide()!")
		print("[Wolkenbruch] Previous position: (%.1f, %.1f)" % [position_before.x, position_before.y])
		print("[Wolkenbruch] Velocity was: (%.1f, %.1f)" % [player.velocity.x, player.velocity.y])
		# Reset velocity instead of teleporting (prevents glitches)
		player.velocity = Vector2.ZERO
		_complete_wolkenbruch()
		return

	# Safety check: prevent falling through floor
	# If player moved down too far in one frame, emergency stop
	var movement = player.global_position - position_before
	if movement.y > 100.0:  # Moved more than 100 pixels down in one frame
		print("[Wolkenbruch] WARNING: Large movement detected (%.1f), emergency stop!" % movement.y)
		player.velocity = Vector2.ZERO
		_complete_wolkenbruch()
		return


func _process_recovery(delta: float) -> void:
	"""Processes recovery phase"""

	state_timer -= delta

	# Lock in place
	player.velocity = Vector2.ZERO

	# Safety: Check for NaN position during recovery
	if is_nan(player.global_position.x) or is_nan(player.global_position.y):
		print("[Wolkenbruch] ERROR: NaN detected during recovery!")
		print("[Wolkenbruch] Forcing emergency completion")
		_complete_wolkenbruch()
		return

	if state_timer <= 0.0:
		_complete_wolkenbruch()

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _update_brightness() -> void:
	"""Updates player brightness based on charge level"""

	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Calculate brightness (1.0 to 3.0)
	var brightness_progress = float(charge_level - 1) / float(CHARGE_LEVELS - 1)
	var brightness = lerp(MIN_BRIGHTNESS, MAX_BRIGHTNESS, brightness_progress)

	# Apply glow
	sprite.modulate = Color(brightness, brightness, brightness)

	print("[Wolkenbruch] Brightness: %.2f (Level %d)" % [brightness, charge_level])


func _reset_brightness() -> void:
	"""Resets player brightness to normal"""

	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.WHITE


func _apply_screen_darkening() -> void:
	"""Applies 30% screen darkening overlay"""

	# Don't create duplicate overlays
	if darkening_overlay:
		return

	# Create a fullscreen ColorRect overlay
	darkening_overlay = ColorRect.new()
	darkening_overlay.color = Color(0, 0, 0, 0.3)  # Black with 30% opacity
	darkening_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input

	# Make it fullscreen
	darkening_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	darkening_overlay.z_index = 100  # Draw on top

	# Add to scene tree (to CanvasLayer for proper layering)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer for overlay
	canvas_layer.name = "WolkenbruchDarkeningLayer"
	canvas_layer.add_child(darkening_overlay)
	get_tree().root.add_child(canvas_layer)

	print("[Wolkenbruch] Screen darkened by 30%")


func _remove_screen_darkening() -> void:
	"""Removes screen darkening overlay"""

	if not darkening_overlay:
		return

	# Remove the CanvasLayer parent (which contains the ColorRect)
	var canvas_layer = darkening_overlay.get_parent()
	if canvas_layer:
		canvas_layer.queue_free()

	darkening_overlay = null

	print("[Wolkenbruch] Screen darkening removed")

# ============================================================================
# IMPACT
# ============================================================================

func _on_impact() -> void:
	"""Called when slam hits ground"""

	print("[Wolkenbruch] _on_impact called, pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	# Calculate stats based on charge level
	var damage = charge_level * BASE_DAMAGE_PER_LEVEL

	# Apply Urgathons Erbe ability damage bonus
	if UpgradeManager and UpgradeManager.get_ability_damage_multiplier() > 1.0:
		damage = int(damage * UpgradeManager.get_ability_damage_multiplier())

	var knockback = charge_level * BASE_KNOCKBACK_PER_LEVEL
	var radius = charge_level * BASE_RADIUS_PER_LEVEL
	var trauma = charge_level * CAMERA_TRAUMA_PER_LEVEL

	# Play SFX
	AudioManager.play_sfx("ability_wolkenbruch", 0.2)

	print("[Wolkenbruch] IMPACT! Level %d → Damage: %d, Radius: %.0f, Knockback: %.0f" % [
		charge_level, damage, radius, knockback
	])

	# Enter recovery
	current_state = State.RECOVERY
	state_timer = RECOVERY_DURATION

	# Apply AoE effects
	_apply_aoe_damage(damage, radius)

	print("[Wolkenbruch] After damage, pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	_apply_aoe_knockback(knockback, radius)

	print("[Wolkenbruch] After knockback, pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	# Visual effects
	_spawn_impact_effects(radius)

	# Audio
	AudioManager.play_sfx_at_position("player/wolkenbruch_impact_full", player.global_position, 0.0)

	# Camera shake
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(trauma)

	# Hitstop (stronger with higher charge)
	var hitstop_duration = 0.1 + (charge_level * 0.05)
	GlobalTimeEffects.hit_stop(hitstop_duration)

	print("[Wolkenbruch] After hitstop, pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	# Emit signal
	wolkenbruch_impact.emit(charge_level, damage)
	EventBus.wolkenbruch_impact.emit(true)  # powered = true


# ============================================================================
# AOE EFFECTS
# ============================================================================

func _apply_aoe_damage(damage: int, radius: float) -> void:
	"""Applies AoE damage to enemies in radius"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	for enemy in enemies:
		# CRITICAL: Don't hit yourself! (COMMIT 023.9.1)
		if enemy == player:
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= radius:
			# Apply damage (COMMIT 023.9.10: Use HurtboxComponent to respect invulnerability!)
			# PRIORITY 1: Use HurtboxComponent (respects invulnerability/block!)
			if enemy.has_node("HurtboxComponent"):
				var hurtbox = enemy.get_node("HurtboxComponent")
				if hurtbox and hurtbox.has_method("take_damage"):
					var success = hurtbox.take_damage(damage, Vector2.ZERO, 0.1, player)
					if success:
						hit_count += 1
			# FALLBACK: HealthComponent (old enemies)
			elif enemy.has_node("HealthComponent"):
				var health = enemy.get_node("HealthComponent")
				if health.has_method("take_damage"):
					health.take_damage(damage)
					hit_count += 1

	print("[Wolkenbruch] Hit %d enemies for %d damage each" % [hit_count, damage])


func _apply_aoe_knockback(knockback_force: float, radius: float) -> void:
	"""Applies radial knockback to enemies"""

	var enemies = get_tree().get_nodes_in_group("enemies")
	var stuck_enemies = []  # Track enemies that might be stuck at walls

	for enemy in enemies:
		# CRITICAL: Don't knockback yourself! (COMMIT 023.9.1)
		if enemy == player:
			continue

		var distance = player.global_position.distance_to(enemy.global_position)

		if distance <= radius:
			# Store position BEFORE knockback to check if enemy gets stuck
			var position_before = enemy.global_position

			# Calculate radial direction (away from impact)
			var direction_to_enemy = enemy.global_position - player.global_position

			# CRITICAL: Prevent NaN from normalizing zero vector
			# If enemy is at exact same position, use default direction
			var radial_direction: Vector2
			if direction_to_enemy.length_squared() < 0.01:  # Too close (within 0.1 pixels)
				radial_direction = Vector2(1, 0)  # Default to right
				print("[Wolkenbruch] WARNING: Enemy at same position, using default direction")
			else:
				radial_direction = direction_to_enemy.normalized()

			# Create knockback direction: slam enemies DOWN and AWAY
			var direction = Vector2(radial_direction.x, abs(radial_direction.y) + 0.6).normalized()

			# Apply knockback
			if enemy.has_node("KnockbackComponent"):
				var kb = enemy.get_node("KnockbackComponent")
				kb.apply_knockback(direction, knockback_force, 0.5)
			elif enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction, knockback_force, 0.5)

			# Track enemy for stuck check
			stuck_enemies.append({
				"enemy": enemy,
				"position_before": position_before
			})

	# CRITICAL: Kill enemies that are stuck at walls to prevent glitches
	_check_and_kill_stuck_enemies(stuck_enemies)


func _check_and_kill_stuck_enemies(tracked_enemies: Array) -> void:
	"""Checks if enemies moved after knockback, kills them if stuck at walls"""

	# Wait a brief moment for knockback to take effect
	await get_tree().create_timer(0.15).timeout

	for data in tracked_enemies:
		var enemy = data["enemy"]
		var position_before = data["position_before"]

		# Safety check: enemy might have died already
		if not is_instance_valid(enemy):
			continue

		# Check if enemy position changed significantly
		var position_after = enemy.global_position
		var movement = position_after.distance_to(position_before)

		# If enemy barely moved (< 10 pixels), they're stuck at a wall
		if movement < 10.0:
			print("[Wolkenbruch] CRITICAL: Enemy %s stuck at wall (moved %.1fpx), killing to prevent glitch" % [enemy.name, movement])

			# Instant kill to prevent physics glitches
			if enemy.has_method("take_damage"):
				enemy.take_damage(9999, player)  # Overkill damage
			elif enemy.has_node("HealthComponent"):
				var health = enemy.get_node("HealthComponent")
				if health.has_method("take_damage"):
					health.take_damage(9999)


func _spawn_impact_effects(radius: float) -> void:
	"""Spawns impact VFX scaled to charge level"""

	# Crater effect - always spawn
	var crater_scene_path = "res://vfx/particles/wolkenbruch_crater_full.tscn"

	if ResourceLoader.exists(crater_scene_path):
		var crater_scene = load(crater_scene_path)
		if crater_scene:
			var crater = crater_scene.instantiate()
			get_tree().root.add_child(crater)
			crater.global_position = player.global_position

			# Scale based on radius
			var scale_factor = radius / 200.0  # 200 is base radius
			crater.scale = Vector2(scale_factor, scale_factor)

			if crater.has_method("emit_particles"):
				crater.emit_particles()
			elif crater.has_property("emitting"):
				crater.emitting = true

	# Shockwave ring - always spawn, scaled by charge level
	_spawn_shockwave(radius)


func _spawn_shockwave(radius: float) -> void:
	"""Spawns expanding shockwave ring"""

	var shockwave_scene_path = "res://vfx/particles/wolkenbruch_shockwave.tscn"

	if not ResourceLoader.exists(shockwave_scene_path):
		return

	var shockwave_scene = load(shockwave_scene_path)
	var shockwave = shockwave_scene.instantiate()

	get_tree().root.add_child(shockwave)
	shockwave.global_position = player.global_position

	# Animate expansion (scale based on radius)
	var max_scale = radius / 100.0  # Larger radius = larger shockwave
	var tween = create_tween()
	tween.tween_property(shockwave, "scale", Vector2(max_scale, max_scale), 0.5)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.3)

	await tween.finished
	shockwave.queue_free()

# ============================================================================
# COMPLETION
# ============================================================================

func _complete_wolkenbruch() -> void:
	"""Completes Wolkenbruch"""

	print("[Wolkenbruch] _complete_wolkenbruch called, pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	current_state = State.IDLE
	charge_time = 0.0
	charge_level = 0
	is_auto_releasing = false  # Reset auto-release flag

	# Safety: Ensure time scale is restored
	Engine.time_scale = 1.0

	# Safety: Ensure darkening is removed
	_remove_screen_darkening()

	# Safety: Reset velocity to prevent lingering movement
	player.velocity = Vector2.ZERO

	# Safety: Ensure player position is valid (not NaN or extreme values)
	if is_nan(player.global_position.x) or is_nan(player.global_position.y):
		print("[Wolkenbruch] CRITICAL ERROR: NaN position detected in _complete_wolkenbruch!")
		print("[Wolkenbruch] Attempting to restore to safe position...")
		# Reset velocity
		player.velocity = Vector2.ZERO
		# Find a safe ground position (raycast downward from center of arena)
		var safe_pos = Vector2(0, 300)  # Center of arena, near ground
		player.global_position = safe_pos
		print("[Wolkenbruch] Position restored to: ", safe_pos)

	# Safety: Disable hover mode if still active
	if movement_controller and movement_controller.is_hovering:
		movement_controller.is_hovering = false
		print("[Wolkenbruch] Force-disabled lingering hover mode")

	print("[Wolkenbruch] Completed at pos=(%.1f, %.1f)" % [
		player.global_position.x, player.global_position.y
	])

	wolkenbruch_completed.emit()
	EventBus.wolkenbruch_completed.emit()

# ============================================================================
# UTILITY
# ============================================================================

func is_active() -> bool:
	"""Returns true if Wolkenbruch is active"""
	return current_state in [State.CHARGING, State.SLAMMING, State.RECOVERY]


func is_charging() -> bool:
	"""Returns true if currently charging"""
	return current_state == State.CHARGING


func get_charge_level() -> int:
	"""Returns current charge level (1-8)"""
	return charge_level


func get_charge_progress() -> float:
	"""Returns charge progress (0.0-1.0)"""
	return charge_time / MAX_CHARGE_TIME


func can_activate() -> bool:
	"""Returns true if can activate"""
	return current_state == State.IDLE and not player.is_on_floor() and not ability_disabled
