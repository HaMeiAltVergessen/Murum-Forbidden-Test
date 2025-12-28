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
	_add_test_items()  # TODO: Remove this after testing
	print("[InventoryManager] Initialized")


func _add_test_items() -> void:
	"""Adds test items for development (remove in production)"""
	# Add some consumables from each world
	add_item("titanenblut_stein", "consumables")  # World 1
	add_item("staub_einkehr", "consumables")  # World 1
	add_item("resonanzstaub", "consumables")  # World 2
	add_item("heilkraeuter", "consumables")  # Shop item

	# Add some relics
	add_item("auge_von_xy", "relics")  # World 1
	add_item("urtraene", "relics")  # World 1

	# Add a key item
	add_item("key_item_1", "key_items")

	print("[InventoryManager] Test items added (DEV MODE)")


# ============ DATABASE LOADING ============
func _load_item_database() -> void:
	"""Loads all item data from unified database"""
	var file = FileAccess.open("res://data/items/item_database.json", FileAccess.READ)

	if not file:
		push_error("[InventoryManager] Failed to load item database")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[InventoryManager] Failed to parse item database JSON")
		return

	var data = json.get_data()

	if not data.has("items"):
		push_error("[InventoryManager] Database missing 'items' array")
		return

	# Categorize items by type
	for item in data["items"]:
		if not item.has("id") or not item.has("type"):
			continue

		var item_id = item["id"]
		var item_type = item["type"]

		# Map item type to category
		match item_type:
			"consumable":
				item_database["consumables"][item_id] = item
			"relic":
				item_database["relics"][item_id] = item
			"key_item":
				item_database["key_items"][item_id] = item
			_:
				push_warning("[InventoryManager] Unknown item type: " + item_type + " for " + item_id)

	print("[InventoryManager] Loaded ", item_database["consumables"].size(), " consumables")
	print("[InventoryManager] Loaded ", item_database["relics"].size(), " relics")
	print("[InventoryManager] Loaded ", item_database["key_items"].size(), " key items")


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
	if not item_data.has("stats"):
		print("[InventoryManager] Item has no stats: ", item_data.get("name", "???"))
		return

	var stats = item_data["stats"]

	# Get player reference
	var player = GameManager.player
	if not player:
		push_error("[InventoryManager] No player registered")
		return

	# Check for instant heal
	if stats.has("heal_percent"):
		_apply_percent_heal(player, stats["heal_percent"])

	# Check for HP regen over time
	if stats.has("hp_regen_percent_per_sec") and stats.has("duration_sec"):
		_apply_hp_regen(player, stats["hp_regen_percent_per_sec"], stats["duration_sec"])

	# Check for flat HP regen
	if stats.has("hp_regen_flat") and stats.has("duration_sec"):
		_apply_flat_hp_regen(player, stats["hp_regen_flat"], stats["duration_sec"])

	# Check for Mana regen over time
	if stats.has("mana_regen_percent_per_sec") and stats.has("duration_sec"):
		_apply_mana_regen(player, stats["mana_regen_percent_per_sec"], stats["duration_sec"])

	# For buffs and other effects, emit signal to BuffManager (to be created)
	if stats.has("damage_reduction") or stats.has("knockback_reduction") or stats.has("movement_speed_bonus"):
		EventBus.emit_signal("consumable_buff_applied", item_data)
		print("[InventoryManager] Buff effect applied: ", item_data.get("name", "???"))


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


func _apply_percent_heal(player: Node, heal_percent: float) -> void:
	"""Applies percentage-based instant healing"""
	if not player.has_node("HealthComponent"):
		return

	var health_comp = player.get_node("HealthComponent")
	var heal_amount = int(health_comp.max_health * heal_percent)
	health_comp.heal(heal_amount)
	print("[InventoryManager] Applied percent heal: ", heal_percent * 100, "% (", heal_amount, " HP)")


func _apply_flat_hp_regen(player: Node, regen_amount: float, duration: float) -> void:
	"""Applies flat HP regeneration over time"""
	if not player.has_node("HealthComponent"):
		return

	var health_comp = player.get_node("HealthComponent")
	var timer = Timer.new()
	timer.wait_time = 5.0  # Tick every 5 seconds
	timer.one_shot = false
	player.add_child(timer)

	var ticks_remaining = int(duration / 5.0)

	timer.timeout.connect(func():
		if ticks_remaining > 0:
			health_comp.heal(int(regen_amount))
			ticks_remaining -= 1
		else:
			timer.queue_free()
	)

	timer.start()
	print("[InventoryManager] Applied flat HP regen: ", regen_amount, " every 5s for ", duration, "s")


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
