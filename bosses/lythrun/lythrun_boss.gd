extends BaseBoss
## Lythrun Boss - The Forgotten One
## Secret boss with adaptive AI and HP scaling based on revive items

# ============================================================================
# CONSTANTS
# ============================================================================

const BASE_HP: float = 2500.0
const HP_PER_REVIVE_ITEM: float = 750.0

const REVIVE_ITEM_IDS: Array[String] = ["funken_gnade", "core_reconstructor", "traene_erwachens"]

# ============================================================================
# CHARGE COLORS (Visual feedback during attack wind-up)
# ============================================================================

const CHARGE_COLOR_SLAM: Color = Color(1.0, 0.3, 0.0)      # Orange-red for slam
const CHARGE_COLOR_DASH: Color = Color(0.5, 0.0, 0.8)      # Dark purple for dash
const CHARGE_COLOR_CAST: Color = Color(0.0, 0.5, 1.0)      # Blue for casting
const CHARGE_COLOR_AOE: Color = Color(1.0, 0.0, 0.0)       # Red for desperation
const CHARGE_COLOR_TELEPORT: Color = Color(0.3, 0.0, 0.5)  # Deep purple for teleport

# ============================================================================
# DIALOG PORTRAITS
# ============================================================================
const LYTHRUN_PORTRAIT := "res://Assets/AIPlaceholder/Char/Lythrun/lythrunVBossSprite.png"
const MURUM_PORTRAIT := "res://Assets/AIPlaceholder/Char/Murum/Murum.png"

# ============================================================================
# SIGNALS
# ============================================================================
signal dialog_sequence_finished

# ============================================================================
# STATE
# ============================================================================

var extra_lives: int = 0
var current_life: int = 0
var player_target: CharacterBody2D = null
var is_charging: bool = false  # Track if currently charging an attack
var is_hovering: bool = false  # Phase 2+: Boss floats like ghost enemy
var current_phase: int = 1     # Track current phase for movement logic
var hover_height: float = 0.0  # Oscillation for hover effect
var hover_time: float = 0.0    # Timer for hover oscillation
var gap_closer_cooldown: float = 0.0  # Cooldown for gap-closer dashes
var _wave_spawner: BossWaveSpawner = null
const GAP_CLOSER_DISTANCE: float = 350.0  # Distance to trigger gap closer
const GAP_CLOSER_COOLDOWN_TIME: float = 3.0  # Cooldown between gap closes

# Boss distance preferences - NEVER stand on top of player!
const PREFERRED_DISTANCE: float = 180.0  # Preferred distance from player
const MIN_DISTANCE: float = 120.0  # NEVER get closer than this
const MAX_DISTANCE: float = 250.0  # Start approaching if beyond this

# ============================================================================
# SCYTHE (Sense) STATE
# ============================================================================
var scythe_sprite: Sprite2D = null
var _scythe_base_rotation: float = 0.0
var _scythe_base_position: Vector2 = Vector2.ZERO
var _scythe_thrown: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Set boss-specific stats
	boss_name = "Lythrun, der Vergessene"
	gold_reward = 750
	unlock_flag = "lythrun_defeated"

	# Calculate HP scaling
	_calculate_scaled_hp()

	# Calculate extra lives
	_calculate_extra_lives()

	# Setup attack patterns
	_setup_attack_patterns()

	# Find player
	_find_player()

	# Get scythe sprite reference
	scythe_sprite = get_node_or_null("SenseSprite") as Sprite2D
	if scythe_sprite:
		_scythe_base_rotation = scythe_sprite.rotation
		_scythe_base_position = scythe_sprite.position
		print("[Lythrun] Scythe sprite found")

	# Call parent ready
	super._ready()


func _calculate_scaled_hp() -> void:
	"""Calculates boss HP based on owned revive items"""

	var revive_items_owned = _count_revive_items()

	max_health = BASE_HP + (revive_items_owned * HP_PER_REVIVE_ITEM)

	print("[Lythrun] HP Scaling: %d (Base: %d + %d from %d revive items)" % [
		max_health, BASE_HP, revive_items_owned * HP_PER_REVIVE_ITEM, revive_items_owned
	])


func _count_revive_items() -> int:
	"""Counts how many revive items the player owns"""

	var count = 0

	for item_id in REVIVE_ITEM_IDS:
		if InventoryManager.has_item(item_id):
			count += 1

	return count


func _calculate_extra_lives() -> void:
	"""Calculates extra lives based on owned revive items"""

	extra_lives = _count_revive_items()
	current_life = 0

	print("[Lythrun] Extra Lives: %d" % extra_lives)


func _setup_attack_patterns() -> void:
	"""Sets up attack patterns for each phase"""

	# Phase 1 (100%-75%): Sense-Angriffe + Fernkampf
	phase_1_pattern = [
		"scythe_combo",
		"teleport_strike",
		"void_orbs",
		"scythe_combo",
		"scythe_throw",
		"shadow_dash"
	]

	# Phase 2 (75%-50%): Mehr Teleport, AoE, aggressiver
	phase_2_pattern = [
		"scythe_combo",
		"teleport_strike",
		"void_orbs",
		"ground_aoe",
		"scythe_throw",
		"shadow_dash",
		"teleport_strike",
		"void_orbs_spread"
	]

	# Phase 3 (50%-25%): Alles kombiniert, maximaler Druck
	phase_3_pattern = [
		"scythe_combo",
		"ground_aoe",
		"teleport_barrage",
		"scythe_throw",
		"void_orbs_spread",
		"ground_aoe",
		"shadow_dash_multi",
		"desperation_aoe"
	]


# Added: Connect adaptive AI to phase changes
func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	"""Override to add adaptive AI integration and hover mode"""
	super._on_phase_changed(old_phase, new_phase)

	current_phase = new_phase

	# Phase-specific music
	if new_phase == 2 and MusicScenePlayer:
		MusicScenePlayer.force_play_scene("LythrunBossP2")
	elif new_phase == 3 and MusicScenePlayer:
		MusicScenePlayer.force_play_scene("LythrunBossP3")

	# Phase 2+: Activate hover mode (boss floats like ghost enemy)
	if new_phase >= 2 and not is_hovering:
		is_hovering = true
		print("[Lythrun] Phase %d: Hover mode ACTIVATED - Boss now floats!" % new_phase)

		# Visual effect: Boss rises slightly and glows
		if sprite:
			var rise_tween = create_tween()
			rise_tween.tween_property(self, "global_position:y", global_position.y - 30, 0.5)

			# Purple glow for hovering phase
			sprite.modulate = Color(0.8, 0.6, 1.0)  # Light purple tint

	# Notify adaptive AI
	var ai = get_adaptive_ai()
	if ai and ai.has_method("on_phase_changed"):
		ai.on_phase_changed(new_phase)


