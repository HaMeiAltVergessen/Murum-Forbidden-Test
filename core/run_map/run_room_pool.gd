extends RefCounted
## Defines enemy compositions and rewards per node type and world
## Used by RunNodeRoom to configure combat encounters
class_name RunRoomPool

# ============ ENEMY SCENES ============
const ENEMY_SCENES_W1: Dictionary = {
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"untote": "res://enemies/untote.tscn",
	"hermit": "res://enemies/world_1_ruins/hermit.tscn",
	"guardian_statue": "res://enemies/world_1_ruins/guardian_statue.tscn",
	"glimmerseed": "res://enemies/world_1_ruins/glimmerseed.tscn",
	"corpse_trap": "res://enemies/world_1_ruins/corpse_trap.tscn",
}

const ENEMY_SCENES_W2: Dictionary = {
	"sentinel_drone": "res://enemies/world_2_kollektiv/sentinel_drone.tscn",
	"enforcer": "res://enemies/world_2_kollektiv/enforcer.tscn",
	"mender": "res://enemies/world_2_kollektiv/mender.tscn",
	"disruptor": "res://enemies/world_2_kollektiv/disruptor.tscn",
	"vanguard": "res://enemies/world_2_kollektiv/vanguard.tscn",
	"hivemind_nexus": "res://enemies/world_2_kollektiv/hivemind_nexus.tscn",
}

const ENEMY_SCENES_W3: Dictionary = {
	# W3 neue Gegner
	"phase_wraith": "res://enemies/world_3_abgrund/phase_wraith.tscn",
	"hollow_vessel": "res://enemies/world_3_abgrund/hollow_vessel.tscn",
	"abyssal_anchor": "res://enemies/world_3_abgrund/abyssal_anchor.tscn",
	"breach_hulk": "res://enemies/world_3_abgrund/breach_hulk.tscn",
	"echo_siren": "res://enemies/world_3_abgrund/echo_siren.tscn",
	"hollow_mender": "res://enemies/world_3_abgrund/hollow_mender.tscn",
	"tethered_warden": "res://enemies/world_3_abgrund/the_tethered.tscn",
	"tethered_beast": "res://enemies/world_3_abgrund/tethered_beast.tscn",
	"the_witness": "res://enemies/world_3_abgrund/the_witness.tscn",
	# W1+W2 Gegner (gemischt laut Design)
	"geist": "res://enemies/world_1_ruins/geist.tscn",
	"untote": "res://enemies/untote.tscn",
	"glimmerseed": "res://enemies/world_1_ruins/glimmerseed.tscn",
	"sentinel_drone": "res://enemies/world_2_kollektiv/sentinel_drone.tscn",
	"enforcer": "res://enemies/world_2_kollektiv/enforcer.tscn",
}

# ============ ENCOUNTER TEMPLATES ============
# Each template: single list of {scene_key, count} — all spawn at once, no waves

# === WELT 1: Niemandsland (Untote + Geist, Elite: Hermit) ===
const COMBAT_ENCOUNTERS_W1: Array = [
	[{"key": "geist", "count": 2}, {"key": "untote", "count": 1}],
	[{"key": "geist", "count": 3}],
	[{"key": "untote", "count": 2}, {"key": "geist", "count": 1}],
	[{"key": "untote", "count": 3}],
	[{"key": "untote", "count": 2}, {"key": "corpse_trap", "count": 2}],
	[{"key": "geist", "count": 2}, {"key": "glimmerseed", "count": 3}],
	[{"key": "guardian_statue", "count": 1}, {"key": "geist", "count": 1}],
]

const ELITE_ENCOUNTERS_W1: Array = [
	[{"key": "hermit", "count": 1}, {"key": "geist", "count": 2}],
	[{"key": "hermit", "count": 1}, {"key": "untote", "count": 2}],
	[{"key": "guardian_statue", "count": 1}, {"key": "untote", "count": 3}],
	[{"key": "guardian_statue", "count": 1}, {"key": "geist", "count": 2}],
]

# === WELT 2: Kollektiv (Sentinel Drone, Enforcer, Mender, Disruptor; Elite: Vanguard, Hivemind Nexus) ===
const COMBAT_ENCOUNTERS_W2: Array = [
	[{"key": "sentinel_drone", "count": 2}, {"key": "enforcer", "count": 1}],
	[{"key": "enforcer", "count": 2}, {"key": "mender", "count": 1}],
	[{"key": "sentinel_drone", "count": 3}, {"key": "mender", "count": 1}],
	[{"key": "disruptor", "count": 1}, {"key": "sentinel_drone", "count": 2}],
	[{"key": "enforcer", "count": 1}, {"key": "disruptor", "count": 1}, {"key": "mender", "count": 1}],
	[{"key": "sentinel_drone", "count": 2}, {"key": "disruptor", "count": 1}, {"key": "enforcer", "count": 1}],
]

