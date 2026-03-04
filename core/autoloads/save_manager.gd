extends Node

## Central Save/Load System
## Handles game state persistence across sessions

# ============================================================================
# CONSTANTS
# ============================================================================

const SAVE_VERSION: String = "1.0.0"
const SAVE_DIR: String = "user://saves/"
const SETTINGS_PATH: String = "user://settings.json"

const MAX_SLOTS: int = 3
const AUTO_SAVE_ENABLED: bool = true

# ============================================================================
# SAVE SLOT DATA
# ============================================================================

class SaveSlotMetadata:
	var slot_index: int
	var exists: bool = false
	var timestamp: String = ""
	var playtime_seconds: int = 0
	var player_name: String = "Murum"
	var current_world: String = ""
	var current_room: String = ""
	var player_level: int = 1

	func get_formatted_playtime() -> String:
		var hours = playtime_seconds / 3600
		var minutes = (playtime_seconds % 3600) / 60
		return "%02d:%02d" % [hours, minutes]

	func get_formatted_timestamp() -> String:
		if timestamp.is_empty():
			return "---"

		var parts = timestamp.split("T")
		if parts.size() != 2:
			return timestamp

		var date_parts = parts[0].split("-")
		if date_parts.size() != 3:
			return timestamp

		var time_parts = parts[1].split(":")
		if time_parts.size() < 2:
			return timestamp

		var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var month_index = int(date_parts[1]) - 1

		return "%s %s, %s %s:%s" % [
			months[month_index],
			date_parts[2],
			date_parts[0],
			time_parts[0],
			time_parts[1]
		]

# ============================================================================
# STATE
# ============================================================================

var current_slot: int = -1
var slot_metadata: Array[SaveSlotMetadata] = []

var playtime_seconds: int = 0
var playtime_timer: float = 0.0

# Pending data to apply after scene load
var pending_player_data: Dictionary = {}

# ============================================================================
# SIGNALS
# ============================================================================

signal save_completed(slot_index: int, success: bool)
signal load_completed(slot_index: int, success: bool)
signal save_failed(slot_index: int, error: String)
signal load_failed(slot_index: int, error: String)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create save directory if not exists
	_ensure_save_directory()

	# Load slot metadata
	_load_all_slot_metadata()

	# Load settings
	load_settings()

	print("[SaveManager] Initialized")
	print("[SaveManager] Save directory: %s" % SAVE_DIR)

func _process(delta: float) -> void:
	# Track playtime
	if current_slot >= 0:
		playtime_timer += delta
		if playtime_timer >= 1.0:
			playtime_seconds += 1
			playtime_timer = 0.0

# ============================================================================
# DIRECTORY MANAGEMENT
# ============================================================================

