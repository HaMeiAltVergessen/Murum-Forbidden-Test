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
const PACHRON_IMAGES: Dictionary = {
	"arthra": "res://Assets/AIPlaceholder/Char/Pachrons/Arthra/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_58172.jpg",
	"noron": "res://Assets/AIPlaceholder/Char/Pachrons/Noron/NORON_Pachron_of_Twilight_Use__Nano_Banana_Pro_34835.jpg",
	"raelear": "res://Assets/AIPlaceholder/Char/Pachrons/Realear/_Use_the_provided_Murum_artwor_Nano_Banana_60213.jpg",
	"murrum": "res://Assets/AIPlaceholder/Char/Pachrons/Mur_rum/_Use_the_provided_Murum_artwor_Nano_Banana_78991.jpg",
	"sairias": "res://Assets/AIPlaceholder/Char/Pachrons/Sairias/_Use_the_provided_Murum_artwor_Nano_Banana_45046.jpg",
}

# ============ STATE ============
var _pachron_dialogs: Dictionary = {}  # path_id -> parsed JSON dict
var _seen_stories: Dictionary = {}     # path_id -> Array of seen story IDs (persistent across runs)
var _loop_indices: Dictionary = {}     # path_id -> int (current loop index, per run)
var _current_path_id: String = ""
var _is_farewell: bool = false


func _ready() -> void:
	_load_all_dialogs()
	_load_sync_dialogs()
	if RunManager:
		RunManager.run_started.connect(_on_run_started)
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

	# 2. Story (if new one available) OR Loop OR Wegwerf
	var content_text: String = _get_content_text(path_id, dialog_data)
	if content_text != "":
		entries.append(_make_entry(path_id, content_text))

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


func _get_content_text(path_id: String, dialog_data: Dictionary) -> String:
	"""Picks the best content dialog: story > loop > wegwerf."""
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
			return story.get("text", "")

	# No new story — try loop
	var loops: Array = dialog_data.get("loop", [])
	if not loops.is_empty():
		var idx: int = _loop_indices.get(path_id, 0)
		var text: String = loops[idx % loops.size()]
		_loop_indices[path_id] = idx + 1
		return text

	# Fallback: wegwerf
	var wegwerf: Array = dialog_data.get("wegwerf", [])
	return _pick_random(wegwerf)


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
	}


func load_from_save(data: Dictionary) -> void:
	_seen_stories = data.get("seen_stories", {})


func reset_run_state() -> void:
	"""Called at run start — resets loop indices but keeps story tracking."""
	_loop_indices.clear()


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
