extends Node2D
## Room 05 - Lythrun Boss Arena

# ============================================================================
# CONSTANTS
# ============================================================================

const ROOM_ID: String = "room_05_boss_arena"
const WORLD_ID: String = "world_1_ruins"
const BOSS_SCENE_PATH: String = "res://bosses/lythrun/lythrun_boss.tscn"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var player_spawn: Marker2D = $Spawns/PlayerSpawn
@onready var boss_spawn: Marker2D = $Spawns/BossSpawn
@onready var exit_door: Area2D = $Doors/ExitDoor if has_node("Doors/ExitDoor") else null
@onready var arena_boundary: Node2D = $ArenaBoundary if has_node("ArenaBoundary") else null

# ============================================================================
# STATE
# ============================================================================

var boss_instance: BaseBoss = null
var player: CharacterBody2D = null
var player2: CharacterBody2D = null
var fight_started: bool = false
var fight_ended: bool = false
var is_pvp_mode: bool = false
var dialog_label: Label = null  # COMMIT 023.8: Dialog placeholder
var player_death_count: int = 0  # Track deaths in solo boss fight

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[Room15_BossUrgathon] Arena initialized")
	print("[Room15_BossUrgathon] P2 Active (initial): ", CoopManager.is_p2_active)

	# Set current room in WorldManager (COMMIT 018)
	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID

	_setup_arena()
	_spawn_player()

	# Grace period: Wait for P2 to potentially join before starting sequence
	# This handles race conditions where P2 joins right as arena loads
	await get_tree().create_timer(1.0).timeout

	# Check P2 status after grace period
	_check_arena_mode_and_start()


func _setup_arena() -> void:
	"""Sets up the arena environment"""

	# Lock exit door
	if exit_door and exit_door.has_method("lock_door"):
		exit_door.lock_door()

	# Set arena boundary visible (semi-transparent)
	if arena_boundary:
		arena_boundary.modulate = Color(1, 1, 1, 0.3)

	print("[Room15_BossUrgathon] Arena setup complete")


func _spawn_player() -> void:
	"""Spawns the player(s) at the designated spawn point"""

	# Spawn P1
	player = get_tree().get_first_node_in_group("player")

	if not player:
		print("[Room15_BossUrgathon] No player found in scene tree")
		return

	if player_spawn:
		player.global_position = player_spawn.global_position

	# Disable movement during intro
	if player.has_method("disable_movement"):
		player.disable_movement()

	var spawn_pos = player_spawn.global_position if player_spawn else Vector2.ZERO
	print("[Room15_BossUrgathon] P1 spawned at: ", spawn_pos)

	# If P2 is already active, position them in arena too
	var p2_instance = CoopManager.get_p2_instance()
	if p2_instance and is_instance_valid(p2_instance):
		player2 = p2_instance
		# Position P2 on opposite side of arena
		if player_spawn:
			player2.global_position = player_spawn.global_position + Vector2(100, 0)

		# Disable P2 movement during intro
		if player2.has_method("disable_movement"):
			player2.disable_movement()

		print("[Room15_BossUrgathon] P2 spawned at: ", player2.global_position)


func _check_arena_mode_and_start() -> void:
	"""Check if P2 is present and decide: Solo Boss Fight vs PvP"""

	# Double-check P2 status (both flag and instance)
	var p2_instance = CoopManager.get_p2_instance()
	var is_p2_present = CoopManager.is_p2_active and p2_instance != null and is_instance_valid(p2_instance)

	print("[Room15_BossUrgathon] === ARENA MODE CHECK ===")
	print("[Room15_BossUrgathon] P2 Active Flag: ", CoopManager.is_p2_active)
	print("[Room15_BossUrgathon] P2 Instance: ", p2_instance)
	print("[Room15_BossUrgathon] P2 Valid: ", is_p2_present)

	if is_p2_present:
		# 2 PLAYERS → PvP MODE
		print("[Room15_BossUrgathon] >>> MODE: PvP (2 Players detected)")
		player2 = p2_instance
		is_pvp_mode = true
		_start_pvp_sequence()
	else:
		# 1 PLAYER → SOLO MODE (Boss Fight)
		print("[Room15_BossUrgathon] >>> MODE: Solo (1 Player, spawning boss)")
		is_pvp_mode = false
		_play_intro_cutscene()


# ============================================================================
# INTRO CUTSCENE
# ============================================================================

