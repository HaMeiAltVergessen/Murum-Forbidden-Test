extends Node
## StatisticsManager - Tracks all gameplay statistics across sessions
## Connects to EventBus signals for automatic tracking

# ============================================================================
# LIFETIME STATISTICS (persist across all runs)
# ============================================================================

var total_deaths: int = 0
var total_playtime_seconds: int = 0
var enemies_killed: int = 0
var perfect_parries: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var max_combo: int = 0
var bosses_defeated_count: int = 0
var resonance_modes_activated: int = 0
var urgathon_uses: int = 0
var secrets_found_count: int = 0
var relics_collected: int = 0
var rooms_visited: int = 0
var coins_total_earned: int = 0

# ============================================================================
# RUN-SPECIFIC STATS (reset per run, used for no-death/speedrun checks)
# ============================================================================

var run_deaths: int = 0
var run_start_time_msec: int = 0
var run_playtime_seconds: int = 0
var _run_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to EventBus signals for tracking
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry)
	EventBus.hit_registered.connect(_on_hit_registered)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.combo_increased.connect(_on_combo_increased)
	EventBus.combo_broken.connect(_on_combo_broken)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.resonance_mode_activated.connect(_on_resonance_activated)
	EventBus.urgathon_activated.connect(_on_urgathon_activated)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.secret_found.connect(_on_secret_found)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.damage_taken.connect(_on_damage_taken)

	# Also track run time when a run starts via RunManager
	if RunManager:
		RunManager.run_started.connect(_on_game_started)

	# Track room visits via WorldManager
	if WorldManager:
		WorldManager.room_changed.connect(_on_room_changed)

	print("[StatisticsManager] Initialized")

func _process(delta: float) -> void:
	# Track run playtime
	if run_start_time_msec > 0:
		_run_timer += delta
		if _run_timer >= 1.0:
			run_playtime_seconds += 1
			_run_timer = 0.0

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_player_died() -> void:
	total_deaths += 1
	run_deaths += 1
	print("[StatisticsManager] Death recorded. Total: %d, Run: %d" % [total_deaths, run_deaths])

func _on_enemy_died(_enemy: Node, _position: Vector2) -> void:
	enemies_killed += 1

func _on_perfect_parry(_enemy: Node) -> void:
	perfect_parries += 1

func _on_hit_registered(_attacker: Node, _target: Node, damage: int) -> void:
	# Track damage dealt via hit registration
	total_damage_dealt += damage

func _on_player_damaged(damage: int, _source: Node) -> void:
	total_damage_taken += damage

func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	if new_count > max_combo:
		max_combo = new_count

func _on_combo_broken(final_count: int) -> void:
	if final_count > max_combo:
		max_combo = final_count

func _on_boss_defeated(_boss_id: String) -> void:
	bosses_defeated_count += 1

func _on_resonance_activated() -> void:
	resonance_modes_activated += 1

func _on_urgathon_activated() -> void:
	urgathon_uses += 1

func _on_item_picked_up(_item_id: String, _item_name: String, category: String) -> void:
	if category == "relics":
		relics_collected += 1

func _on_secret_found(_secret_id: String) -> void:
	secrets_found_count += 1

var _last_coin_amount: int = 0

func _on_coins_changed(new_amount: int) -> void:
	# Track coins earned (only positive changes count as earned)
	if new_amount > _last_coin_amount:
		coins_total_earned += new_amount - _last_coin_amount
	_last_coin_amount = new_amount

func _on_room_changed(_room_id: String) -> void:
	rooms_visited += 1

func _on_game_started() -> void:
	# Reset run-specific stats
	run_deaths = 0
	run_start_time_msec = Time.get_ticks_msec()
	run_playtime_seconds = 0
	_run_timer = 0.0
	print("[StatisticsManager] Run started, run stats reset")

func _on_damage_dealt(amount: int, _target: Node) -> void:
	total_damage_dealt += amount

func _on_damage_taken(amount: int, _source: Node) -> void:
	total_damage_taken += amount

# ============================================================================
# PUBLIC API
# ============================================================================

func get_all_statistics() -> Dictionary:
	"""Returns all lifetime statistics"""
	# Sync playtime from SaveManager
	if SaveManager:
		total_playtime_seconds = SaveManager.playtime_seconds

	return {
		"total_deaths": total_deaths,
		"total_playtime_seconds": total_playtime_seconds,
		"enemies_killed": enemies_killed,
		"perfect_parries": perfect_parries,
		"total_damage_dealt": total_damage_dealt,
		"total_damage_taken": total_damage_taken,
		"max_combo": max_combo,
		"bosses_defeated_count": bosses_defeated_count,
		"resonance_modes_activated": resonance_modes_activated,
		"urgathon_uses": urgathon_uses,
		"secrets_found_count": secrets_found_count,
		"relics_collected": relics_collected,
		"rooms_visited": rooms_visited,
		"coins_total_earned": coins_total_earned
	}

func get_run_statistics() -> Dictionary:
	"""Returns current-run statistics (for no-death/speedrun checks)"""
	return {
		"run_deaths": run_deaths,
		"run_playtime_seconds": run_playtime_seconds
	}

func get_formatted_playtime() -> String:
	"""Returns playtime as HH:MM:SS string"""
	if SaveManager:
		total_playtime_seconds = SaveManager.playtime_seconds
	var hours = total_playtime_seconds / 3600
	var minutes = (total_playtime_seconds % 3600) / 60
	var seconds = total_playtime_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

# ============================================================================
# SAVE/LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	"""Returns data for persistence"""
	if SaveManager:
		total_playtime_seconds = SaveManager.playtime_seconds

	return {
		"total_deaths": total_deaths,
		"total_playtime_seconds": total_playtime_seconds,
		"enemies_killed": enemies_killed,
		"perfect_parries": perfect_parries,
		"total_damage_dealt": total_damage_dealt,
		"total_damage_taken": total_damage_taken,
		"max_combo": max_combo,
		"bosses_defeated_count": bosses_defeated_count,
		"resonance_modes_activated": resonance_modes_activated,
		"urgathon_uses": urgathon_uses,
		"secrets_found_count": secrets_found_count,
		"relics_collected": relics_collected,
		"rooms_visited": rooms_visited,
		"coins_total_earned": coins_total_earned,
		"run_deaths": run_deaths,
		"run_playtime_seconds": run_playtime_seconds
	}

func load_from_save(data: Dictionary) -> void:
	"""Restores statistics from save data"""
	total_deaths = data.get("total_deaths", 0)
	total_playtime_seconds = data.get("total_playtime_seconds", 0)
	enemies_killed = data.get("enemies_killed", 0)
	perfect_parries = data.get("perfect_parries", 0)
	total_damage_dealt = data.get("total_damage_dealt", 0)
	total_damage_taken = data.get("total_damage_taken", 0)
	max_combo = data.get("max_combo", 0)
	bosses_defeated_count = data.get("bosses_defeated_count", 0)
	resonance_modes_activated = data.get("resonance_modes_activated", 0)
	urgathon_uses = data.get("urgathon_uses", 0)
	secrets_found_count = data.get("secrets_found_count", 0)
	relics_collected = data.get("relics_collected", 0)
	rooms_visited = data.get("rooms_visited", 0)
	coins_total_earned = data.get("coins_total_earned", 0)
	run_deaths = data.get("run_deaths", 0)
	run_playtime_seconds = data.get("run_playtime_seconds", 0)
	print("[StatisticsManager] Statistics loaded from save")
