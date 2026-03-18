extends Node
## BoonManager handles the Pachron (Boon/Path) system for runs
## 5 Paths: Arthra, Raelear, Mur|rum, Noron, Sairias
## Each path has 5 tiers — tiers must be acquired in order
## Boons are run-volatile (cleared on run end)

# ============ CONSTANTS ============
const BOON_DATA_PATH: String = "res://data/boons/boons.json"
const PATH_IDS: Array = ["arthra", "raelear", "murrum", "noron", "sairias"]
const MAX_TIER: int = 5
const BOON_CHOICES_COUNT: int = 3  # How many boons to offer in elite rooms

# ============ SIGNALS ============
signal boon_acquired(path_id: String, tier: int, boon_data: Dictionary)
signal boon_upgraded(path_id: String, tier: int, new_level: int)
signal boons_cleared()
signal boon_choices_ready(choices: Array)  # Array of boon dicts

# ============ DATA ============
var _boon_database: Dictionary = {}  # path_id -> {name, theme, focus, color, boons: [{...}]}
var _all_boons: Dictionary = {}      # boon_id -> boon dict (flat lookup)

# ============ RUN STATE (volatile) ============
var active_boons: Dictionary = {}    # path_id -> Array[int] of acquired tiers (e.g. {"arthra": [1, 2]})
var boon_levels: Dictionary = {}     # boon_id -> int level (e.g. {"arthra_1": 2, "arthra_2": 1})
var _room_state: Dictionary = {}     # Per-room volatile state (kill counters, etc.)

# ============ ARTHRA T2 STATE ============
var arthra_kill_bonus: float = 0.0   # Current damage bonus from kills


func _ready() -> void:
	_load_boon_database()
	EventBus.enemy_died.connect(_on_enemy_died)
	if RunManager:
		RunManager.run_started.connect(_on_run_started)
		RunManager.run_ended.connect(_on_run_ended)
	print("[BoonManager] Initialized — %d paths, %d total boons" % [
		_boon_database.size(), _all_boons.size()
	])