const ELITE_ENCOUNTERS_W2: Array = [
	[{"key": "vanguard", "count": 1}, {"key": "enforcer", "count": 2}],
	[{"key": "vanguard", "count": 1}, {"key": "sentinel_drone", "count": 3}],
	[{"key": "hivemind_nexus", "count": 1}, {"key": "disruptor", "count": 1}],
	[{"key": "hivemind_nexus", "count": 1}, {"key": "enforcer", "count": 1}],
]

# === WELT 3: Abgrund (W3-Gegner + W1/W2 gemischt; Elite: Tethered-Paar, Witness) ===
const COMBAT_ENCOUNTERS_W3: Array = [
	[{"key": "phase_wraith", "count": 2}, {"key": "hollow_vessel", "count": 1}],
	[{"key": "hollow_vessel", "count": 2}, {"key": "echo_siren", "count": 1}],
	[{"key": "abyssal_anchor", "count": 1}, {"key": "phase_wraith", "count": 2}],
	[{"key": "breach_hulk", "count": 1}, {"key": "hollow_mender", "count": 1}],
	[{"key": "echo_siren", "count": 1}, {"key": "hollow_vessel", "count": 2}, {"key": "geist", "count": 1}],
	[{"key": "phase_wraith", "count": 1}, {"key": "sentinel_drone", "count": 2}, {"key": "hollow_mender", "count": 1}],
	[{"key": "abyssal_anchor", "count": 1}, {"key": "enforcer", "count": 1}, {"key": "hollow_vessel", "count": 1}],
	[{"key": "breach_hulk", "count": 1}, {"key": "echo_siren", "count": 1}, {"key": "phase_wraith", "count": 1}],
	[{"key": "hollow_mender", "count": 1}, {"key": "glimmerseed", "count": 3}, {"key": "untote", "count": 1}],
]

const ELITE_ENCOUNTERS_W3: Array = [
	[{"key": "tethered_warden", "count": 1}, {"key": "tethered_beast", "count": 1}],
	[{"key": "tethered_warden", "count": 1}, {"key": "tethered_beast", "count": 1}, {"key": "phase_wraith", "count": 1}],
	[{"key": "the_witness", "count": 1}, {"key": "hollow_vessel", "count": 2}],
	[{"key": "the_witness", "count": 1}, {"key": "echo_siren", "count": 1}],
]

# ============ REWARD POOLS ============
# Reward logic moved to RewardManager autoload
# Combat: Gold + 30% consumable drop
# Elite: Gold only (Boon placeholder for later)
# Treasure: 3 consumables to choose from
# Boss: Magicka + full heal


# ============ ROOM SCENE POOLS (handcrafted .tscn files per node type) ============
const ROOM_SCENES_W1: Dictionary = {
	RunMapData.NodeType.COMBAT: [
		"res://worlds/run_rooms/niemandsland/combat_room_01.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_02.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_03.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_04.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_05.tscn",
		"res://worlds/run_rooms/niemandsland/combat_room_06.tscn",
	],
	RunMapData.NodeType.ELITE: [
		"res://worlds/run_rooms/niemandsland/elite_room_01.tscn",
		"res://worlds/run_rooms/niemandsland/elite_room_02.tscn",
		"res://worlds/run_rooms/niemandsland/elite_room_03.tscn",
	],
	RunMapData.NodeType.TREASURE: [
		"res://worlds/run_rooms/niemandsland/treasure_room_01.tscn",
		"res://worlds/run_rooms/niemandsland/treasure_room_02.tscn",
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
		"res://worlds/run_rooms/kollektiv/pre_boss_room.tscn",
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
		"res://worlds/world_1_ruins/section_4_tempel/room_15_boss_urgathon.tscn",
	],
}

const ENTRY_ROOM_SCENES: Dictionary = {
	RunMapData.WorldId.NIEMANDSLAND: "res://worlds/run_rooms/niemandsland/entry_room.tscn",
	RunMapData.WorldId.KOLLEKTIV: "res://worlds/run_rooms/kollektiv/entry_room.tscn",
	RunMapData.WorldId.ABGRUND: "res://worlds/run_rooms/abgrund/entry_room.tscn",
}

