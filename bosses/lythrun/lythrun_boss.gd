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
# STATE
# ============================================================================

var extra_lives: int = 0
var current_life: int = 0
var player_target: CharacterBody2D = null

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

	# Phase 1 (100%-75%): Basic attacks
	phase_1_pattern = [
		"staff_slam",
		"shadow_dash",
		"staff_slam",
		"void_orbs"
	]

	# Phase 2 (75%-50%): More aggressive
	phase_2_pattern = [
		"staff_slam_combo",
		"shadow_dash",
		"void_orbs",
		"teleport_strike",
		"staff_slam"
	]

	# Phase 3 (50%-0%): Desperate
	phase_3_pattern = [
		"teleport_barrage",
		"void_orbs_spread",
		"staff_slam_combo",
		"shadow_dash_multi",
		"desperation_aoe"
	]


func _find_player() -> void:
	"""Finds and sets the player target"""

	player_target = get_player()

	if not player_target:
		push_error("[Lythrun] No player found!")


# ============================================================================
# EXTRA LIVES SYSTEM
# ============================================================================

func _on_defeated() -> void:
	"""Override: Check for extra lives before defeat"""

	if current_life < extra_lives:
		# Revive instead of defeat
		_perform_revive()
	else:
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
	"""Plays revive animation and VFX"""

	# Spawn revive VFX
	_spawn_revive_vfx()

	# Flash effect
	if sprite:
		for i in range(3):
			sprite.modulate = Color.WHITE * 1.5
			await get_tree().create_timer(0.1).timeout
			sprite.modulate = Color.WHITE
			await get_tree().create_timer(0.1).timeout


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
		_:
			print("[Lythrun] Unknown attack: ", attack_name)
			await get_tree().create_timer(1.0).timeout


# ============================================================================
# PHASE 1 ATTACKS (100%-75% HP)
# ============================================================================

func perform_staff_slam() -> void:
	"""Basic staff slam attack"""

	print("[Lythrun] Staff Slam")

	# Face player
	face_player()

	# Telegraph
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("staff_slam_windup"):
		sprite.play("staff_slam_windup")
		await get_tree().create_timer(0.5).timeout

	# Slam
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("staff_slam"):
		sprite.play("staff_slam")

	# Spawn hitbox
	_spawn_slam_hitbox(global_position + Vector2(0, 60), 80.0, 35.0)

	# Camera shake
	if camera_controller:
		camera_controller.shake(8.0, 0.3)

	# Shockwave VFX
	_spawn_shockwave_vfx()

	await get_tree().create_timer(0.5).timeout


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
	"""Dash attack towards player"""

	print("[Lythrun] Shadow Dash")

	if not player_target:
		await get_tree().create_timer(1.0).timeout
		return

	# Calculate dash direction
	var target_pos = player_target.global_position
	var dash_direction = (target_pos - global_position).normalized()

	# Telegraph: Charge up
	if sprite:
		sprite.modulate = Color(0.5, 0, 0.5)  # Dark purple

	await get_tree().create_timer(0.4).timeout

	# Dash
	if sprite:
		sprite.modulate = Color.WHITE

	var dash_speed = 800.0
	var dash_duration = 0.3
	var elapsed = 0.0

	# Spawn dash hitbox
	var dash_hitbox = _spawn_dash_hitbox()

	while elapsed < dash_duration:
		velocity = dash_direction * dash_speed
		move_and_slide()

		elapsed += get_process_delta_time()
		await get_tree().process_frame

	if dash_hitbox and dash_hitbox.has_method("deactivate"):
		dash_hitbox.deactivate()

	velocity = Vector2.ZERO
	await get_tree().create_timer(0.2).timeout


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
	"""Shoots void orbs at player"""

	print("[Lythrun] Void Orbs")

	# Cast animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("cast"):
		sprite.play("cast")

	# Spawn 3 orbs with delay
	for i in range(3):
		_spawn_void_orb(i * 0.2)
		await get_tree().create_timer(0.3).timeout

	await get_tree().create_timer(0.3).timeout


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

	orb.global_position = global_position + Vector2(0, -30)

	# Set properties
	if "target" in orb:
		orb.target = player_target.global_position
	if "damage" in orb:
		orb.damage = 25
	if "speed" in orb:
		orb.speed = 200.0


# ============================================================================
# PHASE 2+ ATTACKS (Placeholders for Part 2)
# ============================================================================

func perform_staff_slam_combo() -> void:
	await perform_staff_slam()
	await get_tree().create_timer(0.3).timeout
	await perform_staff_slam()


func perform_teleport_strike() -> void:
	print("[Lythrun] Teleport Strike (TODO)")
	await get_tree().create_timer(1.5).timeout


func perform_void_orbs_spread() -> void:
	await perform_void_orbs()


func perform_teleport_barrage() -> void:
	print("[Lythrun] Teleport Barrage (TODO)")
	await get_tree().create_timer(2.0).timeout


func perform_shadow_dash_multi() -> void:
	await perform_shadow_dash()
	await get_tree().create_timer(0.3).timeout
	await perform_shadow_dash()


func perform_desperation_aoe() -> void:
	print("[Lythrun] Desperation AOE (TODO)")
	await get_tree().create_timer(2.0).timeout


# ============================================================================
# ANIMATIONS
# ============================================================================

func play_intro_animation() -> void:
	"""Plays Lythrun's intro animation"""
	print("[Lythrun] Intro animation")

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func play_phase_transition(new_phase: int) -> void:
	"""Plays Lythrun's phase transition animation"""
	print("[Lythrun] Phase transition to phase ", new_phase)

	# Flash effect
	if sprite:
		for i in range(3):
			sprite.modulate = Color.WHITE * 1.5
			await get_tree().create_timer(0.1).timeout
			sprite.modulate = Color.WHITE
			await get_tree().create_timer(0.1).timeout

	await get_tree().create_timer(0.5).timeout


func play_death_animation() -> void:
	"""Plays Lythrun's death animation"""
	print("[Lythrun] Death animation")

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
		await tween.finished
