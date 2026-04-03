extends Node2D
## KollektivController — Coordinates the 5-core + central hub boss fight
## "Das Kollektiv der Einen Stimme" — Welt 2 Boss
## Exposes same interface as HeroGroupController for run_node_room integration
class_name KollektivController

# ============ SIGNALS (same as HeroGroupController) ============
signal fight_started
signal defeated
signal health_changed(current_hp: float, max_hp: float)
signal core_destroyed(core: KollektivCore)
signal dialog_sequence_finished

# ============ CORE SCENE (for central hub only) ============
const HUB_SCENE: String = "res://bosses/kollektiv/cores/central_hub.tscn"

# Core ID mapping by node name prefix
const CORE_ID_MAP: Dictionary = {
	"EnergyCore": "energy",
	"DefenseCore": "defense",
	"MobilityCore": "mobility",
	"FabricatorCore": "fabricator",
	"CognitionCore": "cognition",
}

# ============ PORTRAITS (for dialog) ============
const MURUM_PORTRAIT := "res://Assets/AIPlaceholder/Char/Murum/Murum02.png"

# ============ DEATH VFX ============
const DEATH_VFX_SCENE: PackedScene = preload("res://vfx/boss/boss_death_explosion.tscn")

# ============ CORE COLORS (for VFX tinting) ============
const CORE_COLORS: Dictionary = {
	"energy": Color(1.0, 0.6, 0.1),     # Orange/Reactor
	"defense": Color(0.8, 0.2, 0.2),    # Red/Weapons
	"mobility": Color(0.2, 0.6, 1.0),   # Blue/Navigation
	"fabricator": Color(0.2, 0.8, 0.3),  # Green/Drones
	"cognition": Color(0.7, 0.3, 1.0),  # Purple/AI
}

# ============ ESCALATION ============
const ESCALATION: Array = [
	{"speed_mult": 1.0, "damage_mult": 1.0},   # 0 destroyed
	{"speed_mult": 1.1, "damage_mult": 1.0},   # 1 destroyed
	{"speed_mult": 1.2, "damage_mult": 1.1},   # 2 destroyed
	{"speed_mult": 1.4, "damage_mult": 1.2},   # 3 destroyed
	{"speed_mult": 1.6, "damage_mult": 1.3},   # 4 destroyed
]

# ============ STATE ============
var cores: Array[KollektivCore] = []
var alive_cores: Array[KollektivCore] = []
var destroyed_core_ids: Array[String] = []
var is_fight_active: bool = false
var is_defeated: bool = false
var total_max_hp: float = 0.0
var _central_hub: Node = null
var _in_final_phase: bool = false

# Cognition tracking
var _cognition_destroyed: bool = false
var _energy_destroyed: bool = false

# ============ HEALTH BAR ============
var health_bar: Node = null  # KollektivHealthBar

# ============ PLATFORMS ============
var _platforms: Array = []


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not is_fight_active or is_defeated:
		return


# ============ FIGHT LIFECYCLE ============
func start_fight() -> void:
	if is_fight_active:
		return

	print("[KollektivController] Starting boss fight!")

	# Find platforms already placed in scene
	_find_platforms()

	# Find cores already placed in scene
	_find_cores()

	# --- INTRO SEQUENCE ---
	await _play_intro_sequence()

	# Create health bar (after intro)
	_create_health_bar()

	# Start fight
	is_fight_active = true
	set_process(true)
	fight_started.emit()

	# Signal boss fight started for music etc.
	EventBus.boss_fight_started.emit("kollektiv")

	# Phase 1 music
	if MusicScenePlayer:
		MusicScenePlayer.force_play_scene("W2BossP1")

	# Activate all core systems after delay
	get_tree().create_timer(1.0).timeout.connect(func():
		for core in cores:
			core.activate_systems()
	)

	print("[KollektivController] Fight started — %d cores, %.0f total HP" % [cores.size(), total_max_hp])