func _find_player() -> void:
	"""Finds and sets the player target"""

	player_target = get_player()

	if not player_target:
		push_error("[Lythrun] No player found!")


# Override physics to add hover movement in Phase 2+
func _physics_process(delta: float) -> void:
	"""Custom physics: Hover in Phase 2+, normal gravity in Phase 1"""

	# CRITICAL: Check for NaN position
	if is_nan(global_position.x) or is_nan(global_position.y):
		print("[Lythrun] CRITICAL: NaN position detected!")
		global_position = Vector2(0, 300)
		velocity = Vector2.ZERO
		return

	# Update gap closer cooldown
	if gap_closer_cooldown > 0:
		gap_closer_cooldown -= delta

	if is_hovering:
		# PHASE 2+: Hover movement (like ghost enemy)
		_process_hover_movement(delta)
	else:
		# PHASE 1: Normal ground movement with gravity
		if not is_on_floor():
			velocity.y += 980.0 * delta

		# Move toward/away from player based on distance - NEVER stand on player!
		if not is_charging and is_active and player_target and is_instance_valid(player_target):
			var distance = global_position.distance_to(player_target.global_position)
			var direction = (player_target.global_position - global_position).normalized()

			# GAP CLOSER: Use shadow_dash when far from player
			if distance > GAP_CLOSER_DISTANCE and gap_closer_cooldown <= 0:
				print("[Lythrun] Gap closer triggered! Distance: %.0f" % distance)
				_perform_gap_closer_dash()
			elif distance < MIN_DISTANCE:
				# TOO CLOSE! Move away from player
				velocity.x = -direction.x * movement_speed * 1.5
			elif distance > MAX_DISTANCE:
				# Too far, approach player
				velocity.x = direction.x * movement_speed
			else:
				# Good distance - stop or strafe
				velocity.x = 0

		move_and_slide()


func _process_hover_movement(delta: float) -> void:
	"""Hover movement for Phase 2+ - Boss floats BESIDE player, not on top!"""

	# Update hover oscillation
	hover_time += delta * 2.0  # Oscillation speed
	hover_height = sin(hover_time) * 8.0  # ±8 pixels oscillation

	# Move toward/away from player - NEVER hover directly on top!
	if is_active and player_target and is_instance_valid(player_target) and not is_charging:
		var target_pos = player_target.global_position
		var distance = global_position.distance_to(target_pos)
		var direction = (target_pos - global_position).normalized()

		# GAP CLOSER: Use shadow_dash when far from player (also in hover mode)
		if distance > GAP_CLOSER_DISTANCE and gap_closer_cooldown <= 0:
			print("[Lythrun] Hover gap closer triggered! Distance: %.0f" % distance)
			_perform_gap_closer_dash()
		elif distance < MIN_DISTANCE:
			# TOO CLOSE! Move away from player
			var hover_speed = movement_speed * 1.5
			velocity.x = -direction.x * hover_speed

			# Stay at same height level as player (not above)
			var target_y = target_pos.y - 30  # Slight float, not directly on
			var y_diff = target_y - global_position.y
			velocity.y = y_diff * 2.0 + hover_height * 20.0
		elif distance > MAX_DISTANCE:
			# Too far, approach player
			var hover_speed = movement_speed * 1.5
			velocity.x = direction.x * hover_speed

			# Move to same level
			var target_y = target_pos.y - 30
			var y_diff = target_y - global_position.y
			velocity.y = y_diff * 2.0 + hover_height * 20.0
		else:
			# Good distance - hover in place beside player
			velocity.x = 0

			# Stay beside player, not above
			var target_y = target_pos.y - 30
			var y_diff = target_y - global_position.y
			velocity.y = y_diff * 1.0 + hover_height * 20.0
	else:
		# Not active or charging - maintain hover
		velocity.x = 0
		velocity.y = hover_height * 20.0

	move_and_slide()


func _perform_gap_closer_dash() -> void:
	"""Performs a quick shadow dash toward player - stops at PREFERRED_DISTANCE"""
	gap_closer_cooldown = GAP_CLOSER_COOLDOWN_TIME

	# Don't interrupt if already attacking
	if is_charging:
		return

	# Quick gap closer - faster than normal attack version
	print("[Lythrun] Performing gap closer shadow dash!")

	if not player_target or not is_instance_valid(player_target):
		return

	# Face player
	face_player()

	# Calculate dash direction toward player, but stop at preferred distance
	var target_pos = player_target.global_position
	var dash_direction = (target_pos - global_position).normalized()
	var distance = global_position.distance_to(target_pos)

	# Calculate dash distance - stop at PREFERRED_DISTANCE from player
	var dash_distance = max(0, distance - PREFERRED_DISTANCE)

	# Quick charge visual (shorter than attack)
	is_charging = true
	if sprite:
		sprite.modulate = CHARGE_COLOR_DASH

	# Very brief charge for gap closer (0.2s instead of 0.5s)
	await get_tree().create_timer(0.2).timeout

	if sprite:
		sprite.modulate = Color(1.5, 1.0, 1.5)  # Bright purple-white during dash

	# Fast dash toward player (but stop at preferred distance)
	var dash_speed = 1000.0
	var dash_duration = min(dash_distance / dash_speed, 0.3)  # Cap duration
	var elapsed = 0.0

	# Spawn dash hitbox (deals damage while dashing)
	var dash_hitbox = _spawn_dash_hitbox()

	while elapsed < dash_duration:
		# Re-check distance to player to avoid overshooting
		var current_distance = global_position.distance_to(player_target.global_position)
		if current_distance <= PREFERRED_DISTANCE:
			break  # Reached preferred distance

		velocity = dash_direction * dash_speed
		move_and_slide()
		elapsed += get_process_delta_time()
		await get_tree().process_frame

	if dash_hitbox and is_instance_valid(dash_hitbox):
		dash_hitbox.queue_free()

	velocity = Vector2.ZERO
	is_charging = false

	# Reset color
	if sprite:
		if is_hovering:
			sprite.modulate = Color(0.8, 0.6, 1.0)  # Back to hover purple
		else:
			sprite.modulate = Color.WHITE