func _play_intro_cutscene() -> void:
	"""Plays the boss intro cutscene"""

	print("[Room15_BossUrgathon] Starting intro cutscene")

	var active_camera = get_viewport().get_camera_2d()

	if active_camera and boss_spawn:
		# Zoom camera to boss spawn altar
		var tween = create_tween()
		tween.tween_property(active_camera, "global_position", boss_spawn.global_position, 1.5).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

	await get_tree().create_timer(0.5).timeout

	# Spawn boss
	_spawn_boss()

	await get_tree().create_timer(2.0).timeout

	# Return camera to player
	if active_camera and player:
		var tween = create_tween()
		tween.tween_property(active_camera, "global_position", player.global_position, 1.0).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

	await get_tree().create_timer(0.5).timeout

	# Start fight
	_start_fight()


func _spawn_boss() -> void:
	"""Spawns the boss at the designated spawn point"""

	# SAFETY CHECK: Do NOT spawn boss in PvP mode
	if is_pvp_mode:
		print("[Room15_BossUrgathon] ABORT: Cannot spawn boss in PvP mode!")
		return

	if not ResourceLoader.exists(BOSS_SCENE_PATH):
		push_error("[Room15_BossUrgathon] Boss scene not found: " + BOSS_SCENE_PATH)
		return

	var boss_scene = load(BOSS_SCENE_PATH)
	boss_instance = boss_scene.instantiate()

	add_child(boss_instance)

	if boss_spawn:
		boss_instance.global_position = boss_spawn.global_position

	# Set player reference if boss has the method
	if boss_instance.has_method("set_player_target"):
		boss_instance.set_player_target(player)

	# Connect signals
	boss_instance.defeated.connect(_on_boss_defeated)
	boss_instance.phase_changed.connect(_on_boss_phase_changed)

	# Spawn VFX
	_spawn_boss_vfx()

	print("[Room15_BossUrgathon] Boss spawned (Solo Mode)")


func _spawn_boss_vfx() -> void:
	"""Spawns VFX when boss appears"""

	var vfx_path = "res://vfx/boss/lythrun_spawn.tscn"

	if not ResourceLoader.exists(vfx_path):
		print("[Room15_BossUrgathon] Boss spawn VFX not found")
		return

	var vfx_scene = load(vfx_path)
	var vfx = vfx_scene.instantiate()

	if boss_spawn:
		boss_spawn.add_child(vfx)

	if vfx is GPUParticles2D:
		vfx.emitting = true

	# Play SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("lythrun_spawn")


# ============================================================================
# FIGHT MANAGEMENT
# ============================================================================

func _start_fight() -> void:
	"""Starts the boss fight"""

	fight_started = true

	# Enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()

	# Connect to player death for solo mode respawn
	if not is_pvp_mode and player and player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		if health_comp.has_signal("health_depleted"):
			# Disconnect any existing connections first
			if health_comp.health_depleted.is_connected(_on_player_death_solo):
				health_comp.health_depleted.disconnect(_on_player_death_solo)
			health_comp.health_depleted.connect(_on_player_death_solo)
			print("[Room15_BossUrgathon] Connected to P1 death signal (Solo Mode)")

	# Start boss fight (if not already started by boss_base)
	if boss_instance and boss_instance.has_method("start_fight"):
		if not boss_instance.is_active:
			boss_instance.start_fight()

	# Change music
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_boss_music"):
			audio_manager.play_boss_music("lythrun_theme")

	print("[Room15_BossUrgathon] Fight started!")


func _on_player_death_solo() -> void:
	"""Called when player dies in Solo Boss Fight - Respawn at arena entrance"""

	if fight_ended or is_pvp_mode:
		return

	player_death_count += 1
	print("[Room15_BossUrgathon] Player died in Solo Mode! Deaths: ", player_death_count)

	# Brief delay before respawn
	await get_tree().create_timer(1.5).timeout

	# Respawn player at arena spawn point
	if player and player_spawn:
		# Reset player state
		if player.has_method("respawn"):
			player.respawn(player_spawn.global_position)
		else:
			player.global_position = player_spawn.global_position
			if "is_dead" in player:
				player.is_dead = false
			player.set_physics_process(true)
			player.set_process_input(true)

		# Reset health
		if player.has_node("HealthComponent"):
			var health_comp = player.get_node("HealthComponent")
			if health_comp.has_method("reset_health"):
				health_comp.reset_health()

		# Reset mana
		if player.has_node("ManaComponent"):
			var mana_comp = player.get_node("ManaComponent")
			if mana_comp.has_method("reset_mana"):
				mana_comp.reset_mana()

		print("[Room15_BossUrgathon] Player respawned at arena entrance")

		# Reset boss to full HP but keep current phase (punishment for dying)
		if boss_instance and boss_instance.has_node("HealthComponent"):
			var boss_health = boss_instance.get_node("HealthComponent")
			if boss_health.has_method("reset_health"):
				boss_health.reset_health()
				print("[Room15_BossUrgathon] Boss HP reset to full")

		# Small invulnerability window for player
		if player.has_node("HealthComponent"):
			var health_comp = player.get_node("HealthComponent")
			if health_comp.has_method("start_invulnerability"):
				health_comp.start_invulnerability()

		# Emit respawn signal
		EventBus.player_respawned.emit()


