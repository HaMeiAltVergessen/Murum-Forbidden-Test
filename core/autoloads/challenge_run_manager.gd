extends Node
## ChallengeRunManager - Siegel-Run System
## 33 Siegel-Modifier als Knotenpunkte eines mystischen Siegels
## Spieler vervollständigen ein Siegel statt eine Difficulty-Liste
## HINWEIS: Dieser Commit enthält nur UI + Datenstruktur, keine Gameplay-Mechaniken

# ============================================================================
# SIGNALS
# ============================================================================

signal modifier_changed(modifier_id: String, is_active: bool)
signal challenge_run_started(active_modifiers: Dictionary)
signal challenge_run_completed(active_modifiers: Dictionary)
signal schwellensicht_changed(active: bool)

# ============================================================================
# SIEGEL-MODIFIER DEFINITIONS (33 Knotenpunkte)
# ============================================================================

## All 33 seal modifiers - currently data-only, gameplay effects follow later
## Structure: { id: { name, description, is_active } }
## Later additions: effect_type, effect_value, trigger_conditions
const SIEGEL_MODIFIERS := {
	# --- Kern-Qualen (1-8) ---
	"zaeher_alptraum": {
		"name": "Zäher Alptraum",
		"description": "Gegner besitzen mehr Lebenspunkte. Kämpfe dauern länger. Gegner werden schwerer zu besiegen.",
		"category": "kern"
	},
	"endlose_schatten": {
		"name": "Endlose Schatten",
		"description": "Mehr Gegner erscheinen in Räumen. Kampfdichte steigt deutlich.",
		"category": "kern"
	},
	"schmerz": {
		"name": "Schmerz",
		"description": "Gegner verursachen erhöhten Schaden. Fehler werden stärker bestraft.",
		"category": "kern"
	},
	"schwindendes_bewusstsein": {
		"name": "Schwindendes Bewusstsein",
		"description": "Der Run besitzt ein Zeitlimit. Spieler muss effizient spielen.",
		"category": "kern"
	},
	"zerbrechlicher_geist": {
		"name": "Zerbrechlicher Geist",
		"description": "Murum besitzt weniger Lebenspunkte. Überleben wird schwieriger.",
		"category": "kern"
	},
	"traumfaeule": {
		"name": "Traumfäule",
		"description": "Heilung wirkt schwächer. Ressourcenmanagement wird wichtiger.",
		"category": "kern"
	},
	"verblassende_kraft": {
		"name": "Verblassende Kraft",
		"description": "Murum verursacht weniger Schaden. Kämpfe werden länger und gefährlicher.",
		"category": "kern"
	},
	"myrkurs_fluch": {
		"name": "Myrkurs Fluch",
		"description": "Bosse besitzen zusätzliche Albtraumphase. Bosskämpfe werden erweitert.",
		"category": "kern"
	},
	# --- Albtraum-Qualen (9-14) ---
	"fluesternde_schattenhorden": {
		"name": "Flüsternde Schattenhorden",
		"description": "Spieler kann plötzlich in dunkle Arenen teleportiert werden. Berserker-Horden erscheinen kurzzeitig.",
		"category": "albtraum"
	},
	"zerfall_der_erinnerung": {
		"name": "Zerfall der Erinnerung",
		"description": "Minimap funktioniert nur eingeschränkt. Orientierung wird schwieriger.",
		"category": "albtraum"
	},
	"risse_der_vergangenheit": {
		"name": "Risse der Vergangenheit",
		"description": "Besiegte Gegner hinterlassen instabile Risse. Diese können kurz darauf explodieren.",
		"category": "albtraum"
	},
	"risse_im_traum": {
		"name": "Risse im Traum",
		"description": "Instabile Portale erscheinen. Gegner strömen daraus hervor.",
		"category": "albtraum"
	},
	"fallende_sterne": {
		"name": "Fallende Sterne",
		"description": "Kosmische Splitter schlagen gelegentlich in Räumen ein. Diese verursachen Explosionen.",
		"category": "albtraum"
	},
	"der_wahre_traum": {
		"name": "Der wahre Traum",
		"description": "Einige Räume verwandeln sich in Albtraumversionen. Atmosphäre und Gegner verändern sich.",
		"category": "albtraum"
	},
	# --- Körper-Qualen (15-21) ---
	"verzweiflung_und_raserei": {
		"name": "Verzweiflung & Raserei",
		"description": "Murums Angriffe sind extrem stark. Verteidigung sinkt drastisch.",
		"category": "koerper"
	},
	"schwere_last": {
		"name": "Schwere Last",
		"description": "Bewegungsgeschwindigkeit reduziert. Ausweichbewegungen langsamer.",
		"category": "koerper"
	},
	"schlafwanderer": {
		"name": "Schlafwanderer",
		"description": "Murum bewegt sich gelegentlich automatisch weiter. Kontrolle über Bewegung wird erschwert.",
		"category": "koerper"
	},
	"gespaltene_persoenlichkeit": {
		"name": "Gespaltene Persönlichkeit",
		"description": "Angriffsrichtung kann sich spiegeln. Steuerung wird unberechenbarer.",
		"category": "koerper"
	},
	"hunger_der_finsternis": {
		"name": "Hunger der Finsternis",
		"description": "Wenn Murum nicht kämpft, verliert er langsam Leben. Spieler muss aggressiv bleiben.",
		"category": "koerper"
	},
	"verlorenes_licht": {
		"name": "Verlorenes Licht",
		"description": "Heilung funktioniert nur noch beim Respawn. Zwischenkämpfe werden gefährlicher.",
		"category": "koerper"
	},
	"fluch_der_umkehr": {
		"name": "Fluch der Umkehr",
		"description": "Heilquellen verursachen Schaden. Spieler muss Heilung vermeiden.",
		"category": "koerper"
	},
	# --- Relikte & Fähigkeiten (22) ---
	"zerbrochen_zerstoert_zerfallen": {
		"name": "Zerbrochen, zerstört, zerfallen",
		"description": "Relikte und Fähigkeiten wirken schwächer. Builds verlieren Effektivität.",
		"category": "koerper"
	},
	# --- Myrkur-Qualen (23-25) ---
	"myrkurs_blick": {
		"name": "Myrkurs Blick",
		"description": "Räume können in Dunkelheit gehüllt werden. Gegner erscheinen in Wellen.",
		"category": "myrkur"
	},
	"myrkurs_schleier": {
		"name": "Myrkurs Schleier",
		"description": "Murums Sichtweite wird reduziert. Umgebung wird schwerer erkennbar.",
		"category": "myrkur"
	},
	"myrkurs_gelaechter": {
		"name": "Myrkurs Gelächter",
		"description": "Schaden kann Zeit im Timer reduzieren. Zeitdruck steigt.",
		"category": "myrkur"
	},
	# --- Voch Numta-Qualen (26-28) ---
	"urteil_der_voch_numta": {
		"name": "Urteil der Voch Numta",
		"description": "Schaden kann göttliche Bestrafungen auslösen. Spieler muss präziser kämpfen.",
		"category": "voch_numta"
	},
	"zerbrochene_statue": {
		"name": "Zerbrochene Statue",
		"description": "Beschädigte Voch-Numta-Statuen verstärken Gegner. Gegner erhalten Buffs in ihrer Nähe.",
		"category": "voch_numta"
	},
	"erbe_der_voch_numta": {
		"name": "Erbe der Voch Numta",
		"description": "Fragmente können erscheinen. Sie können Murum oder Gegner stärken.",
		"category": "voch_numta"
	},
	# --- Urgathon-Qualen (29-33) ---
	"versiegelt_in_stille": {
		"name": "Versiegelt in Stille",
		"description": "Spezialfähigkeiten sind versiegelt. Murum kann nur grundlegende Aktionen nutzen.",
		"category": "urgathon"
	},
	"stimme_aus_urgathon": {
		"name": "Stimme aus Urgathon",
		"description": "Kosmische Stimmen können Murum betäuben. Spieler muss rechtzeitig reagieren.",
		"category": "urgathon"
	},
	"puls_von_urgathon": {
		"name": "Puls von Urgathon",
		"description": "Periodische Druckwellen bewegen Einheiten. Positionierung wird schwieriger.",
		"category": "urgathon"
	},
	"echo_des_zorns": {
		"name": "Echo des Zorns",
		"description": "Angriffe erzeugen verzögerte Explosionen. Kämpfe werden chaotischer.",
		"category": "urgathon"
	},
	"die_vergessenen": {
		"name": "Die Vergessenen",
		"description": "Besiegte Gegner können erneut aufstehen. Kämpfe dauern länger.",
		"category": "urgathon"
	}
}

