extends Node
## PachronDialogSystem — Manages Pachron-specific dialog sequences.
## Uses the existing DialogManager with programmatically created DialogData resources.
## Tracks story progress, cycles through loop dialogs, and picks random filler.
## NOTE: No class_name — registered as autoload singleton "PachronDialogSystem"

# ============ SIGNALS ============
signal dialog_sequence_finished()

# ============ CONSTANTS ============
const DIALOG_DATA_PATH: String = "res://data/pachron_dialogs/"
const SYNC_DIALOG_PATH: String = "res://data/pachron_dialogs/sync/"
const ENDINGS_DIALOG_PATH: String = "res://data/pachron_dialogs/endings/"

## Maps EventBus boss_defeated IDs to the reaction key used in pachron JSON files.
const BOSS_REACTION_MAP: Dictionary = {
	"hero_group":    "boss_1_defeated",
	"kollektiv":     "boss_2_defeated",
	"murum_mirror":  "boss_3_defeated",
}

## Ending thresholds — share of runs in which a pachron was picked.
const ENDING_THRESHOLD_TREUE: float = 0.6
const ENDING_THRESHOLD_NEUTRAL: float = 0.2
const PACHRON_IMAGES: Dictionary = {
	"arthra": "res://Assets/AIPlaceholder/Char/Pachrons/Arthra/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_58172.jpg",
	"noron": "res://Assets/AIPlaceholder/Char/Pachrons/Noron/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_34835.jpg",
	"raelear": "res://Assets/AIPlaceholder/Char/Pachrons/Realear/_Use_the_provided_Murum_artwor_Nano_Banana_60213.jpg",
	"murrum": "res://Assets/AIPlaceholder/Char/Pachrons/Mur_rum/_Use_the_provided_Murum_artwor_Nano_Banana_78991.jpg",
	"sairias": "res://Assets/AIPlaceholder/Char/Pachrons/Sairias/_Use_the_provided_Murum_artwor_Nano_Banana_45046.jpg",
}

# ============ STATE ============
var _pachron_dialogs: Dictionary = {}     # path_id -> parsed JSON dict
var _seen_stories: Dictionary = {}        # path_id -> Array of seen story IDs (persistent)
var _loop_indices: Dictionary = {}        # path_id -> int (per run)
var _pending_reactions: Dictionary = {}   # path_id -> Array[String] reaction keys (persistent until played)
var _played_reactions_run: Dictionary = {}  # path_id -> Array[String] already played this run
var _selection_counts: Dictionary = {}    # path_id -> int (persistent selection count)
var _unified_ending_data: Dictionary = {} # loaded from endings/secret_unified.json
var _current_path_id: String = ""
var _is_farewell: bool = false


func _ready() -> void:
	_load_all_dialogs()
	_load_sync_dialogs()
	_load_unified_ending()
	if RunManager:
		RunManager.run_started.connect(_on_run_started)
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.schwellensicht_changed.connect(_on_schwellensicht_changed)
	print("[PachronDialogSystem] Initialized — %d pachron dialogs, %d sync dialogs loaded" % [_pachron_dialogs.size(), _sync_dialogs.size()])


func _on_run_started() -> void:
	reset_run_state()


# ============ LOADING ============
func _load_all_dialogs() -> void:
	for path_id in BoonManager.PATH_IDS:
		var file_path: String = DIALOG_DATA_PATH + path_id + ".json"
		if not FileAccess.file_exists(file_path):
			push_warning("[PachronDialogSystem] Dialog file missing: %s" % file_path)
			continue

		var file := FileAccess.open(file_path, FileAccess.READ)
		var json := JSON.new()
		var result := json.parse(file.get_as_text())
		file.close()

		if result != OK:
			push_error("[PachronDialogSystem] Failed to parse %s: %s" % [file_path, json.get_error_message()])
			continue

		_pachron_dialogs[path_id] = json.data


# ============ DIALOG FLOW ============
func start_dialog(path_id: String) -> void:
	"""Starts the full greeting + story/loop/filler dialog for a Pachron."""
	_current_path_id = path_id
	_is_farewell = false

	var dialog_data: Dictionary = _pachron_dialogs.get(path_id, {})
	if dialog_data.is_empty():
		print("[PachronDialogSystem] No dialog data for %s — skipping" % path_id)
		dialog_sequence_finished.emit()
		return

	# Build dialog entries: greeting + content
	var entries: Array[DialogEntry] = []

	# 1. Greeting
	var greeting: String = _pick_random(dialog_data.get("greetings", []))
	if greeting != "":
		entries.append(_make_entry(path_id, greeting))

	# 2. Pending world reactions (one-shot, from boss kills / schwellensicht)
	var reaction_beats: Array = _consume_pending_reaction(path_id, dialog_data)
	for beat in reaction_beats:
		if typeof(beat) == TYPE_STRING and beat != "":
			entries.append(_make_entry(path_id, beat))

	# 3. Story (if new one available) OR Loop OR Wegwerf — may return multiple beats
	var content_beats: Array = _get_content_beats(path_id, dialog_data)
	for beat in content_beats:
		if typeof(beat) == TYPE_STRING and beat != "":
			entries.append(_make_entry(path_id, beat))

	if entries.is_empty():
		dialog_sequence_finished.emit()
		return

	if EventBus:
		EventBus.pachron_dialog_started.emit(path_id)
	_play_entries(path_id, entries)