# ============ LOADING ============
func _load_boon_database() -> void:
	if not FileAccess.file_exists(BOON_DATA_PATH):
		push_error("[BoonManager] boons.json not found!")
		return

	var file := FileAccess.open(BOON_DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		push_error("[BoonManager] Failed to parse boons.json: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	var paths: Dictionary = data.get("paths", {})

	for path_id in paths:
		var path_data: Dictionary = paths[path_id]
		_boon_database[path_id] = path_data

		var boons: Array = path_data.get("boons", [])
		for boon in boons:
			var boon_id: String = boon.get("id", "")
			if boon_id != "":
				_all_boons[boon_id] = boon
				_all_boons[boon_id]["path_id"] = path_id


# ============ BOON ACQUISITION ============
func add_boon(path_id: String, tier: int) -> bool:
	"""Acquires a boon. Returns false if invalid (wrong tier order, etc.)."""
	if not _boon_database.has(path_id):
		push_warning("[BoonManager] Unknown path: %s" % path_id)
		return false

	if tier < 1 or tier > MAX_TIER:
		push_warning("[BoonManager] Invalid tier: %d" % tier)
		return false

	# Check tier order — must have all previous tiers
	var current_tiers: Array = active_boons.get(path_id, [])
	if tier > 1 and not current_tiers.has(tier - 1):
		push_warning("[BoonManager] Missing prerequisite: %s T%d requires T%d" % [path_id, tier, tier - 1])
		return false

	if current_tiers.has(tier):
		push_warning("[BoonManager] Already have: %s T%d" % [path_id, tier])
		return false

	# Acquire
	if not active_boons.has(path_id):
		active_boons[path_id] = []
	active_boons[path_id].append(tier)

	var boon_data: Dictionary = get_boon_data(path_id, tier)
	boon_acquired.emit(path_id, tier, boon_data)
	print("[BoonManager] Boon acquired: %s T%d — %s" % [path_id, tier, boon_data.get("name", "?")])
	return true


func add_boon_by_id(boon_id: String) -> bool:
	"""Acquires a boon by its unique ID (e.g. 'arthra_2')."""
	var boon: Dictionary = _all_boons.get(boon_id, {})
	if boon.is_empty():
		return false
	return add_boon(boon["path_id"], boon["tier"])


# ============ QUERIES ============
func has_boon(path_id: String, tier: int) -> bool:
	"""Returns true if the player has this specific boon active."""
	return active_boons.get(path_id, []).has(tier)


func get_highest_tier(path_id: String) -> int:
	"""Returns the highest acquired tier for a path (0 if none)."""
	var tiers: Array = active_boons.get(path_id, [])
	if tiers.is_empty():
		return 0
	return tiers.max()


func get_next_available_tier(path_id: String) -> int:
	"""Returns the next tier that can be acquired (0 if maxed out)."""
	var highest: int = get_highest_tier(path_id)
	if highest >= MAX_TIER:
		return 0
	return highest + 1


func get_boon_data(path_id: String, tier: int) -> Dictionary:
	"""Returns the boon data dict for a specific path + tier."""
	var boon_id: String = "%s_%d" % [path_id, tier]
	return _all_boons.get(boon_id, {})


func get_path_data(path_id: String) -> Dictionary:
	"""Returns the full path data (name, theme, color, etc.)."""
	return _boon_database.get(path_id, {})


func get_path_color(path_id: String) -> Color:
	"""Returns the color for a path as Color."""
	var data: Dictionary = _boon_database.get(path_id, {})
	var c: Array = data.get("color", [1.0, 1.0, 1.0])
	return Color(c[0], c[1], c[2])


func get_active_boon_count() -> int:
	"""Returns total number of active boons across all paths."""
	var count: int = 0
	for path_id in active_boons:
		count += active_boons[path_id].size()
	return count


func get_all_active_boons() -> Array:
	"""Returns array of all active boon dicts."""
	var result: Array = []
	for path_id in active_boons:
		for tier in active_boons[path_id]:
			var boon: Dictionary = get_boon_data(path_id, tier)
			if not boon.is_empty():
				result.append(boon)
	return result


# ============ BOON SELECTION (for Elite rooms) ============
func get_boon_choices() -> Array:
	"""Returns BOON_CHOICES_COUNT boons to offer the player.
	Each boon is the NEXT available tier for a different path.
	Paths that are maxed out are excluded."""
	var available: Array = []

	for path_id in PATH_IDS:
		var next_tier: int = get_next_available_tier(path_id)
		if next_tier == 0:
			continue  # Path maxed out
		var boon: Dictionary = get_boon_data(path_id, next_tier)
		if not boon.is_empty():
			available.append(boon)

	# Shuffle and pick up to BOON_CHOICES_COUNT
	available.shuffle()
	var count: int = mini(BOON_CHOICES_COUNT, available.size())
	var choices: Array = available.slice(0, count)

	boon_choices_ready.emit(choices)
	return choices


# ============ EFFECT PARAMETER HELPERS ============
func get_param(path_id: String, tier: int, param_name: String, default_value = null):
	"""Shorthand to get a boon's effect parameter (base value, no scaling)."""
	var boon: Dictionary = get_boon_data(path_id, tier)
	var params: Dictionary = boon.get("params", {})
	return params.get(param_name, default_value)


func get_scaled_param(path_id: String, tier: int, param_name: String, default_value: float = 0.0) -> float:
	"""Returns param scaled by boon level: base + (level-1) * scaling."""
	var boon: Dictionary = get_boon_data(path_id, tier)
	var params: Dictionary = boon.get("params", {})
	var base_value: float = float(params.get(param_name, default_value))

	var level: int = get_boon_level(path_id, tier)
	if level <= 1:
		return base_value

	var scaling: Dictionary = boon.get("level_scaling", {})
	var scale_per_level: float = float(scaling.get(param_name, 0.0))
	return base_value + (level - 1) * scale_per_level


func get_boon_level(path_id: String, tier: int) -> int:
	"""Returns the level of a boon (default 1 if acquired, 0 if not)."""
	if not has_boon(path_id, tier):
		return 0
	var boon_id: String = "%s_%d" % [path_id, tier]
	return boon_levels.get(boon_id, 1)


func upgrade_boon(path_id: String, tier: int) -> bool:
	"""Upgrades a boon by 1 level. Returns false if not owned."""
	if not has_boon(path_id, tier):
		push_warning("[BoonManager] Cannot upgrade: %s T%d not owned" % [path_id, tier])
		return false

	var boon_id: String = "%s_%d" % [path_id, tier]
	var current_level: int = boon_levels.get(boon_id, 1)
	var new_level: int = current_level + 1
	boon_levels[boon_id] = new_level

	boon_upgraded.emit(path_id, tier, new_level)
	if EventBus:
		EventBus.boon_upgraded.emit(path_id, tier, new_level)
	print("[BoonManager] Boon upgraded: %s T%d → Level %d" % [path_id, tier, new_level])
	return true


func get_upgradeable_boons(path_id: String) -> Array:
	"""Returns all acquired boons of a path that have level_scaling defined."""
	var result: Array = []
	var tiers: Array = active_boons.get(path_id, [])
	for tier in tiers:
		var boon: Dictionary = get_boon_data(path_id, tier)
		var scaling: Dictionary = boon.get("level_scaling", {})
		if not scaling.is_empty():
			result.append(boon)
	return result


func get_mana_regen_multiplier() -> float:
	"""Returns combined mana regen multiplier from all active boons (additive)."""
	var bonus: float = 0.0
	for path_id in active_boons:
		for tier in active_boons[path_id]:
			var regen_pct: float = get_scaled_param(path_id, tier, "mana_regen_percent", 0.0)
			bonus += regen_pct
	return 1.0 + bonus


func get_damage_multiplier() -> float:
	"""Returns combined damage multiplier from all active boons."""
	var multiplier: float = 1.0

	# Arthra T2: kill stacking
	if has_boon("arthra", 2):
		multiplier += arthra_kill_bonus

	return multiplier


# ============ ROOM STATE ============
func reset_room_state() -> void:
	"""Called when entering a new room — resets per-room boon state."""
	_room_state.clear()
	arthra_kill_bonus = 0.0

	# Raelear T5: reset death save
	if has_boon("raelear", 5):
		_room_state["clone_death_save_available"] = true

	print("[BoonManager] Room state reset")


func is_death_save_available() -> bool:
	"""Returns true if Raelear T5 death save can trigger."""
	return _room_state.get("clone_death_save_available", false)


func consume_death_save() -> void:
	"""Consumes the Raelear T5 death save for this room."""
	_room_state["clone_death_save_available"] = false
	print("[BoonManager] Death save consumed!")


# ============ EVENT HANDLERS ============
func _on_enemy_died(_enemy: Node, _position: Vector2) -> void:
	if not RunManager or not RunManager.is_run_active():
		return

	# Arthra T2: Unnachgiebiger Zorn — stack damage per kill
	if has_boon("arthra", 2):
		var max_bonus: float = get_param("arthra", 2, "max_bonus_percent", 0.4)
		var per_kill: float = get_param("arthra", 2, "damage_per_kill_percent", 0.05)
		arthra_kill_bonus = minf(arthra_kill_bonus + per_kill, max_bonus)


func _on_run_started() -> void:
	clear_boons()


func _on_run_ended(_victory: bool) -> void:
	clear_boons()


# ============ CLEAR ============
func clear_boons() -> void:
	"""Clears all active boons (called at run start/end)."""
	active_boons.clear()
	boon_levels.clear()
	_room_state.clear()
	arthra_kill_bonus = 0.0
	# Cleanup active boon effects (blades, DoTs, etc.)
	if BoonEffectHandler:
		BoonEffectHandler.cleanup()
	boons_cleared.emit()
	print("[BoonManager] All boons cleared")


# ============ SAVE/LOAD (for mid-run saves) ============
func get_save_data() -> Dictionary:
	return {
		"active_boons": active_boons.duplicate(true),
		"boon_levels": boon_levels.duplicate(true),
		"arthra_kill_bonus": arthra_kill_bonus,
	}


func load_from_save(data: Dictionary) -> void:
	active_boons = data.get("active_boons", {})
	boon_levels = data.get("boon_levels", {})
	arthra_kill_bonus = data.get("arthra_kill_bonus", 0.0)
	print("[BoonManager] Loaded: %d active boons" % get_active_boon_count())