func _find_cores() -> void:
	"""Find cores already placed in the scene (in 'kollektiv_core' group)"""
	var found_cores: Array = get_tree().get_nodes_in_group("kollektiv_core")

	for node in found_cores:
		var core: KollektivCore = node as KollektivCore
		if not core or core == self:
			continue

		# Determine core_id from node name
		var core_id: String = ""
		for name_prefix in CORE_ID_MAP.keys():
			if core.name.begins_with(name_prefix):
				core_id = CORE_ID_MAP[name_prefix]
				break

		if core_id.is_empty():
			push_warning("[KollektivController] Unknown core node: %s" % core.name)
			continue

		core.controller = self
		core.set_meta("core_id", core_id)

		# Connect signals
		core.destroyed.connect(_on_core_destroyed.bind(core_id))
		core.health_changed.connect(_on_core_health_changed)

		cores.append(core)
		alive_cores.append(core)
		total_max_hp += core.max_hp

	print("[KollektivController] Found %d cores in scene" % cores.size())


# ============ PLATFORMS ============
func _find_platforms() -> void:
	"""Find platforms already placed in the scene"""
	_platforms = get_tree().get_nodes_in_group("kollektiv_platform")
	print("[KollektivController] Found %d platforms in scene" % _platforms.size())


# ============ HEALTH BAR ============
func _create_health_bar() -> void:
	var hb_scene_path: String = "res://bosses/kollektiv/kollektiv_health_bar.tscn"
	if ResourceLoader.exists(hb_scene_path):
		var hb_scene: PackedScene = load(hb_scene_path)
		health_bar = hb_scene.instantiate()
		health_bar.setup(cores)

		var canvas := CanvasLayer.new()
		canvas.name = "BossHealthBarLayer"
		canvas.layer = 10
		add_child(canvas)
		canvas.add_child(health_bar)
	else:
		push_warning("[KollektivController] Health bar scene not found")


# ============ CORE EVENT HANDLERS ============
func _on_core_destroyed(core: KollektivCore, core_id: String) -> void:
	if core in alive_cores:
		alive_cores.erase(core)
	if core_id not in destroyed_core_ids:
		destroyed_core_ids.append(core_id)

	core_destroyed.emit(core)
	_update_total_health()

	print("[KollektivController] %s destroyed — %d alive, %d destroyed" % [core.core_name, alive_cores.size(), destroyed_core_ids.size()])

	# Core destruction VFX
	_play_core_destruction_vfx(core, core_id)

	# Apply specific destruction effects
	_apply_destruction_effect(core_id)

	# Update escalation for all remaining cores
	_update_escalation()

	# Escalation VFX: pulse remaining cores red
	_play_escalation_vfx()

	# Check if all cores destroyed → final phase
	if alive_cores.is_empty() and not _in_final_phase:
		_start_final_phase()


func _on_core_health_changed(_current: float, _max: float) -> void:
	_update_total_health()


func _update_total_health() -> void:
	var current_total: float = 0.0
	for core in cores:
		current_total += max(0, core.current_hp)
	if _central_hub and is_instance_valid(_central_hub) and _central_hub.has_method("get_hp_percent"):
		current_total += max(0, _central_hub.current_hp)
	health_changed.emit(current_total, total_max_hp)

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(cores, _central_hub)


# ============ ESCALATION ============
func _update_escalation() -> void:
	var level: int = min(destroyed_core_ids.size(), ESCALATION.size() - 1)
	var esc: Dictionary = ESCALATION[level]

	for core in alive_cores:
		core.speed_mult = esc["speed_mult"]
		core.damage_mult = esc["damage_mult"]
		core.cognition_active = not _cognition_destroyed

	print("[KollektivController] Escalation level %d — Speed: %.1fx, Damage: %.1fx" % [level, esc["speed_mult"], esc["damage_mult"]])