func play_farewell(path_id: String) -> void:
	"""Plays a farewell dialog line for the Pachron."""
	_current_path_id = path_id
	_is_farewell = true

	var dialog_data: Dictionary = _pachron_dialogs.get(path_id, {})
	var farewell: String = _pick_random(dialog_data.get("farewells", []))

	if farewell == "":
		dialog_sequence_finished.emit()
		return

	var entries: Array[DialogEntry] = [_make_entry(path_id, farewell)]
	_play_entries(path_id, entries)


func _get_content_beats(path_id: String, dialog_data: Dictionary) -> Array:
	"""Picks the best content dialog: story > loop > wegwerf. Returns Array[String] of beats."""
	# Check for new story
	var stories: Array = dialog_data.get("story", [])
	var highest_tier: int = BoonManager.get_highest_tier(path_id)
	var seen: Array = _seen_stories.get(path_id, [])

	for story in stories:
		var story_id: String = story.get("id", "")
		var requires_tier: int = story.get("requires_tier", 0)
		if requires_tier <= highest_tier and story_id not in seen:
			# New story available!
			if not _seen_stories.has(path_id):
				_seen_stories[path_id] = []
			_seen_stories[path_id].append(story_id)
			return _extract_beats(story)

	# No new story — try loop
	var loops: Array = dialog_data.get("loop", [])
	if not loops.is_empty():
		var idx: int = _loop_indices.get(path_id, 0)
		var text: String = loops[idx % loops.size()]
		_loop_indices[path_id] = idx + 1
		return [text]

	# Fallback: wegwerf
	var wegwerf: Array = dialog_data.get("wegwerf", [])
	var pick: String = _pick_random(wegwerf)
	if pick == "":
		return []
	return [pick]


func _extract_beats(entry: Dictionary) -> Array:
	"""Returns the beats array for a dialog entry. Supports legacy 'text' field as 1-element array."""
	if entry.has("beats"):
		var beats = entry.get("beats", [])
		if beats is Array:
			return beats
	var text: String = entry.get("text", "")
	if text != "":
		return [text]
	return []


# ============ DIALOG HELPERS ============
func _make_entry(path_id: String, text: String) -> DialogEntry:
	"""Creates a DialogEntry with the Pachron's image as speaker sprite."""
	var entry := DialogEntry.new()
	var path_data: Dictionary = BoonManager.get_path_data(path_id)
	entry.speaker_name = path_data.get("name", path_id.capitalize())
	entry.text = text
	entry.text_speed = 35.0

	# Load Pachron image as speaker sprite
	var img_path: String = PACHRON_IMAGES.get(path_id, "")
	if img_path != "" and ResourceLoader.exists(img_path):
		entry.speaker_sprite = load(img_path)

	return entry


func _play_entries(path_id: String, entries: Array[DialogEntry]) -> void:
	"""Creates a DialogData and plays it via DialogManager."""
	var dialog := DialogData.new()
	dialog.dialog_id = "pachron_%s" % path_id
	dialog.entries = entries

	# Connect to dialog finished signal
	if EventBus:
		EventBus.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	DialogManager.play_dialog_resource(dialog)


func _on_dialog_finished(_dialog_id: String) -> void:
	if EventBus and _current_path_id != "":
		EventBus.pachron_dialog_finished.emit(_current_path_id)
	dialog_sequence_finished.emit()


func _pick_random(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]


# ============ SAVE/LOAD (persistent story tracking) ============
func get_save_data() -> Dictionary:
	return {
		"seen_stories": _seen_stories.duplicate(true),
		"selection_counts": _selection_counts.duplicate(true),
		"pending_reactions": _pending_reactions.duplicate(true),
	}


func load_from_save(data: Dictionary) -> void:
	_seen_stories = data.get("seen_stories", {})
	_selection_counts = data.get("selection_counts", {})
	_pending_reactions = data.get("pending_reactions", {})