func _on_boss_defeated() -> void:
	"""Called when boss is defeated"""

	fight_ended = true

	# Unlock exit door
	if exit_door and exit_door.has_method("unlock_door"):
		exit_door.unlock_door()

	# Fade out arena boundary
	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate:a", 0.0, 2.0)

	# Set game flag
	GameManager.set_flag("world1_boss_defeated", true)

	print("[Room15_BossUrgathon] Boss defeated! Fight complete.")


func _on_boss_phase_changed(phase: int) -> void:
	"""Called when boss changes phase"""

	print("[Room15_BossUrgathon] Boss entered phase: ", phase)

	# Change arena atmosphere based on phase
	match phase:
		2:
			_intensify_arena_phase2()
		3:
			_intensify_arena_phase3()


func _intensify_arena_phase2() -> void:
	"""Changes arena atmosphere for phase 2"""

	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate", Color.ORANGE_RED, 1.0)

	# Play intensify SFX
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_sfx"):
			audio_manager.play_sfx("arena_intensify")


func _intensify_arena_phase3() -> void:
	"""Changes arena atmosphere for phase 3"""

	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate", Color.DARK_RED, 1.0)

	# Spawn hazards (placeholder)
	print("[Room15_BossUrgathon] Phase 3 arena hazards activated")


# ============================================================================
# PvP SEQUENCE (COMMIT 023)
# ============================================================================

