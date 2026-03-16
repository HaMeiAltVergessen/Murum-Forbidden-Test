extends Node2D
## HeroGroupController — Coordinates 5-hero boss fight
## Exposes same interface as BaseBoss for run_node_room integration
class_name HeroGroupController

# ============ SIGNALS (same as BaseBoss) ============
signal fight_started
signal defeated
signal health_changed(current_hp: float, max_hp: float)
signal hero_died(hero: HeroGroupMember)
signal hero_resurrected(hero: HeroGroupMember)
signal last_standing_triggered(hero: HeroGroupMember)

# ============ HERO SCENES ============
const HERO_SCENES: Dictionary = {
	"knight": "res://bosses/hero_group/heroes/hero_knight.tscn",
	"cleric": "res://bosses/hero_group/heroes/hero_cleric.tscn",
	"bloodhunter": "res://bosses/hero_group/heroes/hero_bloodhunter.tscn",
	"barbarian": "res://bosses/hero_group/heroes/hero_barbarian.tscn",
	"necromancer": "res://bosses/hero_group/heroes/hero_necromancer.tscn",
}

# ============ SPAWN POSITIONS (relative to controller position) ============
const SPAWN_OFFSETS: Dictionary = {
	"knight":      Vector2(-200,   0),
	"cleric":      Vector2(-300, -30),
	"necromancer": Vector2(-350, -20),
	"barbarian":   Vector2( 100,   0),
	"bloodhunter": Vector2( 200,   0),
}

# ============ STATE ============
var heroes: Array[HeroGroupMember] = []
var alive_heroes: Array[HeroGroupMember] = []
var dead_heroes: Array[HeroGroupMember] = []
var is_fight_active: bool = false
var is_defeated: bool = false
var total_max_hp: float = 0.0
var _coordination_timer: float = 0.0

# ============ HEALTH BAR ============
var health_bar: Node = null  # HeroGroupHealthBar


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_fight_active or is_defeated:
		return

	# AI coordination every 0.5s
	_coordination_timer += delta
	if _coordination_timer >= 0.5:
		_coordination_timer = 0.0
		_coordinate_ai()


# ============ FIGHT LIFECYCLE ============
func start_fight() -> void:
	if is_fight_active:
		return

	print("[HeroGroupController] Starting boss fight!")

	# Spawn all heroes
	_spawn_heroes()

	# Create health bar
	_create_health_bar()

	# Start fight after brief delay
	is_fight_active = true
	set_process(true)
	fight_started.emit()

	# Signal boss fight started for music etc.
	EventBus.boss_fight_started.emit("hero_group")

	print("[HeroGroupController] Fight started — %d heroes, %.0f total HP" % [heroes.size(), total_max_hp])


func _spawn_heroes() -> void:
	for key in HERO_SCENES.keys():
		var scene_path: String = HERO_SCENES[key]
		if not ResourceLoader.exists(scene_path):
			push_warning("[HeroGroupController] Scene not found: %s" % scene_path)
			continue

		var scene: PackedScene = load(scene_path)
		var hero: HeroGroupMember = scene.instantiate() as HeroGroupMember

		# Position relative to controller
		var offset: Vector2 = SPAWN_OFFSETS.get(key, Vector2.ZERO)
		hero.global_position = global_position + offset
		hero.controller = self

		# Connect signals
		hero.died.connect(_on_hero_died)
		hero.resurrected.connect(_on_hero_resurrected)
		hero.health_changed.connect(_on_hero_health_changed)

		get_parent().add_child(hero)
		heroes.append(hero)
		alive_heroes.append(hero)
		total_max_hp += hero.max_hp

	print("[HeroGroupController] Spawned %d heroes" % heroes.size())


# ============ HEALTH BAR ============
func _create_health_bar() -> void:
	var hb_scene_path: String = "res://bosses/hero_group/hero_group_health_bar.tscn"
	if ResourceLoader.exists(hb_scene_path):
		var hb_scene: PackedScene = load(hb_scene_path)
		health_bar = hb_scene.instantiate()
		health_bar.setup(heroes)

		# Add to CanvasLayer for HUD
		var canvas := CanvasLayer.new()
		canvas.name = "BossHealthBarLayer"
		canvas.layer = 10
		add_child(canvas)
		canvas.add_child(health_bar)
	else:
		push_warning("[HeroGroupController] Health bar scene not found")


