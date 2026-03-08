extends Node
## UpgradeManager - Permanent upgrades purchased with Magicka
## 8 Upgrades with multiple tiers, persisted via SaveManager

# ============ SIGNALS ============
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal upgrade_changed(upgrade_id: String, new_level: int)

# ============ UPGRADE DEFINITIONS ============

const UPGRADES := {
	"erwachende_essenz": {
		"name": "Erwachende Essenz",
		"lore": "Ein Teil von Murums ursprünglicher Kraft kehrt zurück.",
		"max_level": 4,
		"costs": [1, 2, 3, 4],
		"effects": [
			{"hp_percent": 0.10, "description": "+10% Leben"},
			{"hp_percent": 0.20, "description": "+20% Leben"},
			{"hp_percent": 0.30, "description": "+30% Leben"},
			{"hp_percent": 0.40, "description": "+40% Leben"}
		]
	},
	"geschaerfter_wille": {
		"name": "Geschärfter Wille",
		"lore": "Murum beginnt wieder, mit klarer Entschlossenheit zu kämpfen.",
		"max_level": 4,
		"costs": [1, 2, 3, 4],
		"effects": [
			{"damage_percent": 0.10, "description": "+10% Schaden"},
			{"damage_percent": 0.20, "description": "+20% Schaden"},
			{"damage_percent": 0.30, "description": "+30% Schaden"},
			{"damage_percent": 0.40, "description": "+40% Schaden"}
		]
	},
	"ungebrochene_bewegung": {
		"name": "Ungebrochene Bewegung",
		"lore": "Die Schuld verliert langsam ihre Schwere.",
		"max_level": 3,
		"costs": [1, 2, 3],
		"effects": [
			{"speed_percent": 0.05, "description": "+5% Bewegungsgeschwindigkeit"},
			{"speed_percent": 0.10, "description": "+10% Bewegungsgeschwindigkeit"},
			{"speed_percent": 0.15, "description": "+15% Bewegungsgeschwindigkeit"}
		]
	},
	"widerstand_des_geistes": {
		"name": "Widerstand des Geistes",
		"lore": "Murums Geist wird stabiler.",
		"max_level": 3,
		"costs": [1, 2, 3],
		"effects": [
			{"cc_reduction": 0.25, "description": "Kontrollverlust-Effekte dauern 25% kürzer"},
			{"cc_reduction": 0.50, "description": "Kontrollverlust-Effekte dauern 50% kürzer"},
			{"cc_reduction": 1.0, "description": "Immunität gegen Kontroll-Effekte"}
		]
	},
	"blut_der_schlacht": {
		"name": "Blut der Schlacht",
		"lore": "Der Kampf nährt Murums Seele.",
		"max_level": 3,
		"costs": [1, 2, 3],
		"effects": [
			{"kill_heal_mana": true, "description": "Gegner heilen Mana wenn getötet"},
			{"kill_heal_mana": true, "kill_heal_hp": true, "description": "Gegner heilen Mana und Leben wenn getötet"},
			{"kill_heal_mana": true, "kill_heal_hp": true, "kill_heal_bonus": true, "description": "Heilung erhöht"}
		]
	},
	"erinnerung_der_voch_numta": {
		"name": "Erinnerung der Voch Numta",
		"lore": "Das Wissen der Voch Numta hallt in Murum nach.",
		"max_level": 2,
		"costs": [2, 4],
		"effects": [
			{"damage_reduction": 0.40, "description": "Schaden um 40% reduziert"},
			{"damage_reduction": 0.40, "perfect_block_immunity": true, "description": "Murum erhält kurze Immunität nach perfektem Block"}
		]
	},
	"echo_der_macht": {
		"name": "Echo der Macht",
		"lore": "Murums Schläge hallen durch die Realität.",
		"max_level": 3,
		"costs": [1, 2, 3],
		"effects": [
			{"echo_chance": 0.15, "description": "Chance auf zusätzlichen Treffer nach Angriff"},
			{"echo_chance": 0.25, "echo_aoe": true, "description": "Höhere Chance + AoE-Schaden"},
			{"echo_chance": 0.35, "echo_aoe": true, "echo_strong": true, "description": "Stärkerer Echo-Schaden"}
		]
	},
	"urgathons_erbe": {
		"name": "Urgathons Erbe",
		"lore": "Die uralte Macht von Urgathon durchströmt Murum.",
		"max_level": 2,
		"costs": [2, 4],
		"effects": [
			{"mana_regen_percent": 0.50, "description": "Mana-Regeneration +50%"},
			{"mana_regen_percent": 0.50, "ability_damage_percent": 0.50, "description": "Alle Fähigkeiten +50% Schaden"}
		]
	}
}

# ============ STATE ============

## Current upgrade levels: upgrade_id -> int (0 = not purchased)
var upgrade_levels: Dictionary = {}


func _ready() -> void:
	_initialize_levels()
	print("[UpgradeManager] Initialized with %d upgrades" % UPGRADES.size())


func _initialize_levels() -> void:
	for upgrade_id in UPGRADES:
		if upgrade_id not in upgrade_levels:
			upgrade_levels[upgrade_id] = 0


# ============ PURCHASE ============

func can_purchase(upgrade_id: String) -> bool:
	"""Returns true if upgrade can be purchased (has next level and enough Magicka)"""
	if upgrade_id not in UPGRADES:
		return false

	var current = upgrade_levels.get(upgrade_id, 0)
	var max_level = UPGRADES[upgrade_id]["max_level"]
	if current >= max_level:
		return false

	var cost = get_next_cost(upgrade_id)
	return RunManager.get_magicka() >= cost


