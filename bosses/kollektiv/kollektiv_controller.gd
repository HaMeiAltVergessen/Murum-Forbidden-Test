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

# ============ CORE SCENES ============
const CORE_SCENES: Dictionary = {
	"energy":     "res://bosses/kollektiv/cores/energy_core.tscn",
	"defense":    "res://bosses/kollektiv/cores/defense_core.tscn",
	"mobility":   "res://bosses/kollektiv/cores/mobility_core.tscn",
	"fabricator": "res://bosses/kollektiv/cores/fabricator_core.tscn",
	"cognition":  "res://bosses/kollektiv/cores/cognition_core.tscn",
}

# Core positions (absolute in 2800x2800 arena)
const CORE_POSITIONS: Dictionary = {
	"energy":     Vector2(1400, 2500),
	"defense":    Vector2(200, 1400),
	"mobility":   Vector2(1400, 200),
	"fabricator": Vector2(2600, 1400),
	"cognition":  Vector2(1400, 1400),
}

const HUB_SCENE: String = "res://bosses/kollektiv/cores/central_hub.tscn"

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

	# Spawn platforms first
	_spawn_platforms()

	# Spawn all cores
	_spawn_cores()

	# Create health bar
	_create_health_bar()

	# Start fight
	is_fight_active = true
	set_process(true)
	fight_started.emit()

	# Signal boss fight started for music etc.
	EventBus.boss_fight_started.emit("kollektiv")

	# Activate all core systems after delay
	get_tree().create_timer(1.0).timeout.connect(func():
		for core in cores:
			core.activate_systems()
	)

	print("[KollektivController] Fight started — %d cores, %.0f total HP" % [cores.size(), total_max_hp])


func _spawn_cores() -> void:
	for key in CORE_SCENES.keys():
		var scene_path: String = CORE_SCENES[key]
		if not ResourceLoader.exists(scene_path):
			push_warning("[KollektivController] Scene not found: %s — creating placeholder" % scene_path)
			_spawn_placeholder_core(key)
			continue

		var scene: PackedScene = load(scene_path)
		var core: KollektivCore = scene.instantiate() as KollektivCore
		if not core:
			push_warning("[KollektivController] Failed to instantiate: %s" % scene_path)
			_spawn_placeholder_core(key)
			continue

		core.global_position = CORE_POSITIONS[key]
		core.controller = self
		core.set_meta("core_id", key)

		# Connect signals
		core.destroyed.connect(_on_core_destroyed.bind(key))
		core.health_changed.connect(_on_core_health_changed)

		get_parent().add_child(core)
		cores.append(core)
		alive_cores.append(core)
		total_max_hp += core.max_hp

	print("[KollektivController] Spawned %d cores" % cores.size())


func _spawn_placeholder_core(core_id: String) -> void:
	"""Creates a minimal placeholder core when scene is missing"""
	var core := KollektivCore.new()
	core.core_name = _get_core_display_name(core_id)
	core.max_hp = _get_core_default_hp(core_id)
	core.core_color = _get_core_color(core_id)
	core.global_position = CORE_POSITIONS[core_id]
	core.controller = self
	core.set_meta("core_id", core_id)

	# Add minimal collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 80)
	col.shape = rect
	core.add_child(col)
	core.collision_layer = 8
	core.collision_mask = 0

	# Add sprite placeholder
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	core.add_child(sprite)

	# Add hurtbox
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.collision_layer = 1024
	hurtbox.collision_mask = 48
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	var hb_shape := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(100, 100)
	hb_shape.shape = hb_rect
	hurtbox.add_child(hb_shape)
	core.add_child(hurtbox)

	# Visual placeholder
	var visual := ColorRect.new()
	visual.size = Vector2(80, 80)
	visual.position = Vector2(-40, -40)
	visual.color = _get_core_color(core_id)
	core.add_child(visual)

	# Label
	var label := Label.new()
	label.text = core.core_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-60, -60)
	label.size = Vector2(120, 20)
	label.add_theme_font_size_override("font_size", 12)
	core.add_child(label)

	core.destroyed.connect(_on_core_destroyed.bind(core_id))
	core.health_changed.connect(_on_core_health_changed)

	get_parent().add_child(core)
	cores.append(core)
	alive_cores.append(core)
	total_max_hp += core.max_hp


