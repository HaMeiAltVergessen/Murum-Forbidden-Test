extends Node
## ChallengeRunManager - "Ebenen des Deliriums" / Murums Albtraum
## Hades-inspiriertes System mit "Murums Qualen" als Modifikatoren
## Ab 50%+ Delirium aktiviert sich die "Schwellensicht" (kosmischer Horror)

# ============================================================================
# SIGNALS
# ============================================================================

signal modifier_changed(modifier_id: String, new_level: int)
signal challenge_run_started(active_modifiers: Dictionary)
signal challenge_run_completed(active_modifiers: Dictionary)
signal schwellensicht_changed(active: bool)

# ============================================================================
# MURUMS QUALEN - MODIFIER DEFINITIONS
# ============================================================================

## Tiered modifiers - each upgradeable 2x (levels 0/1/2)
const TIERED_MODIFIERS := {
	"zaeher_alptraum": {
		"name": "Zäher Alptraum",
		"description": "Die Kreaturen des Traums sind widerstandsfähiger",
		"max_level": 2,
		"values": [1.0, 1.5, 2.0],
		"dialog_suffix": ["", "_za1", "_za2"]
	},
	"endlose_schatten": {
		"name": "Endlose Schatten",
		"description": "Mehr Schattenwesen manifestieren sich",
		"max_level": 2,
		"values": [1.0, 1.3, 1.6],
		"dialog_suffix": ["", "_es1", "_es2"]
	},
	"schmerzensecho": {
		"name": "Schmerzensecho",
		"description": "Schmerz hallt durch die Traumschichten",
		"max_level": 2,
		"values": [1.0, 1.5, 2.0],
		"dialog_suffix": ["", "_se1", "_se2"]
	},
	"schwindendes_bewusstsein": {
		"name": "Schwindendes Bewusstsein",
		"description": "Murums Bewusstsein droht zu verblassen",
		"max_level": 2,
		"values": [0, 3600, 1800],
		"dialog_suffix": ["", "_sb1", "_sb2"]
	},
	"zerbrechlicher_geist": {
		"name": "Zerbrechlicher Geist",
		"description": "Murums Lebenskraft ist geschwächt",
		"max_level": 2,
		"values": [1.0, 0.75, 0.5],
		"dialog_suffix": ["", "_zg1", "_zg2"]
	},
	"traumfaeule": {
		"name": "Traumfäule",
		"description": "Heilung verrottet in den Traumschichten",
		"max_level": 2,
		"values": [1.0, 0.5, 0.25],
		"dialog_suffix": ["", "_tf1", "_tf2"]
	},
	"verblassende_kraft": {
		"name": "Verblassende Kraft",
		"description": "Murums Angriffe verlieren an Wucht",
		"max_level": 2,
		"values": [1.0, 0.75, 0.5],
		"dialog_suffix": ["", "_vk1", "_vk2"]
	}
}