# Override start_fight for dramatic intro sequence
func start_fight() -> void:
	"""Starts the boss fight with full intro cutscene"""
	# Set faster attack cooldown
	if attack_manager:
		attack_manager.attack_cooldown = 0.8

	is_active = true
	fight_started.emit()

	# Make invulnerable during intro
	if health_component:
		health_component.set_invulnerable(true)

	# Activate camera
	if camera_controller:
		camera_controller.activate()

	# --- INTRO SEQUENCE ---
	await _play_intro_sequence()

	# Show health bar (after intro)
	if health_bar:
		health_bar.show_bar()

	# Make vulnerable
	if health_component:
		health_component.set_invulnerable(false)

	# Activate attacks
	if attack_manager:
		attack_manager.set_pattern(phase_1_pattern)
		attack_manager.activate()

	# Phase 1 music
	if MusicScenePlayer:
		MusicScenePlayer.force_play_scene("LythrunBossP1")

	# Start enemy wave spawner
	_wave_spawner = BossWaveSpawner.new()
	_wave_spawner.name = "BossWaveSpawner"
	add_child(_wave_spawner)
	_wave_spawner.start_spawning()

	print("[Lythrun] Fight started with attack_cooldown: ", attack_manager.attack_cooldown if attack_manager else "N/A")


func _play_intro_sequence() -> void:
	"""Dramatic intro — boss materializes from darkness, dialog, then fight."""
	# Boss starts invisible
	modulate = Color(0.0, 0.0, 0.0, 0.0)

	await get_tree().create_timer(0.5).timeout

	# Spawn dark energy particles at boss position
	var intro_vfx := GPUParticles2D.new()
	intro_vfx.amount = 40
	intro_vfx.lifetime = 1.5
	intro_vfx.one_shot = true
	intro_vfx.explosiveness = 0.4

	var intro_mat := ParticleProcessMaterial.new()
	intro_mat.particle_flag_disable_z = true
	intro_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	intro_mat.emission_sphere_radius = 50.0
	intro_mat.direction = Vector3(0, -1, 0)
	intro_mat.spread = 180.0
	intro_mat.gravity = Vector3(0, -60, 0)
	intro_mat.initial_velocity_min = 20.0
	intro_mat.initial_velocity_max = 60.0
	intro_mat.scale_min = 2.0
	intro_mat.scale_max = 5.0
	intro_mat.color = Color(0.4, 0.1, 0.7, 0.8)
	intro_vfx.process_material = intro_mat
	intro_vfx.position = Vector2.ZERO
	add_child(intro_vfx)

	# Auto-free VFX
	var vfx_timer := Timer.new()
	vfx_timer.wait_time = 3.0
	vfx_timer.one_shot = true
	vfx_timer.timeout.connect(intro_vfx.queue_free)
	intro_vfx.add_child(vfx_timer)
	vfx_timer.start()

	# Materialize — fade in with purple tint
	var materialize := create_tween()
	materialize.tween_property(self, "modulate", Color(0.5, 0.2, 0.8, 1.0), 1.0).set_ease(Tween.EASE_OUT)
	await materialize.finished

	# Flash white → settle to normal
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(2.0, 1.8, 2.5, 1.0), 0.15)
	flash.tween_property(self, "modulate", Color.WHITE, 0.4)
	await flash.finished

	# Camera shake on arrival
	if camera_controller:
		camera_controller.shake(8.0, 0.5)

	# Scythe glow
	if scythe_sprite:
		_glow_scythe(Color(0.5, 0.0, 1.0), 0.5)

	await get_tree().create_timer(0.3).timeout

	# Play idle animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

	# Intro dialog
	var entries: Array[DialogEntry] = [
		_make_dialog_entry("Lythrun", LYTHRUN_PORTRAIT, "Du hast mich gefunden. Das Vergessen hat mich nicht schuetzen koennen."),
		_make_dialog_entry("Murum", MURUM_PORTRAIT, "Dann kaempfe. Zeig mir, was das Vergessen uebrig gelassen hat."),
	]
	await _play_dialog(entries, "lythrun_intro")

	await get_tree().create_timer(0.5).timeout


# ============================================================================
# CHARGE EFFECT HELPERS
# ============================================================================

func _start_charge_effect(charge_color: Color, duration: float) -> void:
	"""Starts visual charge effect - colors boss and pulses"""
	is_charging = true
	if sprite:
		# Create pulsing tween effect
		var tween = create_tween()
		tween.set_loops(int(duration / 0.2))  # Pulse every 0.2s
		tween.tween_property(sprite, "modulate", charge_color * 1.5, 0.1)
		tween.tween_property(sprite, "modulate", charge_color, 0.1)


func _end_charge_effect() -> void:
	"""Ends visual charge effect - resets color"""
	is_charging = false
	if sprite:
		sprite.modulate = Color.WHITE


func _move_toward_player(move_speed: float = 300.0) -> void:
	"""Actively moves toward player - used between attacks"""
	if not player_target or not is_instance_valid(player_target):
		return

	var direction = (player_target.global_position - global_position).normalized()
	var distance = global_position.distance_to(player_target.global_position)

	# Only move if not too close
	if distance > 100.0:
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO


# ============================================================================
# EXTRA LIVES SYSTEM
# ============================================================================

func _on_defeated() -> void:
	"""Override: Check for extra lives before defeat"""

	if current_life < extra_lives:
		# Revive instead of defeat
		_perform_revive()
	else:
		# Stop wave spawner
		if _wave_spawner:
			_wave_spawner.stop_and_clear()
		# True defeat
		super._on_defeated()


func _perform_revive() -> void:
	"""Revives the boss with partial HP"""

	current_life += 1

	print("[Lythrun] Revive %d/%d" % [current_life, extra_lives])

	# Stop all attacks
	if attack_manager:
		attack_manager.interrupt_attack()

	set_invulnerable(true)

	# Play revive animation
	_play_revive_animation()

	# Restore HP based on item
	var heal_percent = _get_revive_heal_percent(current_life)
	if health_component:
		health_component.current_hp = max_health * heal_percent

	if health_bar:
		health_bar.update_health(health_component.current_hp, max_health)

	# Camera shake
	if camera_controller:
		camera_controller.shake(15.0, 1.0)

	await get_tree().create_timer(2.0).timeout

	# Reset to phase 1
	if phase_manager:
		phase_manager.current_phase = 1

	if attack_manager:
		attack_manager.set_pattern(phase_1_pattern)

	set_invulnerable(false)

	# Notification
	EventBus.show_notification.emit("Lythrun rises again! (%d/%d)" % [current_life, extra_lives], 3.0)


func _play_revive_animation() -> void:
	"""Plays revive animation — hitstop + glow pulse + golden particles."""

	# Hitstop for dramatic effect
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(0.3)

	# Spawn revive VFX
	_spawn_revive_vfx()

	# Power-up glow: dark → gold → white → normal
	if sprite:
		var glow := create_tween()
		glow.tween_property(sprite, "modulate", Color(0.2, 0.1, 0.3, 1.0), 0.2)
		glow.tween_property(sprite, "modulate", Color(1.5, 1.2, 0.5, 1.0), 0.3)
		glow.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
		glow.tween_property(sprite, "modulate", Color.WHITE, 0.4)
		await glow.finished


