extends Node
## RewardManager handles all run reward logic
## Loads consumable pools from item_database.json, grouped by world
## Provides reward queries for combat, treasure, boss, and event rooms

# ============ CONSUMABLE POOLS (loaded from item_database.json) ============
var _consumable_pools: Dictionary = {}  # world_id -> Array[String] of item_ids
var _item_database: Dictionary = {}     # item_id -> item_data dict

# ============ GOLD RANGES PER WORLD ============
const GOLD_RANGES: Dictionary = {
	1: {"min": 15, "max": 25},
	2: {"min": 25, "max": 40},
	3: {"min": 40, "max": 60},
}

# ============ BOSS MAGICKA PER WORLD ============
const BOSS_MAGICKA: Dictionary = {
	1: 2,
	2: 3,
	3: 4,
}

# ============ COMBAT CONSUMABLE DROP CHANCE ============
const COMBAT_CONSUMABLE_DROP_CHANCE: float = 0.3

# ============ TREASURE CHOICE COUNT ============
const TREASURE_CHOICE_COUNT: int = 3

# ============ EVENT COMBAT REWARD ============
const EVENT_COMBAT_GOLD_MIN: int = 10
const EVENT_COMBAT_GOLD_MAX: int = 20
const EVENT_COMBAT_HEAL_PERCENT: float = 0.15


func _ready() -> void:
	_load_item_database()
	print("[RewardManager] Initialized — Pools: W1=%d, W2=%d, W3=%d" % [
		_consumable_pools.get(1, []).size(),
		_consumable_pools.get(2, []).size(),
		_consumable_pools.get(3, []).size(),
	])


# ============ LOADING ============
func _load_item_database() -> void:
	var path := "res://data/items/item_database.json"
	if not FileAccess.file_exists(path):
		push_error("[RewardManager] item_database.json not found!")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		push_error("[RewardManager] Failed to parse item_database.json")
		return

	var data: Dictionary = json.data
	var items: Array = data.get("items", [])

	for item in items:
		var item_id: String = item.get("id", "")
		if item_id.is_empty():
			continue

		_item_database[item_id] = item

		# Only consumables go into reward pools
		if item.get("type", "") != "consumable":
			continue

		var world: int = item.get("world", 1)
		if not _consumable_pools.has(world):
			_consumable_pools[world] = []
		_consumable_pools[world].append(item_id)


# ============ COMBAT REWARDS ============
func get_combat_gold(world_id: int) -> int:
	"""Returns random gold amount for a combat room in the given world"""
	var range_data: Dictionary = GOLD_RANGES.get(world_id, GOLD_RANGES[1])
	return randi_range(range_data["min"], range_data["max"])


func get_combat_consumable_drop(world_id: int) -> String:
	"""30% chance to return a consumable item_id, otherwise empty string"""
	if randf() > COMBAT_CONSUMABLE_DROP_CHANCE:
		return ""

	var pool: Array = _consumable_pools.get(world_id, [])
	if pool.is_empty():
		return ""

	return pool[randi() % pool.size()]


# ============ TREASURE REWARDS ============
func get_treasure_choices(world_id: int) -> Array:
	"""Returns array of TREASURE_CHOICE_COUNT unique consumable item_ids"""
	var pool: Array = _consumable_pools.get(world_id, []).duplicate()
	if pool.is_empty():
		return []

	pool.shuffle()
	var count: int = mini(TREASURE_CHOICE_COUNT, pool.size())
	return pool.slice(0, count)


# ============ BOSS REWARDS ============
func get_boss_magicka(world_id: int) -> int:
	"""Returns magicka amount for boss kill in given world"""
	return BOSS_MAGICKA.get(world_id, 2)


# ============ EVENT REWARDS ============
func get_event_combat_reward() -> Dictionary:
	"""Returns reward dict for winning an event NPC fight"""
	return {
		"gold": randi_range(EVENT_COMBAT_GOLD_MIN, EVENT_COMBAT_GOLD_MAX),
		"heal_percent": EVENT_COMBAT_HEAL_PERCENT,
	}


# ============ ITEM DATA ACCESS ============
func get_item_data(item_id: String) -> Dictionary:
	"""Returns the full item data dict for a given item_id"""
	return _item_database.get(item_id, {})


func get_item_name(item_id: String) -> String:
	"""Returns the display name for an item_id"""
	var data: Dictionary = _item_database.get(item_id, {})
	return data.get("name", item_id)


func get_item_description(item_id: String) -> String:
	"""Returns the effect description for an item_id"""
	var data: Dictionary = _item_database.get(item_id, {})
	return data.get("effect", data.get("description", ""))


func get_world_id_int(world_id: RunMapData.WorldId) -> int:
	"""Converts RunMapData.WorldId enum to int (1, 2, 3)"""
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return 1
		RunMapData.WorldId.KOLLEKTIV:
			return 2
		RunMapData.WorldId.ABGRUND:
			return 3
	return 1
