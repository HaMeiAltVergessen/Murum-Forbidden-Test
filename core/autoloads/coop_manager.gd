extends Node
## CoopManager handles Player 2 join/leave and co-op respawn logic

# ============ SIGNALS ============
signal p2_joined
signal p2_left
signal p2_respawned

# ============ PLAYER REFERENCES ============
var p2_instance: CharacterBody2D = null
var p1_instance: CharacterBody2D = null
var is_p2_active: bool = false

# ============ PvP MODE (COMMIT 023) ============
var pvp_mode: bool = false  # When true, players can damage each other

# ============ JOIN BLOCKING FLAGS ============
var join_blocked_cutscene: bool = false
var join_blocked_boss_fight: bool = false

# ============ RESPAWN TIMERS ============
const RESPAWN_DELAY: float = 4.0  # COMMIT 021: 4 seconds as requested

func _ready() -> void:
	print("[CoopManager] Initialized")

	# Connect to InputManager signals
	if InputManager:
		InputManager.p2_join_requested.connect(_on_p2_join_requested)
		InputManager.p2_leave_requested.connect(_on_p2_controller_disconnected)  # COMMIT 022.5: Controller hotplug

# ============ P2 JOIN/LEAVE SYSTEM ============

func _on_p2_join_requested() -> void:
	"""Handle P2 join request from InputManager"""
	if is_p2_active:
		print("[CoopManager] P2 already active, ignoring join request")
		return

	# CRITICAL: Set flag IMMEDIATELY to prevent multiple spawns from START button spam
	is_p2_active = true

	if not can_join():
		is_p2_active = false  # Reset if blocked
		show_join_blocked_message()
		return

	spawn_p2()

func can_join() -> bool:
	"""Check if P2 can join"""
	if join_blocked_cutscene:
		return false

	if join_blocked_boss_fight:
		return false

	if not p1_instance or not is_instance_valid(p1_instance):
		print("[CoopManager] Cannot join: P1 not registered")
		return false

	return true

func show_join_blocked_message() -> void:
	"""Show notification why join is blocked"""
	if join_blocked_cutscene:
		print("[CoopManager] Join blocked: Cutscene active")
		# TODO: Add notification when NotificationManager exists
		# NotificationManager.show("Warte bis die Cutscene endet...", 2.0)
	elif join_blocked_boss_fight:
		print("[CoopManager] Join blocked: Boss fight active")
		# TODO: Add notification when NotificationManager exists
		# NotificationManager.show("Kann während des Kampfes nicht beitreten.", 2.0)

func spawn_p2() -> void:
	"""Spawn Player 2 (Lythrun)"""
	print("[CoopManager] Spawning Player 2 (Lythrun)...")

	# Load P2 scene
	var p2_scene = load("res://player/lythrun_player.tscn")
	if not p2_scene:
		push_error("[CoopManager] Could not load lythrun_player.tscn!")
		is_p2_active = false
		return

	# CRITICAL: Set P2's controller device BEFORE instantiating P2
	# This ensures MovementController._ready() gets the correct device ID
	if InputManager.p2_controller_device < 0:
		if InputManager.detected_controllers.size() > 0:
			InputManager.p2_controller_device = InputManager.detected_controllers[0]
			print("[CoopManager] P2 controller assigned EARLY: Device %d" % InputManager.p2_controller_device)
		else:
			push_warning("[CoopManager] No controller detected for P2!")

	p2_instance = p2_scene.instantiate()

	# Add to current scene
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("[CoopManager] No current scene!")
		p2_instance.queue_free()
		is_p2_active = false
		return

	# IMPORTANT: Set is_p2_active BEFORE adding to scene tree
	# This ensures P2 won't be ignored if they take damage during spawn
	is_p2_active = true

	current_scene.add_child(p2_instance)

	# Set spawn position near P1
	p2_instance.global_position = p1_instance.global_position + Vector2(50, 0)

	# CRITICAL: Initialize P2's health to max BEFORE anything else
	if p2_instance.has_node("HealthComponent"):
		var health_comp = p2_instance.get_node("HealthComponent")
		# Force health to max (in case it wasn't initialized properly)
		health_comp.current_health = health_comp.max_health
		print("[CoopManager] P2 HP initialized: %d/%d" % [health_comp.current_health, health_comp.max_health])

	# Make P2 invulnerable during spawn (set EARLY)
	if p2_instance.has_method("set_invulnerable"):
		p2_instance.set_invulnerable(true)

	# Disable P2's collision temporarily to prevent DeathBox issues
	p2_instance.set_collision_layer_value(3, false)  # Temporarily disable player layer

	# Connect signals BEFORE animation so death is tracked
	connect_p2_signals()

	# Play spawn animation
	await play_shadow_spawn_animation()

	# Re-enable P2's collision
	p2_instance.set_collision_layer_value(3, true)

	# Activate P2 input (controller device already assigned earlier)
	InputManager.set_p2_active(true)

	# Emit joined signal AFTER everything is ready
	p2_joined.emit()

	# Setup co-op camera
	_setup_coop_camera()

	print("[CoopManager] Player 2 joined!")

