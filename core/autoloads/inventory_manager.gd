extends Node
## InventoryManager handles item storage, item effects, and inventory logic

# ============ ITEM DATABASE ============
var item_database: Dictionary = {
	"consumables": {},
	"relics": {},
	"key_items": {}
}

# ============ INVENTORY STATE ============
var inventory: Dictionary = {
	"consumables": [],  # Array of {item_id: String, count: int}
	"relics": [],       # Array of item_id (String)
	"key_items": []     # Array of item_id (String)
}

# ============ SIGNALS ============
signal item_added(item_id: String, category: String)
signal item_removed(item_id: String, category: String)
signal item_used(item_id: String)
signal inventory_changed()


func _ready() -> void:
	_load_item_database()
	print("[InventoryManager] Initialized")


# ============ DATABASE LOADING ============
func _load_item_database() -> void:
	"""Loads all item data from JSON files"""
	_load_category("consumables", "res://data/items/consumables.json")
	_load_category("relics", "res://data/items/relics.json")
	_load_category("key_items", "res://data/items/key_items.json")

	print("[InventoryManager] Loaded ", item_database["consumables"].size(), " consumables")
	print("[InventoryManager] Loaded ", item_database["relics"].size(), " relics")
	print("[InventoryManager] Loaded ", item_database["key_items"].size(), " key items")