func _ensure_save_directory() -> void:
	"""Creates save directory if it doesn't exist"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		var err = dir.make_dir("saves")
		if err == OK:
			print("[SaveManager] Created saves directory")
		else:
			push_error("[SaveManager] Failed to create saves directory: %d" % err)

# ============================================================================
# SLOT METADATA
# ============================================================================

func _load_all_slot_metadata() -> void:
	"""Loads metadata for all save slots"""
	slot_metadata.clear()

	for i in range(MAX_SLOTS):
		var metadata = _load_slot_metadata(i + 1)
		slot_metadata.append(metadata)

	print("[SaveManager] Loaded metadata for %d slots" % slot_metadata.size())

func _load_slot_metadata(slot_index: int) -> SaveSlotMetadata:
	"""Loads metadata for specific slot"""
	var metadata = SaveSlotMetadata.new()
	metadata.slot_index = slot_index

	var file_path = _get_slot_path(slot_index)

	if not FileAccess.file_exists(file_path):
		return metadata

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open slot %d for metadata" % slot_index)
		return metadata

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[SaveManager] Failed to parse slot %d JSON" % slot_index)
		return metadata

	var data = json.data

	# Extract metadata
	metadata.exists = true
	metadata.timestamp = data.get("timestamp", "")
	metadata.playtime_seconds = data.get("playtime_seconds", 0)

	var player_data = data.get("player", {})
	metadata.current_world = player_data.get("current_world", "")
	metadata.current_room = player_data.get("current_room", "")

	return metadata

func get_slot_metadata(slot_index: int) -> SaveSlotMetadata:
	"""Returns metadata for slot (1-3)"""
	if slot_index < 1 or slot_index > MAX_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		return SaveSlotMetadata.new()

	return slot_metadata[slot_index - 1]

func slot_exists(slot_index: int) -> bool:
	"""Returns true if slot has save data"""
	return get_slot_metadata(slot_index).exists

# ============================================================================
# SAVE GAME
# ============================================================================

func save_game(slot_index: int) -> bool:
	"""Saves current game state to slot (1-3)"""

	if slot_index < 1 or slot_index > MAX_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		save_failed.emit(slot_index, "Invalid slot index")
		return false

	print("[SaveManager] Saving game to slot %d..." % slot_index)

	# Gather save data
	var save_data = _gather_save_data(slot_index)

	# Convert to JSON
	var json_string = JSON.stringify(save_data, "\t")

	# Write to file
	var file_path = _get_slot_path(slot_index)
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		var error = "Failed to open file for writing"
		push_error("[SaveManager] %s: %s" % [error, file_path])
		save_failed.emit(slot_index, error)
		return false

	file.store_string(json_string)
	file.close()

	# Update metadata
	current_slot = slot_index
	_load_all_slot_metadata()

	print("[SaveManager] Save completed: %s" % file_path)
	save_completed.emit(slot_index, true)

	return true

func _gather_save_data(slot_index: int) -> Dictionary:
	"""Gathers all game state into save dictionary"""

	var player = get_tree().get_first_node_in_group("player")

	if not player:
		print("[SaveManager] WARNING: No player found in scene, using defaults")

	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": playtime_seconds,
		"slot_index": slot_index,

		"player": _gather_player_data(player),
		"inventory": _gather_inventory_data(),
		"progression": _gather_progression_data(),
		"path_choices": _gather_path_choices(),
		"statistics": _gather_statistics(),
		"abilities": _gather_abilities_data(),
		"statistics_full": _gather_statistics_full(),
		"achievements": _gather_achievements_data(),
		"challenge_run": _gather_challenge_run_data()
	}

	print("[SaveManager] Save data gathered successfully")
	return save_data

func _gather_player_data(player: Node) -> Dictionary:
	"""Gathers player state"""
	if not player:
		return {
			"current_hp": 100,
			"max_hp": 100,
			"current_mana": 100,
			"max_mana": 100,
			"position": {"x": 0.0, "y": 0.0},
			"facing_direction": 1,
			"current_world": "",
			"current_room": "",
			"last_checkpoint": ""
		}

	# Get current world/room from WorldManager
	var current_world = "world_1_ruins"
	var current_room = "test_room"
	var last_checkpoint = ""

	if WorldManager:
		current_world = WorldManager.current_world
		current_room = WorldManager.current_room
		last_checkpoint = WorldManager.last_checkpoint

	# Use checkpoint position if available, otherwise use current position
	# This ensures player always spawns at checkpoint when loading
	var save_position = player.global_position
	if WorldManager and WorldManager.last_checkpoint_position != Vector2.ZERO:
		save_position = WorldManager.last_checkpoint_position
		print("[SaveManager] Using checkpoint position for save: %v" % save_position)
	else:
		print("[SaveManager] No checkpoint, using current position: %v" % save_position)

	# Read HP from HealthComponent
	var current_hp: int = 100
	var max_hp: int = 100
	if player.has_node("HealthComponent"):
		var hc = player.get_node("HealthComponent")
		current_hp = hc.current_health
		max_hp = hc.max_health

	# Read Mana from ManaComponent
	var current_mana: int = 100
	var max_mana: int = 100
	if player.has_node("ManaComponent"):
		var mc = player.get_node("ManaComponent")
		current_mana = mc.current_mana
		max_mana = mc.max_mana

	return {
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mana": current_mana,
		"max_mana": max_mana,
		"position": {
			"x": save_position.x,
			"y": save_position.y
		},
		"facing_direction": 1,
		"current_world": current_world,
		"current_room": current_room,
		"last_checkpoint": last_checkpoint
	}

func _gather_inventory_data() -> Dictionary:
	"""Gathers inventory state from InventoryManager and GameManager"""
	var inventory_data = {
		"consumables": [],
		"relics": [],
		"key_items": [],
		"coins": 0
	}

	# Get inventory from InventoryManager
	if InventoryManager:
		inventory_data["consumables"] = InventoryManager.inventory.get("consumables", []).duplicate(true)
		inventory_data["relics"] = InventoryManager.inventory.get("relics", []).duplicate(true)
		inventory_data["key_items"] = InventoryManager.inventory.get("key_items", []).duplicate(true)
		print("[SaveManager] Gathered inventory: %d consumables, %d relics, %d keys" % [
			inventory_data["consumables"].size(),
			inventory_data["relics"].size(),
			inventory_data["key_items"].size()
		])

	# Get coins from GameManager
	if GameManager:
		inventory_data["coins"] = GameManager.coins_collected
		print("[SaveManager] Gathered coins: %d" % inventory_data["coins"])

	return inventory_data

func _gather_progression_data() -> Dictionary:
	"""Gathers world progression"""
	# Get progression from WorldManager if available
	if WorldManager and WorldManager.has_method("get_progression_data"):
		return WorldManager.get_progression_data()

	# Fallback if WorldManager not available or method missing
	return {
		"worlds_unlocked": ["world_1_ruins"],
		"rooms_cleared": {},
		"visited_rooms": [],
		"unlocked_doors": [],
		"bosses_defeated": [],
		"checkpoints_activated": [],
		"secrets_found": [],
		"collected_items": [],
		"solved_puzzles": []
	}

func _gather_path_choices() -> Dictionary:
	"""Gathers path choice stats"""
	return {
		"destroy": 0,
		"mercy": 0,
		"adapt": 0
	}

func _gather_statistics() -> Dictionary:
	"""Gathers gameplay statistics from GameManager"""
	var stats = {
		"total_deaths": 0,
		"enemies_killed": 0,
		"perfect_parries": 0,
		"max_combo": 0,
		"resonance_modes_activated": 0,
		"urgathon_uses": 0
	}
	if GameManager:
		stats["total_deaths"] = GameManager.deaths
		stats["enemies_killed"] = GameManager.enemies_killed
	return stats

func _gather_abilities_data() -> Dictionary:
	"""Gathers abilities state"""
	return {
		"unlocked": [],
		"equipped": [null, null, null, null]
	}

func _gather_statistics_full() -> Dictionary:
	"""Gathers full statistics from StatisticsManager"""
	if StatisticsManager:
		return StatisticsManager.get_save_data()
	return {}

func _gather_achievements_data() -> Dictionary:
	"""Gathers achievement unlock state from AchievementManager"""
	if AchievementManager:
		return AchievementManager.get_save_data()
	return {"unlocked": [], "unlock_dates": {}}

func _gather_challenge_run_data() -> Dictionary:
	"""Gathers challenge run state from ChallengeRunManager"""
	if ChallengeRunManager:
		return ChallengeRunManager.get_save_data()
	return {"active_modifiers": {}, "is_active": false, "highest_heat_completed": 0}

# ============================================================================
# LOAD GAME
# ============================================================================

func load_game(slot_index: int) -> bool:
	"""Loads game state from slot (1-3)"""

	if slot_index < 1 or slot_index > MAX_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		load_failed.emit(slot_index, "Invalid slot index")
		return false

	if not slot_exists(slot_index):
		var error = "Slot is empty"
		push_error("[SaveManager] %s: %d" % [error, slot_index])
		load_failed.emit(slot_index, error)
		return false

	print("[SaveManager] Loading game from slot %d..." % slot_index)

	# Read file
	var file_path = _get_slot_path(slot_index)
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		var error = "Failed to open file for reading"
		push_error("[SaveManager] %s: %s" % [error, file_path])
		load_failed.emit(slot_index, error)
		return false

	var json_string = file.get_as_text()
	file.close()

	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		var error = "Failed to parse JSON"
		push_error("[SaveManager] %s" % error)
		load_failed.emit(slot_index, error)
		return false

	var save_data = json.data

	# Validate version
	if save_data.get("version", "") != SAVE_VERSION:
		push_warning("[SaveManager] Save version mismatch: %s vs %s" % [
			save_data.get("version", ""),
			SAVE_VERSION
		])

	# Apply save data
	_apply_save_data(save_data)

	# Update state
	current_slot = slot_index
	playtime_seconds = save_data.get("playtime_seconds", 0)

	print("[SaveManager] Load completed from slot %d" % slot_index)
	load_completed.emit(slot_index, true)

	return true

func _apply_save_data(save_data: Dictionary) -> void:
	"""Applies loaded save data to game state"""

	# Store player data for later application
	pending_player_data = save_data.get("player", {})

	# Load progression data into WorldManager
	var progression_data = save_data.get("progression", {})
	if WorldManager:
		WorldManager.load_progression_data(progression_data)
		print("[SaveManager] Loaded progression data to WorldManager")

	# Load inventory data
	var inventory_data = save_data.get("inventory", {})
	_restore_inventory(inventory_data)

	# Restore statistics to GameManager
	var statistics = save_data.get("statistics", {})
	if GameManager:
		GameManager.deaths = statistics.get("total_deaths", 0)
		GameManager.enemies_killed = statistics.get("enemies_killed", 0)
		print("[SaveManager] Statistics restored: %d deaths, %d kills" % [GameManager.deaths, GameManager.enemies_killed])

	# Restore full statistics to StatisticsManager
	var statistics_full = save_data.get("statistics_full", {})
	if StatisticsManager:
		StatisticsManager.load_from_save(statistics_full)

	# Restore achievements
	var achievements_data = save_data.get("achievements", {})
	if AchievementManager:
		AchievementManager.load_from_save(achievements_data)

	# Restore challenge run state
	var challenge_data = save_data.get("challenge_run", {})
	if ChallengeRunManager:
		ChallengeRunManager.load_from_save(challenge_data)

	# Get saved room data
	var player_data = save_data.get("player", {})
	var saved_world = player_data.get("current_world", "world_1_ruins")
	var saved_room = player_data.get("current_room", "room_01_entry")

	# Build full path for section-based structure (COMMIT 019d FIX)
	# If saved_room doesn't contain "/", it's a legacy simple room name
	# Construct full path: worlds/{world}/{section}/{room}
	var full_room_path = saved_room

	if "/" not in saved_room:
		# Legacy format - construct section-based path
		# Map room_01, room_02, room_03 → section_1_entrance
		# Map room_04, room_05 → section_2_village
		# etc.
		var section = "section_1_entrance"  # Default to entrance section

		# Simple heuristic: room_01-03 = entrance, room_04-06 = village, etc.
		if saved_room.begins_with("room_0"):
			var room_num = saved_room.substr(6, 1).to_int()
			if room_num >= 4:
				section = "section_2_village"

		full_room_path = "worlds/%s/%s/%s" % [saved_world, section, saved_room]
		print("[SaveManager] Constructed full path from legacy room: %s → %s" % [saved_room, full_room_path])

	# Use WorldManager to get correct scene path
	var scene_path = ""
	if WorldManager and WorldManager.has_method("_get_room_path"):
		scene_path = WorldManager._get_room_path(full_room_path)
	else:
		# Fallback if WorldManager not available
		scene_path = "res://%s.tscn" % full_room_path

	print("[SaveManager] Loading saved room: %s (path: %s)" % [saved_room, scene_path])

	# Load scene directly
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("[SaveManager] ERROR: Saved room scene not found: %s" % scene_path)
		# Fallback to room_01_entry (UPDATED for section-based structure - COMMIT 019d)
		get_tree().change_scene_to_file("res://worlds/world_1_ruins/section_1_entrance/room_01_entry.tscn")

	print("[SaveManager] Stored player data for application after scene load")


func _restore_inventory(inventory_data: Dictionary) -> void:
	"""Restores inventory from save data"""
	if not InventoryManager:
		push_error("[SaveManager] InventoryManager not found!")
		return

	# Clear existing inventory
	InventoryManager.inventory["consumables"].clear()
	InventoryManager.inventory["relics"].clear()
	InventoryManager.inventory["key_items"].clear()

	# Restore consumables
	var consumables = inventory_data.get("consumables", [])
	for item in consumables:
		InventoryManager.inventory["consumables"].append(item.duplicate())

	# Restore relics
	var relics = inventory_data.get("relics", [])
	for item_id in relics:
		InventoryManager.inventory["relics"].append(item_id)

	# Restore key items
	var key_items = inventory_data.get("key_items", [])
	for item_id in key_items:
		InventoryManager.inventory["key_items"].append(item_id)

	# Restore coins
	var coins = inventory_data.get("coins", 0)
	if GameManager:
		GameManager.coins_collected = coins

	print("[SaveManager] Inventory restored: %d consumables, %d relics, %d keys, %d coins" % [
		consumables.size(), relics.size(), key_items.size(), coins
	])

	# Emit signal to refresh UI
	InventoryManager.inventory_changed.emit()

# ============================================================================
# DELETE SAVE
# ============================================================================

func delete_save(slot_index: int) -> bool:
	"""Deletes save file from slot"""

	if slot_index < 1 or slot_index > MAX_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		return false

	var file_path = _get_slot_path(slot_index)

	if not FileAccess.file_exists(file_path):
		return true

	var dir = DirAccess.open("user://saves/")
	var file_name = "slot_%d.json" % slot_index
	var err = dir.remove(file_name)

	if err != OK:
		push_error("[SaveManager] Failed to delete slot %d: %d" % [slot_index, err])
		return false

	print("[SaveManager] Deleted save slot %d" % slot_index)

	# Update metadata
	_load_all_slot_metadata()

	return true

# ============================================================================
# SETTINGS
# ============================================================================

func save_settings() -> bool:
	"""Saves game settings to settings.json"""

	var settings_data = {
		"version": SAVE_VERSION,
		"audio": {
			"master_volume": AudioServer.get_bus_volume_db(0),
			"music_volume": 0.7,
			"sfx_volume": 0.9,
			"muted": false
		},
		"video": {
			"window_mode": "windowed",
			"resolution": {
				"width": 1920,
				"height": 1080
			},
			"vsync": true,
			"fps_limit": 0
		},
		"gameplay": {
			"blood_effects": true,
			"screen_shake": true,
			"damage_numbers": true,
			"tutorial_prompts": true
		}
	}

	var json_string = JSON.stringify(settings_data, "\t")

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to save settings")
		return false

	file.store_string(json_string)
	file.close()

	print("[SaveManager] Settings saved")
	return true

func load_settings() -> bool:
	"""Loads game settings from settings.json"""

	if not FileAccess.file_exists(SETTINGS_PATH):
		print("[SaveManager] No settings file found, using defaults")
		return false

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open settings file")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[SaveManager] Failed to parse settings JSON")
		return false

	var settings_data = json.data

	# Apply settings
	_apply_settings(settings_data)

	print("[SaveManager] Settings loaded")
	return true

func _apply_settings(settings: Dictionary) -> void:
	"""Applies loaded settings"""

	# Audio
	var audio = settings.get("audio", {})
	var master_vol = audio.get("master_volume", 0.8)
	AudioServer.set_bus_volume_db(0, master_vol)

# ============================================================================
# UTILITY
# ============================================================================

func _get_slot_path(slot_index: int) -> String:
	"""Returns file path for slot"""
	return SAVE_DIR + "slot_%d.json" % slot_index

func get_current_slot() -> int:
	"""Returns currently loaded slot (or -1)"""
	return current_slot

func get_playtime() -> int:
	"""Returns playtime in seconds"""
	return playtime_seconds

func reset_playtime() -> void:
	"""Resets playtime counter"""
	playtime_seconds = 0
	playtime_timer = 0.0

func set_current_slot(slot_index: int) -> void:
	"""Sets current active slot (for new game)"""
	current_slot = slot_index
	playtime_seconds = 0
	playtime_timer = 0.0
	print("[SaveManager] Set current slot to %d" % slot_index)

# ============================================================================
# SINGLE-SLOT CONVENIENCE FUNCTIONS (COMMIT 016)
# ============================================================================
# These functions provide simple API for single-save games
# All operations default to Slot 1

const DEFAULT_SLOT: int = 1

func has_save_file() -> bool:
	"""Checks if default save file exists (Slot 1)"""
	return slot_exists(DEFAULT_SLOT)

func create_new_save() -> bool:
	"""Creates new save file in default slot (Slot 1)"""
	print("[SaveManager] Creating new save in slot %d..." % DEFAULT_SLOT)

	# Set current slot for playtime tracking
	set_current_slot(DEFAULT_SLOT)

	# Save immediately to create file
	return save_game(DEFAULT_SLOT)

func save_current_game() -> bool:
	"""Saves current game to default slot (Slot 1)"""
	return save_game(DEFAULT_SLOT)

func load_current_game() -> bool:
	"""Loads game from default slot (Slot 1)"""
	return load_game(DEFAULT_SLOT)

func delete_current_save() -> bool:
	"""Deletes save from default slot (Slot 1)"""
	return delete_save(DEFAULT_SLOT)

func get_current_save_metadata() -> SaveSlotMetadata:
	"""Returns metadata for default slot (Slot 1)"""
	return get_slot_metadata(DEFAULT_SLOT)