func _start_pvp_sequence() -> void:
	"""Start the PvP sequence when 2 players are detected"""

	print("[Room15_BossUrgathon] === STARTING PVP SEQUENCE ===")

	# Lock both players in place for intro
	if player and player.has_method("disable_movement"):
		player.disable_movement()
		print("[Room15_BossUrgathon] P1 movement locked")

	if player2 and player2.has_method("disable_movement"):
		player2.disable_movement()
		print("[Room15_BossUrgathon] P2 movement locked")

	# Get camera
	var active_camera = get_viewport().get_camera_2d()

	# Calculate midpoint between players for camera focus
	var midpoint = Vector2.ZERO
	if player and player2:
		midpoint = (player.global_position + player2.global_position) / 2.0

	# Zoom camera to midpoint
	if active_camera:
		var tween = create_tween()
		tween.tween_property(active_camera, "global_position", midpoint, 1.5).set_trans(Tween.TRANS_CUBIC)
		await tween.finished

	await get_tree().create_timer(0.5).timeout

	# Show dialog placeholder (COMMIT 023.8)
	_show_dialog("The arena senses two warriors...\nOnly one may claim victory!")

	await get_tree().create_timer(2.0).timeout

	# Hide dialog
	_hide_dialog()

	# COMMIT 023.6: Make players into enemies for PvP
	# This is the SIMPLE solution - just change their groups!
	if player:
		player.remove_from_group("player")  # No longer a player
		player.add_to_group("enemies")      # Now an enemy
		print("[Room15_BossUrgathon] P1 converted to enemy")

		# COMMIT 023.9.2: Change hurtbox layer from PlayerHurtbox (10) to EnemyHurtbox (9)
		if player.has_node("HurtboxComponent"):
			var hurtbox = player.get_node("HurtboxComponent")
			hurtbox.collision_layer = 0
			hurtbox.set_collision_layer_value(9, true)  # EnemyHurtbox
			print("[Room15_BossUrgathon] P1 hurtbox changed to EnemyHurtbox layer")

		# COMMIT 023.9.3: Change hitbox mask to check EnemyHurtbox (9) instead of PlayerHurtbox (10)
		if player.has_node("CombatSystem/HitboxComponent"):
			var hitbox = player.get_node("CombatSystem/HitboxComponent")
			hitbox.set_collision_mask_value(10, false)  # Stop checking PlayerHurtbox
			hitbox.set_collision_mask_value(9, true)    # Start checking EnemyHurtbox
			print("[Room15_BossUrgathon] P1 hitbox mask updated for PvP (checks EnemyHurtbox)")

	if player2:
		player2.remove_from_group("player2")  # No longer player2
		player2.add_to_group("enemies")       # Now an enemy
		print("[Room15_BossUrgathon] P2 converted to enemy")

		# COMMIT 023.9.2: Change hurtbox layer from PlayerHurtbox (10) to EnemyHurtbox (9)
		if player2.has_node("HurtboxComponent"):
			var hurtbox = player2.get_node("HurtboxComponent")
			hurtbox.collision_layer = 0
			hurtbox.set_collision_layer_value(9, true)  # EnemyHurtbox
			print("[Room15_BossUrgathon] P2 hurtbox changed to EnemyHurtbox layer")

		# COMMIT 023.9.3: Change hitbox mask to check EnemyHurtbox (9) instead of PlayerHurtbox (10)
		if player2.has_node("CombatSystem/HitboxComponent"):
			var hitbox = player2.get_node("CombatSystem/HitboxComponent")
			hitbox.set_collision_mask_value(10, false)  # Stop checking PlayerHurtbox
			hitbox.set_collision_mask_value(9, true)    # Start checking EnemyHurtbox
			print("[Room15_BossUrgathon] P2 hitbox mask updated for PvP (checks EnemyHurtbox)")

	# Enable PvP mode (allows enemy-to-enemy damage in HitboxComponent)
	CoopManager.pvp_mode = true
	print("[Room15_BossUrgathon] >>> PVP MODE ENABLED (friendly fire ON)")

	# Enable PvP collision
	CoopManager.set_pvp_collision()
	print("[Room15_BossUrgathon] PvP collision enabled")

	# Unlock both players
	if player and player.has_method("enable_movement"):
		player.enable_movement()
		print("[Room15_BossUrgathon] P1 movement unlocked")

	if player2 and player2.has_method("enable_movement"):
		player2.enable_movement()
		print("[Room15_BossUrgathon] P2 movement unlocked")

	# Change music to PvP theme
	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		if audio_manager.has_method("play_boss_music"):
			audio_manager.play_boss_music("pvp_theme")  # TODO: Create PvP music track

	# Close arena barrier (prevent escape)
	_close_arena_barrier()

	# COMMIT 023.7: Connect death signals for PvP victory detection
	_connect_pvp_death_signals()

	fight_started = true

	print("[Room15_BossUrgathon] >>> PVP FIGHT STARTED <<<")


func _connect_pvp_death_signals() -> void:
	"""Connect to player death signals for PvP victory detection"""

	# Connect P1 death signal
	if player and player.has_node("HealthComponent"):
		var p1_health = player.get_node("HealthComponent")
		if p1_health.has_signal("health_depleted"):
			p1_health.health_depleted.connect(_on_p1_death_pvp)
			print("[Room15_BossUrgathon] Connected to P1 death signal")

	# Connect P2 death signal
	if player2 and player2.has_node("HealthComponent"):
		var p2_health = player2.get_node("HealthComponent")
		if p2_health.has_signal("health_depleted"):
			p2_health.health_depleted.connect(_on_p2_death_pvp)
			print("[Room15_BossUrgathon] Connected to P2 death signal")


func _on_p1_death_pvp() -> void:
	"""Called when P1 dies in PvP - P2 wins!"""

	# CRITICAL: Check if fight already ended (both died simultaneously)
	if fight_ended:
		print("[Room15_BossUrgathon] Fight already ended, ignoring P1 death")
		return

	print("[Room15_BossUrgathon] === P1 DIED - P2 WINS! ===")

	# Disable further damage
	fight_ended = true

	# Show victory message
	print("[Room15_BossUrgathon] >>> VICTORY: Player 2 (Lythrun) wins! <<<")
	# TODO: Show victory screen / pause game

	await get_tree().create_timer(2.0).timeout

	# For now: Just show message and pause
	print("[Room15_BossUrgathon] PvP ended - P2 victorious. Game should show victory screen here.")
	get_tree().paused = true


