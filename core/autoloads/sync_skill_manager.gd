extends Node
## SyncSkillManager — Manages Pachron Sync Skills (cross-path combinations)
## Requirements: T5 in one path + T3+ in the other path
## Chance to be offered at altar: 30% (T3), 60% (T4), 80% (T5) of the lower-tier path
## Sync skills are run-volatile (cleared on run end)

# ============ CONSTANTS ============
const SYNC_DATA_PATH: String = "res://data/boons/sync_skills.json"
const SYNC_DIALOG_PATH: String = "res://data/pachron_dialogs/sync/"

# Chance to offer sync at altar based on the LOWER tier of the two paths
const SYNC_CHANCE_T3: float = 0.30
const SYNC_CHANCE_T4: float = 0.60
const SYNC_CHANCE_T5: float = 0.80

# ============ SIGNALS ============
signal sync_skill_acquired(sync_id: String, sync_data: Dictionary)
signal sync_skills_cleared()

# ============ DATA ============
var _sync_database: Dictionary = {}  # sync_id -> sync dict

# ============ RUN STATE (volatile) ============
var active_syncs: Dictionary = {}  # sync_id -> sync dict (acquired this run)


func _ready() -> void:
	_load_sync_database()
	if RunManager:
		RunManager.run_started.connect(_on_run_started)
		RunManager.run_ended.connect(_on_run_ended)
	print("[SyncSkillManager] Initialized — %d sync skills loaded" % _sync_database.size())