func _apply_destruction_effect(core_id: String) -> void:
	match core_id:
		"energy":
			_energy_destroyed = true
			print("[KollektivController] Energy Core destroyed — shields fall, ship overheats!")
			# Remove shields from cognition core if still alive
			for core in alive_cores:
				if core.has_method("remove_shield"):
					core.remove_shield()

		"defense":
			print("[KollektivController] Defense Core destroyed — turrets offline!")
			# Turrets are children of defense core, deactivated via deactivate_systems()

		"mobility":
			print("[KollektivController] Mobility Core destroyed — platforms stable!")
			# Platforms stop moving, laser walls stop
			for platform in _platforms:
				if platform.has_method("stop_moving"):
					platform.stop_moving()

		"fabricator":
			print("[KollektivController] Fabricator destroyed — drones explode!")
			# Kill all active drones
			for drone in get_tree().get_nodes_in_group("kollektiv_drone"):
				if is_instance_valid(drone) and drone.has_method("explode"):
					drone.explode()

		"cognition":
			_cognition_destroyed = true
			print("[KollektivController] Cognition Core destroyed — attacks chaotic!")
			# Update all remaining cores
			for core in alive_cores:
				core.cognition_active = false


# ============ FINAL PHASE ============
func _start_final_phase() -> void:
	_in_final_phase = true
	print("[KollektivController] ALL CORES DESTROYED — FINAL PHASE!")

	# Phase 2 music — final phase
	if MusicScenePlayer:
		MusicScenePlayer.force_play_scene("W2BossP2")

	# Brief pause for dramatic effect
	await get_tree().create_timer(2.0).timeout

	# Spawn Central Hub
	var hub_scene_path: String = HUB_SCENE
	if ResourceLoader.exists(hub_scene_path):
		var scene: PackedScene = load(hub_scene_path)
		_central_hub = scene.instantiate()
	else:
		_central_hub = _create_placeholder_hub()

	_central_hub.global_position = Vector2(1400, 1400)
	if _central_hub.has_signal("destroyed"):
		_central_hub.destroyed.connect(_on_hub_destroyed)
	if _central_hub.has_signal("health_changed"):
		_central_hub.health_changed.connect(_on_core_health_changed)

	total_max_hp += 80.0  # Hub HP
	get_parent().add_child(_central_hub)

	if _central_hub.has_method("activate_systems"):
		_central_hub.activate_systems()

	# Update health bar for final phase
	if health_bar and health_bar.has_method("start_final_phase"):
		health_bar.start_final_phase(_central_hub)

	print("[KollektivController] Central Hub spawned — 80 HP")


func _create_placeholder_hub() -> KollektivCore:
	"""Create placeholder central hub"""
	var hub := KollektivCore.new()
	hub.core_name = "Zentraler Kern"
	hub.max_hp = 80.0
	hub.core_color = Color(1.0, 0.85, 0.3)  # Gold

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 100)
	col.shape = rect
	hub.add_child(col)
	hub.collision_layer = 8
	hub.collision_mask = 0

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	hub.add_child(sprite)

	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.collision_layer = 1024
	hurtbox.collision_mask = 48
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var hb_shape := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(120, 120)
	hb_shape.shape = hb_rect
	hurtbox.add_child(hb_shape)
	hub.add_child(hurtbox)

	# Gold visual
	var visual := ColorRect.new()
	visual.size = Vector2(100, 100)
	visual.position = Vector2(-50, -50)
	visual.color = Color(1.0, 0.85, 0.3)
	hub.add_child(visual)

	var label := Label.new()
	label.text = "ZENTRALER KERN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-80, -80)
	label.size = Vector2(160, 20)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hub.add_child(label)

	return hub


func _on_hub_destroyed(_hub: KollektivCore) -> void:
	_on_all_cores_and_hub_defeated()


