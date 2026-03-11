extends RefCounted
## Defines enemy compositions and rewards per node type and world
## Used by RunNodeRoom to configure combat encounters
class_name RunRoomPool

# ============ ENEMY SCENES (Geist + Untote zum Testen) ============
const ENEMY_SCENES_W1: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"untote": "res://enemies/untote.tscn",
}

const ENEMY_SCENES_W2: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"untote": "res://enemies/untote.tscn",
}

const ENEMY_SCENES_W3: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"untote": "res://enemies/untote.tscn",
}

# ============ ENCOUNTER TEMPLATES ============
# Each template: single list of {scene_key, count} — all spawn at once, no waves

# K: Kampf
const COMBAT_ENCOUNTERS_W1: Array = [
	[{"key": "geist", "count": 2}, {"key": "untote", "count": 1}],
	[{"key": "geist", "count": 3}],
	[{"key": "untote", "count": 2}, {"key": "geist", "count": 1}],
]

# E: Elite
const ELITE_ENCOUNTERS_W1: Array = [
	[{"key": "untote", "count": 2}, {"key": "geist", "count": 3}],
	[{"key": "geist", "count": 4}, {"key": "untote", "count": 2}],
]

# W2: Kollektiv (etwas haerter)
const COMBAT_ENCOUNTERS_W2: Array = [
	[{"key": "geist", "count": 3}, {"key": "untote", "count": 1}],
	[{"key": "untote", "count": 2}, {"key": "geist", "count": 2}],
	[{"key": "geist", "count": 2}, {"key": "untote", "count": 2}],
]

const ELITE_ENCOUNTERS_W2: Array = [
	[{"key": "untote", "count": 3}, {"key": "geist", "count": 3}],
	[{"key": "geist", "count": 4}, {"key": "untote", "count": 2}],
]

# W3: Abgrund (am haertesten)
const COMBAT_ENCOUNTERS_W3: Array = [
	[{"key": "geist", "count": 3}, {"key": "untote", "count": 2}],
	[{"key": "untote", "count": 3}, {"key": "geist", "count": 2}],
	[{"key": "geist", "count": 4}, {"key": "untote", "count": 1}],
]

const ELITE_ENCOUNTERS_W3: Array = [
	[{"key": "untote", "count": 3}, {"key": "geist", "count": 4}],
	[{"key": "geist", "count": 5}, {"key": "untote", "count": 3}],
]

# ============ REWARD POOLS ============
const COMBAT_REWARDS: Array = ["gold", "gold", "gold", "item"]
const ELITE_REWARDS: Array = ["relic", "relic", "item"]
const TREASURE_ITEM_COUNT: int = 3  # Player picks 1 of 3


# ============ ROOM SCENE POOLS (handcrafted .tscn files per node type) ============
const ROOM_SCENES_W1: Dictionary = {
	RunMapData.NodeType.COMBAT: [
		"res://worlds/run_rooms/niemandsland/combat_room_01.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_02.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_03.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_04.tscn",
	],
	RunMapData.NodeType.ELITE: [
		"res://worlds/run_rooms/niemandsland/elite_room_01.tscn",
		"res://worlds/run_rooms/niemandsland/elite_room_02.tscn",
	],
	RunMapData.NodeType.TREASURE: [
		"res://worlds/run_rooms/niemandsland/treasure_room_01.tscn",
	],
	RunMapData.NodeType.REST: [
		"res://worlds/run_rooms/niemandsland/rest_room_01.tscn",
	],
	RunMapData.NodeType.EVENT: [
		"res://worlds/run_rooms/niemandsland/event_room_01.tscn",
	],
	RunMapData.NodeType.BOSS: [
		"res://worlds/run_rooms/niemandsland/boss_room_01.tscn",
	],
	RunMapData.NodeType.SHOP: [
		"res://worlds/run_rooms/niemandsland/shop_room_01.tscn",
	],
}