func _spawn_revive_vfx() -> void:
	"""Spawns revive VFX"""

	var vfx_path = "res://vfx/boss/lythrun_revive.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Lythrun] Revive VFX not found")
		return

	var vfx_scene = load(vfx_path)
	var vfx = vfx_scene.instantiate()
	add_child(vfx)

	if vfx is GPUParticles2D:
		vfx.emitting = true

	# Play SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("lythrun_revive")


func _get_revive_heal_percent(life_number: int) -> float:
	"""Returns heal percentage for revive based on item type"""

	var owned_items = []

	if InventoryManager.has_item("funken_gnade"):
		owned_items.append(0.25)  # 25% HP

	if InventoryManager.has_item("core_reconstructor"):
		owned_items.append(0.20)  # 20% HP

	if InventoryManager.has_item("traene_erwachens"):
		owned_items.append(0.50)  # 50% HP

	if life_number <= owned_items.size():
		return owned_items[life_number - 1]

	return 0.25  # Fallback


# ============================================================================
# PLAYER TARGET
# ============================================================================

func set_player_target(target: CharacterBody2D) -> void:
	"""Sets the player target for attacks"""
	player_target = target


# ============================================================================
# ATTACK EXECUTION
# ============================================================================

func execute_attack(attack_name: String) -> void:
	"""Executes Lythrun's attacks"""

	match attack_name:
		"staff_slam":
			await perform_staff_slam()
		"shadow_dash":
			await perform_shadow_dash()
		"void_orbs":
			await perform_void_orbs()
		"staff_slam_combo":
			await perform_staff_slam_combo()
		"teleport_strike":
			await perform_teleport_strike()
		"void_orbs_spread":
			await perform_void_orbs_spread()
		"teleport_barrage":
			await perform_teleport_barrage()
		"shadow_dash_multi":
			await perform_shadow_dash_multi()
		"desperation_aoe":
			await perform_desperation_aoe()
		"scythe_combo":
			await perform_scythe_combo()
		"scythe_throw":
			await perform_scythe_throw()
		"ground_aoe":
			await perform_ground_aoe()
		_:
			print("[Lythrun] Unknown attack: ", attack_name)
			await get_tree().create_timer(1.0).timeout


# ============================================================================
# PHASE 1 ATTACKS (100%-75% HP)
# ============================================================================

func perform_staff_slam() -> void:
	"""Sensen-Slam mit Aufleuchten und AoE"""

	print("[Lythrun] Scythe Slam")

	face_player()

	# Move toward player
	if player_target and is_instance_valid(player_target):
		var target_pos = player_target.global_position
		var distance = global_position.distance_to(target_pos)
		if distance > MIN_DISTANCE + 50:
			var move_direction = (target_pos - global_position).normalized()
			var move_distance = min(distance - MIN_DISTANCE, 200.0)
			global_position = global_position + move_direction * move_distance

	# Sense aufleuchten + Charge
	_glow_scythe(CHARGE_COLOR_SLAM, 0.8)
	_start_charge_effect(CHARGE_COLOR_SLAM, 0.8)
	await get_tree().create_timer(0.8).timeout
	_end_charge_effect()

	# Sense schwingen
	_animate_scythe_swing(1.5, 0.25)

	# Hitbox + AoE
	var impact_pos = global_position + Vector2(0, 60)
	_spawn_slam_hitbox(impact_pos, 100.0, 40.0)
	_spawn_aoe_ring(impact_pos, 140.0, 30.0)

	if camera_controller:
		camera_controller.shake(8.0, 0.3)

	_spawn_shockwave_vfx()

	await get_tree().create_timer(0.3).timeout
	_reset_scythe()


func _spawn_slam_hitbox(pos: Vector2, radius: float, damage: float) -> void:
	"""Spawns a slam hitbox"""

	var hitbox_path = "res://hitboxes/boss_slam_hitbox.tscn"

	if not ResourceLoader.exists(hitbox_path):
		print("[Lythrun] Slam hitbox not found")
		return

	var hitbox_scene = load(hitbox_path)
	var hitbox = hitbox_scene.instantiate()
	get_parent().add_child(hitbox)
	hitbox.global_position = pos

	# Set properties if they exist
	if "damage" in hitbox:
		hitbox.damage = damage
	if "radius" in hitbox:
		hitbox.radius = radius
	if hitbox.has_method("activate"):
		hitbox.activate()


func _spawn_shockwave_vfx() -> void:
	"""Spawns shockwave VFX"""

	var vfx_path = "res://vfx/boss/staff_slam_shockwave.tscn"

	if not ResourceLoader.exists(vfx_path):
		return

	var vfx_scene = load(vfx_path)
	var vfx = vfx_scene.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position + Vector2(0, 60)

	if vfx is GPUParticles2D:
		vfx.emitting = true


func perform_shadow_dash() -> void:
	"""Dash attack towards player with charge-up visual"""

	print("[Lythrun] Shadow Dash")

	if not player_target or not is_instance_valid(player_target):
		await get_tree().create_timer(0.5).timeout
		return

	# Face player
	face_player()

	# Calculate dash direction
	var target_pos = player_target.global_position
	var dash_direction = (target_pos - global_position).normalized()

	# CHARGE PHASE - Visual feedback (pulsing purple, doubled)
	_start_charge_effect(CHARGE_COLOR_DASH, 1.0)

	await get_tree().create_timer(1.0).timeout

	# END CHARGE - Execute dash
	_end_charge_effect()

	# Flash white briefly during dash
	if sprite:
		sprite.modulate = Color(1.5, 1.0, 1.5)  # Bright purple-white

	var dash_speed = 900.0  # Faster dash
	var dash_duration = 0.25
	var elapsed = 0.0

	# Spawn dash hitbox
	var dash_hitbox = _spawn_dash_hitbox()

	while elapsed < dash_duration:
		velocity = dash_direction * dash_speed
		move_and_slide()

		elapsed += get_process_delta_time()
		await get_tree().process_frame

	if dash_hitbox and is_instance_valid(dash_hitbox):
		dash_hitbox.queue_free()

	velocity = Vector2.ZERO

	# Reset color
	if sprite:
		sprite.modulate = Color.WHITE

	await get_tree().create_timer(0.15).timeout


