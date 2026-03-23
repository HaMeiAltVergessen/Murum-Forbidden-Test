extends Node2D
## MirrorController — Coordinates the "Murum (Spiegel)" boss fight
## Inverted boss: Auto-scrolling runner with Momentum system instead of HP
class_name MirrorController

# ============ SIGNALS (same interface as HeroGroupController/KollektivController) ============
signal fight_started
signal defeated
signal health_changed(current_hp: float, max_hp: float)

# ============ PHASE CONFIG (3 Boss Phases) ============
enum Phase { RUNNER, DER_FALL, FINALER_KAMPF }

# ============ SECTION CONFIG (Phase 1 sub-sections) ============
enum Section { DER_FALL, DER_SPIEGELKAMPF, DER_GEBROCHENE_ABGRUND, FINALE_VERFOLGUNG }

const SECTION_CONFIG: Dictionary = {
	Section.DER_FALL: {
		"name": "Der Fall",
		"scroll_speed": 200.0,
		"duration": 45.0,
		"chunk_pool": "fall",
	},
	Section.DER_SPIEGELKAMPF: {
		"name": "Der Spiegelkampf",
		"scroll_speed": 280.0,
		"duration": 60.0,
		"chunk_pool": "spiegel",
	},
	Section.DER_GEBROCHENE_ABGRUND: {
		"name": "Der gebrochene Abgrund",
		"scroll_speed": 350.0,
		"duration": 60.0,
		"chunk_pool": "abgrund",
	},
	Section.FINALE_VERFOLGUNG: {
		"name": "Finale Verfolgung",
		"scroll_speed": 400.0,
		"duration": 45.0,
		"chunk_pool": "finale",
	},
}

const FINALE_MAX_SPEED: float = 500.0

# ============ STATE ============
var is_fight_active: bool = false
var is_defeated: bool = false
var current_phase: int = Phase.RUNNER
var current_section: int = Section.DER_FALL
var section_timer: float = 0.0
var finisher_count: int = 0
var finishers_required: int = 4
var ending_modifiers: Dictionary = {}

# ============ CHILD REFERENCES ============
var runner_camera: Camera2D = null
var chunk_spawner: Node = null
var mirror_boss: CharacterBody2D = null
var momentum_system: Node = null
var momentum_bar: CanvasLayer = null

# ============ DIALOG SPEAKER IMAGES ============
const SPIEGEL_PORTRAIT: String = "res://Assets/AIPlaceholder/Char/Murum_Spiegel/mirrorai1.jpg"
const MURUM_PORTRAIT: String = "res://Assets/AIPlaceholder/Char/Murum/Murum.png"

# ============ BACKGROUND IMAGES (per section) ============
const BG_PATHS: Dictionary = {
	Section.DER_FALL: "res://Assets/AIPlaceholder/AlbtraumWelten/Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_29025.jpg",
	Section.DER_SPIEGELKAMPF: "res://Assets/AIPlaceholder/AlbtraumWelten/Welt3_Abgrund/2D_pixel_art_cosmic_horror_bac_GPT_Image_15_45960.jpg",
	Section.DER_GEBROCHENE_ABGRUND: "res://Assets/AIPlaceholder/AlbtraumWelten/Welt3_Abgrund/2D_pixel_art_cosmic_horror_env_GPT_Image_15_03661.jpg",
	Section.FINALE_VERFOLGUNG: "res://Assets/AIPlaceholder/AlbtraumWelten/Welt3_Abgrund/2D_pixel_art_cosmic_horror_bos_GPT_Image_15_12927.jpg",
}
var _bg_sprite: Sprite2D = null

# ============ DEATH ZONE ============
const DEATH_ZONE_OFFSET: float = -80.0  # px left of camera edge
const DEATH_ZONE_DAMAGE: int = 50
const DEATH_ZONE_TICK: float = 0.5
var _death_zone_timer: float = 0.0

# ============ FALL-OFF RESPAWN ============
const FALL_OFF_Y_OFFSET: float = 600.0  # Below camera center = fall-off
const FALL_OFF_DAMAGE: int = 20