func _setup_coop_camera() -> void:
	"""Setup or activate co-op camera when P2 joins"""
	# Check if CoopCamera already exists in scene
	var existing_coop_cam = get_tree().get_first_node_in_group("coop_camera")
	if existing_coop_cam:
		print("[CoopManager] Existing CoopCamera found, activating...")
		if existing_coop_cam.has_method("set_player1"):
			existing_coop_cam.set_player1(p1_instance)
		if existing_coop_cam.has_method("set_player2"):
			existing_coop_cam.set_player2(p2_instance)
		if existing_coop_cam.has_method("activate_coop_camera"):
			existing_coop_cam.activate_coop_camera()
		return

	# No CoopCamera exists - create one dynamically
	var coop_cam_scene = load("res://camera/coop_camera.tscn")
	if coop_cam_scene:
		var coop_cam = coop_cam_scene.instantiate()
		get_tree().current_scene.add_child(coop_cam)
		coop_cam.add_to_group("coop_camera")

		# Set player references
		coop_cam.set_player1(p1_instance)
		coop_cam.set_player2(p2_instance)
		coop_cam.activate_coop_camera()

		print("[CoopManager] CoopCamera created and activated")
	else:
		push_warning("[CoopManager] Could not load coop_camera.tscn")

func play_shadow_spawn_animation() -> void:
	"""Play shadow abyss spawn animation"""
	# Load shadow abyss VFX
	var shadow_abyss_scene = load("res://vfx/shadow_abyss_spawn.tscn")
	if not shadow_abyss_scene:
		print("[CoopManager] Could not load shadow_abyss_spawn.tscn, skipping animation")
		await get_tree().create_timer(0.5).timeout
		return

	# Create shadow abyss at P1's position
	var shadow_abyss = shadow_abyss_scene.instantiate()
	p1_instance.get_parent().add_child(shadow_abyss)
	shadow_abyss.global_position = p1_instance.global_position + Vector2(0, 20)

	# P2 plays spawn animation
	if p2_instance.has_method("play_spawn_animation"):
		p2_instance.play_spawn_animation()

	# Make P2 invulnerable during spawn
	if p2_instance.has_method("set_invulnerable"):
		p2_instance.set_invulnerable(true)

	# Play audio
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("player_hurt")  # Placeholder sound

	# Wait for animation (2 seconds)
	await get_tree().create_timer(2.0).timeout

	# Close shadow abyss
	if shadow_abyss.has_method("play_close_animation"):
		shadow_abyss.play_close_animation()
		await get_tree().create_timer(0.5).timeout

	shadow_abyss.queue_free()

	# P2 is now vulnerable
	if p2_instance.has_method("set_invulnerable"):
		p2_instance.set_invulnerable(false)

func connect_p2_signals() -> void:
	"""Connect P2 signals (COMMIT 021: Fixed - never worked before!)"""
	# Connect death signal from HealthComponent
	if p2_instance.has_node("HealthComponent"):
		var health_comp = p2_instance.get_node("HealthComponent")
		if health_comp.has_signal("health_depleted"):
			health_comp.health_depleted.connect(_on_p2_died)
			print("[CoopManager] P2 death signal connected successfully")
		else:
			print("[CoopManager] WARNING: HealthComponent has no health_depleted signal")
	else:
		print("[CoopManager] WARNING: P2 has no HealthComponent")

	# Connect gold collection (if needed)
	# TODO: Implement when gold collection system is in place

func despawn_p2() -> void:
	"""Despawn Player 2"""
	if not is_p2_active:
		return

	print("[CoopManager] Despawning Player 2...")

	# Remove P2
	if p2_instance and is_instance_valid(p2_instance):
		p2_instance.queue_free()
		p2_instance = null

	is_p2_active = false
	InputManager.set_p2_active(false)

	# Deactivate CoopCamera and return to single-player camera
	_deactivate_coop_camera()

	p2_left.emit()

func _deactivate_coop_camera() -> void:
	"""Deactivate co-op camera when P2 leaves"""
	var coop_cam = get_tree().get_first_node_in_group("coop_camera")
	if coop_cam and coop_cam.has_method("deactivate_coop_camera"):
		coop_cam.deactivate_coop_camera()
		print("[CoopManager] CoopCamera deactivated")