func reset_run_state() -> void:
	"""Called at run start — resets loop indices and per-run played reactions.
	Keeps story tracking, pending reactions, and selection counts."""
	_loop_indices.clear()
	_played_reactions_run.clear()


# ============ REACTIONS (boss kills / schwellensicht) ============
func _on_boss_defeated(boss_id: String) -> void:
	"""Enqueue a world reaction for every pachron that has one defined for this boss."""
	var reaction_key: String = BOSS_REACTION_MAP.get(boss_id, "")
	if reaction_key == "":
		return
	for path_id in BoonManager.PATH_IDS:
		_enqueue_reaction(path_id, reaction_key)


func _on_schwellensicht_changed(active: bool) -> void:
	if not active:
		return
	for path_id in BoonManager.PATH_IDS:
		_enqueue_reaction(path_id, "schwellensicht_active")


func _enqueue_reaction(path_id: String, reaction_key: String) -> void:
	"""Queue a reaction if the pachron has content for it AND it wasn't played this run."""
	var dialog_data: Dictionary = _pachron_dialogs.get(path_id, {})
	var reactions: Dictionary = dialog_data.get("world_reactions", {})
	if not reactions.has(reaction_key):
		return

	# Already played this run? skip
	var played: Array = _played_reactions_run.get(path_id, [])
	if reaction_key in played:
		return

	if not _pending_reactions.has(path_id):
		_pending_reactions[path_id] = []
	if reaction_key not in _pending_reactions[path_id]:
		_pending_reactions[path_id].append(reaction_key)


func _consume_pending_reaction(path_id: String, dialog_data: Dictionary) -> Array:
	"""Pops the next pending reaction for this pachron and returns its beats.
	Marks it as played (this run) so it won't fire again until next run."""
	var pending: Array = _pending_reactions.get(path_id, [])
	if pending.is_empty():
		return []

	var reactions: Dictionary = dialog_data.get("world_reactions", {})
	var reaction_key: String = pending.pop_front()

	# Mark as played for this run
	if not _played_reactions_run.has(path_id):
		_played_reactions_run[path_id] = []
	_played_reactions_run[path_id].append(reaction_key)

	var reaction_entry = reactions.get(reaction_key, null)
	if reaction_entry == null:
		return []

	# world_reactions value may be a Dict with beats OR an Array of entries — support both
	if reaction_entry is Array and reaction_entry.size() > 0:
		return _extract_beats(reaction_entry[0])
	if reaction_entry is Dictionary:
		return _extract_beats(reaction_entry)
	return []


# ============ SELECTION TRACKING (for ending determination) ============
func register_selection(path_id: String) -> void:
	"""Called by PachronSelectionScreen when the player commits to a pachron."""
	if path_id == "":
		return
	_selection_counts[path_id] = int(_selection_counts.get(path_id, 0)) + 1


func get_selection_count(path_id: String) -> int:
	return int(_selection_counts.get(path_id, 0))


func get_total_selections() -> int:
	var total: int = 0
	for path_id in _selection_counts:
		total += int(_selection_counts[path_id])
	return total


# ============ ENDINGS ============
func determine_ending_type(path_id: String) -> String:
	"""Returns 'treue' / 'neutral' / 'abweisung' based on how often this pachron was picked."""
	var total: int = get_total_selections()
	if total == 0:
		return "abweisung"
	var count: int = get_selection_count(path_id)
	var share: float = float(count) / float(total)
	if share >= ENDING_THRESHOLD_TREUE:
		return "treue"
	if share >= ENDING_THRESHOLD_NEUTRAL:
		return "neutral"
	return "abweisung"


func determine_secret_ending() -> bool:
	"""Secret ending unlocks when ALL 5 pachrons have reached T5."""
	for path_id in BoonManager.PATH_IDS:
		if BoonManager.get_highest_tier(path_id) < 5:
			return false
	return true


func play_ending(path_id: String, ending_type: String = "") -> void:
	"""Plays the pachron's ending dialog. If ending_type is empty, it's auto-determined."""
	if ending_type == "":
		ending_type = determine_ending_type(path_id)

	_current_path_id = path_id
	_is_farewell = false

	var dialog_data: Dictionary = _pachron_dialogs.get(path_id, {})
	var endings: Dictionary = dialog_data.get("endings", {})
	var ending_entry = endings.get(ending_type, null)
	if ending_entry == null:
		print("[PachronDialogSystem] No ending '%s' for %s" % [ending_type, path_id])
		dialog_sequence_finished.emit()
		return

	var beats: Array = _extract_beats(ending_entry)
	if beats.is_empty():
		dialog_sequence_finished.emit()
		return

	var entries: Array[DialogEntry] = []
	for beat in beats:
		if typeof(beat) == TYPE_STRING and beat != "":
			entries.append(_make_entry(path_id, beat))

	if entries.is_empty():
		dialog_sequence_finished.emit()
		return

	print("[PachronDialogSystem] Playing ending '%s' for %s" % [ending_type, path_id])
	_play_entries("ending_%s_%s" % [path_id, ending_type], entries)