func purchase(upgrade_id: String) -> bool:
	"""Purchases next level of an upgrade. Returns true on success."""
	if not can_purchase(upgrade_id):
		return false

	var cost = get_next_cost(upgrade_id)
	if not RunManager.spend_magicka(cost):
		return false

	upgrade_levels[upgrade_id] += 1
	var new_level = upgrade_levels[upgrade_id]

	upgrade_purchased.emit(upgrade_id, new_level)
	upgrade_changed.emit(upgrade_id, new_level)

	print("[UpgradeManager] Purchased %s Stufe %d (cost: %d Magicka)" % [
		UPGRADES[upgrade_id]["name"], new_level, cost
	])
	return true


# ============ GETTERS ============

func get_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)


func get_max_level(upgrade_id: String) -> int:
	if upgrade_id not in UPGRADES:
		return 0
	return UPGRADES[upgrade_id]["max_level"]


func is_maxed(upgrade_id: String) -> bool:
	return get_level(upgrade_id) >= get_max_level(upgrade_id)


func get_next_cost(upgrade_id: String) -> int:
	"""Returns cost for the next level (0 if maxed)"""
	if upgrade_id not in UPGRADES:
		return 0

	var current = upgrade_levels.get(upgrade_id, 0)
	var costs = UPGRADES[upgrade_id]["costs"]
	if current >= costs.size():
		return 0
	return costs[current]


func get_current_effect(upgrade_id: String) -> Dictionary:
	"""Returns the effect dict for current level (empty if level 0)"""
	var level = get_level(upgrade_id)
	if level <= 0 or upgrade_id not in UPGRADES:
		return {}
	return UPGRADES[upgrade_id]["effects"][level - 1]


func get_next_effect(upgrade_id: String) -> Dictionary:
	"""Returns the effect dict for the next level (empty if maxed)"""
	var level = get_level(upgrade_id)
	if upgrade_id not in UPGRADES:
		return {}
	var effects = UPGRADES[upgrade_id]["effects"]
	if level >= effects.size():
		return {}
	return effects[level]


# ============ GAMEPLAY MULTIPLIERS ============

func get_hp_multiplier() -> float:
	"""Returns HP bonus from Erwachende Essenz"""
	var effect = get_current_effect("erwachende_essenz")
	return 1.0 + effect.get("hp_percent", 0.0)


func get_damage_multiplier() -> float:
	"""Returns damage bonus from Geschärfter Wille"""
	var effect = get_current_effect("geschaerfter_wille")
	return 1.0 + effect.get("damage_percent", 0.0)


func get_speed_multiplier() -> float:
	"""Returns speed bonus from Ungebrochene Bewegung"""
	var effect = get_current_effect("ungebrochene_bewegung")
	return 1.0 + effect.get("speed_percent", 0.0)


func get_cc_reduction() -> float:
	"""Returns CC reduction from Widerstand des Geistes (0.0 to 1.0)"""
	var effect = get_current_effect("widerstand_des_geistes")
	return effect.get("cc_reduction", 0.0)


func get_damage_reduction() -> float:
	"""Returns damage reduction from Erinnerung der Voch Numta"""
	var effect = get_current_effect("erinnerung_der_voch_numta")
	return effect.get("damage_reduction", 0.0)


func has_perfect_block_immunity() -> bool:
	"""Returns whether perfect block grants immunity"""
	var effect = get_current_effect("erinnerung_der_voch_numta")
	return effect.get("perfect_block_immunity", false)


func get_echo_chance() -> float:
	"""Returns echo hit chance from Echo der Macht"""
	var effect = get_current_effect("echo_der_macht")
	return effect.get("echo_chance", 0.0)


func has_echo_aoe() -> bool:
	var effect = get_current_effect("echo_der_macht")
	return effect.get("echo_aoe", false)


func has_echo_strong() -> bool:
	var effect = get_current_effect("echo_der_macht")
	return effect.get("echo_strong", false)


func get_mana_regen_multiplier() -> float:
	"""Returns mana regen bonus from Urgathons Erbe"""
	var effect = get_current_effect("urgathons_erbe")
	return 1.0 + effect.get("mana_regen_percent", 0.0)


func get_ability_damage_multiplier() -> float:
	"""Returns ability damage bonus from Urgathons Erbe"""
	var effect = get_current_effect("urgathons_erbe")
	return 1.0 + effect.get("ability_damage_percent", 0.0)


func get_kill_heal_data() -> Dictionary:
	"""Returns kill heal data from Blut der Schlacht"""
	return get_current_effect("blut_der_schlacht")


# ============ SAVE/LOAD ============

func get_save_data() -> Dictionary:
	return {"upgrade_levels": upgrade_levels.duplicate()}


func load_from_save(data: Dictionary) -> void:
	var saved_levels = data.get("upgrade_levels", {})
	for upgrade_id in saved_levels:
		if upgrade_id in UPGRADES:
			upgrade_levels[upgrade_id] = clampi(
				saved_levels[upgrade_id], 0, UPGRADES[upgrade_id]["max_level"]
			)
	print("[UpgradeManager] Loaded: %s" % str(upgrade_levels))


func reset_all() -> void:
	"""Resets all upgrades to level 0"""
	for upgrade_id in upgrade_levels:
		upgrade_levels[upgrade_id] = 0
	print("[UpgradeManager] All upgrades reset")