const ROOM_SCENES_W2: Dictionary = {
	RunMapData.NodeType.COMBAT: [
		"res://worlds/run_rooms/kollektiv/combat_room_01.tscn",
		"res://worlds/run_rooms/kollektiv/combat_room_02.tscn",
		"res://worlds/run_rooms/kollektiv/combat_room_03.tscn",
		"res://worlds/run_rooms/kollektiv/combat_room_04.tscn",
		"res://worlds/run_rooms/kollektiv/combat_room_05.tscn",
	],
	RunMapData.NodeType.ELITE: [
		"res://worlds/run_rooms/kollektiv/elite_room_01.tscn",
		"res://worlds/run_rooms/kollektiv/elite_room_02.tscn",
	],
	RunMapData.NodeType.TREASURE: [
		"res://worlds/run_rooms/kollektiv/treasure_room_01.tscn",
	],
	RunMapData.NodeType.REST: [
		"res://worlds/run_rooms/kollektiv/rest_room_01.tscn",
	],
	RunMapData.NodeType.EVENT: [
		"res://worlds/run_rooms/kollektiv/event_room_01.tscn",
	],
	RunMapData.NodeType.BOSS: [
		"res://worlds/run_rooms/kollektiv/boss_room_01.tscn",
	],
	RunMapData.NodeType.SHOP: [
		"res://worlds/run_rooms/kollektiv/shop_room_01.tscn",
	],
}

const ROOM_SCENES_W3: Dictionary = {
	RunMapData.NodeType.COMBAT: [
		"res://worlds/run_rooms/abgrund/combat_room_01.tscn",
		"res://worlds/run_rooms/abgrund/combat_room_02.tscn",
		"res://worlds/run_rooms/abgrund/combat_room_03.tscn",
		"res://worlds/run_rooms/abgrund/combat_room_04.tscn",
		"res://worlds/run_rooms/abgrund/combat_room_05.tscn",
		"res://worlds/run_rooms/abgrund/combat_room_06.tscn",
	],
	RunMapData.NodeType.ELITE: [
		"res://worlds/run_rooms/abgrund/elite_room_01.tscn",
		"res://worlds/run_rooms/abgrund/elite_room_02.tscn",
	],
	RunMapData.NodeType.TREASURE: [
		"res://worlds/run_rooms/abgrund/treasure_room_01.tscn",
	],
	RunMapData.NodeType.REST: [
		"res://worlds/run_rooms/abgrund/rest_room_01.tscn",
	],
	RunMapData.NodeType.EVENT: [
		"res://worlds/run_rooms/abgrund/event_room_01.tscn",
		"res://worlds/run_rooms/abgrund/event_room_02.tscn",
	],
	RunMapData.NodeType.BOSS: [
		"res://worlds/run_rooms/abgrund/boss_room_01.tscn",
	],
	RunMapData.NodeType.SHOP: [
		"res://worlds/run_rooms/abgrund/shop_room_01.tscn",
	],
	RunMapData.NodeType.ARENA: [
		"res://worlds/run_rooms/abgrund/arena_room_01.tscn",
	],
}

const ENTRY_ROOM_SCENES: Dictionary = {
	RunMapData.WorldId.NIEMANDSLAND: "res://worlds/run_rooms/niemandsland/entry_room.tscn",
	RunMapData.WorldId.KOLLEKTIV: "res://worlds/run_rooms/kollektiv/entry_room.tscn",
	RunMapData.WorldId.ABGRUND: "res://worlds/run_rooms/abgrund/entry_room.tscn",
}


# ============ STATIC API ============