func _spawn_dash_hitbox():
	"""Spawns dash hitbox"""

	var hitbox_path = "res://hitboxes/boss_dash_hitbox.tscn"

	if not ResourceLoader.exists(hitbox_path):
		return null

	var hitbox_scene = load(hitbox_path)
	var hitbox = hitbox_scene.instantiate()
	add_child(hitbox)

	if "damage" in hitbox:
		hitbox.damage = 30

	if hitbox.has_method("activate"):
		hitbox.activate()

	return hitbox


func perform_void_orbs() -> void:
	"""Shoots void orbs at player - count based on current phase (3/6/8)"""

	print("[Lythrun] Void Orbs (Phase %d)" % current_phase)

	# Face player
	face_player()

	# CHARGE PHASE - Blue casting glow (doubled)
	_start_charge_effect(CHARGE_COLOR_CAST, 0.8)

	# Cast animation if available
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("cast"):
		sprite.play("cast")

	await get_tree().create_timer(0.8).timeout

	# END CHARGE
	_end_charge_effect()

	# Orb count based on phase: Phase 1 = 3, Phase 2 = 6, Phase 3 = 8
	var orb_count = 3
	match current_phase:
		2:
			orb_count = 6
		3:
			orb_count = 8

	# Spawn orbs with slight delay between each
	for i in range(orb_count):
		_spawn_void_orb(0.0)
		await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(0.2).timeout


func _spawn_void_orb(delay: float) -> void:
	"""Spawns a void orb projectile"""

	await get_tree().create_timer(delay).timeout

	var orb_path = "res://projectiles/void_orb.tscn"

	if not ResourceLoader.exists(orb_path):
		print("[Lythrun] Void orb not found")
		return

	if not player_target:
		return

	var orb_scene = load(orb_path)
	var orb = orb_scene.instantiate()
	get_parent().add_child(orb)

	# CRITICAL: Set owner for ParryBlockSystem detection
	orb.owner = self

	orb.global_position = global_position + Vector2(0, -30)

	# Set properties
	if "target" in orb:
		orb.target = player_target  # Node2D reference, not Vector2!
	if "damage" in orb:
		orb.damage = 25
	if "speed" in orb:
		orb.speed = 200.0


# ============================================================================
# PHASE 2+ ATTACKS
# ============================================================================

# Get adaptive AI component
func get_adaptive_ai() -> Node:
	return get_node_or_null("AdaptiveAI")


func perform_staff_slam_combo() -> void:
	"""3x Staff Slam combo"""
	for i in range(3):
		await perform_staff_slam()
		await get_tree().create_timer(0.2).timeout