# ============ HERO EVENT HANDLERS ============
func _on_hero_died(hero: HeroGroupMember) -> void:
	if hero in alive_heroes:
		alive_heroes.erase(hero)
	if hero not in dead_heroes:
		dead_heroes.append(hero)

	hero_died.emit(hero)
	_update_total_health()

	print("[HeroGroupController] %s died — %d alive, %d dead" % [hero.hero_name, alive_heroes.size(), dead_heroes.size()])

	# Necromancer passive: heal 20% on ally death
	for h in alive_heroes:
		if h.hero_name == "Nekromant" and h != hero:
			var heal_amount: float = h.max_hp * 0.2
			h.current_hp = min(h.current_hp + heal_amount, h.max_hp)
			h.health_changed.emit(h.current_hp, h.max_hp)
			print("[HeroGroupController] Necromancer healed %.0f from ally death" % heal_amount)

	# Check victory
	if alive_heroes.is_empty():
		_on_all_heroes_defeated()
		return

	# Check last standing
	if alive_heroes.size() == 1:
		var last: HeroGroupMember = alive_heroes[0]
		if not last.is_last_standing:
			last.activate_last_standing()
			last_standing_triggered.emit(last)


func _on_hero_resurrected(hero: HeroGroupMember) -> void:
	if hero in dead_heroes:
		dead_heroes.erase(hero)
	if hero not in alive_heroes:
		alive_heroes.append(hero)

	hero_resurrected.emit(hero)
	_update_total_health()
	print("[HeroGroupController] %s resurrected! %d alive" % [hero.hero_name, alive_heroes.size()])


func _on_hero_health_changed(_current: float, _max: float) -> void:
	_update_total_health()


func _update_total_health() -> void:
	var current_total: float = 0.0
	for hero in heroes:
		current_total += max(0, hero.current_hp)
	health_changed.emit(current_total, total_max_hp)

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(heroes)


# ============ DEFEAT ============
func _on_all_heroes_defeated() -> void:
	if is_defeated:
		return

	print("[HeroGroupController] ALL HEROES DEFEATED!")
	is_defeated = true
	is_fight_active = false
	set_process(false)

	# Hide health bar
	if health_bar:
		health_bar.visible = false

	defeated.emit()
	EventBus.boss_defeated.emit("hero_group")


# ============ AI COORDINATION ============
func _coordinate_ai() -> void:
	if alive_heroes.size() <= 1:
		return

	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Coordinate Cleric: stay behind tank
	var tank: HeroGroupMember = get_hero_by_name("Ritter")
	var cleric: HeroGroupMember = get_hero_by_name("Kleriker")

	if cleric and cleric.is_alive() and tank and tank.is_alive():
		# Cleric tries to stay 100px behind tank (away from player)
		var away_dir: float = -sign(player.global_position.x - tank.global_position.x)
		var ideal_x: float = tank.global_position.x + away_dir * 100.0
		cleric.set_meta("ideal_x", ideal_x)

	# Coordinate Necromancer: max distance from player
	var necro: HeroGroupMember = get_hero_by_name("Nekromant")
	if necro and necro.is_alive():
		necro.set_meta("keep_distance", 250.0)

	# Bloodhunter: flank from opposite side of tank
	var bh: HeroGroupMember = get_hero_by_name("Blutjaeger")
	if bh and bh.is_alive() and tank and tank.is_alive():
		var tank_side: float = sign(tank.global_position.x - player.global_position.x)
		bh.set_meta("flank_side", -tank_side)


# ============ UTILITY ============
func get_hero_by_name(name: String) -> HeroGroupMember:
	for hero in heroes:
		if hero.hero_name == name:
			return hero
	return null


func get_weakest_alive_hero() -> HeroGroupMember:
	var weakest: HeroGroupMember = null
	var lowest_percent: float = 2.0
	for hero in alive_heroes:
		var pct: float = hero.get_hp_percent()
		if pct < lowest_percent:
			lowest_percent = pct
			weakest = hero
	return weakest


func get_dead_heroes() -> Array[HeroGroupMember]:
	return dead_heroes


func get_alive_count() -> int:
	return alive_heroes.size()