## Category display info for the seal visualization
const CATEGORY_INFO := {
	"kern": {"name": "Kern-Qualen", "color": Color(0.9, 0.75, 0.3, 1.0)},
	"albtraum": {"name": "Albtraum-Qualen", "color": Color(0.6, 0.3, 0.9, 1.0)},
	"koerper": {"name": "Körper-Qualen", "color": Color(0.8, 0.2, 0.2, 1.0)},
	"myrkur": {"name": "Myrkur-Qualen", "color": Color(0.2, 0.0, 0.4, 1.0)},
	"voch_numta": {"name": "Voch Numta-Qualen", "color": Color(0.9, 0.85, 0.5, 1.0)},
	"urgathon": {"name": "Urgathon-Qualen", "color": Color(0.3, 0.8, 0.6, 1.0)}
}

# ============================================================================
# STATE
# ============================================================================

## Current modifier states: modifier_id -> bool (active/inactive)
var active_modifiers: Dictionary = {}
## Whether a challenge run is currently active
var is_challenge_run_active: bool = false
## Timer for Schwindendes Bewusstsein
var challenge_timer: float = 0.0
## Time limit in seconds (0 = no limit)
var challenge_time_limit: float = 0.0
## Deepest delirium level completed (most seals active)
var deepest_delirium_reached: int = 0
## Whether Schwellensicht is currently active
var is_schwellensicht_active: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_reset_modifiers()
	print("[ChallengeRunManager] Siegel-Run System initialisiert (%d Siegel)" % SIEGEL_MODIFIERS.size())

