extends Node2D
## MirrorController — Coordinates the "Murum (Spiegel)" boss fight
## Inverted boss: Auto-scrolling runner with Momentum system instead of HP
class_name MirrorController

# ============ SIGNALS (same interface as HeroGroupController/KollektivController) ============
signal fight_started
signal defeated
signal health_changed(current_hp: float, max_hp: float)

# ============ SECTION CONFIG ============
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


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_fight_active or is_defeated:
		return

	# Update section timer
	section_timer += delta
	var config: Dictionary = SECTION_CONFIG[current_section]

	# Check section transition
	if section_timer >= config["duration"]:
		_advance_section()

	# Update scroll speed (finale ramps up)
	var scroll_speed: float = _get_current_scroll_speed()
	if runner_camera:
		runner_camera.scroll_speed = scroll_speed

	# Debug: log section/speed every 5 seconds
	if int(section_timer) % 5 == 0 and section_timer - delta < float(int(section_timer)):
		print("[MirrorController] Section %d (%s) | Timer: %.1fs/%.1fs | Speed: %.0f" % [
			current_section,
			SECTION_CONFIG[current_section]["name"],
			section_timer,
			config["duration"],
			scroll_speed
		])

	# Death zone check
	_check_death_zone(delta)

	# Emit health_changed as momentum (for compatibility)
	if momentum_system:
		health_changed.emit(momentum_system.momentum, 100.0)


# ============ FIGHT LIFECYCLE ============
func start_fight() -> void:
	if is_fight_active:
		return

	print("[MirrorController] Starting boss fight — Murum (Spiegel)!")

	# Setup subsystems
	_setup_runner_camera()
	_setup_background()
	_setup_chunk_spawner()
	_setup_momentum_system()
	_setup_momentum_bar()
	_setup_mirror_boss()

	# Start
	is_fight_active = true
	current_section = Section.DER_FALL
	section_timer = 0.0
	finisher_count = 0
	set_process(true)
	fight_started.emit()

	EventBus.boss_fight_started.emit("murum_mirror")

	# Show section title
	_show_section_title("Der Fall")

	print("[MirrorController] Fight started — Section 1: Der Fall")


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

	# Position boss ahead of player
	var player: Node2D = GameManager.player if GameManager else null
	if player and is_instance_valid(player):
		mirror_boss.global_position = player.global_position + Vector2(400, 0)
	else:
		mirror_boss.global_position = global_position + Vector2(400, 0)

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
		_death_zone_timer += delta
		if _death_zone_timer >= DEATH_ZONE_TICK:
			_death_zone_timer = 0.0
			# Deal damage
			if player.has_node("HealthComponent"):
				var health = player.get_node("HealthComponent")
				if health.has_method("take_damage"):
					health.take_damage(DEATH_ZONE_DAMAGE)
			# Reduce momentum
			if momentum_system:
				momentum_system.reduce_momentum(3.0)
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
		_start_defeat_sequence()


func _start_defeat_sequence() -> void:
	"""4th finisher landed — begin finale"""
	print("[MirrorController] All finishers landed — starting defeat sequence!")
	is_fight_active = false
	set_process(false)

	# Stop camera scrolling
	if runner_camera:
		runner_camera.scroll_speed = 0.0

	# Stop boss
	if mirror_boss and mirror_boss.has_method("enter_defeated_state"):
		mirror_boss.enter_defeated_state()

	# Defeat dialog sequence
	_play_defeat_dialog()


func _play_defeat_dialog() -> void:
	"""Finale dialog + defeat"""
	# Silence music
	if AudioManager:
		AudioManager.stop_music()

	# Brief pause before dialog
	await get_tree().create_timer(1.5).timeout

	# Dialog lines (shown via notifications for now)
	var lines: Array[Dictionary] = [
		{"speaker": "Spiegel", "text": "Du suchst Antworten.", "delay": 2.5},
		{"speaker": "Spiegel", "text": "Doch du bist nur die Frage.", "delay": 3.0},
		{"speaker": "Murum", "text": "Ich brauche keine Antworten.", "delay": 2.5},
	]

	for line in lines:
		EventBus.show_notification.emit("%s: %s" % [line["speaker"], line["text"]], line["delay"])
		await get_tree().create_timer(line["delay"] + 0.5).timeout

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


# ============ UTILITY ============
func _show_section_title(title: String) -> void:
	EventBus.show_notification.emit(title, 3.0)


func _get_p2_player() -> Node2D:
	if not CoopManager:
		return null
	return CoopManager.p2_instance


func get_mirror_boss() -> CharacterBody2D:
	return mirror_boss


func get_current_section() -> int:
	return current_section


func get_scroll_speed() -> float:
	return _get_current_scroll_speed()
