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

# Permanently discovered relics (persisted per save slot, survive run resets)
var found_relics: Array = []

# ============ SIGNALS ============
signal item_added(item_id: String, category: String)
signal item_removed(item_id: String, category: String)
signal item_used(item_id: String)
signal inventory_changed()


func _ready() -> void:
	_load_item_database()
	_load_relics_database()
	_connect_p2_signals()
	print("[InventoryManager] Initialized")


# ============ DATABASE LOADING ============
func _load_item_database() -> void:
	"""Loads all item data from unified database"""
	# Load main item database
	_load_database_file("res://data/items/item_database.json")

	# Load shadow items database
	_load_database_file("res://data/items/shadow_items.json")

	print("[InventoryManager] Loaded ", item_database["consumables"].size(), " consumables")
	print("[InventoryManager] Loaded ", item_database["relics"].size(), " relics")
	print("[InventoryManager] Loaded ", item_database["key_items"].size(), " key items")


func _load_database_file(file_path: String) -> void:
	"""Helper to load a single database file"""
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("[InventoryManager] Failed to load: " + file_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[InventoryManager] Failed to parse JSON: " + file_path)
		return

	var data = json.get_data()

	if not data.has("items"):
		push_error("[InventoryManager] Database missing 'items' array: " + file_path)
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


# ============ RELIC DISCOVERY (Siegel-Run Relics) ============

func _load_relics_database() -> void:
	"""Loads relics from dedicated relics.json into item_database"""
	_load_database_file("res://data/items/relics.json")
	print("[InventoryManager] Relics database loaded: %d relics" % item_database["relics"].size())


func discover_relic(relic_id: String) -> bool:
	"""Permanently discovers a relic during a Siegel-Run. Returns true if newly found."""
	if relic_id in found_relics:
		print("[InventoryManager] Relic already discovered: %s" % relic_id)
		return false

	if not item_database["relics"].has(relic_id):
		push_error("[InventoryManager] Unknown relic: %s" % relic_id)
		return false

	# Mark as permanently found
	found_relics.append(relic_id)

	# Add to active inventory
	_add_relic(relic_id)

	var item_data = get_item_data(relic_id)
	var item_name = item_data.get("name", relic_id)

	# Notify
	item_added.emit(relic_id, "relics")
	inventory_changed.emit()
	EventBus.item_picked_up.emit(relic_id, item_name, "relics")

	print("[InventoryManager] Relic discovered: %s (%s)" % [relic_id, item_name])
	return true


func is_relic_found(relic_id: String) -> bool:
	"""Checks if a relic has been permanently found"""
	return relic_id in found_relics


func get_relic_qual_level(relic_id: String) -> int:
	"""Returns the qual_level required for a relic"""
	var data = item_database["relics"].get(relic_id, {})
	return data.get("qual_level", 0)


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


# ============ P2 MIRROR INVENTORY SYSTEM (COMMIT 020) ============

# P2's separate inventory
var p2_inventory: Dictionary = {
	"consumables": [],  # Separate pool (P2 buys own)
	"relics": [],       # Mirrors of P1's relics
	"key_items": []     # Empty placeholders
}

# P2-specific signals
signal p2_item_added(item_id: String, category: String)
signal p2_item_removed(item_id: String, category: String)
signal p2_item_used(item_id: String)
signal p2_inventory_changed()

func _connect_p2_signals() -> void:
	"""Connect P2 mirror sync signals"""
	item_added.connect(_on_p1_item_added)
	item_removed.connect(_on_p1_item_removed)


func _on_p1_item_added(item_id: String, category: String) -> void:
	"""When P1 adds item, sync P2's mirror (relics and consumables)"""
	if category == "relics":
		_sync_p2_mirror_relic(item_id, true)
	elif category == "consumables":
		_sync_p2_mirror_consumable(item_id, true)


func _on_p1_item_removed(item_id: String, category: String) -> void:
	"""When P1 removes item, remove P2's mirror"""
	if category == "relics":
		_sync_p2_mirror_relic(item_id, false)
	elif category == "consumables":
		_sync_p2_mirror_consumable(item_id, false)


func _sync_p2_mirror_relic(original_id: String, add: bool) -> void:
	"""Sync P2's mirror relic with P1's relic"""
	var mirror_id = get_mirror_item_id(original_id)

	if mirror_id == "":
		print("[P2 Mirror] No mirror found for: ", original_id)
		return

	if add:
		# Add mirror relic to P2
		if not mirror_id in p2_inventory["relics"]:
			p2_inventory["relics"].append(mirror_id)
			print("[P2 Mirror] Relic added: %s → %s" % [original_id, mirror_id])
			p2_item_added.emit(mirror_id, "relics")
			p2_inventory_changed.emit()
	else:
		# Remove mirror relic from P2
		var index = p2_inventory["relics"].find(mirror_id)
		if index != -1:
			p2_inventory["relics"].remove_at(index)
			print("[P2 Mirror] Relic removed: %s" % mirror_id)
			p2_item_removed.emit(mirror_id, "relics")
			p2_inventory_changed.emit()


func _sync_p2_mirror_consumable(original_id: String, add: bool) -> void:
	"""Sync P2's mirror consumable with P1's consumable"""
	var mirror_id = get_mirror_item_id(original_id)

	if mirror_id == "":
		print("[P2 Mirror] No mirror consumable found for: ", original_id, " - P2 will not receive mirror")
		return

	if add:
		# Add one mirror consumable to P2 (without syncing back to prevent loop)
		add_p2_consumable(mirror_id, false)
		print("[P2 Mirror] Consumable added: %s → %s" % [original_id, mirror_id])
	else:
		# Remove one mirror consumable from P2
		_remove_p2_consumable(mirror_id)
		print("[P2 Mirror] Consumable removed: %s" % mirror_id)


func _remove_p2_consumable(item_id: String) -> bool:
	"""Remove one P2 consumable (internal, does not emit used signal)"""
	for i in range(p2_inventory["consumables"].size()):
		var entry = p2_inventory["consumables"][i]
		if entry["item_id"] == item_id:
			entry["count"] -= 1

			if entry["count"] <= 0:
				p2_inventory["consumables"].remove_at(i)

			p2_item_removed.emit(item_id, "consumables")
			p2_inventory_changed.emit()
			return true

	return false


func get_mirror_item_id(original_id: String) -> String:
	"""Find mirror variant of an item"""
	# Search all items for mirror_of field
	for category in ["consumables", "relics", "key_items"]:
		for item_id in item_database[category]:
			var item = item_database[category][item_id]
			if item.has("mirror_of") and item["mirror_of"] == original_id:
				return item_id

	return ""


func get_original_item_id(mirror_id: String) -> String:
	"""Find original item from a mirror variant"""
	var item_data = get_item_data(mirror_id)
	if item_data.has("mirror_of"):
		return item_data["mirror_of"]
	return ""


# ============ P2 CONSUMABLE MANAGEMENT (Separate Pool) ============

func add_p2_consumable(item_id: String, sync_to_p1: bool = true) -> bool:
	"""Add consumable to P2's separate pool"""
	if not item_database["consumables"].has(item_id):
		push_error("[P2 Inventory] Unknown consumable: " + item_id)
		return false

	# Check if already owned
	for entry in p2_inventory["consumables"]:
		if entry["item_id"] == item_id:
			entry["count"] += 1
			p2_inventory_changed.emit()
			return true

	# New consumable
	p2_inventory["consumables"].append({
		"item_id": item_id,
		"count": 1
	})

	p2_item_added.emit(item_id, "consumables")
	p2_inventory_changed.emit()
	print("[P2 Inventory] Consumable added: ", item_id)

	# Sync to P1 if this is a mirror item
	if sync_to_p1:
		var original_id = get_original_item_id(item_id)
		if original_id != "":
			_add_consumable(original_id)
			print("[P2 → P1 Mirror] P1 received original: %s ← %s" % [original_id, item_id])

	return true


func use_p2_consumable(item_id: String) -> bool:
	"""Use P2's consumable"""
	for i in range(p2_inventory["consumables"].size()):
		var entry = p2_inventory["consumables"][i]
		if entry["item_id"] == item_id and entry["count"] > 0:
			entry["count"] -= 1

			if entry["count"] <= 0:
				p2_inventory["consumables"].remove_at(i)

			# Apply effect to P2
			var item_data = get_item_data(item_id)
			if item_data:
				_apply_p2_consumable_effect(item_data)

			p2_item_used.emit(item_id)
			p2_item_removed.emit(item_id, "consumables")
			p2_inventory_changed.emit()
			print("[P2 Inventory] Consumable used: ", item_id)
			return true

	return false


func _apply_p2_consumable_effect(item_data: Dictionary) -> void:
	"""Apply consumable effect to P2"""
	if not item_data.has("stats"):
		return

	var stats = item_data["stats"]
	var p2 = CoopManager.get_p2_instance() if CoopManager else null

	if not p2:
		push_error("[P2 Inventory] P2 not active")
		return

	# Instant heal
	if stats.has("heal_percent"):
		_apply_percent_heal(p2, stats["heal_percent"])

	# HP regen over time
	if stats.has("hp_regen_percent_per_sec") and stats.has("duration_sec"):
		_apply_hp_regen(p2, stats["hp_regen_percent_per_sec"], stats["duration_sec"])

	# Flat HP regen
	if stats.has("hp_regen_flat") and stats.has("duration_sec"):
		_apply_flat_hp_regen(p2, stats["hp_regen_flat"], stats["duration_sec"])

	# Mana regen
	if stats.has("mana_regen_percent_per_sec") and stats.has("duration_sec"):
		_apply_mana_regen(p2, stats["mana_regen_percent_per_sec"], stats["duration_sec"])

	# Buffs
	if stats.has("damage_reduction") or stats.has("knockback_reduction") or stats.has("movement_speed_bonus"):
		EventBus.emit_signal("p2_consumable_buff_applied", item_data)


func get_p2_consumable_count(item_id: String) -> int:
	"""Get P2's consumable count"""
	for entry in p2_inventory["consumables"]:
		if entry["item_id"] == item_id:
			return entry["count"]
	return 0


# ============ P2 KEY ITEMS (Placeholders) ============

func get_p2_key_placeholders() -> Array:
	"""Get P2's empty key item placeholders"""
	return [
		"shadow_key_placeholder_1",
		"shadow_key_placeholder_2",
		"shadow_key_placeholder_3",
		"shadow_key_placeholder_4"
	]


# ============ P2 QUERY METHODS ============

func has_p2_item(item_id: String) -> bool:
	"""Check if P2 has an item"""
	# Check consumables
	for entry in p2_inventory["consumables"]:
		if entry["item_id"] == item_id:
			return true

	# Check relics
	if item_id in p2_inventory["relics"]:
		return true

	return false


func has_relic(item_id: String) -> bool:
	"""Check if P1 has a relic (for scaling calculation)"""
	return item_id in inventory["relics"]


func get_p2_inventory() -> Dictionary:
	"""Get P2's full inventory"""
	return {
		"consumables": p2_inventory["consumables"],
		"relics": p2_inventory["relics"],
		"key_items": get_p2_key_placeholders()
	}


func get_p2_items_by_category(category: String) -> Array:
	"""Get P2's items by category"""
	if category == "key_items":
		return get_p2_key_placeholders()
	return p2_inventory.get(category, [])
