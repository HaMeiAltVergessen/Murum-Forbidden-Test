extends Node
## ChallengeRunManager - Manages Hades-inspired "Heat" challenge modifiers
## Tiered modifiers (0/1/2) and toggle modifier (Myrkurs Fluch)

# ============================================================================
# SIGNALS
# ============================================================================

signal modifier_changed(modifier_id: String, new_level: int)
signal challenge_run_started(active_modifiers: Dictionary)
signal challenge_run_completed(active_modifiers: Dictionary)

# ============================================================================
# MODIFIER DEFINITIONS
# ============================================================================

## Tiered modifiers - each upgradeable 2x (levels 0/1/2)
const TIERED_MODIFIERS := {
	"mehr_gegnerleben": {
		"name": "Mehr Gegnerleben",
		"description": "Gegner haben mehr Lebenspunkte",
		"max_level": 2,
		"values": [1.0, 1.5, 2.0],
		"dialog_suffix": ["", "_mgl1", "_mgl2"]
	},
	"mehr_gegner": {
		"name": "Mehr Gegner",
		"description": "Mehr Gegner spawnen in Wellen",
		"max_level": 2,
		"values": [1.0, 1.3, 1.6],
		"dialog_suffix": ["", "_mg1", "_mg2"]
	},
	"mehr_schaden": {
		"name": "Mehr Schaden",
		"description": "Spieler erleidet mehr Schaden",
		"max_level": 2,
		"values": [1.0, 1.5, 2.0],
		"dialog_suffix": ["", "_ms1", "_ms2"]
	},
	"zeitlimit": {
		"name": "Zeitlimit",
		"description": "Zeitlimit fuer den gesamten Run",
		"max_level": 2,
		"values": [0, 3600, 1800],
		"dialog_suffix": ["", "_zl1", "_zl2"]
	}
}

## Toggle modifier (on/off)
const TOGGLE_MODIFIERS := {
	"myrkurs_fluch": {
		"name": "Myrkurs Fluch",
		"description": "Bosse erhalten zusaetzliche Phasen",
		"dialog_suffix": "_myrkur"
	}
}

# ============================================================================
# STATE
# ============================================================================

## Current modifier levels: modifier_id -> level (0 = off)
var active_modifiers: Dictionary = {}
## Whether a challenge run is currently active
var is_challenge_run_active: bool = false
## Timer for Zeitlimit
var challenge_timer: float = 0.0
## Time limit in seconds (0 = no limit)
var challenge_time_limit: float = 0.0
## Highest completed heat level
var highest_heat_completed: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_reset_modifiers()
	print("[ChallengeRunManager] Initialized")

func _process(delta: float) -> void:
	if not is_challenge_run_active:
		return
	if challenge_time_limit <= 0:
		return

	# Update timer
	challenge_timer += delta
	var remaining = challenge_time_limit - challenge_timer
	EventBus.challenge_time_updated.emit(remaining)

	if remaining <= 0:
		# Time's up - challenge failed
		_on_time_expired()

func _reset_modifiers() -> void:
	"""Resets all modifiers to default (off)"""
	active_modifiers.clear()
	for modifier_id in TIERED_MODIFIERS:
		active_modifiers[modifier_id] = 0
	for modifier_id in TOGGLE_MODIFIERS:
		active_modifiers[modifier_id] = 0

# ============================================================================
# MODIFIER MANAGEMENT
# ============================================================================

func set_modifier_level(modifier_id: String, level: int) -> void:
	"""Sets the level of a modifier"""
	if modifier_id in TIERED_MODIFIERS:
		var max_lvl = TIERED_MODIFIERS[modifier_id]["max_level"]
		level = clampi(level, 0, max_lvl)
	elif modifier_id in TOGGLE_MODIFIERS:
		level = clampi(level, 0, 1)
	else:
		push_warning("[ChallengeRunManager] Unknown modifier: %s" % modifier_id)
		return

	active_modifiers[modifier_id] = level
	modifier_changed.emit(modifier_id, level)
	print("[ChallengeRunManager] Modifier %s set to level %d" % [modifier_id, level])

func get_modifier_level(modifier_id: String) -> int:
	"""Returns current level of a modifier"""
	return active_modifiers.get(modifier_id, 0)

func is_modifier_active(modifier_id: String) -> bool:
	"""Returns whether a modifier is active (level > 0)"""
	return active_modifiers.get(modifier_id, 0) > 0

# ============================================================================
# GAMEPLAY MULTIPLIERS
# ============================================================================

func get_enemy_hp_multiplier() -> float:
	"""Returns HP multiplier for enemies"""
	var level = active_modifiers.get("mehr_gegnerleben", 0)
	return TIERED_MODIFIERS["mehr_gegnerleben"]["values"][level]

func get_enemy_count_multiplier() -> float:
	"""Returns spawn count multiplier"""
	var level = active_modifiers.get("mehr_gegner", 0)
	return TIERED_MODIFIERS["mehr_gegner"]["values"][level]

func get_damage_to_player_multiplier() -> float:
	"""Returns damage multiplier applied to player"""
	var level = active_modifiers.get("mehr_schaden", 0)
	return TIERED_MODIFIERS["mehr_schaden"]["values"][level]