# ============ LOADING ============
func _load_sync_database() -> void:
	if not FileAccess.file_exists(SYNC_DATA_PATH):
		push_error("[SyncSkillManager] sync_skills.json not found!")
		return

	var file := FileAccess.open(SYNC_DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		push_error("[SyncSkillManager] Failed to parse sync_skills.json: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	_sync_database = data.get("sync_skills", {})


# ============ SYNC SKILL QUERIES ============
func has_sync(sync_id: String) -> bool:
	"""Returns true if this sync skill is active in the current run."""
	return active_syncs.has(sync_id)


func get_sync_data(sync_id: String) -> Dictionary:
	"""Returns the full sync skill data dict."""
	return _sync_database.get(sync_id, {})


func get_sync_param(sync_id: String, param_name: String, default_value = null):
	"""Returns a parameter from an active sync skill."""
	var sync: Dictionary = _sync_database.get(sync_id, {})
	var params: Dictionary = sync.get("params", {})
	return params.get(param_name, default_value)


func get_all_active_syncs() -> Array:
	"""Returns array of all active sync skill dicts."""
	return active_syncs.values()


func get_active_sync_count() -> int:
	return active_syncs.size()


# ============ ELIGIBILITY & CHANCE ============
func get_eligible_syncs() -> Array:
	"""Returns all sync_ids whose prerequisites are met (T5 + T3+ on the pair).
	Does NOT check chance — just hard requirements."""
	var eligible: Array = []

	for sync_id in _sync_database:
		if active_syncs.has(sync_id):
			continue  # Already acquired

		var sync: Dictionary = _sync_database[sync_id]
		var path_a: String = sync.get("path_a", "")
		var path_b: String = sync.get("path_b", "")

		var tier_a: int = BoonManager.get_highest_tier(path_a)
		var tier_b: int = BoonManager.get_highest_tier(path_b)

		# Need T5 on one side and T3+ on the other
		var valid: bool = false
		if tier_a >= 5 and tier_b >= 3:
			valid = true
		elif tier_b >= 5 and tier_a >= 3:
			valid = true

		if valid:
			eligible.append(sync_id)

	return eligible


func get_eligible_syncs_for_path(path_id: String) -> Array:
	"""Returns eligible sync_ids that involve a specific path."""
	var all_eligible: Array = get_eligible_syncs()
	var result: Array = []

	for sync_id in all_eligible:
		var sync: Dictionary = _sync_database[sync_id]
		if sync.get("path_a", "") == path_id or sync.get("path_b", "") == path_id:
			result.append(sync_id)

	return result


func get_sync_chance(sync_id: String) -> float:
	"""Returns the chance (0.0-1.0) for a sync to be offered, based on the lower tier."""
	var sync: Dictionary = _sync_database.get(sync_id, {})
	var path_a: String = sync.get("path_a", "")
	var path_b: String = sync.get("path_b", "")

	var tier_a: int = BoonManager.get_highest_tier(path_a)
	var tier_b: int = BoonManager.get_highest_tier(path_b)

	# The "lower" tier determines chance (the one that's NOT T5)
	var lower_tier: int = mini(tier_a, tier_b)

	match lower_tier:
		3: return SYNC_CHANCE_T3
		4: return SYNC_CHANCE_T4
		5: return SYNC_CHANCE_T5
		_: return 0.0  # Shouldn't happen if eligible


func roll_sync_offer(path_id: String) -> Dictionary:
	"""Attempts to roll a sync skill offer for the selected path.
	Returns the sync data dict if successful, empty dict if not.
	Only one sync is offered per altar visit."""
	var eligible: Array = get_eligible_syncs_for_path(path_id)

	if eligible.is_empty():
		return {}

	# Shuffle so it's not always the same order
	eligible.shuffle()

	# Try each eligible sync — first one that passes the chance roll wins
	for sync_id in eligible:
		var chance: float = get_sync_chance(sync_id)
		var roll: float = randf()
		print("[SyncSkillManager] Rolling sync %s: chance=%.0f%%, roll=%.2f" % [sync_id, chance * 100, roll])

		if roll < chance:
			print("[SyncSkillManager] Sync offered: %s" % sync_id)
			return _sync_database[sync_id]

	return {}


# ============ ACQUISITION ============
func acquire_sync(sync_id: String) -> bool:
	"""Acquires a sync skill. Returns false if invalid or already owned."""
	if not _sync_database.has(sync_id):
		push_warning("[SyncSkillManager] Unknown sync: %s" % sync_id)
		return false

	if active_syncs.has(sync_id):
		push_warning("[SyncSkillManager] Already have sync: %s" % sync_id)
		return false

	var sync_data: Dictionary = _sync_database[sync_id]
	active_syncs[sync_id] = sync_data

	sync_skill_acquired.emit(sync_id, sync_data)
	if EventBus:
		EventBus.sync_skill_acquired.emit(sync_id, sync_data)

	print("[SyncSkillManager] Sync acquired: %s — %s" % [sync_id, sync_data.get("name", "?")])
	return true


func get_partner_path(sync_id: String, selected_path: String) -> String:
	"""Returns the other path in a sync pair."""
	var sync: Dictionary = _sync_database.get(sync_id, {})
	var path_a: String = sync.get("path_a", "")
	var path_b: String = sync.get("path_b", "")
	if selected_path == path_a:
		return path_b
	return path_a


func get_sync_color(sync_id: String) -> Color:
	"""Returns the blended color for a sync skill."""
	var sync: Dictionary = _sync_database.get(sync_id, {})
	var c: Array = sync.get("icon_color", [1.0, 1.0, 1.0])
	return Color(c[0], c[1], c[2])


# ============ CLEAR ============
func clear_syncs() -> void:
	"""Clears all active sync skills (called at run start/end)."""
	active_syncs.clear()
	sync_skills_cleared.emit()
	print("[SyncSkillManager] All sync skills cleared")


# ============ EVENT HANDLERS ============
func _on_run_started() -> void:
	clear_syncs()


func _on_run_ended(_victory: bool) -> void:
	clear_syncs()


# ============ SAVE/LOAD (for mid-run saves) ============
func get_save_data() -> Dictionary:
	return {
		"active_syncs": active_syncs.duplicate(true),
	}


func load_from_save(data: Dictionary) -> void:
	active_syncs = data.get("active_syncs", {})
	print("[SyncSkillManager] Loaded: %d active syncs" % active_syncs.size())
