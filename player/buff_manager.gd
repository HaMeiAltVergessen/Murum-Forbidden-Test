extends Node
## BuffManager - Handles temporary stat buffs from consumables
class_name BuffManager

# ============================================================================
# SIGNALS
# ============================================================================

signal buff_applied(buff_id: String, buff_data: Dictionary)
signal buff_expired(buff_id: String)
signal buff_updated()

# ============================================================================
# STATE
# ============================================================================

var active_buffs: Dictionary = {}  # buff_id -> buff_data
var next_buff_id: int = 0

# Aggregated stat modifiers (for easy querying)
var total_damage_reduction: float = 0.0
var total_damage_bonus: float = 0.0
var total_knockback_reduction: float = 0.0
var total_movement_speed_bonus: float = 0.0
var total_attack_speed_bonus: float = 0.0
var total_max_mana_bonus: float = 0.0
var total_environmental_damage_reduction: float = 0.0
var total_resonance_gain_bonus: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to EventBus signal from InventoryManager
	if is_instance_valid(EventBus):
		EventBus.consumable_buff_applied.connect(_on_consumable_buff_applied)

	print("[BuffManager] Initialized")


# ============================================================================
# BUFF APPLICATION
# ============================================================================

func apply_buff(item_data: Dictionary) -> String:
	"""Applies a buff from item data. Returns buff_id."""
	if not item_data.has("stats"):
		push_warning("[BuffManager] Item has no stats")
		return ""

	var buff_id = "buff_" + str(next_buff_id)
	next_buff_id += 1

	var stats = item_data["stats"]
	var duration_sec = stats.get("duration_sec", 0.0)

	var buff = {
		"id": buff_id,
		"item_id": item_data.get("id", ""),
		"item_name": item_data.get("name", "Unknown"),
		"stats": stats,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration_sec,
		"expire_time": (Time.get_ticks_msec() / 1000.0) + duration_sec
	}

	active_buffs[buff_id] = buff
	_apply_stat_modifiers(stats, 1.0)  # 1.0 = add

	# Start expiration timer if buff has duration
	if duration_sec > 0:
		var timer = get_tree().create_timer(duration_sec)
		timer.timeout.connect(func(): expire_buff(buff_id))

	buff_applied.emit(buff_id, buff)
	buff_updated.emit()

	print("[BuffManager] Applied buff: ", item_data.get("name", "???"), " for ", duration_sec, "s")
	return buff_id


func _on_consumable_buff_applied(item_data: Dictionary) -> void:
	"""Handler for consumable buff signal from InventoryManager"""
	apply_buff(item_data)


# ============================================================================
# BUFF EXPIRATION
# ============================================================================

func expire_buff(buff_id: String) -> void:
	"""Removes a buff"""
	if not active_buffs.has(buff_id):
		return

	var buff = active_buffs[buff_id]
	_apply_stat_modifiers(buff["stats"], -1.0)  # -1.0 = remove

	active_buffs.erase(buff_id)

	buff_expired.emit(buff_id)
	buff_updated.emit()

	print("[BuffManager] Buff expired: ", buff.get("item_name", "???"))


func clear_all_buffs() -> void:
	"""Clears all active buffs (e.g., on death)"""
	for buff_id in active_buffs.keys():
		expire_buff(buff_id)


# ============================================================================
# STAT MODIFIER APPLICATION
# ============================================================================

func _apply_stat_modifiers(stats: Dictionary, multiplier: float) -> void:
	"""Applies or removes stat modifiers (multiplier: 1.0 = add, -1.0 = remove)"""

	# Damage reduction
	if stats.has("damage_reduction"):
		total_damage_reduction += stats["damage_reduction"] * multiplier

	# Damage bonus
	if stats.has("damage_bonus"):
		total_damage_bonus += stats["damage_bonus"] * multiplier

	# Knockback reduction
	if stats.has("knockback_reduction"):
		total_knockback_reduction += stats["knockback_reduction"] * multiplier

	# Movement speed bonus
	if stats.has("movement_speed_bonus"):
		total_movement_speed_bonus += stats["movement_speed_bonus"] * multiplier

	# Attack speed bonus
	if stats.has("attack_speed_bonus"):
		total_attack_speed_bonus += stats["attack_speed_bonus"] * multiplier

	# Max mana bonus
	if stats.has("max_mana_bonus"):
		total_max_mana_bonus += stats["max_mana_bonus"] * multiplier

	# Environmental damage reduction
	if stats.has("environmental_damage_reduction"):
		total_environmental_damage_reduction += stats["environmental_damage_reduction"] * multiplier

	# Resonance gain bonus
	if stats.has("resonance_gain_bonus"):
		total_resonance_gain_bonus += stats["resonance_gain_bonus"] * multiplier

	_recalculate_totals()


func _recalculate_totals() -> void:
	"""Ensures totals are clamped to reasonable values"""
	total_damage_reduction = clampf(total_damage_reduction, 0.0, 0.9)  # Max 90% reduction
	total_knockback_reduction = clampf(total_knockback_reduction, 0.0, 1.0)
	total_environmental_damage_reduction = clampf(total_environmental_damage_reduction, 0.0, 0.9)


# ============================================================================
# QUERY METHODS
# ============================================================================

func has_buff(item_id: String) -> bool:
	"""Checks if a specific item buff is active"""
	for buff in active_buffs.values():
		if buff["item_id"] == item_id:
			return true
	return false


func get_active_buffs() -> Array:
	"""Returns array of active buff data"""
	return active_buffs.values()


func get_buff_time_remaining(buff_id: String) -> float:
	"""Returns time remaining for a buff"""
	if not active_buffs.has(buff_id):
		return 0.0

	var buff = active_buffs[buff_id]
	var current_time = Time.get_ticks_msec() / 1000.0
	return maxf(0.0, buff["expire_time"] - current_time)


# ============================================================================
# STAT GETTERS
# ============================================================================

func get_damage_reduction() -> float:
	return total_damage_reduction


func get_damage_bonus() -> float:
	return total_damage_bonus


func get_knockback_reduction() -> float:
	return total_knockback_reduction


func get_movement_speed_multiplier() -> float:
	return 1.0 + total_movement_speed_bonus


func get_attack_speed_multiplier() -> float:
	return 1.0 + total_attack_speed_bonus


func get_max_mana_multiplier() -> float:
	return 1.0 + total_max_mana_bonus


func get_environmental_damage_reduction() -> float:
	return total_environmental_damage_reduction


func get_resonance_gain_multiplier() -> float:
	return 1.0 + total_resonance_gain_bonus


# ============================================================================
# SAVE/LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	"""Returns buff data for saving"""
	return {
		"active_buffs": active_buffs.duplicate(true),
		"next_buff_id": next_buff_id
	}


func load_save_data(data: Dictionary) -> void:
	"""Loads buff data from save"""
	clear_all_buffs()

	if data.has("next_buff_id"):
		next_buff_id = data["next_buff_id"]

	if data.has("active_buffs"):
		# Restore buffs and restart timers
		for buff_data in data["active_buffs"].values():
			var current_time = Time.get_ticks_msec() / 1000.0
			var time_remaining = buff_data["expire_time"] - current_time

			if time_remaining > 0:
				# Buff still valid
				active_buffs[buff_data["id"]] = buff_data
				_apply_stat_modifiers(buff_data["stats"], 1.0)

				# Restart timer
				var timer = get_tree().create_timer(time_remaining)
				timer.timeout.connect(func(): expire_buff(buff_data["id"]))

	buff_updated.emit()
	print("[BuffManager] Loaded ", active_buffs.size(), " active buffs")