func perform_teleport_strike() -> void:
	"""Teleport behind player and attack with visual feedback"""
	print("[Lythrun] Teleport Strike")

	if not player_target or not is_instance_valid(player_target):
		await get_tree().create_timer(0.5).timeout
		return

	# Sense leuchtet lila auf
	_glow_scythe(CHARGE_COLOR_TELEPORT, 0.4)
	_start_charge_effect(CHARGE_COLOR_TELEPORT, 0.4)

	await get_tree().create_timer(0.4).timeout

	# Verschwinden (schnelles Ausblenden)
	_end_charge_effect()
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
		await tween.finished
	if scythe_sprite:
		scythe_sprite.modulate.a = 0.0

	await get_tree().create_timer(0.15).timeout

	# Hinter Spieler teleportieren
	var player_pos = player_target.global_position
	var behind_offset = Vector2(-100, 0) if player_target.global_position.x > global_position.x else Vector2(100, 0)
	global_position = player_pos + behind_offset

	# Erscheinen mit Flash
	if sprite:
		sprite.modulate = Color(1.5, 0.5, 1.5, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if scythe_sprite:
		scythe_sprite.modulate = Color(1.0, 0.6, 1.0, 1.0)

	await get_tree().create_timer(0.1).timeout

	# Sofort Sensen-Schlag
	await perform_staff_slam()


func perform_void_orbs_spread() -> void:
	"""Shoots void orbs in all directions with charge-up"""
	print("[Lythrun] Void Orbs Spread")

	# CHARGE PHASE - Blue glow (doubled)
	_start_charge_effect(CHARGE_COLOR_CAST, 0.8)

	await get_tree().create_timer(0.8).timeout

	# END CHARGE
	_end_charge_effect()

	# Flash on release
	if sprite:
		sprite.modulate = Color(0.5, 1.0, 1.5)  # Bright blue

	# 8 orbs in circle - spawn all at once
	var orb_count = 8
	var angle_step = TAU / orb_count

	for i in range(orb_count):
		var angle = i * angle_step
		var direction = Vector2(cos(angle), sin(angle))
		_spawn_void_orb_directional(direction)

	# Reset color
	if sprite:
		sprite.modulate = Color.WHITE

	await get_tree().create_timer(0.4).timeout


func _spawn_void_orb_directional(direction: Vector2) -> void:
	"""Spawns void orb in specific direction"""
	var orb_path = "res://projectiles/void_orb.tscn"

	if not ResourceLoader.exists(orb_path):
		return

	var orb_scene = load(orb_path)
	var orb = orb_scene.instantiate()
	get_parent().add_child(orb)

	# CRITICAL: Set owner for ParryBlockSystem detection
	orb.owner = self

	orb.global_position = global_position + Vector2(0, -30)

	# Set direction instead of target
	if "velocity" in orb:
		orb.velocity = direction * 250.0
	if "damage" in orb:
		orb.damage = 30


func perform_teleport_barrage() -> void:
	"""4-Hit Combo: Teleport + 4 rapid slams with 0.5s charge each"""
	print("[Lythrun] Teleport Barrage - 4 Hit Combo")

	if not player_target or not is_instance_valid(player_target):
		await get_tree().create_timer(0.5).timeout
		return

	# Initial teleport behind player (doubled)
	_start_charge_effect(CHARGE_COLOR_TELEPORT, 0.6)
	await get_tree().create_timer(0.6).timeout
	_end_charge_effect()

	# Vanish
	if sprite:
		sprite.modulate.a = 0.0
	await get_tree().create_timer(0.1).timeout

	# Teleport to player
	var player_pos = player_target.global_position
	var behind_offset = Vector2(-80, 0) if player_target.global_position.x > global_position.x else Vector2(80, 0)
	global_position = player_pos + behind_offset

	# Appear
	if sprite:
		sprite.modulate = Color(1.5, 0.5, 1.5, 1.0)

	# 4 rapid hits with 1.0s charge each (doubled)
	for i in range(4):
		# Charge for hit
		_start_charge_effect(CHARGE_COLOR_SLAM, 1.0)
		await get_tree().create_timer(1.0).timeout
		_end_charge_effect()

		# Execute hit
		face_player()
		var impact_pos = global_position + Vector2(0, 60)
		_spawn_slam_hitbox(impact_pos, 80.0, 30.0)

		# Small camera shake per hit
		if camera_controller:
			camera_controller.shake(5.0, 0.15)

		await get_tree().create_timer(0.15).timeout

	# Reset color
	if sprite:
		sprite.modulate = Color.WHITE


func perform_shadow_dash_multi() -> void:
	"""3x shadow dashes followed by massive AoE explosion"""
	print("[Lythrun] Shadow Dash Multi + AoE Finisher")

	# 3 dashes
	for i in range(3):
		await perform_shadow_dash()
		await get_tree().create_timer(0.15).timeout

	# After dashes: BIG AoE explosion as finisher
	print("[Lythrun] Shadow Dash Multi - AoE Finisher!")

	# Charge for AoE (doubled)
	_start_charge_effect(CHARGE_COLOR_AOE, 1.2)
	if camera_controller:
		camera_controller.shake(8.0, 1.2)
	await get_tree().create_timer(1.2).timeout
	_end_charge_effect()

	# Spawn large AoE
	_spawn_aoe_ring(global_position, 200.0, 50.0)  # 200 radius, 50 damage

	# Big camera shake
	if camera_controller:
		camera_controller.shake(15.0, 0.5)

	# Flash
	if sprite:
		sprite.modulate = Color.WHITE * 2.0
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = Color.WHITE

	await get_tree().create_timer(0.3).timeout


func perform_desperation_aoe() -> void:
	"""Massive AoE explosion with dramatic charge-up"""
	print("[Lythrun] Desperation AOE")

	# DRAMATIC CHARGE PHASE - Long red glow with camera shake buildup (doubled)
	_start_charge_effect(CHARGE_COLOR_AOE, 2.4)

	# Camera shake building during charge
	if camera_controller:
		camera_controller.shake(5.0, 1.0)

	await get_tree().create_timer(1.2).timeout

	# Intensify charge
	if sprite:
		sprite.modulate = CHARGE_COLOR_AOE * 2.0

	if camera_controller:
		camera_controller.shake(10.0, 1.2)

	await get_tree().create_timer(1.2).timeout

	# END CHARGE - EXPLOSION
	_end_charge_effect()

	# Flash white on explosion
	if sprite:
		sprite.modulate = Color.WHITE * 2.0

	# Spawn large AoE
	var aoe_radius = 300.0
	var ai = get_adaptive_ai()
	if ai and ai.has_method("get_aoe_radius"):
		aoe_radius = ai.get_aoe_radius(aoe_radius)

	_spawn_aoe_ring(global_position, aoe_radius, 70.0)

	# Big camera shake on explosion
	if camera_controller:
		camera_controller.shake(25.0, 0.8)

	await get_tree().create_timer(0.3).timeout

	# Reset color
	if sprite:
		sprite.modulate = Color.WHITE

	await get_tree().create_timer(0.5).timeout


func _spawn_aoe_ring(pos: Vector2, radius: float, damage: float) -> void:
	"""Spawns AoE ring"""
	var aoe_path = "res://hitboxes/boss_aoe_ring.tscn"

	if not ResourceLoader.exists(aoe_path):
		return

	var aoe_scene = load(aoe_path)
	var aoe = aoe_scene.instantiate()
	get_parent().add_child(aoe)

	aoe.global_position = pos

	if "radius" in aoe:
		aoe.radius = radius
	if "damage" in aoe:
		aoe.damage = damage
	if aoe.has_method("activate"):
		aoe.activate()


# ============================================================================
# SCYTHE VISUAL HELPERS
# ============================================================================

func _glow_scythe(glow_color: Color = Color(1.0, 0.6, 1.0), duration: float = 0.5) -> void:
	"""Sense leuchtet auf vor einem Angriff"""
	if not scythe_sprite:
		return
	var tween := create_tween()
	tween.tween_property(scythe_sprite, "modulate", glow_color * 1.8, duration * 0.5)
	tween.tween_property(scythe_sprite, "modulate", glow_color, duration * 0.5)


func _reset_scythe() -> void:
	"""Setzt Sense auf Ausgangsposition zurueck"""
	if not scythe_sprite:
		return
	scythe_sprite.modulate = Color.WHITE
	scythe_sprite.rotation = _scythe_base_rotation
	scythe_sprite.position = _scythe_base_position
	scythe_sprite.scale = Vector2(0.2, 0.2)
	scythe_sprite.visible = true


func _animate_scythe_swing(swing_angle: float = 1.2, duration: float = 0.2) -> void:
	"""Schwingt die Sense in einem Bogen (Rotation)"""
	if not scythe_sprite:
		return
	var tween := create_tween()
	var target_rot: float = _scythe_base_rotation + swing_angle
	tween.tween_property(scythe_sprite, "rotation", target_rot, duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(scythe_sprite, "rotation", _scythe_base_rotation, duration * 0.6).set_ease(Tween.EASE_IN)


func _grow_scythe(scale_mult: float = 3.0, duration: float = 0.3) -> void:
	"""Sense wird riesig fuer Spezialattacken"""
	if not scythe_sprite:
		return
	var big_scale := Vector2(0.2 * scale_mult, 0.2 * scale_mult)
	var tween := create_tween()
	tween.tween_property(scythe_sprite, "scale", big_scale, duration).set_ease(Tween.EASE_OUT)


func _shrink_scythe(duration: float = 0.3) -> void:
	"""Sense kehrt auf Normalgroesse zurueck"""
	if not scythe_sprite:
		return
	var tween := create_tween()
	tween.tween_property(scythe_sprite, "scale", Vector2(0.2, 0.2), duration).set_ease(Tween.EASE_IN)


# ============================================================================
# NEW ATTACKS: SCYTHE COMBO (3-hit mit riesiger Sense)
# ============================================================================

func perform_scythe_combo() -> void:
	"""3-Hit-Combo mit wachsender Sense — jeder Schlag rotiert die Sense"""
	print("[Lythrun] Scythe Combo!")

	if not player_target or not is_instance_valid(player_target):
		await get_tree().create_timer(0.5).timeout
		return

	# Teleport nah zum Spieler
	face_player()
	var target_pos: Vector2 = player_target.global_position
	var approach_dir: float = sign(global_position.x - target_pos.x)
	if approach_dir == 0:
		approach_dir = 1.0
	global_position = target_pos + Vector2(approach_dir * PREFERRED_DISTANCE, 0)

	# Sense aufleuchten lassen
	_glow_scythe(Color(0.8, 0.2, 1.0), 0.6)
	_start_charge_effect(CHARGE_COLOR_SLAM, 0.6)
	await get_tree().create_timer(0.6).timeout
	_end_charge_effect()

	# Sense wachsen lassen
	_grow_scythe(3.0, 0.2)
	await get_tree().create_timer(0.2).timeout

	# 3 Schwuenge mit steigendem Schaden
	var damages: Array[int] = [35, 45, 65]
	var swing_angles: Array[float] = [1.0, -1.4, 2.0]

	for i in range(3):
		face_player()

		# Sense schwingen
		_animate_scythe_swing(swing_angles[i], 0.25)

		# Hitbox
		var impact_pos: Vector2 = global_position + Vector2(-approach_dir * 100.0, -30.0)
		_spawn_slam_hitbox(impact_pos, 130.0, damages[i])

		# Kamera-Shake (staerker pro Hit)
		if camera_controller:
			camera_controller.shake(5.0 + i * 3.0, 0.15)

		await get_tree().create_timer(0.35).timeout

	# Sense zuruecksetzen
	_shrink_scythe(0.3)
	await get_tree().create_timer(0.3).timeout
	_reset_scythe()


# ============================================================================
# NEW ATTACKS: SCYTHE THROW (Sensenwurf)
# ============================================================================

func perform_scythe_throw() -> void:
	"""Wirft die Sense zum Spieler — sie fliegt hin und zurueck"""
	print("[Lythrun] Scythe Throw!")

	if not player_target or not is_instance_valid(player_target):
		await get_tree().create_timer(0.5).timeout
		return

	if not scythe_sprite:
		# Fallback: void orbs stattdessen
		await perform_void_orbs()
		return

	face_player()

	# Aufladen
	_glow_scythe(Color(1.0, 0.4, 0.8), 0.5)
	_start_charge_effect(CHARGE_COLOR_CAST, 0.5)
	await get_tree().create_timer(0.5).timeout
	_end_charge_effect()

	_scythe_thrown = true

	# Sense-Projektil visuell fliegen lassen
	var start_pos: Vector2 = scythe_sprite.global_position
	var target_pos: Vector2 = player_target.global_position + Vector2(0, -30)
	var throw_speed: float = 800.0
	var distance: float = start_pos.distance_to(target_pos)
	var fly_time: float = distance / throw_speed

	# Reparent scythe to scene root for world-space movement
	var scene_root: Node = get_tree().current_scene
	var original_parent: Node = scythe_sprite.get_parent()
	scythe_sprite.reparent(scene_root, true)

	# Hinflug — Sense rotiert schnell
	var throw_tween := create_tween()
	throw_tween.set_parallel(true)
	throw_tween.tween_property(scythe_sprite, "global_position", target_pos, fly_time)
	throw_tween.tween_property(scythe_sprite, "rotation", scythe_sprite.rotation + TAU * 4.0, fly_time)

	# Schaden auf dem Weg (Hitbox am Ziel)
	await throw_tween.finished

	# AoE Schaden am Ziel
	_spawn_aoe_ring(scythe_sprite.global_position, 120.0, 40.0)
	if camera_controller:
		camera_controller.shake(8.0, 0.3)

	await get_tree().create_timer(0.3).timeout

	# Rueckflug
	var return_pos: Vector2 = global_position + Vector2(_scythe_base_position.x * scale.x, _scythe_base_position.y * scale.y)
	var return_dist: float = scythe_sprite.global_position.distance_to(return_pos)
	var return_time: float = return_dist / (throw_speed * 1.2)

	var return_tween := create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(scythe_sprite, "global_position", return_pos, return_time)
	return_tween.tween_property(scythe_sprite, "rotation", scythe_sprite.rotation + TAU * 3.0, return_time)
	await return_tween.finished

	# Sense zurueck zum Boss reparenten
	scythe_sprite.reparent(original_parent, false)
	_reset_scythe()
	_scythe_thrown = false

	await get_tree().create_timer(0.2).timeout


# ============================================================================
# NEW ATTACKS: GROUND AOE (Boden-Flaechenschaden, gesamte Arena)
# ============================================================================

func perform_ground_aoe() -> void:
	"""Boden-AoE: Lythrun haemmert Sense in den Boden, Schadenswelle ueber die ganze Arena"""
	print("[Lythrun] Ground AoE!")

	face_player()

	# Teleport weg vom Spieler (Mitte der Arena)
	global_position = Vector2(960, global_position.y - 60)

	# Dramatisches Aufladen: Sense leuchtet rot
	_glow_scythe(Color(1.0, 0.15, 0.0), 1.0)
	_start_charge_effect(CHARGE_COLOR_AOE, 1.5)

	# Sense nach oben schwingen (Aufladen)
	if scythe_sprite:
		var tween := create_tween()
		tween.tween_property(scythe_sprite, "rotation", _scythe_base_rotation - 1.5, 0.8).set_ease(Tween.EASE_OUT)

	if camera_controller:
		camera_controller.shake(6.0, 1.5)

	await get_tree().create_timer(1.5).timeout
	_end_charge_effect()

	# Sense in den Boden rammen
	if scythe_sprite:
		var slam_tween := create_tween()
		slam_tween.tween_property(scythe_sprite, "rotation", _scythe_base_rotation + 0.8, 0.1).set_ease(Tween.EASE_IN)

	# Flash
	if sprite:
		sprite.modulate = Color.WHITE * 2.0

	# Massive Kamera-Erschuetterung
	if camera_controller:
		camera_controller.shake(20.0, 0.8)

	# Schadenswellen: 3 Ringe die sich ausbreiten (zeitversetzt)
	var arena_center: Vector2 = Vector2(960, 800)
	var wave_damage: int = 30 + current_phase * 10  # 40/50/60 je nach Phase
	var wave_radii: Array[float] = [200.0, 450.0, 800.0]

	for i in range(wave_radii.size()):
		get_tree().create_timer(0.2 * i).timeout.connect(func():
			# Visueller Ring (ColorRect als Placeholder)
			_spawn_ground_wave_visual(arena_center, wave_radii[i])
			# Schaden an alle Spieler in der Arena
			var player: Node2D = GameManager.player if GameManager else null
			if player and is_instance_valid(player):
				if player.global_position.distance_to(arena_center) < wave_radii[i]:
					if player.has_node("HealthComponent"):
						player.get_node("HealthComponent").take_damage(wave_damage)
		)

	await get_tree().create_timer(0.8).timeout

	# Reset
	if sprite:
		sprite.modulate = Color.WHITE
	_reset_scythe()

	await get_tree().create_timer(0.5).timeout


func _spawn_ground_wave_visual(center: Vector2, radius: float) -> void:
	"""Spawnt eine visuelle Bodenwelle (expandierender Partikelring)"""
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return

	# Expanding particle ring
	var ring_vfx := GPUParticles2D.new()
	ring_vfx.amount = int(clampf(radius * 0.15, 15, 80))
	ring_vfx.lifetime = 0.6
	ring_vfx.one_shot = true
	ring_vfx.explosiveness = 0.95

	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.particle_flag_disable_z = true
	ring_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ring_mat.emission_ring_radius = radius
	ring_mat.emission_ring_inner_radius = radius * 0.85
	ring_mat.emission_ring_height = 0.0
	ring_mat.emission_ring_axis = Vector3(0, 0, 1)
	ring_mat.direction = Vector3(0, -1, 0)
	ring_mat.spread = 30.0
	ring_mat.gravity = Vector3(0, 50, 0)
	ring_mat.initial_velocity_min = 10.0
	ring_mat.initial_velocity_max = 40.0
	ring_mat.scale_min = 2.0
	ring_mat.scale_max = 4.0
	ring_mat.color = Color(1.0, 0.3, 0.1, 0.7)
	ring_vfx.process_material = ring_mat

	ring_vfx.global_position = center
	scene_root.add_child(ring_vfx)

	# Auto-free
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(ring_vfx.queue_free)
	ring_vfx.add_child(timer)
	timer.start()


# ============================================================================
# ANIMATIONS
# ============================================================================

func play_intro_animation() -> void:
	"""Plays Lythrun's intro animation"""
	print("[Lythrun] Intro animation")

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func play_phase_transition(new_phase: int) -> void:
	"""Plays dramatic phase transition with hitstop, particles, and power-up glow."""
	print("[Lythrun] Phase transition to phase ", new_phase)

	# Hitstop for dramatic pause
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(0.25)
	await get_tree().create_timer(0.25, true, false, true).timeout

	# Camera shake
	if camera_controller:
		camera_controller.shake(12.0, 0.8)

	# Phase-specific colors
	var phase_color: Color
	match new_phase:
		2: phase_color = Color(0.6, 0.3, 1.0)   # Purple — hover awakening
		3: phase_color = Color(1.0, 0.2, 0.4)    # Red — desperation
		_: phase_color = Color(0.8, 0.8, 1.0)

	# Power-up particle burst
	var burst_vfx := GPUParticles2D.new()
	burst_vfx.amount = 50
	burst_vfx.lifetime = 1.2
	burst_vfx.one_shot = true
	burst_vfx.explosiveness = 0.9

	var burst_mat := ParticleProcessMaterial.new()
	burst_mat.particle_flag_disable_z = true
	burst_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	burst_mat.emission_sphere_radius = 30.0
	burst_mat.direction = Vector3(0, 0, 0)
	burst_mat.spread = 180.0
	burst_mat.gravity = Vector3(0, -20, 0)
	burst_mat.initial_velocity_min = 80.0
	burst_mat.initial_velocity_max = 200.0
	burst_mat.scale_min = 2.0
	burst_mat.scale_max = 4.0
	burst_mat.color = phase_color
	burst_vfx.process_material = burst_mat
	burst_vfx.position = Vector2.ZERO
	add_child(burst_vfx)

	var vfx_timer := Timer.new()
	vfx_timer.wait_time = 2.0
	vfx_timer.one_shot = true
	vfx_timer.timeout.connect(burst_vfx.queue_free)
	burst_vfx.add_child(vfx_timer)
	vfx_timer.start()

	# Boss glow pulse: intense phase color → white flash → settle
	if sprite:
		var glow := create_tween()
		glow.tween_property(sprite, "modulate", phase_color * 2.0, 0.15)
		glow.tween_property(sprite, "modulate", Color.WHITE * 1.8, 0.1)
		glow.tween_property(sprite, "modulate", Color.WHITE, 0.4)
		await glow.finished
	else:
		await get_tree().create_timer(0.65).timeout

	await get_tree().create_timer(0.3).timeout


func play_death_animation() -> void:
	"""Plays Lythrun's death animation — color shift + particles + dissolve."""
	print("[Lythrun] Death animation")

	# Death particle burst (dark purple fragments)
	var death_vfx := GPUParticles2D.new()
	death_vfx.amount = 60
	death_vfx.lifetime = 2.0
	death_vfx.one_shot = true
	death_vfx.explosiveness = 0.3

	var death_mat := ParticleProcessMaterial.new()
	death_mat.particle_flag_disable_z = true
	death_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	death_mat.emission_sphere_radius = 40.0
	death_mat.direction = Vector3(0, -1, 0)
	death_mat.spread = 180.0
	death_mat.gravity = Vector3(0, -30, 0)
	death_mat.initial_velocity_min = 15.0
	death_mat.initial_velocity_max = 70.0
	death_mat.scale_min = 2.0
	death_mat.scale_max = 5.0
	death_mat.color = Color(0.4, 0.15, 0.7, 0.8)
	death_vfx.process_material = death_mat
	death_vfx.position = Vector2.ZERO
	add_child(death_vfx)

	var vfx_timer := Timer.new()
	vfx_timer.wait_time = 3.0
	vfx_timer.one_shot = true
	vfx_timer.timeout.connect(death_vfx.queue_free)
	death_vfx.add_child(vfx_timer)
	vfx_timer.start()

	# Boss color shift to purple → fade to transparent
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 0.2, 0.8, 1.0), 0.4)
		tween.tween_property(sprite, "modulate:a", 0.0, 1.6)
		await tween.finished

	# Scythe fades too
	if scythe_sprite:
		var s_tween := create_tween()
		s_tween.tween_property(scythe_sprite, "modulate:a", 0.0, 1.0)


# ============================================================================
# DIALOG HELPERS
# ============================================================================

func _make_dialog_entry(speaker_name: String, portrait_path: String, text: String) -> DialogEntry:
	"""Creates a DialogEntry with speaker portrait."""
	var entry := DialogEntry.new()
	entry.speaker_name = speaker_name
	entry.text = text
	entry.text_speed = 35.0

	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		entry.speaker_sprite = load(portrait_path)

	return entry


func _play_dialog(entries: Array[DialogEntry], dialog_id: String) -> void:
	"""Plays dialog entries via DialogManager and awaits completion."""
	var dialog := DialogData.new()
	dialog.dialog_id = dialog_id
	dialog.entries = entries

	if EventBus:
		EventBus.dialog_finished.connect(_on_lythrun_dialog_finished, CONNECT_ONE_SHOT)

	DialogManager.play_dialog_resource(dialog)

	await dialog_sequence_finished


func _on_lythrun_dialog_finished(_dialog_id: String) -> void:
	dialog_sequence_finished.emit()