func play_run_end_dialog() -> bool:
	"""Plays the appropriate ending dialog for the completed run.
	Returns true if a dialog was started, false otherwise."""
	# Secret ending: all 5 pachrons at tier 5
	if determine_secret_ending():
		play_unified_ending()
		return true

	# Normal ending: pick the pachron the player leaned into this run
	var best_path: String = ""
	var best_count: int = -1
	for path_id in BoonManager.active_boons.keys():
		var tiers: Array = BoonManager.active_boons[path_id]
		if tiers.size() > best_count:
			best_count = tiers.size()
			best_path = path_id

	if best_path == "":
		return false

	play_ending(best_path, determine_ending_type(best_path))
	return true


func _load_unified_ending() -> void:
	var file_path: String = ENDINGS_DIALOG_PATH + "secret_unified.json"
	if not FileAccess.file_exists(file_path):
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result == OK:
		_unified_ending_data = json.data


func play_unified_ending() -> void:
	"""Plays the secret ending where all 5 pachrons + Murum speak sequentially."""
	if _unified_ending_data.is_empty():
		print("[PachronDialogSystem] Secret unified ending data missing")
		dialog_sequence_finished.emit()
		return

	var lines: Array = _unified_ending_data.get("beats", [])
	if lines.is_empty():
		dialog_sequence_finished.emit()
		return

	var entries: Array[DialogEntry] = []
	for line in lines:
		if not (line is Dictionary):
			continue
		var speaker: String = line.get("speaker", "")
		var text: String = line.get("text", "")
		if speaker != "" and text != "":
			entries.append(_make_entry(speaker, text))

	if entries.is_empty():
		dialog_sequence_finished.emit()
		return

	print("[PachronDialogSystem] Playing secret unified ending")
	_play_entries("ending_secret_unified", entries)


# ============ SYNC SKILL DIALOGS ============
var _sync_dialogs: Dictionary = {}  # sync_id -> parsed JSON dict

func _load_sync_dialogs() -> void:
	"""Loads all sync dialog files from the sync/ subdirectory."""
	var dir := DirAccess.open(SYNC_DIALOG_PATH)
	if not dir:
		push_warning("[PachronDialogSystem] Sync dialog directory missing: %s" % SYNC_DIALOG_PATH)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path: String = SYNC_DIALOG_PATH + file_name
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json := JSON.new()
				var result := json.parse(file.get_as_text())
				file.close()
				if result == OK:
					var data: Dictionary = json.data
					var sync_id: String = data.get("sync_id", file_name.get_basename())
					_sync_dialogs[sync_id] = data
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[PachronDialogSystem] Loaded %d sync dialogs" % _sync_dialogs.size())


func start_sync_dialog(sync_id: String) -> void:
	"""Starts the dual-Pachron intro dialog for a sync skill."""
	_current_path_id = sync_id
	_is_farewell = false

	var dialog_data: Dictionary = _sync_dialogs.get(sync_id, {})
	if dialog_data.is_empty():
		print("[PachronDialogSystem] No sync dialog for %s — skipping" % sync_id)
		dialog_sequence_finished.emit()
		return

	var intro: Array = dialog_data.get("intro", [])
	if intro.is_empty():
		dialog_sequence_finished.emit()
		return

	var entries: Array[DialogEntry] = []
	for line in intro:
		var speaker: String = line.get("speaker", "")
		var text: String = line.get("text", "")
		if speaker != "" and text != "":
			entries.append(_make_entry(speaker, text))

	if entries.is_empty():
		dialog_sequence_finished.emit()
		return

	_play_entries("sync_%s" % sync_id, entries)


func play_sync_farewell(sync_id: String) -> void:
	"""Plays the farewell dialog for a sync skill (both Pachrons)."""
	_current_path_id = sync_id
	_is_farewell = true

	var dialog_data: Dictionary = _sync_dialogs.get(sync_id, {})
	var farewell_lines: Array = dialog_data.get("farewell", [])

	if farewell_lines.is_empty():
		dialog_sequence_finished.emit()
		return

	var entries: Array[DialogEntry] = []
	for line in farewell_lines:
		var speaker: String = line.get("speaker", "")
		var text: String = line.get("text", "")
		if speaker != "" and text != "":
			entries.append(_make_entry(speaker, text))

	if entries.is_empty():
		dialog_sequence_finished.emit()
		return

	_play_entries("sync_%s_farewell" % sync_id, entries)