func _on_p2_controller_disconnected() -> void:
	"""Handle P2's controller being disconnected (COMMIT 022.5)"""
	if is_p2_active:
		print("[CoopManager] P2's controller disconnected - despawning P2")
		# TODO: Show notification when NotificationManager exists
		# NotificationManager.show("Player 2's controller disconnected", 3.0)
		despawn_p2()

# ============ RESPAWN SYSTEM ============

func _on_p2_died() -> void:
	"""Handle P2 death"""
	if not is_p2_active:
		return

	# COMMIT 023.7: Don't respawn in PvP mode - let arena handle it
	if pvp_mode:
		print("[CoopManager] P2 died in PvP mode - arena will handle victory")
		return  # Arena handles PvP death

	print("[CoopManager] P2 died, waiting %s seconds..." % RESPAWN_DELAY)

	# Wait for respawn delay
	await get_tree().create_timer(RESPAWN_DELAY).timeout

	# Check if P1 is still alive
	if p1_instance and is_instance_valid(p1_instance) and not p1_instance.is_dead:
		respawn_p2_at_p1()
	else:
		# Both dead → Game Over
		trigger_game_over()

func respawn_p2_at_p1() -> void:
	"""Respawn P2 at P1's position"""
	if not p2_instance or not is_instance_valid(p2_instance):
		print("[CoopManager] Cannot respawn P2: instance invalid")
		return

	print("[CoopManager] Respawning P2 at P1...")

	# Set position to P1
	p2_instance.global_position = p1_instance.global_position + Vector2(50, 0)

	# Play spawn animation
	await play_shadow_spawn_animation()

	# Heal P2 to FULL HP (COMMIT 021: 100% instead of 50%)
	if p2_instance.has_node("HealthComponent"):
		var health_comp = p2_instance.get_node("HealthComponent")
		health_comp.heal(health_comp.max_health)

	# Reset dead flag
	if "is_dead" in p2_instance:
		p2_instance.is_dead = false

	# Re-enable physics
	p2_instance.set_physics_process(true)
	p2_instance.set_process_input(true)

	p2_respawned.emit()

func on_p1_died() -> void:
	"""Handle P1 death (called from GameManager)"""
	print("[CoopManager] P1 died")

	# COMMIT 023.7: Don't respawn in PvP mode - let arena handle it
	if pvp_mode:
		print("[CoopManager] P1 died in PvP mode - P2 wins!")
		return  # Arena handles PvP death

	# Check if P2 is active and alive
	if is_p2_active and p2_instance and is_instance_valid(p2_instance) and not p2_instance.is_dead:
		print("[CoopManager] P2 is alive, will respawn P1 at P2")
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		respawn_p1_at_p2()
	else:
		# P2 not active or also dead → normal Game Over
		trigger_game_over()

func respawn_p1_at_p2() -> void:
	"""Respawn P1 at P2's position"""
	if not p1_instance or not is_instance_valid(p1_instance):
		print("[CoopManager] Cannot respawn P1: instance invalid")
		return

	if not p2_instance or not is_instance_valid(p2_instance):
		print("[CoopManager] Cannot respawn P1: P2 invalid")
		return

	print("[CoopManager] Respawning P1 at P2...")

	# Set position to P2
	p1_instance.global_position = p2_instance.global_position + Vector2(-50, 0)

	# Create shadow abyss at P2's position
	var shadow_abyss_scene = load("res://vfx/shadow_abyss_spawn.tscn")
	if shadow_abyss_scene:
		var shadow_abyss = shadow_abyss_scene.instantiate()
		p2_instance.get_parent().add_child(shadow_abyss)
		shadow_abyss.global_position = p2_instance.global_position + Vector2(0, 20)

		# Make P1 invulnerable during spawn
		if p1_instance.has_method("set_invulnerable"):
			p1_instance.set_invulnerable(true)

		# Wait for animation
		await get_tree().create_timer(2.0).timeout

		# Close shadow
		if shadow_abyss.has_method("play_close_animation"):
			shadow_abyss.play_close_animation()
			await get_tree().create_timer(0.5).timeout

		shadow_abyss.queue_free()

		# P1 is now vulnerable
		if p1_instance.has_method("set_invulnerable"):
			p1_instance.set_invulnerable(false)

	# Heal P1 to 50% HP
	if p1_instance.has_node("HealthComponent"):
		var health_comp = p1_instance.get_node("HealthComponent")
		var half_health = health_comp.max_health / 2
		health_comp.heal(half_health)

	# Reset dead flag
	if "is_dead" in p1_instance:
		p1_instance.is_dead = false

	# Re-enable physics
	p1_instance.set_physics_process(true)
	p1_instance.set_process_input(true)