func get_time_limit() -> float:
	"""Returns time limit in seconds (0 = no limit)"""
	var level = active_modifiers.get("zeitlimit", 0)
	return TIERED_MODIFIERS["zeitlimit"]["values"][level]

func has_extra_boss_phases() -> bool:
	"""Returns whether Myrkurs Fluch is active (extra boss phases)"""
	return active_modifiers.get("myrkurs_fluch", 0) > 0

# ============================================================================
# HEAT CALCULATION
# ============================================================================

func get_total_heat() -> int:
	"""Returns total heat level (sum of all modifier levels)"""
	var total = 0
	for modifier_id in active_modifiers:
		total += active_modifiers[modifier_id]
	return total

func get_max_heat() -> int:
	"""Returns maximum possible heat"""
	var total = 0
	for modifier_id in TIERED_MODIFIERS:
		total += TIERED_MODIFIERS[modifier_id]["max_level"]
	total += TOGGLE_MODIFIERS.size()  # Each toggle adds 1
	return total

func are_all_modifiers_maxed() -> bool:
	"""Returns whether all modifiers are at maximum level"""
	for modifier_id in TIERED_MODIFIERS:
		if active_modifiers.get(modifier_id, 0) < TIERED_MODIFIERS[modifier_id]["max_level"]:
			return false
	for modifier_id in TOGGLE_MODIFIERS:
		if active_modifiers.get(modifier_id, 0) < 1:
			return false
	return true

# ============================================================================
# DIALOG VARIANT SUPPORT
# ============================================================================

func get_dialog_variant_suffix() -> String:
	"""Returns suffix for dialog variant loading based on active modifiers"""
	if not is_challenge_run_active:
		return ""

	# Myrkurs Fluch takes priority for dialog variants
	if has_extra_boss_phases():
		return TOGGLE_MODIFIERS["myrkurs_fluch"]["dialog_suffix"]

	# Otherwise check tiered modifiers (highest active one)
	for modifier_id in TIERED_MODIFIERS:
		var level = active_modifiers.get(modifier_id, 0)
		if level > 0:
			return TIERED_MODIFIERS[modifier_id]["dialog_suffix"][level]

	return ""

# ============================================================================
# CHALLENGE RUN LIFECYCLE
# ============================================================================

func start_challenge_run() -> void:
	"""Starts a challenge run with current modifier settings"""
	is_challenge_run_active = true
	challenge_timer = 0.0
	challenge_time_limit = get_time_limit()

	print("[ChallengeRunManager] Challenge run started! Heat: %d/%d" % [get_total_heat(), get_max_heat()])
	for modifier_id in active_modifiers:
		if active_modifiers[modifier_id] > 0:
			print("[ChallengeRunManager]   %s: Level %d" % [modifier_id, active_modifiers[modifier_id]])

	challenge_run_started.emit(active_modifiers.duplicate())
	EventBus.challenge_run_started.emit(active_modifiers.duplicate())

func complete_challenge_run() -> void:
	"""Called when the final boss is defeated during a challenge run"""
	var heat = get_total_heat()
	if heat > highest_heat_completed:
		highest_heat_completed = heat

	print("[ChallengeRunManager] Challenge run completed! Heat: %d" % heat)

	challenge_run_completed.emit(active_modifiers.duplicate())
	EventBus.challenge_run_completed.emit(active_modifiers.duplicate())

	is_challenge_run_active = false

func _on_time_expired() -> void:
	"""Called when the Zeitlimit expires"""
	print("[ChallengeRunManager] Time expired! Challenge run failed.")
	is_challenge_run_active = false
	EventBus.challenge_run_failed.emit("Zeitlimit abgelaufen!")

func end_challenge_run() -> void:
	"""Ends the current challenge run without completion"""
	is_challenge_run_active = false
	challenge_timer = 0.0
	print("[ChallengeRunManager] Challenge run ended")

# ============================================================================
# ENDING CONDITIONS
# ============================================================================

func should_trigger_true_ending() -> bool:
	"""Returns true if all modifiers maxed and final boss defeated"""
	return is_challenge_run_active and are_all_modifiers_maxed()

func should_trigger_myrkur_ending() -> bool:
	"""Returns true if Myrkurs Fluch is active (but not all maxed)"""
	return is_challenge_run_active and has_extra_boss_phases() and not are_all_modifiers_maxed()

# ============================================================================
# SAVE/LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	"""Returns data for persistence"""
	return {
		"active_modifiers": active_modifiers.duplicate(),
		"is_active": is_challenge_run_active,
		"challenge_timer": challenge_timer,
		"highest_heat_completed": highest_heat_completed
	}

func load_from_save(data: Dictionary) -> void:
	"""Restores state from save data"""
	var saved_modifiers = data.get("active_modifiers", {})
	for modifier_id in saved_modifiers:
		active_modifiers[modifier_id] = saved_modifiers[modifier_id]

	is_challenge_run_active = data.get("is_active", false)
	challenge_timer = data.get("challenge_timer", 0.0)
	highest_heat_completed = data.get("highest_heat_completed", 0)

	if is_challenge_run_active:
		challenge_time_limit = get_time_limit()

	print("[ChallengeRunManager] State loaded from save. Active: %s, Heat: %d" % [is_challenge_run_active, get_total_heat()])