## Toggle modifier (on/off)
const TOGGLE_MODIFIERS := {
	"myrkurs_siegel": {
		"name": "Myrkurs Siegel",
		"description": "Das Siegel der kosmischen Finsternis erwacht",
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
## Timer for Schwindendes Bewusstsein
var challenge_timer: float = 0.0
## Time limit in seconds (0 = no limit)
var challenge_time_limit: float = 0.0
## Deepest delirium level completed
var deepest_delirium_reached: int = 0
## Whether Schwellensicht is currently active
var is_schwellensicht_active: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_reset_modifiers()
	print("[ChallengeRunManager] Ebenen des Deliriums initialisiert")

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
		push_warning("[ChallengeRunManager] Unbekannte Qual: %s" % modifier_id)
		return

	active_modifiers[modifier_id] = level
	modifier_changed.emit(modifier_id, level)
	_check_schwellensicht()
	print("[ChallengeRunManager] Qual %s auf Stufe %d gesetzt" % [modifier_id, level])

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
	"""Returns HP multiplier for enemies (Zäher Alptraum)"""
	var level = active_modifiers.get("zaeher_alptraum", 0)
	return TIERED_MODIFIERS["zaeher_alptraum"]["values"][level]

func get_enemy_count_multiplier() -> float:
	"""Returns spawn count multiplier (Endlose Schatten)"""
	var level = active_modifiers.get("endlose_schatten", 0)
	return TIERED_MODIFIERS["endlose_schatten"]["values"][level]

func get_damage_to_player_multiplier() -> float:
	"""Returns damage multiplier applied to player (Schmerzensecho)"""
	var level = active_modifiers.get("schmerzensecho", 0)
	return TIERED_MODIFIERS["schmerzensecho"]["values"][level]

func get_time_limit() -> float:
	"""Returns time limit in seconds (0 = no limit) (Schwindendes Bewusstsein)"""
	var level = active_modifiers.get("schwindendes_bewusstsein", 0)
	return TIERED_MODIFIERS["schwindendes_bewusstsein"]["values"][level]

func get_player_max_hp_multiplier() -> float:
	"""Returns max HP multiplier for player (Zerbrechlicher Geist)"""
	var level = active_modifiers.get("zerbrechlicher_geist", 0)
	return TIERED_MODIFIERS["zerbrechlicher_geist"]["values"][level]

func get_healing_multiplier() -> float:
	"""Returns healing multiplier (Traumfäule)"""
	var level = active_modifiers.get("traumfaeule", 0)
	return TIERED_MODIFIERS["traumfaeule"]["values"][level]

func get_player_damage_multiplier() -> float:
	"""Returns player damage multiplier (Verblassende Kraft)"""
	var level = active_modifiers.get("verblassende_kraft", 0)
	return TIERED_MODIFIERS["verblassende_kraft"]["values"][level]

func has_extra_boss_phases() -> bool:
	"""Returns whether Myrkurs Siegel is active (extra boss phases)"""
	return active_modifiers.get("myrkurs_siegel", 0) > 0

# ============================================================================
# DELIRIUM CALCULATION
# ============================================================================

func get_delirium_depth() -> int:
	"""Returns total delirium depth (sum of all modifier levels)"""
	var total = 0
	for modifier_id in active_modifiers:
		total += active_modifiers[modifier_id]
	return total

func get_max_delirium() -> int:
	"""Returns maximum possible delirium depth"""
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

# Legacy compatibility
func get_total_heat() -> int:
	return get_delirium_depth()

func get_max_heat() -> int:
	return get_max_delirium()

# ============================================================================
# SCHWELLENSICHT SYSTEM
# ============================================================================

func _check_schwellensicht() -> void:
	"""Checks if Schwellensicht threshold is reached (50%+ delirium)"""
	var threshold = get_max_delirium() * 0.5
	var new_state = get_delirium_depth() >= threshold
	if new_state != is_schwellensicht_active:
		is_schwellensicht_active = new_state
		schwellensicht_changed.emit(new_state)
		if EventBus:
			EventBus.schwellensicht_changed.emit(new_state)
		print("[ChallengeRunManager] Schwellensicht: %s (Delirium: %d/%d)" % [
			"AKTIV" if new_state else "inaktiv",
			get_delirium_depth(),
			get_max_delirium()
		])

# ============================================================================
# DIALOG VARIANT SUPPORT
# ============================================================================

func get_dialog_variant_suffix() -> String:
	"""Returns suffix for dialog variant loading based on active modifiers"""
	if not is_challenge_run_active:
		return ""

	# Myrkurs Siegel takes priority for dialog variants
	if has_extra_boss_phases():
		return TOGGLE_MODIFIERS["myrkurs_siegel"]["dialog_suffix"]

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

	# Activate Schwellensicht if threshold met
	_check_schwellensicht()

	print("[ChallengeRunManager] Abstieg in den Albtraum! Delirium: %d/%d" % [get_delirium_depth(), get_max_delirium()])
	for modifier_id in active_modifiers:
		if active_modifiers[modifier_id] > 0:
			print("[ChallengeRunManager]   Qual: %s - Stufe %d" % [modifier_id, active_modifiers[modifier_id]])

	challenge_run_started.emit(active_modifiers.duplicate())
	EventBus.challenge_run_started.emit(active_modifiers.duplicate())

func complete_challenge_run() -> void:
	"""Called when the final boss is defeated during a challenge run"""
	var depth = get_delirium_depth()
	if depth > deepest_delirium_reached:
		deepest_delirium_reached = depth

	print("[ChallengeRunManager] Albtraum überwunden! Delirium: %d" % depth)

	challenge_run_completed.emit(active_modifiers.duplicate())
	EventBus.challenge_run_completed.emit(active_modifiers.duplicate())

	# Deactivate Schwellensicht
	if is_schwellensicht_active:
		is_schwellensicht_active = false
		schwellensicht_changed.emit(false)
		if EventBus:
			EventBus.schwellensicht_changed.emit(false)

	is_challenge_run_active = false

func _on_time_expired() -> void:
	"""Called when the Schwindendes Bewusstsein timer expires"""
	print("[ChallengeRunManager] Bewusstsein verblasst! Albtraum gescheitert.")
	is_challenge_run_active = false

	# Deactivate Schwellensicht
	if is_schwellensicht_active:
		is_schwellensicht_active = false
		schwellensicht_changed.emit(false)
		if EventBus:
			EventBus.schwellensicht_changed.emit(false)

	EventBus.challenge_run_failed.emit("Murums Bewusstsein ist verblasst!")

func end_challenge_run() -> void:
	"""Ends the current challenge run without completion"""
	is_challenge_run_active = false
	challenge_timer = 0.0

	# Deactivate Schwellensicht
	if is_schwellensicht_active:
		is_schwellensicht_active = false
		schwellensicht_changed.emit(false)
		if EventBus:
			EventBus.schwellensicht_changed.emit(false)

	print("[ChallengeRunManager] Albtraum beendet")

# ============================================================================
# ENDING CONDITIONS
# ============================================================================

func should_trigger_true_ending() -> bool:
	"""Returns true if all modifiers maxed and final boss defeated"""
	return is_challenge_run_active and are_all_modifiers_maxed()

func should_trigger_myrkur_ending() -> bool:
	"""Returns true if Myrkurs Siegel is active (but not all maxed)"""
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
		"deepest_delirium_reached": deepest_delirium_reached
	}

func load_from_save(data: Dictionary) -> void:
	"""Restores state from save data"""
	var saved_modifiers = data.get("active_modifiers", {})
	for modifier_id in saved_modifiers:
		active_modifiers[modifier_id] = saved_modifiers[modifier_id]

	is_challenge_run_active = data.get("is_active", false)
	challenge_timer = data.get("challenge_timer", 0.0)
	deepest_delirium_reached = data.get("deepest_delirium_reached", data.get("highest_heat_completed", 0))

	if is_challenge_run_active:
		challenge_time_limit = get_time_limit()
		_check_schwellensicht()

	print("[ChallengeRunManager] Zustand geladen. Aktiv: %s, Delirium: %d" % [is_challenge_run_active, get_delirium_depth()])