func _process(delta: float) -> void:
	if not is_challenge_run_active:
		return
	if challenge_time_limit <= 0:
		return

	challenge_timer += delta
	var remaining = challenge_time_limit - challenge_timer
	EventBus.challenge_time_updated.emit(remaining)

	if remaining <= 0:
		_on_time_expired()

func _reset_modifiers() -> void:
	"""Resets all modifiers to inactive"""
	active_modifiers.clear()
	for modifier_id in SIEGEL_MODIFIERS:
		active_modifiers[modifier_id] = 0

# ============================================================================
# MODIFIER MANAGEMENT
# ============================================================================

func set_modifier_level(modifier_id: String, level: int) -> void:
	"""Sets a modifier active (1) or inactive (0)"""
	if modifier_id not in SIEGEL_MODIFIERS:
		push_warning("[ChallengeRunManager] Unbekanntes Siegel: %s" % modifier_id)
		return

	level = clampi(level, 0, 1)
	active_modifiers[modifier_id] = level
	modifier_changed.emit(modifier_id, level > 0)
	_check_schwellensicht()

func toggle_modifier(modifier_id: String) -> void:
	"""Toggles a modifier on/off"""
	if modifier_id not in SIEGEL_MODIFIERS:
		push_warning("[ChallengeRunManager] Unbekanntes Siegel: %s" % modifier_id)
		return

	var current = active_modifiers.get(modifier_id, 0)
	set_modifier_level(modifier_id, 0 if current > 0 else 1)

func get_modifier_level(modifier_id: String) -> int:
	"""Returns current level of a modifier (0 or 1)"""
	return active_modifiers.get(modifier_id, 0)

func is_modifier_active(modifier_id: String) -> bool:
	"""Returns whether a modifier is active"""
	return active_modifiers.get(modifier_id, 0) > 0

func get_active_count() -> int:
	"""Returns number of active modifiers"""
	var count = 0
	for modifier_id in active_modifiers:
		if active_modifiers[modifier_id] > 0:
			count += 1
	return count

# ============================================================================
# GAMEPLAY MULTIPLIERS (Placeholder - effects follow in later commits)
# ============================================================================

func get_enemy_hp_multiplier() -> float:
	"""Returns HP multiplier for enemies (Zäher Alptraum)"""
	if is_modifier_active("zaeher_alptraum"):
		return 1.5
	return 1.0

func get_enemy_count_multiplier() -> float:
	"""Returns spawn count multiplier (Endlose Schatten)"""
	if is_modifier_active("endlose_schatten"):
		return 1.5
	return 1.0

func get_damage_to_player_multiplier() -> float:
	"""Returns damage multiplier applied to player (Schmerz)"""
	if is_modifier_active("schmerz"):
		return 1.5
	return 1.0

func get_time_limit() -> float:
	"""Returns time limit in seconds (0 = no limit) (Schwindendes Bewusstsein)"""
	if is_modifier_active("schwindendes_bewusstsein"):
		return 1800  # 30 minutes
	return 0.0

func get_player_max_hp_multiplier() -> float:
	"""Returns max HP multiplier for player (Zerbrechlicher Geist)"""
	if is_modifier_active("zerbrechlicher_geist"):
		return 0.5
	return 1.0

func get_healing_multiplier() -> float:
	"""Returns healing multiplier (Traumfäule)"""
	if is_modifier_active("traumfaeule"):
		return 0.25
	return 1.0

func get_player_damage_multiplier() -> float:
	"""Returns player damage multiplier (Verblassende Kraft)"""
	if is_modifier_active("verblassende_kraft"):
		return 0.5
	return 1.0

func has_extra_boss_phases() -> bool:
	"""Returns whether Myrkurs Fluch is active (extra boss phases)"""
	return is_modifier_active("myrkurs_fluch")

