extends Node
## LythrunStatsScaling - Adaptive scaling calculator for Player 2
## Scales from 80% (no items) to 110% (max items) based on P1's shop purchases
class_name LythrunStatsScaling

# ============ SCALING CONSTANTS ============
const BASE_SCALING: float = 0.8  # 80% of Murum without any shop items
const SCALING_PER_SHOP_ITEM: float = 0.05  # +5% per shop item purchased
const MAX_SCALING: float = 1.1  # Maximum 110% (becomes rival)

# ============ SCALING CALCULATION ============

static func calculate_scaling_factor() -> float:
	"""Calculate P2's scaling factor based on P1's shop item count"""
	var shop_items_count = count_shop_items()
	var scaling = BASE_SCALING + (shop_items_count * SCALING_PER_SHOP_ITEM)
	scaling = clamp(scaling, BASE_SCALING, MAX_SCALING)

	print("[Lythrun Scaling] Shop Items: %d | Scaling: %.0f%%" % [shop_items_count, scaling * 100])

	return scaling

static func count_shop_items() -> int:
	"""Count total shop items (consumables + relics) purchased by P1"""
	var count = 0

	# Count consumables from all 3 worlds
	var consumable_ids = [
		# World 1 - Ruins
		"heilkraeuter", "glas_gleichgewicht", "schimmernde_essenz",
		"zerbrochene_muenze", "funken_gnade",
		# World 2 - Tech City
		"nanofluid_patch", "stabilitaet_modul", "neural_booster",
		"katalysatorchip", "core_reconstructor",
		# World 3 - Abyss
		"blut_vergessens", "zerfallener_segen", "zeitlose_scherbe",
		"echo_relikt", "traene_erwachens"
	]

	for item_id in consumable_ids:
		if InventoryManager and InventoryManager.has_method("has_item"):
			if InventoryManager.has_item(item_id):
				count += 1

	# Count relics (permanent upgrades)
	var relic_ids = [
		"auge_von_xy", "splitter_von_xa", "urtraene",
		"quanten_nucleus", "lins_kette", "blitzmauer",
		"runenfragment_lythrun", "echo_antwort", "herz_leere"
	]

	for relic_id in relic_ids:
		if InventoryManager and InventoryManager.has_method("has_relic"):
			if InventoryManager.has_relic(relic_id):
				count += 1

	return count

static func apply_scaling_to_stats(base_stats: Dictionary, scaling: float) -> Dictionary:
	"""Apply scaling factor to all stats"""
	return {
		"max_hp": int(base_stats.get("max_hp", 100) * scaling),
		"max_mana": int(base_stats.get("max_mana", 100) * scaling),
		"damage": base_stats.get("damage", 20.0) * scaling,
		"movement_speed": base_stats.get("movement_speed", 300.0) * scaling,
		"dash_speed": base_stats.get("dash_speed", 800.0) * scaling,
		"jump_force": base_stats.get("jump_force", 800.0) * scaling,
		"parry_window": base_stats.get("parry_window", 0.3) * scaling,
		"staff_throw_damage": base_stats.get("staff_throw_damage", 30.0) * scaling,
		"urgathon_duration": base_stats.get("urgathon_duration", 10.0) * scaling,
		"mana_regen": base_stats.get("mana_regen", 10.0) * scaling
	}

static func get_scaling_description(scaling: float) -> String:
	"""Get description of current scaling level"""
	if scaling <= 0.8:
		return "Supporter (80%)"
	elif scaling <= 0.9:
		return "Balanced (90%)"
	elif scaling < 1.0:
		return "Strong (95%)"
	elif scaling == 1.0:
		return "Equal (100%)"
	else:
		return "Rival (110%)"