# ============ DEFEAT ============
func _on_all_cores_and_hub_defeated() -> void:
	if is_defeated:
		return

	print("[KollektivController] KOLLEKTIV DEFEATED!")
	is_defeated = true
	is_fight_active = false
	set_process(false)

	# Clean up remaining entities
	for drone in get_tree().get_nodes_in_group("kollektiv_drone"):
		if is_instance_valid(drone):
			_play_drone_death_vfx(drone)
			drone.queue_free()
	for pulse in get_tree().get_nodes_in_group("energy_pulse"):
		if is_instance_valid(pulse):
			pulse.queue_free()
	for laser in get_tree().get_nodes_in_group("laser_wall"):
		if is_instance_valid(laser):
			laser.queue_free()

	# Hide health bar
	if health_bar:
		health_bar.visible = false

	# --- DEFEAT SEQUENCE ---
	await _play_defeat_sequence()

	defeated.emit()
	EventBus.boss_defeated.emit("kollektiv")


# ============ UTILITY ============
func get_core_by_id(core_id: String) -> KollektivCore:
	for core in cores:
		if core.get_meta("core_id", "") == core_id:
			return core
	return null


func get_alive_count() -> int:
	return alive_cores.size()


# ============ INTRO SEQUENCE ============
func _play_intro_sequence() -> void:
	"""Plays intro: cores power up one by one, then Kollektiv speaks."""

	await get_tree().create_timer(0.5).timeout

	# Power up each core in sequence (flash + color pulse)
	for core in cores:
		if core and is_instance_valid(core) and core.sprite:
			# Start dark
			core.sprite.modulate = Color(0.2, 0.2, 0.2, 1.0)

	for core in cores:
		if core and is_instance_valid(core) and core.sprite:
			var core_id: String = core.get_meta("core_id", "")
			var target_color: Color = CORE_COLORS.get(core_id, core.core_color)

			# Flash white → settle to core color
			var tween := create_tween()
			tween.tween_property(core.sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
			tween.tween_property(core.sprite, "modulate", target_color, 0.3)
			await get_tree().create_timer(0.35).timeout

	await get_tree().create_timer(0.3).timeout

	# Intro dialog — Kollektiv speaks as one
	var entries: Array[DialogEntry] = [
		_make_dialog_entry("Kollektiv", "", "Einheit erkannt. Nicht kompatibel."),
		_make_dialog_entry("Kollektiv", "", "Wir sind Eins. Du wirst assimiliert — oder eliminiert."),
		_make_dialog_entry("Murum", MURUM_PORTRAIT, "Dann zeigt mir eure Einheit."),
	]

	await _play_dialog(entries, "kollektiv_intro")

	await get_tree().create_timer(0.5).timeout


# ============ CORE DESTRUCTION VFX ============
func _play_core_destruction_vfx(core: KollektivCore, core_id: String) -> void:
	"""Explosion + screen shake when a core is destroyed."""
	if not core or not is_instance_valid(core):
		return

	# Hitstop
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(0.2)

	# Core-colored explosion
	var vfx: GPUParticles2D = DEATH_VFX_SCENE.instantiate()
	vfx.scale = Vector2(0.7, 0.7)
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = core.global_position

	# Tint explosion to core color
	var color: Color = CORE_COLORS.get(core_id, Color.WHITE)
	vfx.modulate = color

	# Fade core sprite to dark
	if core.sprite and is_instance_valid(core.sprite):
		var tween := create_tween()
		tween.tween_property(core.sprite, "modulate", Color(0.15, 0.15, 0.15, 0.5), 0.6)

	# Notification
	var core_display_name: String = core.core_name if core.core_name != "" else core_id
	EventBus.show_notification.emit("%s zerstoert!" % core_display_name, 2.0)


func _play_escalation_vfx() -> void:
	"""Quick red pulse on all remaining alive cores when escalation increases."""
	for core in alive_cores:
		if core and is_instance_valid(core) and core.sprite:
			var core_id: String = core.get_meta("core_id", "")
			var original: Color = CORE_COLORS.get(core_id, core.core_color)
			var tween := create_tween()
			tween.tween_property(core.sprite, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.1)
			tween.tween_property(core.sprite, "modulate", original, 0.4)


func _play_drone_death_vfx(drone: Node) -> void:
	"""Small explosion when a drone is cleaned up."""
	if not drone or not is_instance_valid(drone):
		return

	var vfx: GPUParticles2D = DEATH_VFX_SCENE.instantiate()
	vfx.scale = Vector2(0.25, 0.25)
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = drone.global_position
	vfx.modulate = Color(0.3, 0.8, 0.3)  # Green tint (fabricator color)


# ============ DEFEAT SEQUENCE ============
func _play_defeat_sequence() -> void:
	"""Hub destroyed — dramatic multi-explosion chain + victory dialog."""

	# Hitstop
	if GlobalTimeEffects:
		GlobalTimeEffects.hit_stop(0.5)
	await get_tree().create_timer(0.5, true, false, true).timeout

	# Slowmo
	if GlobalTimeEffects:
		GlobalTimeEffects.slow_motion(0.3, 2.5)

	# Chain explosions across all core positions (staggered)
	var all_positions: Array[Vector2] = []
	for core in cores:
		if core and is_instance_valid(core):
			all_positions.append(core.global_position)
	if _central_hub and is_instance_valid(_central_hub):
		all_positions.append(_central_hub.global_position)

	for pos in all_positions:
		var vfx: GPUParticles2D = DEATH_VFX_SCENE.instantiate()
		vfx.scale = Vector2(0.6, 0.6)
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = pos
		await get_tree().create_timer(0.12).timeout

	await get_tree().create_timer(0.5).timeout

	# Big central explosion at hub position
	if _central_hub and is_instance_valid(_central_hub):
		var big_vfx: GPUParticles2D = DEATH_VFX_SCENE.instantiate()
		big_vfx.scale = Vector2(1.5, 1.5)
		get_tree().current_scene.add_child(big_vfx)
		big_vfx.global_position = _central_hub.global_position
		big_vfx.modulate = Color(1.0, 0.85, 0.3)  # Gold

	await get_tree().create_timer(0.5).timeout

	# Dissolve all core visuals
	var dissolve_tweens: Array = []
	for core in cores:
		if core and is_instance_valid(core) and core.sprite:
			var tween := create_tween()
			tween.tween_property(core.sprite, "modulate:a", 0.0, 1.0)
			dissolve_tweens.append(tween)
	if _central_hub and is_instance_valid(_central_hub):
		var hub_sprite = _central_hub.get_node_or_null("Sprite2D")
		if hub_sprite:
			var tween := create_tween()
			tween.tween_property(hub_sprite, "modulate:a", 0.0, 1.0)
			dissolve_tweens.append(tween)

	if not dissolve_tweens.is_empty():
		await dissolve_tweens[0].finished

	await get_tree().create_timer(0.5).timeout

	# Victory dialog
	var entries: Array[DialogEntry] = [
		_make_dialog_entry("Kollektiv", "", "Ein...heit... zer...brochen..."),
		_make_dialog_entry("Murum", MURUM_PORTRAIT, "Eure Stimme ist verstummt."),
	]
	await _play_dialog(entries, "kollektiv_victory")


# ============ DIALOG HELPERS ============
func _make_dialog_entry(speaker_name: String, portrait_path: String, text: String) -> DialogEntry:
	var entry := DialogEntry.new()
	entry.speaker_name = speaker_name
	entry.text = text
	entry.text_speed = 35.0

	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		entry.speaker_sprite = load(portrait_path)

	return entry


func _play_dialog(entries: Array[DialogEntry], dialog_id: String) -> void:
	var dialog := DialogData.new()
	dialog.dialog_id = dialog_id
	dialog.entries = entries

	if EventBus:
		EventBus.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	DialogManager.play_dialog_resource(dialog)
	await dialog_sequence_finished


func _on_dialog_finished(_dialog_id: String) -> void:
	dialog_sequence_finished.emit()
