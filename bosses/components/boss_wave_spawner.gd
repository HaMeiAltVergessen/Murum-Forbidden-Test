extends Node
## BossWaveSpawner — Spawns enemy waves during boss fights
## Attach as child to any boss. Call start_spawning() / stop_spawning().
## Every SPAWN_INTERVAL seconds: either many small enemies or a single elite.
class_name BossWaveSpawner

# ============ CONFIG ============
const SPAWN_INTERVAL: float = 9.0
const SMALL_ENEMY_COUNT_MIN: int = 3
const SMALL_ENEMY_COUNT_MAX: int = 5
const SPAWN_RADIUS: float = 400.0  # Distance from player to spawn enemies
const ELITE_CHANCE: float = 0.35  # 35% chance for single elite instead of pack

# ============ ENEMY POOLS ============
const SMALL_ENEMIES: Array[String] = [
	"res://enemies/world_1_ruins/geist.tscn",
	"res://enemies/world_1_ruins/hermit.tscn",
	"res://enemies/world_1_ruins/glimmerseed.tscn",
	"res://enemies/world_1_ruins/corpse_trap.tscn",
	"res://enemies/placeholder/ashworm_small.tscn",
	"res://enemies/placeholder/fire_worm.tscn",
	"res://enemies/placeholder/nightborne.tscn",
]

const ELITE_ENEMIES: Array[String] = [
	"res://enemies/world_1_ruins/guardian_statue.tscn",
	"res://enemies/placeholder/ashworm_medium.tscn",
	"res://enemies/placeholder/dark_fantasy.tscn",
	"res://enemies/placeholder/monster_creature.tscn",
	"res://enemies/placeholder/golem.tscn",
	"res://enemies/placeholder/bringer_of_death.tscn",
]

# ============ STATE ============
var _timer: float = 0.0
var _is_active: bool = false
var _spawned_enemies: Array[Node] = []
var _valid_small: Array[String] = []
var _valid_elite: Array[String] = []


func _ready() -> void:
	# Filter pools to only scenes that actually exist
	for path in SMALL_ENEMIES:
		if ResourceLoader.exists(path):
			_valid_small.append(path)
	for path in ELITE_ENEMIES:
		if ResourceLoader.exists(path):
			_valid_elite.append(path)

	print("[BossWaveSpawner] Pool: %d small, %d elite enemies" % [_valid_small.size(), _valid_elite.size()])


func _process(delta: float) -> void:
	if not _is_active:
		return

	_timer += delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		_spawn_wave()

	# Clean up dead references
	_spawned_enemies = _spawned_enemies.filter(func(e): return is_instance_valid(e))


# ============ CONTROL ============
func start_spawning() -> void:
	_is_active = true
	_timer = 0.0
	print("[BossWaveSpawner] Started — waves every %.0fs" % SPAWN_INTERVAL)


func stop_spawning() -> void:
	_is_active = false
	print("[BossWaveSpawner] Stopped")


func stop_and_clear() -> void:
	"""Stop spawning and kill all spawned enemies"""
	_is_active = false
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()
	print("[BossWaveSpawner] Stopped + cleared all spawned enemies")


# ============ SPAWNING ============
func _spawn_wave() -> void:
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	var is_elite: bool = randf() < ELITE_CHANCE and not _valid_elite.is_empty()

	if is_elite:
		_spawn_single_elite(player)
	else:
		_spawn_small_pack(player)


func _spawn_small_pack(player: Node2D) -> void:
	if _valid_small.is_empty():
		return

	var count: int = randi_range(SMALL_ENEMY_COUNT_MIN, SMALL_ENEMY_COUNT_MAX)
	print("[BossWaveSpawner] Spawning %d small enemies" % count)

	for i in range(count):
		var path: String = _valid_small[randi() % _valid_small.size()]
		var pos: Vector2 = _get_spawn_position(player, i, count)
		_spawn_enemy_at(path, pos)


func _spawn_single_elite(player: Node2D) -> void:
	if _valid_elite.is_empty():
		return

	var path: String = _valid_elite[randi() % _valid_elite.size()]
	var pos: Vector2 = _get_spawn_position(player, 0, 1)
	print("[BossWaveSpawner] Spawning elite: %s" % path.get_file())
	_spawn_enemy_at(path, pos)


func _spawn_enemy_at(scene_path: String, pos: Vector2) -> void:
	var scene: PackedScene = load(scene_path)
	if not scene:
		return

	var enemy: Node2D = scene.instantiate()
	enemy.global_position = pos

	# Add to current scene
	get_tree().current_scene.add_child(enemy)
	_spawned_enemies.append(enemy)


func _get_spawn_position(player: Node2D, index: int, total: int) -> Vector2:
	"""Spread enemies in a semicircle around the player"""
	var base_angle: float = randf() * TAU
	var angle: float = base_angle + (TAU / maxf(total, 1)) * index
	var offset := Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
	return player.global_position + offset