# ============ ROOM DISPLAY NAMES (scene path → German in-game name) ============
const ROOM_DISPLAY_NAMES: Dictionary = {
	# === Welt 1: Das Niemandsland ===
	"res://worlds/run_rooms/niemandsland/entry_room.tscn": "Ruinen-Eingang",
	"res://worlds/run_rooms/niemandsland/combat_room_01.tscn": "Tempelhalle",
	"res://worlds/run_rooms/niemandsland/combat_room_02.tscn": "Mittlere Ebene",
	"res://worlds/run_rooms/niemandsland/combat_room_03.tscn": "Tempelvorplatz",
	"res://worlds/run_rooms/niemandsland/combat_room_04.tscn": "Verfallene Ruinen",
	"res://worlds/run_rooms/niemandsland/combat_room_05.tscn": "Vergessener Pfad",
	"res://worlds/run_rooms/niemandsland/combat_room_06.tscn": "Nebellichtung",
	"res://worlds/run_rooms/niemandsland/elite_room_01.tscn": "Tiefer Tempel",
	"res://worlds/run_rooms/niemandsland/elite_room_02.tscn": "Tempeltor",
	"res://worlds/run_rooms/niemandsland/elite_room_03.tscn": "Waechter der Schwelle",
	"res://worlds/run_rooms/niemandsland/treasure_room_01.tscn": "Schatzkammer",
	"res://worlds/run_rooms/niemandsland/treasure_room_02.tscn": "Verborgener Schrein",
	"res://worlds/run_rooms/niemandsland/rest_room_01.tscn": "Dorf der Verlorenen",
	"res://worlds/run_rooms/niemandsland/event_room_01.tscn": "Versteckte Kammer",
	"res://worlds/run_rooms/niemandsland/shop_room_01.tscn": "Letzter Haendler",
	"res://worlds/run_rooms/niemandsland/boss_room_01.tscn": "Heldengruppe-Arena",
	# === Welt 2: Das Kollektiv ===
	"res://worlds/run_rooms/kollektiv/entry_room.tscn": "Slum-Eingang",
	"res://worlds/run_rooms/kollektiv/combat_room_01.tscn": "Neon-Gassen",
	"res://worlds/run_rooms/kollektiv/combat_room_02.tscn": "Kneipen",
	"res://worlds/run_rooms/kollektiv/combat_room_03.tscn": "Aufzuege",
	"res://worlds/run_rooms/kollektiv/combat_room_04.tscn": "Wolkenkratzer",
	"res://worlds/run_rooms/kollektiv/combat_room_05.tscn": "Docks auf den Daechern",
	"res://worlds/run_rooms/kollektiv/elite_room_01.tscn": "Kollektiv-Mecha",
	"res://worlds/run_rooms/kollektiv/elite_room_02.tscn": "AI-Assassine",
	"res://worlds/run_rooms/kollektiv/treasure_room_01.tscn": "Tech-Schatzkammer",
	"res://worlds/run_rooms/kollektiv/rest_room_01.tscn": "Schmuggler-Versteck",
	"res://worlds/run_rooms/kollektiv/event_room_01.tscn": "Wohnung",
	"res://worlds/run_rooms/kollektiv/shop_room_01.tscn": "Schwarzmarkt",
	"res://worlds/run_rooms/kollektiv/boss_room_01.tscn": "Kollektiv-Arena",
	"res://worlds/run_rooms/kollektiv/pre_boss_room.tscn": "Synaptik-Kommandant",
	"res://worlds/run_rooms/kollektiv/transition_room.tscn": "Brainroom",
	# === Welt 3: Der Abgrund ===
	"res://worlds/run_rooms/abgrund/entry_room.tscn": "Auge des Abgrunds",
	"res://worlds/run_rooms/abgrund/combat_room_01.tscn": "Verzerrte Zeit",
	"res://worlds/run_rooms/abgrund/combat_room_02.tscn": "Tiefe",
	"res://worlds/run_rooms/abgrund/combat_room_03.tscn": "Augen",
	"res://worlds/run_rooms/abgrund/combat_room_04.tscn": "Fleisch",
	"res://worlds/run_rooms/abgrund/combat_room_05.tscn": "Abstieg",
	"res://worlds/run_rooms/abgrund/combat_room_06.tscn": "Gehirn",
	"res://worlds/run_rooms/abgrund/elite_room_01.tscn": "Alptraum-Vision",
	"res://worlds/run_rooms/abgrund/elite_room_02.tscn": "Stimme der Leere",
	"res://worlds/run_rooms/abgrund/treasure_room_01.tscn": "Verzerrte Schatzkammer",
	"res://worlds/run_rooms/abgrund/rest_room_01.tscn": "Das letzte Licht",
	"res://worlds/run_rooms/abgrund/event_room_01.tscn": "Elysium",
	"res://worlds/run_rooms/abgrund/event_room_02.tscn": "Urgathon",
	"res://worlds/run_rooms/abgrund/shop_room_01.tscn": "Loch im Abgrund",
	"res://worlds/run_rooms/abgrund/boss_room_01.tscn": "Das Siegel",
	"res://worlds/run_rooms/abgrund/pre_boss_room.tscn": "Nurdurun",
	"res://worlds/world_1_ruins/section_4_tempel/room_15_boss_urgathon.tscn": "Lythrun-Arena",
}

static func get_display_name(scene_path: String) -> String:
	return ROOM_DISPLAY_NAMES.get(scene_path, "")


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
		_rng: RandomNumberGenerator = null) -> String:
	"""Returns the reward type label for the given node type.
	Actual reward logic is in RewardManager."""
	match node_type:
		RunMapData.NodeType.COMBAT: return "gold"
		RunMapData.NodeType.ELITE: return "gold"
		RunMapData.NodeType.TREASURE: return "item"
		RunMapData.NodeType.REST: return "heal"
		RunMapData.NodeType.EVENT: return "event"
		RunMapData.NodeType.BOSS: return "magicka"
		RunMapData.NodeType.SHOP: return "shop"
		RunMapData.NodeType.ARENA: return "arena"
	return "gold"