func _load_category(category: String, path: String) -> void:
	"""Loads items from a JSON file into the database"""
	var file = FileAccess.open(path, FileAccess.READ)

	if not file:
		push_error("[InventoryManager] Failed to load " + category + " from " + path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[InventoryManager] Failed to parse JSON for " + category)
		return

	var data = json.get_data()

	if not data.has("items"):
		push_error("[InventoryManager] JSON missing 'items' array for " + category)
		return

	# Store items by ID
	for item in data["items"]:
		if item.has("id"):
			item_database[category][item["id"]] = item


# ============ ITEM MANAGEMENT ============
func add_item(item_id: String, category: String = "") -> bool:
	"""Adds an item to the inventory. Returns true if successful."""
	# Auto-detect category if not provided
	if category == "":
		category = _get_item_category(item_id)
		if category == "":
			push_error("[InventoryManager] Unknown item: " + item_id)
			return false

	# Verify item exists in database
	if not item_database[category].has(item_id):
		push_error("[InventoryManager] Item not found in database: " + item_id)
		return false

	match category:
		"consumables":
			_add_consumable(item_id)
		"relics":
			_add_relic(item_id)
		"key_items":
			_add_key_item(item_id)

	item_added.emit(item_id, category)
	inventory_changed.emit()
	print("[InventoryManager] Added item: ", item_id, " (", category, ")")
	return true


func _add_consumable(item_id: String) -> void:
	"""Adds a consumable or increments its count"""
	for entry in inventory["consumables"]:
		if entry["item_id"] == item_id:
			entry["count"] += 1
			return

	# New consumable
	inventory["consumables"].append({
		"item_id": item_id,
		"count": 1
	})


func _add_relic(item_id: String) -> void:
	"""Adds a relic (unique, no duplicates)"""
	if item_id in inventory["relics"]:
		print("[InventoryManager] Relic already owned: ", item_id)
		return

	inventory["relics"].append(item_id)
	_apply_relic_stats(item_id)


func _add_key_item(item_id: String) -> void:
	"""Adds a key item (unique, no duplicates)"""
	if item_id in inventory["key_items"]:
		print("[InventoryManager] Key item already owned: ", item_id)
		return

	inventory["key_items"].append(item_id)


func remove_item(item_id: String, category: String = "") -> bool:
	"""Removes an item from inventory. Returns true if successful."""
	if category == "":
		category = _get_item_category(item_id)

	match category:
		"consumables":
			return _remove_consumable(item_id)
		"relics":
			return _remove_relic(item_id)
		"key_items":
			return _remove_key_item(item_id)

	return false


func _remove_consumable(item_id: String) -> bool:
	"""Decrements consumable count or removes it"""
	for i in range(inventory["consumables"].size()):
		var entry = inventory["consumables"][i]
		if entry["item_id"] == item_id:
			entry["count"] -= 1

			if entry["count"] <= 0:
				inventory["consumables"].remove_at(i)

			item_removed.emit(item_id, "consumables")
			inventory_changed.emit()
			return true

	return false


func _remove_relic(item_id: String) -> bool:
	"""Removes a relic"""
	var index = inventory["relics"].find(item_id)
	if index != -1:
		inventory["relics"].remove_at(index)
		_remove_relic_stats(item_id)
		item_removed.emit(item_id, "relics")
		inventory_changed.emit()
		return true

	return false


func _remove_key_item(item_id: String) -> bool:
	"""Removes a key item"""
	var index = inventory["key_items"].find(item_id)
	if index != -1:
		inventory["key_items"].remove_at(index)
		item_removed.emit(item_id, "key_items")
		inventory_changed.emit()
		return true

	return false


# ============ ITEM USAGE ============
func use_item(item_id: String) -> bool:
	"""Uses a consumable item. Returns true if successful."""
	# Only consumables can be used
	if not _is_consumable(item_id):
		print("[InventoryManager] Cannot use non-consumable: ", item_id)
		return false

	# Get item data
	var item_data = get_item_data(item_id)
	if not item_data:
		return false

	# Apply effect
	_apply_consumable_effect(item_data)

	# Remove from inventory
	_remove_consumable(item_id)

	item_used.emit(item_id)
	print("[InventoryManager] Used item: ", item_id)
	return true


func _apply_consumable_effect(item_data: Dictionary) -> void:
	"""Applies the effect of a consumable"""
	if not item_data.has("effect"):
		return

	var effect = item_data["effect"]
	var effect_type = effect.get("type", "")
	var value = effect.get("value", 0)
	var duration = effect.get("duration", 0)

	# Get player reference
	var player = GameManager.player
	if not player:
		push_error("[InventoryManager] No player registered")
		return

	match effect_type:
		"hp_regen":
			_apply_hp_regen(player, value, duration)
		"mana_regen":
			_apply_mana_regen(player, value, duration)
		"instant_heal":
			_apply_instant_heal(player, value)
		_:
			print("[InventoryManager] Unknown effect type: ", effect_type)


func _apply_hp_regen(player: Node, regen_rate: float, duration: float) -> void:
	"""Applies HP regeneration over time"""
	if not player.has_node("HealthComponent"):
		return

	var health_comp = player.get_node("HealthComponent")
	var timer = Timer.new()
	timer.wait_time = 1.0  # Tick every second
	timer.one_shot = false
	player.add_child(timer)

	var ticks_remaining = int(duration)

	timer.timeout.connect(func():
		if ticks_remaining > 0:
			var heal_amount = int(health_comp.max_health * regen_rate)
			health_comp.heal(heal_amount)
			ticks_remaining -= 1
		else:
			timer.queue_free()
	)

	timer.start()
	print("[InventoryManager] Applied HP regen: ", regen_rate, " for ", duration, "s")


func _apply_mana_regen(player: Node, regen_rate: float, duration: float) -> void:
	"""Applies Mana regeneration over time"""
	if not player.has_node("ManaComponent"):
		return

	var mana_comp = player.get_node("ManaComponent")
	var timer = Timer.new()
	timer.wait_time = 1.0  # Tick every second
	timer.one_shot = false
	player.add_child(timer)

	var ticks_remaining = int(duration)

	timer.timeout.connect(func():
		if ticks_remaining > 0:
			var regen_amount = int(mana_comp.max_mana * regen_rate)
			mana_comp.regenerate_mana(regen_amount)
			ticks_remaining -= 1
		else:
			timer.queue_free()
	)

	timer.start()
	print("[InventoryManager] Applied Mana regen: ", regen_rate, " for ", duration, "s")


func _apply_instant_heal(player: Node, heal_amount: int) -> void:
	"""Applies instant healing"""
	if not player.has_node("HealthComponent"):
		return

	var health_comp = player.get_node("HealthComponent")
	health_comp.heal(heal_amount)
	print("[InventoryManager] Applied instant heal: ", heal_amount)


# ============ RELIC STATS ============
func _apply_relic_stats(item_id: String) -> void:
	"""Applies passive stat bonuses from a relic"""
	var item_data = get_item_data(item_id)
	if not item_data or not item_data.has("stats"):
		return

	# Emit signal for other systems to react
	EventBus.emit_signal("relic_equipped", item_id, item_data["stats"])
	print("[InventoryManager] Applied relic stats: ", item_id)


func _remove_relic_stats(item_id: String) -> void:
	"""Removes passive stat bonuses from a relic"""
	var item_data = get_item_data(item_id)
	if not item_data or not item_data.has("stats"):
		return

	# Emit signal for other systems to react
	EventBus.emit_signal("relic_unequipped", item_id, item_data["stats"])
	print("[InventoryManager] Removed relic stats: ", item_id)


# ============ QUERY METHODS ============
func get_item_data(item_id: String) -> Dictionary:
	"""Returns item data from database"""
	var category = _get_item_category(item_id)
	if category == "":
		return {}

	return item_database[category].get(item_id, {})


func get_consumable_count(item_id: String) -> int:
	"""Returns the count of a consumable"""
	for entry in inventory["consumables"]:
		if entry["item_id"] == item_id:
			return entry["count"]

	return 0


func has_item(item_id: String) -> bool:
	"""Checks if an item is in the inventory"""
	# Check consumables
	for entry in inventory["consumables"]:
		if entry["item_id"] == item_id:
			return true

	# Check relics
	if item_id in inventory["relics"]:
		return true

	# Check key items
	if item_id in inventory["key_items"]:
		return true

	return false


func get_items_by_category(category: String) -> Array:
	"""Returns all items in a category"""
	return inventory.get(category, [])


func _get_item_category(item_id: String) -> String:
	"""Returns the category of an item"""
	if item_database["consumables"].has(item_id):
		return "consumables"
	if item_database["relics"].has(item_id):
		return "relics"
	if item_database["key_items"].has(item_id):
		return "key_items"

	return ""


func _is_consumable(item_id: String) -> bool:
	"""Checks if an item is a consumable"""
	return item_database["consumables"].has(item_id)


# ============ SAVE/LOAD ============
func get_save_data() -> Dictionary:
	"""Returns inventory data for saving"""
	return inventory.duplicate(true)


func load_save_data(data: Dictionary) -> void:
	"""Loads inventory from save data"""
	inventory = data.duplicate(true)

	# Reapply all relic stats
	for relic_id in inventory["relics"]:
		_apply_relic_stats(relic_id)

	inventory_changed.emit()
	print("[InventoryManager] Loaded inventory from save")
