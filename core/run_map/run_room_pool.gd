extends RefCounted
## Defines enemy compositions and rewards per node type and world
## Used by RunNodeRoom to configure combat encounters
class_name RunRoomPool

# ============ ENEMY SCENES (Welt 1: Das Niemandsland) ============
const ENEMY_SCENES_W1: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"hermit": "res://enemies/world_1_ruins/hermit.tscn",
	"glimmerseed": "res://enemies/world_1_ruins/glimmerseed.tscn",
	"ashworm_small": "res://enemies/placeholder/ashworm_small.tscn",
	"corpse_trap": "res://enemies/world_1_ruins/corpse_trap.tscn",
}

# ============ ENCOUNTER TEMPLATES ============
# Each template: single list of {scene_key, count} — all spawn at once, no waves

# K: Kampf (moderate difficulty, 3-4 enemies)
const COMBAT_ENCOUNTERS_W1: Array = [
	# Template 1: Mixed basic
	[{"key": "geist", "count": 2}, {"key": "hermit", "count": 1}],
	# Template 2: Swarm
	[{"key": "ashworm_small", "count": 3}, {"key": "geist", "count": 1}],
	# Template 3: Hermit duo
	[{"key": "hermit", "count": 2}, {"key": "corpse_trap", "count": 1}],
	# Template 4: Glimmerseed garden
	[{"key": "glimmerseed", "count": 3}, {"key": "geist", "count": 1}],
	# Template 5: Varied
	[{"key": "geist", "count": 1}, {"key": "hermit", "count": 1}, {"key": "ashworm_small", "count": 2}],
]

# E: Elite (harder, 5-7 enemies)
const ELITE_ENCOUNTERS_W1: Array = [
	# Template 1: Big mixed group
	[{"key": "hermit", "count": 2}, {"key": "geist", "count": 2}, {"key": "corpse_trap", "count": 1}],
	# Template 2: Swarm rush
	[{"key": "ashworm_small", "count": 4}, {"key": "hermit", "count": 2}],
	# Template 3: Trap-heavy
	[{"key": "corpse_trap", "count": 2}, {"key": "hermit", "count": 2}, {"key": "glimmerseed", "count": 2}],
]

# ============ REWARD POOLS ============
const COMBAT_REWARDS: Array = ["gold", "gold", "gold", "item"]
const ELITE_REWARDS: Array = ["relic", "relic", "item"]
const TREASURE_ITEM_COUNT: int = 3  # Player picks 1 of 3


# ============ STATIC API ============

static func get_enemy_scenes(world_id: RunMapData.WorldId) -> Dictionary:
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			return ENEMY_SCENES_W1
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

	if pool.is_empty():
		return "gold"

	var index: int = 0
	if rng:
		index = rng.randi_range(0, pool.size() - 1)
	else:
		index = randi() % pool.size()
	return pool[index]