func _ready() -> void:
	set_process(false)


func _input(event: InputEvent) -> void:
	if not is_fight_active or is_defeated:
		return
	# DEBUG: F9 = Momentum sofort auf 100 (Finisher-Fenster öffnet sich)
	if event.is_action_pressed("ui_page_down") or (event is InputEventKey and event.keycode == KEY_F9 and event.pressed):
		if momentum_system:
			momentum_system.add_momentum(100.0)
			print("[DEBUG] F9: Momentum auf 100 gesetzt!")


func _process(delta: float) -> void:
	if not is_fight_active or is_defeated:
		return

	# Phase 1: section-based progression
	if current_phase == Phase.RUNNER:
		section_timer += delta
		var config: Dictionary = SECTION_CONFIG[current_section]

		if section_timer >= config["duration"]:
			_advance_section()

		var scroll_speed: float = _get_current_scroll_speed()
		if runner_camera:
			runner_camera.scroll_speed = scroll_speed

		if int(section_timer) % 5 == 0 and section_timer - delta < float(int(section_timer)):
			print("[MirrorController] Section %d (%s) | Timer: %.1fs/%.1fs | Speed: %.0f" % [
				current_section,
				SECTION_CONFIG[current_section]["name"],
				section_timer,
				config["duration"],
				scroll_speed
			])

	# Death zone + fall-off (phase-dependent)
	if current_phase == Phase.RUNNER:
		_check_death_zone(delta)
		_check_fall_off()
	else:
		_check_vertical_death_zone()
		_check_vertical_side_bounds()

	# Emit health_changed (momentum in Phase 1, HP in Phase 2+3)
	if momentum_system:
		if current_phase == Phase.RUNNER:
			health_changed.emit(momentum_system.momentum, 100.0)
		elif mirror_boss and mirror_boss.has_node("HealthComponent"):
			var hc: HealthComponentGeneric = mirror_boss.get_node("HealthComponent")
			health_changed.emit(hc.current_hp, hc.max_hp)


# ============ FIGHT LIFECYCLE ============
func start_fight() -> void:
	if is_fight_active:
		return

	print("[MirrorController] Starting boss fight — Murum (Spiegel)!")

	# CRITICAL: Teleport player to GROUND_Y before setting up chunks
	# This ensures chunks spawn at the correct position relative to the player
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		var ground_surface_y: float = ChunkSpawner.GROUND_Y - 40.0  # Stand ON ground, not in it
		player.global_position.y = ground_surface_y
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		print("[MirrorController] Player teleported to ground level Y=%.0f" % ground_surface_y)

	# Setup subsystems
	_setup_runner_camera()
	_setup_background()
	_setup_chunk_spawner()
	_setup_momentum_system()
	_setup_momentum_bar()
	_setup_mirror_boss()

	# Start boss music
	if MusicScenePlayer:
		MusicScenePlayer.force_play_scene("W3Boss")

	# Opening dialog before fight begins
	await _play_opening_dialog()

	# Start
	is_fight_active = true
	current_phase = Phase.RUNNER
	current_section = Section.DER_FALL
	section_timer = 0.0
	finisher_count = 0
	set_process(true)
	fight_started.emit()

	EventBus.boss_fight_started.emit("murum_mirror")

	# Show section title
	_show_section_title("Der Fall")

	print("[MirrorController] Fight started — Section 1: Der Fall")


func _play_opening_dialog() -> void:
	"""Zeigt den Eröffnungsdialog via DialogManager bevor der Kampf beginnt"""
	# Kamera einfrieren während Dialog
	if runner_camera:
		runner_camera.scroll_speed = 0.0

	await get_tree().create_timer(0.8).timeout

	# Build dialog entries
	var entries: Array[DialogEntry] = [
		_make_dialog_entry("Spiegel", SPIEGEL_PORTRAIT, "Du bist die Frage, ich die Antwort."),
	]

	await _play_dialog(entries, "mirror_opening")

	# Kamera wieder starten
	if runner_camera:
		runner_camera.scroll_speed = SECTION_CONFIG[Section.DER_FALL]["scroll_speed"]