# ============ PLATFORMS ============
func _spawn_platforms() -> void:
	"""Spawn the 9 platforms + floor + wall ledges"""
	var platform_positions: Array = [
		# Row 1 (y=500)
		Vector2(400, 500), Vector2(1400, 500), Vector2(2400, 500),
		# Row 2 (y=1000)
		Vector2(800, 1000), Vector2(1400, 1000), Vector2(2000, 1000),
		# Row 3 (y=1900)
		Vector2(400, 1900), Vector2(1400, 1900), Vector2(2400, 1900),
	]

	var platform_scene_path: String = "res://bosses/kollektiv/platforms/moving_platform.tscn"
	var has_scene: bool = ResourceLoader.exists(platform_scene_path)

	for i in range(platform_positions.size()):
		var pos: Vector2 = platform_positions[i]
		if has_scene:
			var scene: PackedScene = load(platform_scene_path)
			var platform = scene.instantiate()
			platform.global_position = pos
			get_parent().add_child(platform)
			_platforms.append(platform)
		else:
			_spawn_placeholder_platform(pos, i)

	# Wall ledges for cores
	_spawn_wall_ledge(Vector2(200, 1450), 120)   # Defense core ledge
	_spawn_wall_ledge(Vector2(2600, 1450), 120)  # Fabricator core ledge
	_spawn_wall_ledge(Vector2(1400, 250), 120)   # Mobility core ledge

	print("[KollektivController] Spawned %d platforms" % _platforms.size())


func _spawn_placeholder_platform(pos: Vector2, index: int) -> void:
	"""Create a simple StaticBody2D platform"""
	var platform := StaticBody2D.new()
	platform.name = "Platform_%d" % index
	platform.global_position = pos
	platform.collision_layer = 1
	platform.collision_mask = 0

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 20)
	col.shape = rect
	platform.add_child(col)

	var visual := ColorRect.new()
	visual.size = Vector2(200, 20)
	visual.position = Vector2(-100, -10)
	visual.color = Color(0.4, 0.4, 0.5)
	platform.add_child(visual)

	platform.add_to_group("kollektiv_platform")
	get_parent().add_child(platform)
	_platforms.append(platform)


func _spawn_wall_ledge(pos: Vector2, width: float) -> void:
	"""Spawn a static ledge near a core"""
	var ledge := StaticBody2D.new()
	ledge.name = "WallLedge"
	ledge.global_position = pos
	ledge.collision_layer = 1
	ledge.collision_mask = 0

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 16)
	col.shape = rect
	ledge.add_child(col)

	var visual := ColorRect.new()
	visual.size = Vector2(width, 16)
	visual.position = Vector2(-width * 0.5, -8)
	visual.color = Color(0.35, 0.35, 0.45)
	ledge.add_child(visual)

	get_parent().add_child(ledge)


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

	# Apply specific destruction effects
	_apply_destruction_effect(core_id)

	# Update escalation for all remaining cores
	_update_escalation()

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


func _get_core_display_name(core_id: String) -> String:
	match core_id:
		"energy": return "Energiekern"
		"defense": return "Verteidigungskern"
		"mobility": return "Navigationskern"
		"fabricator": return "Drohnenfabrik"
		"cognition": return "Kognitionskern"
	return "Kern"


func _get_core_default_hp(core_id: String) -> float:
	match core_id:
		"energy": return 200.0
		"defense": return 150.0
		"mobility": return 120.0
		"fabricator": return 150.0
		"cognition": return 180.0
	return 100.0


func _get_core_color(core_id: String) -> Color:
	match core_id:
		"energy": return Color(1.0, 0.6, 0.1)      # Orange
		"defense": return Color(0.3, 0.5, 0.9)      # Blue
		"mobility": return Color(0.3, 0.9, 0.4)     # Green
		"fabricator": return Color(0.7, 0.3, 0.9)   # Purple
		"cognition": return Color(0.2, 0.8, 0.9)    # Cyan
	return Color(0.7, 0.7, 0.7)