static func get_room_scene_path(world_id: RunMapData.WorldId, node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> String:
	"""Returns a random room .tscn path for the given world and node type"""
	var pool: Dictionary = {}
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			pool = ROOM_SCENES_W1
		RunMapData.WorldId.KOLLEKTIV:
			pool = ROOM_SCENES_W2
		RunMapData.WorldId.ABGRUND:
			pool = ROOM_SCENES_W3
		_:
			pool = ROOM_SCENES_W1

	var scenes: Array = pool.get(node_type, [])
	if scenes.is_empty():
		push_warning("[RunRoomPool] No room scenes for type %d in world %d" % [node_type, world_id])
		return ""

	var index: int = 0
	if rng:
		index = rng.randi_range(0, scenes.size() - 1)
	else:
		index = randi() % scenes.size()
	return scenes[index]


static func get_entry_room_path(world_id: RunMapData.WorldId) -> String:
	return ENTRY_ROOM_SCENES.get(world_id, "")


static func get_enemy_scenes(world_id: RunMapData.WorldId) -> Dictionary:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return ENEMY_SCENES_W1
		RunMapData.WorldId.KOLLEKTIV:
			return ENEMY_SCENES_W2
		RunMapData.WorldId.ABGRUND:
			return ENEMY_SCENES_W3
		_:
			return ENEMY_SCENES_W1


static func get_encounter_template(world_id: RunMapData.WorldId, node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> Array:
	"""Returns a random encounter template (single group of enemies, no waves)"""
	var templates: Array = []

	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			match node_type:
				RunMapData.NodeType.COMBAT:
					templates = COMBAT_ENCOUNTERS_W1
				RunMapData.NodeType.ELITE:
					templates = ELITE_ENCOUNTERS_W1
				_:
					return []
		RunMapData.WorldId.KOLLEKTIV:
			match node_type:
				RunMapData.NodeType.COMBAT:
					templates = COMBAT_ENCOUNTERS_W2
				RunMapData.NodeType.ELITE:
					templates = ELITE_ENCOUNTERS_W2
				_:
					return []
		RunMapData.WorldId.ABGRUND:
			match node_type:
				RunMapData.NodeType.COMBAT:
					templates = COMBAT_ENCOUNTERS_W3
				RunMapData.NodeType.ELITE:
					templates = ELITE_ENCOUNTERS_W3
				_:
					return []

	if templates.is_empty():
		return []

	var index: int = 0
	if rng:
		index = rng.randi_range(0, templates.size() - 1)
	else:
		index = randi() % templates.size()

	return templates[index]


static func build_single_wave_config(world_id: RunMapData.WorldId, node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> ArenaWaveConfig:
	"""Builds a single ArenaWaveConfig with all enemies at once (no waves)"""
	var template: Array = get_encounter_template(world_id, node_type, rng)
	if template.is_empty():
		return null

	var enemy_scenes: Dictionary = get_enemy_scenes(world_id)
	var config = ArenaWaveConfig.new()
	config.delay_before = 1.0
	config.delay_after = 1.0
	var loaded_scenes: Dictionary = {}

	for entry_data in template:
		var key: String = entry_data["key"]
		var count: int = entry_data["count"]

		if not enemy_scenes.has(key):
			push_warning("[RunRoomPool] Unknown enemy key: %s" % key)
			continue

		if not loaded_scenes.has(key):
			var path: String = enemy_scenes[key]
			if ResourceLoader.exists(path):
				loaded_scenes[key] = load(path)
			else:
				push_warning("[RunRoomPool] Scene not found: %s" % path)
				continue

		var entry = ArenaEnemyEntry.new()
		entry.scene = loaded_scenes[key]
		entry.count = count
		config.enemies.append(entry)

	return config


static func get_reward_type(node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> String:
	"""Returns a random reward type for the given node type"""
	var pool: Array = []
	match node_type:
		RunMapData.NodeType.COMBAT:
			pool = COMBAT_REWARDS
		RunMapData.NodeType.ELITE:
			pool = ELITE_REWARDS
		RunMapData.NodeType.TREASURE:
			return "item"
		RunMapData.NodeType.REST:
			return "heal"
		RunMapData.NodeType.EVENT:
			return "event"
		RunMapData.NodeType.BOSS:
			return "boss"
		RunMapData.NodeType.SHOP:
			return "shop"
		RunMapData.NodeType.ARENA:
			return "arena"

	if pool.is_empty():
		return "gold"

	var index: int = 0
	if rng:
		index = rng.randi_range(0, pool.size() - 1)
	else:
		index = randi() % pool.size()
	return pool[index]