# ============================================================================
# DELIRIUM CALCULATION
# ============================================================================

func get_delirium_depth() -> int:
	"""Returns total active seal count"""
	return get_active_count()

func get_max_delirium() -> int:
	"""Returns total number of seals (33)"""
	return SIEGEL_MODIFIERS.size()

func are_all_modifiers_maxed() -> bool:
	"""Returns whether all seals are active"""
	return get_active_count() == SIEGEL_MODIFIERS.size()

# Legacy compatibility
func get_total_heat() -> int:
	return get_delirium_depth()

func get_max_heat() -> int:
	return get_max_delirium()

# ============================================================================
# SCHWELLENSICHT SYSTEM
# ============================================================================

func _check_schwellensicht() -> void:
	"""Checks if Schwellensicht threshold is reached (50%+ seals active)"""
	var threshold = get_max_delirium() * 0.5
	var new_state = get_delirium_depth() >= threshold
	if new_state != is_schwellensicht_active:
		is_schwellensicht_active = new_state
		schwellensicht_changed.emit(new_state)
		if EventBus:
			EventBus.schwellensicht_changed.emit(new_state)
		print("[ChallengeRunManager] Schwellensicht: %s (Siegel: %d/%d)" % [
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

	# Myrkurs Fluch takes priority for dialog variants
	if has_extra_boss_phases():
		return "_myrkur"

	# General challenge suffix if any seal is active
	if get_active_count() > 0:
		return "_siegel"

	return ""

# ============================================================================
# CHALLENGE RUN LIFECYCLE
# ============================================================================

func start_challenge_run() -> void:
	"""Starts a challenge run with current seal configuration"""
	is_challenge_run_active = true
	challenge_timer = 0.0
	challenge_time_limit = get_time_limit()

	_check_schwellensicht()

	print("[ChallengeRunManager] Siegel-Run gestartet! Aktive Siegel: %d/%d" % [get_active_count(), get_max_delirium()])
	for modifier_id in active_modifiers:
		if active_modifiers[modifier_id] > 0:
			var mod_name = SIEGEL_MODIFIERS[modifier_id]["name"]
			print("[ChallengeRunManager]   Siegel: %s" % mod_name)

	challenge_run_started.emit(active_modifiers.duplicate())
	EventBus.challenge_run_started.emit(active_modifiers.duplicate())

func complete_challenge_run() -> void:
	"""Called when the final boss is defeated during a challenge run"""
	var depth = get_active_count()
	if depth > deepest_delirium_reached:
		deepest_delirium_reached = depth

	print("[ChallengeRunManager] Siegel-Run abgeschlossen! Aktive Siegel: %d" % depth)

	challenge_run_completed.emit(active_modifiers.duplicate())
	EventBus.challenge_run_completed.emit(active_modifiers.duplicate())

	if is_schwellensicht_active:
		is_schwellensicht_active = false
		schwellensicht_changed.emit(false)
		if EventBus:
			EventBus.schwellensicht_changed.emit(false)

	is_challenge_run_active = false

func _on_time_expired() -> void:
	"""Called when the Schwindendes Bewusstsein timer expires"""
	print("[ChallengeRunManager] Bewusstsein verblasst! Siegel-Run gescheitert.")
	is_challenge_run_active = false

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

	if is_schwellensicht_active:
		is_schwellensicht_active = false
		schwellensicht_changed.emit(false)
		if EventBus:
			EventBus.schwellensicht_changed.emit(false)

	print("[ChallengeRunManager] Siegel-Run beendet")

# ============================================================================
# ENDING CONDITIONS
# ============================================================================

func should_trigger_true_ending() -> bool:
	"""Returns true if all seals active and final boss defeated"""
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
		"deepest_delirium_reached": deepest_delirium_reached
	}

func load_from_save(data: Dictionary) -> void:
	"""Restores state from save data"""
	var saved_modifiers = data.get("active_modifiers", {})
	for modifier_id in saved_modifiers:
		if modifier_id in SIEGEL_MODIFIERS:
			active_modifiers[modifier_id] = saved_modifiers[modifier_id]

	is_challenge_run_active = data.get("is_active", false)
	challenge_timer = data.get("challenge_timer", 0.0)
	deepest_delirium_reached = data.get("deepest_delirium_reached", data.get("highest_heat_completed", 0))

	if is_challenge_run_active:
		challenge_time_limit = get_time_limit()
		_check_schwellensicht()

	print("[ChallengeRunManager] Zustand geladen. Aktiv: %s, Siegel: %d/%d" % [
		is_challenge_run_active, get_active_count(), get_max_delirium()
	])
