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

# ============ JOIN BLOCKING FLAGS ============
var join_blocked_cutscene: bool = false
var join_blocked_boss_fight: bool = false

# ============ RESPAWN TIMERS ============
const RESPAWN_DELAY: float = 3.0

func _ready() -> void:
	print("[CoopManager] Initialized")

	# Connect to InputManager signals
	if InputManager:
		InputManager.p2_join_requested.connect(_on_p2_join_requested)

# ============ P2 JOIN/LEAVE SYSTEM ============

func _on_p2_join_requested() -> void:
	"""Handle P2 join request from InputManager"""
	if is_p2_active:
		print("[CoopManager] P2 already active, ignoring join request")
		return

	if not can_join():
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
	if is_p2_active:
		return

	print("[CoopManager] Spawning Player 2 (Lythrun)...")

	# Load P2 scene
	var p2_scene = load("res://player/lythrun_player.tscn")
	if not p2_scene:
		push_error("[CoopManager] Could not load lythrun_player.tscn!")
		return

	p2_instance = p2_scene.instantiate()

	# Add to current scene
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("[CoopManager] No current scene!")
		p2_instance.queue_free()
		return

	current_scene.add_child(p2_instance)

	# Set spawn position near P1
	p2_instance.global_position = p1_instance.global_position + Vector2(50, 0)

	# Play spawn animation
	await play_shadow_spawn_animation()

	# Activate P2
	is_p2_active = true
	InputManager.set_p2_active(true)

	# Connect signals
	connect_p2_signals()

	p2_joined.emit()

	print("[CoopManager] Player 2 joined!")

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
	"""Connect P2 signals"""
	# Connect death signal
	if p2_instance.has_signal("health_depleted"):
		# Try to connect to health component
		if p2_instance.has_node("HealthComponent"):
			var health_comp = p2_instance.get_node("HealthComponent")
			if health_comp.has_signal("health_depleted"):
				health_comp.health_depleted.connect(_on_p2_died)

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

	p2_left.emit()

# ============ RESPAWN SYSTEM ============

func _on_p2_died() -> void:
	"""Handle P2 death"""
	if not is_p2_active:
		return

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

	# Heal P2 to 50% HP
	if p2_instance.has_node("HealthComponent"):
		var health_comp = p2_instance.get_node("HealthComponent")
		var half_health = health_comp.max_health / 2
		health_comp.heal(half_health)

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
