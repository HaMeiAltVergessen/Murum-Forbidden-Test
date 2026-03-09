extends RefCounted
## Defines enemy compositions, wave configs, and rewards per node type and world
## Used by RunNodeRoom to configure ArenaController dynamically
class_name RunRoomPool

# ============ ENEMY SCENES (Welt 1: Das Niemandsland) ============
const ENEMY_SCENES_W1: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"hermit": "res://enemies/world_1_ruins/hermit.tscn",
	"glimmerseed": "res://enemies/world_1_ruins/glimmerseed.tscn",
	"ashworm_small": "res://enemies/placeholder/ashworm_small.tscn",
	"corpse_trap": "res://enemies/world_1_ruins/corpse_trap.tscn",
}

# ============ WAVE TEMPLATES ============
# Each template: Array of waves, each wave = Array of {scene_key, count}

# K+R: Kampf + Raetsel (2 waves, moderate difficulty)
const COMBAT_WAVES_W1: Array = [
	# Template 1: Mixed basic enemies
	[
		[{"key": "geist", "count": 2}, {"key": "hermit", "count": 1}],
		[{"key": "geist", "count": 1}, {"key": "glimmerseed", "count": 2}],
	],
	# Template 2: Swarm
	[
		[{"key": "ashworm_small", "count": 3}],
		[{"key": "ashworm_small", "count": 2}, {"key": "geist", "count": 1}],
	],
	# Template 3: Hermit focused
	[
		[{"key": "hermit", "count": 2}],
		[{"key": "hermit", "count": 1}, {"key": "corpse_trap", "count": 1}],
	],
	# Template 4: Glimmerseed garden
	[
		[{"key": "glimmerseed", "count": 3}],
		[{"key": "glimmerseed", "count": 2}, {"key": "geist", "count": 2}],
	],
]

# E+R: Elite + Raetsel (3 waves, harder)
const ELITE_WAVES_W1: Array = [
	# Template 1: Escalating
	[
		[{"key": "hermit", "count": 2}, {"key": "geist", "count": 1}],
		[{"key": "hermit", "count": 1}, {"key": "glimmerseed", "count": 2}, {"key": "corpse_trap", "count": 1}],
		[{"key": "hermit", "count": 2}, {"key": "ashworm_small", "count": 2}],
	],
	# Template 2: Swarm rush
	[
		[{"key": "ashworm_small", "count": 4}],
		[{"key": "geist", "count": 3}, {"key": "ashworm_small", "count": 2}],
		[{"key": "hermit", "count": 2}, {"key": "corpse_trap", "count": 2}],
	],
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
		# Welt 2+3: noch nicht definiert, Fallback auf W1
		_:
			return ENEMY_SCENES_W1


static func get_wave_template(world_id: RunMapData.WorldId, node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> Array:
	"""Returns a random wave template for the given world and node type"""
	var templates: Array = []

	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			match node_type:
				RunMapData.NodeType.COMBAT_PUZZLE:
					templates = COMBAT_WAVES_W1
				RunMapData.NodeType.ELITE_PUZZLE:
					templates = ELITE_WAVES_W1
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


static func build_wave_configs(world_id: RunMapData.WorldId, node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> Array[ArenaWaveConfig]:
	"""Builds ArenaWaveConfig resources from a random template"""
	var template: Array = get_wave_template(world_id, node_type, rng)
	if template.is_empty():
		return []

	var enemy_scenes: Dictionary = get_enemy_scenes(world_id)
	var configs: Array[ArenaWaveConfig] = []
	var loaded_scenes: Dictionary = {}  # Cache loaded scenes

	for wave_index in range(template.size()):
		var wave_data: Array = template[wave_index]
		var config = ArenaWaveConfig.new()
		config.delay_before = 1.0 if wave_index == 0 else 0.5
		config.delay_after = 1.5

		for entry_data in wave_data:
			var key: String = entry_data["key"]
			var count: int = entry_data["count"]

			if not enemy_scenes.has(key):
				push_warning("[RunRoomPool] Unknown enemy key: %s" % key)
				continue

			# Load scene (cached)
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

		configs.append(config)

	return configs


static func get_reward_type(node_type: RunMapData.NodeType,
		rng: RandomNumberGenerator = null) -> String:
	"""Returns a random reward type for the given node type"""
	var pool: Array = []
	match node_type:
		RunMapData.NodeType.COMBAT_PUZZLE:
			pool = COMBAT_REWARDS
		RunMapData.NodeType.ELITE_PUZZLE:
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