func _on_p2_death_pvp() -> void:
	"""Called when P2 dies in PvP - P1 wins!"""

	# CRITICAL: Check if fight already ended (both died simultaneously)
	if fight_ended:
		print("[Room15_BossUrgathon] Fight already ended, ignoring P2 death")
		return

	print("[Room15_BossUrgathon] === P2 DIED - P1 WINS! ===")

	# Disable further damage
	fight_ended = true

	# Restore P1 to player group
	if player:
		player.remove_from_group("enemies")
		player.add_to_group("player")
		print("[Room15_BossUrgathon] P1 restored to player group")

		# COMMIT 023.9.2: Restore hurtbox layer from EnemyHurtbox (9) to PlayerHurtbox (10)
		if player.has_node("HurtboxComponent"):
			var hurtbox = player.get_node("HurtboxComponent")
			hurtbox.collision_layer = 0
			hurtbox.set_collision_layer_value(10, true)  # PlayerHurtbox
			print("[Room15_BossUrgathon] P1 hurtbox restored to PlayerHurtbox layer")

		# COMMIT 023.9.3: Restore hitbox mask to check PlayerHurtbox (10) instead of EnemyHurtbox (9)
		if player.has_node("CombatSystem/HitboxComponent"):
			var hitbox = player.get_node("CombatSystem/HitboxComponent")
			hitbox.set_collision_mask_value(9, false)   # Stop checking EnemyHurtbox
			hitbox.set_collision_mask_value(10, true)   # Start checking PlayerHurtbox
			print("[Room15_BossUrgathon] P1 hitbox mask restored to normal (checks PlayerHurtbox)")

	# Disable PvP mode
	CoopManager.pvp_mode = false
	CoopManager.set_coop_collision()
	print("[Room15_BossUrgathon] PvP mode disabled, co-op collision restored")

	# Unlock exit door
	if exit_door and exit_door.has_method("unlock_door"):
		exit_door.unlock_door()
		print("[Room15_BossUrgathon] Exit door unlocked")

	# Fade arena boundary
	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate:a", 0.0, 2.0)

	print("[Room15_BossUrgathon] >>> VICTORY: Player 1 (Murum) wins! P1 can exit arena. <<<")


func _close_arena_barrier() -> void:
	"""Close the arena barrier to prevent escape during PvP"""

	# Make arena boundary fully visible
	if arena_boundary:
		var tween = create_tween()
		tween.tween_property(arena_boundary, "modulate:a", 0.8, 1.0)

	# Lock exit door
	if exit_door and exit_door.has_method("lock_door"):
		exit_door.lock_door()

	print("[Room15_BossUrgathon] Arena barrier closed")


func _show_dialog(text: String) -> void:
	"""Show dialog placeholder (COMMIT 023.8)"""
	if not dialog_label:
		dialog_label = Label.new()
		dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# Style
		dialog_label.add_theme_font_size_override("font_size", 32)
		dialog_label.add_theme_color_override("font_color", Color.WHITE)
		dialog_label.add_theme_color_override("font_outline_color", Color.BLACK)
		dialog_label.add_theme_constant_override("outline_size", 4)

		# Position (center of screen)
		dialog_label.position = Vector2(0, -200)  # Above center
		dialog_label.size = Vector2(800, 200)
		dialog_label.anchor_left = 0.5
		dialog_label.anchor_top = 0.5
		dialog_label.anchor_right = 0.5
		dialog_label.anchor_bottom = 0.5
		dialog_label.offset_left = -400
		dialog_label.offset_top = -100
		dialog_label.offset_right = 400
		dialog_label.offset_bottom = 100

		add_child(dialog_label)

	dialog_label.text = text
	dialog_label.visible = true
	print("[Room15_BossUrgathon] Dialog shown: ", text)


func _hide_dialog() -> void:
	"""Hide dialog placeholder"""
	if dialog_label:
		dialog_label.visible = false
	print("[Room15_BossUrgathon] Dialog hidden")


# ============================================================================
# UTILITY
# ============================================================================

func get_arena_bounds() -> Rect2:
	"""Returns the bounds of the arena for boss positioning"""

	# Circular arena with ~70m diameter (600x600 pixels)
	var center = global_position
	if boss_spawn:
		center = boss_spawn.global_position

	return Rect2(
		center - Vector2(300, 300),
		Vector2(600, 600)
	)