func trigger_game_over() -> void:
	"""Trigger game over (both players dead)"""
	print("[CoopManager] Both players dead - Game Over")

	if GameManager and GameManager.has_method("set_game_over"):
		GameManager.set_game_over()

# ============ JOIN BLOCKING ============

func set_cutscene_active(active: bool) -> void:
	"""Block/unblock P2 join during cutscenes"""
	join_blocked_cutscene = active
	print("[CoopManager] Cutscene blocking: ", active)

func set_boss_fight_active(active: bool) -> void:
	"""Block/unblock P2 join during boss fights"""
	join_blocked_boss_fight = active
	GameManager.set_flag("lythrun_boss_fight_active", active)
	print("[CoopManager] Boss fight blocking: ", active)

# ============ REFERENCES ============

func set_p1_reference(player: CharacterBody2D) -> void:
	"""Set P1 reference"""
	p1_instance = player
	print("[CoopManager] P1 reference set")

func get_p2_instance() -> CharacterBody2D:
	"""Get P2 instance"""
	return p2_instance

func is_p2_alive() -> bool:
	"""Check if P2 is alive"""
	if not is_p2_active or not p2_instance or not is_instance_valid(p2_instance):
		return false

	if "is_dead" in p2_instance:
		return not p2_instance.is_dead

	return true

# ============ COLLISION LAYER SWITCHING (COMMIT 021) ============

func set_coop_collision() -> void:
	"""Set collision layers for co-op mode (players pass through each other)"""
	if p1_instance and is_instance_valid(p1_instance):
		# P1 collides with world, enemies, P2 projectiles
		p1_instance.collision_mask = 0
		p1_instance.set_collision_mask_value(1, true)   # World
		p1_instance.set_collision_mask_value(4, true)   # Enemies
		p1_instance.set_collision_mask_value(6, true)   # P2 Projectiles
		p1_instance.set_collision_mask_value(7, true)   # Pickups
		p1_instance.set_collision_mask_value(8, true)   # Hazards

	if p2_instance and is_instance_valid(p2_instance):
		# P2 collides with world, enemies, P1 projectiles
		p2_instance.collision_mask = 0
		p2_instance.set_collision_mask_value(1, true)   # World
		p2_instance.set_collision_mask_value(4, true)   # Enemies
		p2_instance.set_collision_mask_value(5, true)   # P1 Projectiles
		p2_instance.set_collision_mask_value(7, true)   # Pickups
		p2_instance.set_collision_mask_value(8, true)   # Hazards

	print("[CoopManager] Collision set to CO-OP mode (players pass through)")

func set_pvp_collision() -> void:
	"""Set collision layers for PvP mode (players collide with each other)"""
	if p1_instance and is_instance_valid(p1_instance):
		# P1 collides with world, enemies, P2 (Layer 3), P2 projectiles
		p1_instance.collision_mask = 0
		p1_instance.set_collision_mask_value(1, true)   # World
		p1_instance.set_collision_mask_value(3, true)   # Player2 (ADDED for PvP)
		p1_instance.set_collision_mask_value(4, true)   # Enemies
		p1_instance.set_collision_mask_value(6, true)   # P2 Projectiles
		p1_instance.set_collision_mask_value(7, true)   # Pickups
		p1_instance.set_collision_mask_value(8, true)   # Hazards

		# P1's hitbox can hit P2
		if p1_instance.has_node("CombatSystem/HitboxComponent"):
			var hitbox = p1_instance.get_node("CombatSystem/HitboxComponent")
			hitbox.set_collision_mask_value(3, true)   # Can hit Player2
			hitbox.set_collision_mask_value(10, true)  # Can hit PlayerHurtbox

	if p2_instance and is_instance_valid(p2_instance):
		# P2 collides with world, enemies, P1 (Layer 2), P1 projectiles
		p2_instance.collision_mask = 0
		p2_instance.set_collision_mask_value(1, true)   # World
		p2_instance.set_collision_mask_value(2, true)   # Player1 (ADDED for PvP)
		p2_instance.set_collision_mask_value(4, true)   # Enemies
		p2_instance.set_collision_mask_value(5, true)   # P1 Projectiles
		p2_instance.set_collision_mask_value(7, true)   # Pickups
		p2_instance.set_collision_mask_value(8, true)   # Hazards

		# P2's hitbox can hit P1
		if p2_instance.has_node("CombatSystem/HitboxComponent"):
			var hitbox = p2_instance.get_node("CombatSystem/HitboxComponent")
			hitbox.set_collision_mask_value(2, true)   # Can hit Player1
			hitbox.set_collision_mask_value(10, true)  # Can hit PlayerHurtbox

	print("[CoopManager] Collision set to PVP mode (players collide)")
