extends Node
## AchievementManager - Tracks and unlocks achievements
## Loads definitions from JSON, checks conditions, shows notifications

# ============================================================================
# CONSTANTS
# ============================================================================

const ACHIEVEMENTS_DATA_PATH := "res://data/achievements.json"
const NOTIFICATION_SCENE_PATH := "res://ui/notifications/achievement_notification.tscn"

# ============================================================================
# SIGNALS
# ============================================================================

signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)

# ============================================================================
# STATE
# ============================================================================

## All achievement definitions keyed by id
var achievements: Dictionary = {}
## Set of unlocked achievement ids
var unlocked_ids: Array[String] = []
## Unlock timestamps
var unlock_dates: Dictionary = {}

var _notification_scene: PackedScene = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_achievement_definitions()
	_load_notification_scene()

	# Connect to EventBus for tracking
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.combo_increased.connect(_on_combo_increased)
	EventBus.combo_broken.connect(_on_combo_broken)
	EventBus.urgathon_activated.connect(_on_urgathon_activated)
	EventBus.secret_found.connect(_on_secret_found)
	EventBus.item_picked_up.connect(_on_item_picked_up)

	print("[AchievementManager] Initialized with %d achievements" % achievements.size())

func _load_achievement_definitions() -> void:
	"""Loads achievement definitions from JSON"""
	if not FileAccess.file_exists(ACHIEVEMENTS_DATA_PATH):
		push_error("[AchievementManager] Achievements file not found: %s" % ACHIEVEMENTS_DATA_PATH)
		return

	var file = FileAccess.open(ACHIEVEMENTS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("[AchievementManager] Failed to open achievements file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[AchievementManager] Failed to parse achievements JSON: %s" % json.get_error_message())
		return

	var data = json.data
	var achievement_list = data.get("achievements", [])

	for achievement in achievement_list:
		var id = achievement.get("id", "")
		if id.is_empty():
			continue
		achievements[id] = {
			"id": id,
			"name": achievement.get("name", ""),
			"description": achievement.get("description", ""),
			"category": achievement.get("category", ""),
			"icon": achievement.get("icon", ""),
			"condition_type": achievement.get("condition_type", ""),
			"condition_stat": achievement.get("condition_stat", ""),
			"condition_value": achievement.get("condition_value", ""),
			"unlocked": false,
			"unlock_date": ""
		}

	print("[AchievementManager] Loaded %d achievement definitions" % achievements.size())

func _load_notification_scene() -> void:
	"""Pre-loads notification scene"""
	if ResourceLoader.exists(NOTIFICATION_SCENE_PATH):
		_notification_scene = load(NOTIFICATION_SCENE_PATH)

# ============================================================================
# UNLOCK LOGIC
# ============================================================================

func unlock_achievement(achievement_id: String) -> void:
	"""Unlocks an achievement and shows notification"""
	if achievement_id not in achievements:
		push_warning("[AchievementManager] Unknown achievement: %s" % achievement_id)
		return

	if is_unlocked(achievement_id):
		return

	achievements[achievement_id]["unlocked"] = true
	achievements[achievement_id]["unlock_date"] = Time.get_datetime_string_from_system()

	if achievement_id not in unlocked_ids:
		unlocked_ids.append(achievement_id)
	unlock_dates[achievement_id] = achievements[achievement_id]["unlock_date"]

	print("[AchievementManager] Achievement unlocked: %s" % achievements[achievement_id]["name"])

	# Emit signals
	achievement_unlocked.emit(achievement_id, achievements[achievement_id])
	EventBus.achievement_unlocked.emit(achievement_id, achievements[achievement_id])

	# Show notification
	_show_notification(achievements[achievement_id])

func is_unlocked(achievement_id: String) -> bool:
	"""Returns whether an achievement is unlocked"""
	return achievement_id in unlocked_ids

func _show_notification(achievement_data: Dictionary) -> void:
	"""Shows toast notification for unlocked achievement"""
	if _notification_scene:
		var notification = _notification_scene.instantiate()
		get_tree().root.add_child(notification)
		if notification.has_method("show_achievement"):
			notification.show_achievement(achievement_data)
	else:
		# Fallback to EventBus notification
		EventBus.show_notification.emit("Achievement: %s" % achievement_data.get("name", ""), 4.0)

# ============================================================================
# CONDITION CHECKS
# ============================================================================

func _check_stat_achievements() -> void:
	"""Checks all stat-threshold achievements against current stats"""
	if not StatisticsManager:
		return

	var stats = StatisticsManager.get_all_statistics()

	for id in achievements:
		if is_unlocked(id):
			continue

		var ach = achievements[id]
		if ach["condition_type"] != "stat_threshold":
			continue

		var stat_name = ach["condition_stat"]
		var threshold = ach["condition_value"]
		var current_value = stats.get(stat_name, 0)

		if current_value >= threshold:
			unlock_achievement(id)

func _check_boss_achievement(boss_id: String) -> void:
	"""Checks boss-related achievements"""
	for id in achievements:
		if is_unlocked(id):
			continue

		var ach = achievements[id]
		if ach["condition_type"] == "boss_defeated" and ach["condition_value"] == boss_id:
			unlock_achievement(id)

func check_run_completion_achievements() -> void:
	"""Called when the game is completed (final boss beaten). Checks no-death and speedrun."""
	if not StatisticsManager:
		return

	var run_stats = StatisticsManager.get_run_statistics()

	# No Death Run
	if run_stats["run_deaths"] == 0:
		unlock_achievement("no_death_run")

	# Speedrun under 2 hours
	for id in achievements:
		if is_unlocked(id):
			continue
		var ach = achievements[id]
		if ach["condition_type"] == "speedrun":
			var time_limit = ach["condition_value"]
			if run_stats["run_playtime_seconds"] <= time_limit:
				unlock_achievement(id)

	# Also check stat achievements at completion
	_check_stat_achievements()

func _check_exploration_achievements() -> void:
	"""Checks exploration-related achievements"""
	if not WorldManager:
		return

	# All Secrets
	if not is_unlocked("all_secrets"):
		var progression = {}
		if WorldManager.has_method("get_progression_data"):
			progression = WorldManager.get_progression_data()
		var secrets = progression.get("secrets_found", [])
		# TODO: Define total secret count when all worlds are implemented
		# For now, check if secrets_found is non-empty and matches expected count
		pass

	# All Relics
	if not is_unlocked("all_relics"):
		if InventoryManager:
			var relics = InventoryManager.inventory.get("relics", [])
			# TODO: Define total relic count when all relics are implemented
			pass

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_boss_defeated(boss_id: String) -> void:
	_check_boss_achievement(boss_id)
	# Also check stat achievements
	_check_stat_achievements()

func _on_enemy_died(_enemy: Node, _position: Vector2) -> void:
	# Check kill count achievements periodically (every 100 kills)
	if StatisticsManager and StatisticsManager.enemies_killed % 100 == 0:
		_check_stat_achievements()

func _on_perfect_parry(_enemy: Node) -> void:
	# Check parry achievements periodically
	if StatisticsManager and StatisticsManager.perfect_parries % 10 == 0:
		_check_stat_achievements()

func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	if new_count >= 50 and not is_unlocked("combo_50"):
		_check_stat_achievements()

func _on_combo_broken(final_count: int) -> void:
	if final_count >= 50 and not is_unlocked("combo_50"):
		_check_stat_achievements()

func _on_urgathon_activated() -> void:
	if StatisticsManager and StatisticsManager.urgathon_uses % 10 == 0:
		_check_stat_achievements()

func _on_secret_found(_secret_id: String) -> void:
	_check_exploration_achievements()

func _on_item_picked_up(_item_id: String, _item_name: String, category: String) -> void:
	if category == "relics":
		_check_exploration_achievements()

# ============================================================================
# PUBLIC API
# ============================================================================

func get_all_achievements() -> Dictionary:
	"""Returns all achievements with their current state"""
	return achievements

func get_unlocked_count() -> int:
	"""Returns number of unlocked achievements"""
	return unlocked_ids.size()

func get_total_count() -> int:
	"""Returns total number of achievements"""
	return achievements.size()

# ============================================================================
# SAVE/LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	"""Returns data for persistence"""
	return {
		"unlocked": unlocked_ids.duplicate(),
		"unlock_dates": unlock_dates.duplicate()
	}

func load_from_save(data: Dictionary) -> void:
	"""Restores achievement state from save data"""
	unlocked_ids.clear()
	unlock_dates.clear()

	var saved_unlocked = data.get("unlocked", [])
	var saved_dates = data.get("unlock_dates", {})

	for id in saved_unlocked:
		if id in achievements:
			unlocked_ids.append(id)
			achievements[id]["unlocked"] = true
			var date = saved_dates.get(id, "")
			achievements[id]["unlock_date"] = date
			unlock_dates[id] = date

	print("[AchievementManager] Loaded %d unlocked achievements" % unlocked_ids.size())