# ============ SUBSYSTEM SETUP ============
func _setup_runner_camera() -> void:
	runner_camera = preload("res://bosses/mirror/runner_camera.gd").new()
	runner_camera.name = "RunnerCamera"
	runner_camera.scroll_speed = SECTION_CONFIG[Section.DER_FALL]["scroll_speed"]

	# Position at player
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		runner_camera.global_position = player.global_position

	add_child(runner_camera)

	# Disable player camera, enable runner camera
	if player and is_instance_valid(player):
		var player_cam: Camera2D = player.get_node_or_null("PlayerCamera")
		if player_cam:
			player_cam.enabled = false
	runner_camera.enabled = true
	runner_camera.make_current()


func _setup_background() -> void:
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "BackgroundSprite"
	_bg_sprite.z_index = -20
	_bg_sprite.modulate = Color(0.6, 0.6, 0.6, 0.8)
	runner_camera.add_child(_bg_sprite)
	_update_background(Section.DER_FALL)


func _update_background(section: int) -> void:
	if not _bg_sprite:
		return
	var path: String = BG_PATHS.get(section, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex:
		_bg_sprite.texture = tex
		# Scale to fill viewport
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			_bg_sprite.scale = Vector2(1920.0 / tex_size.x, 1080.0 / tex_size.y) * 1.2


func _setup_chunk_spawner() -> void:
	chunk_spawner = preload("res://bosses/mirror/chunk_spawner.gd").new()
	chunk_spawner.name = "ChunkSpawner"
	chunk_spawner.controller = self
	add_child(chunk_spawner)
	chunk_spawner.start_spawning("fall")


func _setup_momentum_system() -> void:
	momentum_system = preload("res://bosses/mirror/momentum_system.gd").new()
	momentum_system.name = "MomentumSystem"
	momentum_system.controller = self
	add_child(momentum_system)


func _setup_momentum_bar() -> void:
	momentum_bar = preload("res://bosses/mirror/momentum_bar.gd").new()
	momentum_bar.name = "MomentumBar"
	momentum_bar.layer = 10
	momentum_bar.momentum_system = momentum_system
	momentum_bar.controller = self
	add_child(momentum_bar)


func _setup_mirror_boss() -> void:
	var boss_scene: PackedScene = load("res://bosses/mirror/mirror_boss.tscn")
	mirror_boss = boss_scene.instantiate()
	mirror_boss.controller = self

	# CRITICAL: Place boss on GROUND_Y (not floating in air)
	var player: Node2D = GameManager.player if GameManager else null
	var boss_x: float = global_position.x + 400.0
	if player and is_instance_valid(player):
		boss_x = player.global_position.x + 400.0
	var boss_ground_y: float = ChunkSpawner.GROUND_Y - 120.0  # Half body height above ground
	mirror_boss.global_position = Vector2(boss_x, boss_ground_y)

	get_parent().add_child(mirror_boss)

	# Activate boss AI
	mirror_boss.activate()


# ============ SECTION MANAGEMENT ============
func _advance_section() -> void:
	if current_section >= Section.FINALE_VERFOLGUNG:
		return  # Already at final section

	current_section += 1
	section_timer = 0.0

	var config: Dictionary = SECTION_CONFIG[current_section]
	print("[MirrorController] Section transition → %s (speed: %.0f)" % [config["name"], config["scroll_speed"]])

	# Update chunk pool
	if chunk_spawner:
		chunk_spawner.switch_pool(config["chunk_pool"])

	# Update camera speed
	if runner_camera:
		runner_camera.scroll_speed = config["scroll_speed"]

	_show_section_title(config["name"])

	# Update background
	_update_background(current_section)

	# Camera shake on transition
	if runner_camera and runner_camera.has_method("shake"):
		runner_camera.shake(6.0, 4.0)


func _get_current_scroll_speed() -> float:
	var config: Dictionary = SECTION_CONFIG[current_section]
	var base_speed: float = config["scroll_speed"]

	# Finale ramps up over time
	if current_section == Section.FINALE_VERFOLGUNG:
		var progress: float = section_timer / config["duration"]
		return lerpf(base_speed, FINALE_MAX_SPEED, clampf(progress, 0.0, 1.0))

	return base_speed


# ============ DEATH ZONE ============
func _check_death_zone(delta: float) -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	if not runner_camera:
		return

	# Death zone = left edge of camera viewport
	var cam_left: float = runner_camera.global_position.x - 960.0  # Half viewport width
	var death_x: float = cam_left + DEATH_ZONE_OFFSET

	if player.global_position.x < death_x:
		# Respawn at camera center with damage
		_respawn_at_camera_center(player)
		_death_zone_timer = 0.0
	else:
		_death_zone_timer = 0.0

	# P2 death zone check
	var p2: Node2D = _get_p2_player()
	if p2 and is_instance_valid(p2):
		if p2.global_position.x < death_x - 100.0:
			# P2 dies if too far behind
			if p2.has_node("HealthComponent"):
				var p2_health = p2.get_node("HealthComponent")
				if p2_health.has_method("take_damage"):
					p2_health.take_damage(9999)
			ending_modifiers["p2_died_in_mirror"] = true


# ============ FALL-OFF RESPAWN ============
func _check_fall_off() -> void:
	if not runner_camera:
		return

	var cam_y: float = runner_camera.global_position.y
	var fall_threshold: float = cam_y + FALL_OFF_Y_OFFSET

	# P1 fall-off check
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		if player.global_position.y > fall_threshold:
			_respawn_at_camera_center(player)

	# P2 fall-off check
	var p2: Node2D = _get_p2_player()
	if p2 and is_instance_valid(p2):
		if p2.global_position.y > fall_threshold:
			_respawn_at_camera_center(p2)


# ============ VERTICAL DEATH ZONE (Phase 2+3) ============
func _check_vertical_death_zone() -> void:
	"""Death zone = top edge of camera (player scrolled off screen above)"""
	if not runner_camera:
		return

	var cam_top: float = runner_camera.get_top_edge()
	var death_y: float = cam_top + DEATH_ZONE_OFFSET

	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		if player.global_position.y < death_y:
			_respawn_at_camera_center_vertical(player)

	# P2 check
	var p2: Node2D = _get_p2_player()
	if p2 and is_instance_valid(p2):
		if p2.global_position.y < death_y - 100.0:
			if p2.has_node("HealthComponent"):
				var p2_health = p2.get_node("HealthComponent")
				if p2_health.has_method("take_damage"):
					p2_health.take_damage(9999)
			ending_modifiers["p2_died_in_mirror"] = true


func _check_vertical_side_bounds() -> void:
	"""Clamp player X within viewport bounds during vertical fall"""
	if not runner_camera:
		return

	var cam_left: float = runner_camera.get_left_edge() + 32.0
	var cam_right: float = runner_camera.get_right_edge() - 32.0

	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		player.global_position.x = clampf(player.global_position.x, cam_left, cam_right)

	var p2: Node2D = _get_p2_player()
	if p2 and is_instance_valid(p2):
		p2.global_position.x = clampf(p2.global_position.x, cam_left, cam_right)


func _respawn_at_camera_center_vertical(character: Node2D) -> void:
	"""Respawn character at camera center during vertical fall"""
	if not runner_camera:
		return

	var respawn_pos := Vector2(runner_camera.global_position.x, runner_camera.global_position.y)
	character.global_position = respawn_pos
	if character is CharacterBody2D:
		character.velocity = Vector2.ZERO

	if character.has_node("HealthComponent"):
		var health = character.get_node("HealthComponent")
		if health.has_method("take_damage"):
			health.take_damage(FALL_OFF_DAMAGE)

	if momentum_system and momentum_system.has_method("add_knockdown_meter"):
		momentum_system.add_knockdown_meter(-5.0)

	if runner_camera:
		runner_camera.shake(4.0, 5.0)


func _respawn_at_camera_center(character: Node2D) -> void:
	if not runner_camera:
		return

	# Teleport to camera center on GROUND level (not boss position — boss may be floating)
	var ground_surface_y: float = ChunkSpawner.GROUND_Y - 40.0
	var respawn_x: float = runner_camera.global_position.x
	if mirror_boss and is_instance_valid(mirror_boss):
		# Slightly behind boss so player can see the boss
		respawn_x = mirror_boss.global_position.x - 150.0
	var respawn_pos := Vector2(respawn_x, ground_surface_y)
	character.global_position = respawn_pos
	if character is CharacterBody2D:
		character.velocity = Vector2.ZERO

	# Deal fall damage
	if character.has_node("HealthComponent"):
		var health = character.get_node("HealthComponent")
		if health.has_method("take_damage"):
			health.take_damage(FALL_OFF_DAMAGE)

	# Reduce momentum
	if momentum_system:
		momentum_system.reduce_momentum(5.0)

	# Camera shake feedback
	if runner_camera and runner_camera.has_method("shake"):
		runner_camera.shake(4.0, 5.0)


# ============ FINISHER SYSTEM ============
func on_finisher_landed() -> void:
	"""Called by MomentumSystem when player lands a finisher during MAX window"""
	finisher_count += 1
	print("[MirrorController] Finisher %d/%d landed!" % [finisher_count, finishers_required])

	# Camera shake (stronger each finisher)
	if runner_camera and runner_camera.has_method("shake"):
		runner_camera.shake(10.0 + finisher_count * 5.0, 3.0)

	if mirror_boss and mirror_boss.has_method("on_finisher_hit"):
		mirror_boss.on_finisher_hit(finisher_count)

	if finisher_count >= finishers_required:
		_start_transition_to_phase_2()


# ============ PHASE TRANSITIONS ============
func _start_transition_to_phase_2() -> void:
	"""4 finishers in Phase 1 → transition to Phase 2 (Der Fall / Free Fall)"""
	print("[MirrorController] Phase 1 complete — transitioning to Phase 2: Der Fall!")

	# 1. Stop camera scrolling
	if runner_camera:
		runner_camera.pause_scrolling()

	# 2. Screen shake + pause
	if runner_camera:
		runner_camera.shake(15.0, 3.0)
	_show_section_title("Der Fall")
	await get_tree().create_timer(1.5).timeout

	# 3. Clear all horizontal chunks
	if chunk_spawner:
		chunk_spawner.clear_all_chunks()

	# 4. Switch camera to vertical
	if runner_camera:
		runner_camera.switch_to_vertical()
		runner_camera.scroll_speed = 150.0  # Slower initial fall speed

	# 5. Switch chunk spawner to vertical
	if chunk_spawner:
		chunk_spawner.switch_to_vertical()
		chunk_spawner.switch_pool("fall_vertical")

	# 6. Resume scrolling (now vertical)
	if runner_camera:
		runner_camera.resume_scrolling()

	# 7. Update phase
	current_phase = Phase.DER_FALL
	finisher_count = 0  # Reset for knockdown tracking

	# 8. Switch boss AI to phase 2
	if mirror_boss and mirror_boss.has_method("switch_to_phase_2"):
		mirror_boss.switch_to_phase_2()

	# 9. Switch momentum system to knockdown mode
	if momentum_system and momentum_system.has_method("switch_to_knockdown_mode"):
		momentum_system.switch_to_knockdown_mode()

	# 10. Update HUD
	if momentum_bar and momentum_bar.has_method("switch_to_phase_2_hud"):
		momentum_bar.switch_to_phase_2_hud()

	print("[MirrorController] Phase 2 active — vertical free fall!")


func _start_transition_to_phase_3() -> void:
	"""4 knockdowns in Phase 2 → transition to Phase 3 (Finaler Kampf)"""
	print("[MirrorController] Phase 2 complete — transitioning to Phase 3: Finaler Kampf!")

	# Brief invulnerability + visual
	if mirror_boss and mirror_boss.has_method("set_temp_invulnerable"):
		mirror_boss.set_temp_invulnerable(2.0)
	if runner_camera:
		runner_camera.shake(20.0, 3.0)

	_show_section_title("Finaler Kampf")
	await get_tree().create_timer(1.5).timeout

	# Update phase
	current_phase = Phase.FINALER_KAMPF

	# Boss heals and becomes aggressive
	if mirror_boss and mirror_boss.has_method("switch_to_phase_3"):
		mirror_boss.switch_to_phase_3()

	# Switch chunk pool to finale
	if chunk_spawner:
		chunk_spawner.switch_pool("finale_vertical")

	# Increase camera speed
	if runner_camera:
		runner_camera.scroll_speed = 200.0

	# Update HUD
	if momentum_bar and momentum_bar.has_method("switch_to_phase_3_hud"):
		momentum_bar.switch_to_phase_3_hud()

	print("[MirrorController] Phase 3 active — finaler Kampf!")


func _start_defeat_sequence() -> void:
	"""Boss HP = 0 in Phase 3 — begin finale"""
	print("[MirrorController] Boss defeated — starting end sequence!")
	is_fight_active = false
	set_process(false)

	# 1. Stop camera scrolling
	if runner_camera:
		runner_camera.scroll_speed = 0.0
		runner_camera.pause_scrolling()

	# 2. Boss → DEFEATED
	if mirror_boss and mirror_boss.has_method("enter_defeated_state"):
		mirror_boss.enter_defeated_state()

	# 3. Spawn end platform under camera center
	var end_platform := StaticBody2D.new()
	end_platform.name = "EndPlatform"
	end_platform.collision_layer = 1
	end_platform.collision_mask = 0
	var plat_width: float = 800.0
	var plat_height: float = 32.0
	var cam_center: Vector2 = runner_camera.global_position if runner_camera else Vector2.ZERO
	end_platform.global_position = Vector2(cam_center.x, cam_center.y + 200.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(plat_width, plat_height)
	shape.shape = rect
	end_platform.add_child(shape)

	var visual := ColorRect.new()
	visual.size = Vector2(plat_width, plat_height)
	visual.position = Vector2(-plat_width * 0.5, -plat_height * 0.5)
	visual.color = Color(0.2, 0.15, 0.3)
	end_platform.add_child(visual)

	get_parent().add_child(end_platform)

	# 4. Teleport player (+ P2 + boss) onto platform
	var platform_surface_y: float = end_platform.global_position.y - plat_height * 0.5 - 40.0
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		player.global_position = Vector2(cam_center.x - 100.0, platform_surface_y)
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO

	var p2: Node2D = _get_p2_player()
	if p2 and is_instance_valid(p2):
		p2.global_position = Vector2(cam_center.x - 200.0, platform_surface_y)
		if p2 is CharacterBody2D:
			p2.velocity = Vector2.ZERO

	if mirror_boss and is_instance_valid(mirror_boss):
		mirror_boss.global_position = Vector2(cam_center.x + 100.0, platform_surface_y)
		mirror_boss.velocity = Vector2.ZERO

	# 5. Brief pause
	await get_tree().create_timer(1.5).timeout

	# 6. Defeat dialog
	_play_defeat_dialog()


func _play_defeat_dialog() -> void:
	"""Finale dialog via DialogManager + defeat"""
	# Silence music
	if AudioManager:
		AudioManager.stop_music()

	# Brief pause before dialog
	await get_tree().create_timer(1.5).timeout

	# Build dialog entries
	var entries: Array[DialogEntry] = [
		_make_dialog_entry("Spiegel", SPIEGEL_PORTRAIT, "Du suchst Antworten. Doch du bist nur die Frage."),
		_make_dialog_entry("Spiegel", SPIEGEL_PORTRAIT, "Ich gebe dir deine Antworten."),
		_make_dialog_entry("Murum", MURUM_PORTRAIT, "Ich brauche keine Antworten."),
	]

	await _play_dialog(entries, "mirror_defeat")

	# Final strike + dissolve
	await get_tree().create_timer(1.0).timeout

	# Boss dissolves
	if mirror_boss and is_instance_valid(mirror_boss):
		var tween := create_tween()
		tween.tween_property(mirror_boss, "modulate:a", 0.0, 2.0)
		await tween.finished
		mirror_boss.queue_free()

	# Fade to black
	await get_tree().create_timer(1.0).timeout

	_on_boss_defeated()


func _on_boss_defeated() -> void:
	if is_defeated:
		return

	print("[MirrorController] MURUM (SPIEGEL) DEFEATED!")
	is_defeated = true
	is_fight_active = false

	# Restore player camera
	_restore_player_camera()

	# Clean up
	if momentum_bar:
		momentum_bar.visible = false

	defeated.emit()
	EventBus.boss_defeated.emit("murum_mirror")


# ============ CLEANUP ============
func _restore_player_camera() -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		var player_cam: Camera2D = player.get_node_or_null("PlayerCamera")
		if player_cam:
			player_cam.enabled = true
			player_cam.make_current()

	if runner_camera:
		runner_camera.enabled = false


func _exit_tree() -> void:
	_restore_player_camera()
	if mirror_boss and is_instance_valid(mirror_boss):
		mirror_boss.queue_free()


# ============ DIALOG HELPERS ============
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
		EventBus.dialog_finished.connect(_on_mirror_dialog_finished, CONNECT_ONE_SHOT)

	DialogManager.play_dialog_resource(dialog)

	# Wait for dialog to finish
	await dialog_sequence_finished


signal dialog_sequence_finished


func _on_mirror_dialog_finished(_dialog_id: String) -> void:
	dialog_sequence_finished.emit()


# ============ UTILITY ============
func _show_section_title(title: String) -> void:
	_show_dialog_text(title, 3.0)


func _show_dialog_text(text: String, duration: float) -> void:
	"""Zeigt Text direkt als CanvasLayer-Label an (unabhaengig von HUD/EventBus)"""
	# Auch an EventBus senden falls HUD aktiv
	EventBus.show_notification.emit(text, duration)

	# Eigenes Label erstellen das immer funktioniert
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER_TOP
	label.position = Vector2(960.0 - 400.0, 200.0)
	label.size = Vector2(800.0, 60.0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate.a = 0.0
	layer.add_child(label)

	# Einblenden
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration - 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(layer.queue_free)


func _get_p2_player() -> Node2D:
	if not CoopManager:
		return null
	return CoopManager.p2_instance


func on_knockdown_triggered(knockdown_count: int) -> void:
	"""Called by MomentumSystem when knockdown meter hits 100 in Phase 2+3"""
	print("[MirrorController] Knockdown %d triggered!" % knockdown_count)

	if runner_camera:
		runner_camera.shake(12.0, 3.0)

	# Make boss enter knockdown state
	if mirror_boss and mirror_boss.has_method("enter_knockdown_state"):
		mirror_boss.enter_knockdown_state()


func on_knockdown_ended(knockdown_count: int) -> void:
	"""Called by MirrorBoss when knockdown timer expires"""
	print("[MirrorController] Knockdown %d ended" % knockdown_count)

	# Reset momentum system knockdown state
	if momentum_system and momentum_system.has_method("_end_knockdown"):
		momentum_system._end_knockdown()

	# After 4 knockdowns → Phase 3
	if knockdown_count >= 4 and current_phase == Phase.DER_FALL:
		_start_transition_to_phase_3()


func on_boss_hp_depleted() -> void:
	"""Called when boss HP reaches 0 in Phase 3"""
	if current_phase == Phase.FINALER_KAMPF:
		_start_defeat_sequence()


func get_mirror_boss() -> CharacterBody2D:
	return mirror_boss


func get_current_section() -> int:
	return current_section


func get_scroll_speed() -> float:
	if current_phase == Phase.RUNNER:
		return _get_current_scroll_speed()
	elif runner_camera:
		return runner_camera.scroll_speed
	return 200.0
