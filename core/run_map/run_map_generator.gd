extends RefCounted
## Generates fixed node-network maps for each world
## Each world has a predefined, deterministic layout
class_name RunMapGenerator


# ============ GENERATION ============

static func generate_map(world_id: RunMapData.WorldId, _rng_seed: int = -1) -> RunMapData.Map:
	"""Generates the fixed node-network map for the given world"""
	var map: RunMapData.Map
	match world_id:
		RunMapData.WorldId.NIEMANDSLAND:
			map = _generate_fixed_w1()
		RunMapData.WorldId.KOLLEKTIV:
			map = _generate_fixed_w2()
		RunMapData.WorldId.ABGRUND:
			map = _generate_fixed_w3()
		_:
			push_error("[RunMapGenerator] Unknown world %d" % world_id)
			return null

	_assign_positions(map)

	print("[RunMapGenerator] Generated fixed map for world %d: %d nodes, %d rows" % [
		world_id, map.nodes.size(), map.rows.size()
	])

	return map


# ============ HELPER ============

static func _make_node(id: int, row: int, col: int, type: RunMapData.NodeType,
		scene_path: String) -> RunMapData.MapNode:
	"""Creates a MapNode with scene path, display name, and default reward"""
	var node = RunMapData.MapNode.new(id, row, col, type)
	node.room_scene_path = scene_path
	node.display_name = RunRoomPool.get_display_name(scene_path)
	node.reward_type = _get_default_reward(type)
	return node


static func _connect(node: RunMapData.MapNode, target_ids: Array) -> void:
	"""Sets connections on a node (workaround for typed Array[int] assignment)"""
	for tid in target_ids:
		node.connections.append(tid as int)


# ============ WELT 1: DAS NIEMANDSLAND ============
# Row 0: [Vergessener Pfad] [Nebellichtung]                                  (Kampf-Wahl)
# Row 1: [Tempelvorplatz] [Verfallene Ruinen] [Verborgener Schrein]          (Kampf/Schatz-Wahl)
# Row 2: [Dorf der Verlorenen]                                               (Rast, Pflicht)
# Row 3: [Waechter der Schwelle]                                             (Elite NEU, Pflicht)
# Row 4: [Tempeltor]                                                          (Elite, Pflicht)
# Row 5: [Versteckte Kammer] [Schatzkammer] [Tempelhalle] [Mittlere Ebene]   (Tempel-Hub, Wahl)
# Row 6: [Tiefer Tempel] [Letzter Haendler]                                  (Wahl)
# Row 7: [Heldengruppe-Arena]                                                 (Boss)

static func _generate_fixed_w1() -> RunMapData.Map:
	var map = RunMapData.Map.new()
	map.world_id = RunMapData.WorldId.NIEMANDSLAND
	var P = "res://worlds/run_rooms/niemandsland/"

	# Row 0: Combat choices (Einstieg)
	var n0 = _make_node(0, 0, 0, RunMapData.NodeType.COMBAT, P + "combat_room_05.tscn")   # Vergessener Pfad
	var n1 = _make_node(1, 0, 1, RunMapData.NodeType.COMBAT, P + "combat_room_06.tscn")   # Nebellichtung

	# Row 1: Combat + Treasure choices
	var n2 = _make_node(2, 1, 0, RunMapData.NodeType.COMBAT, P + "combat_room_03.tscn")   # Tempelvorplatz
	var n3 = _make_node(3, 1, 1, RunMapData.NodeType.COMBAT, P + "combat_room_04.tscn")   # Verfallene Ruinen
	var n4 = _make_node(4, 1, 2, RunMapData.NodeType.TREASURE, P + "treasure_room_02.tscn") # Verborgener Schrein

	# Row 2: Mandatory rest
	var n5 = _make_node(5, 2, 0, RunMapData.NodeType.REST, P + "rest_room_01.tscn")       # Dorf der Verlorenen

	# Row 3: New elite
	var n6 = _make_node(6, 3, 0, RunMapData.NodeType.ELITE, P + "elite_room_03.tscn")     # Waechter der Schwelle

	# Row 4: Existing elite
	var n7 = _make_node(7, 4, 0, RunMapData.NodeType.ELITE, P + "elite_room_02.tscn")     # Tempeltor

	# Row 5: Temple hub (non-combat → same-row combat)
	var n8 = _make_node(8, 5, 0, RunMapData.NodeType.EVENT, P + "event_room_01.tscn")     # Versteckte Kammer
	var n9 = _make_node(9, 5, 1, RunMapData.NodeType.TREASURE, P + "treasure_room_01.tscn") # Schatzkammer
	var n10 = _make_node(10, 5, 2, RunMapData.NodeType.COMBAT, P + "combat_room_01.tscn") # Tempelhalle
	var n11 = _make_node(11, 5, 3, RunMapData.NodeType.COMBAT, P + "combat_room_02.tscn") # Mittlere Ebene

	# Row 6: Pre-boss choices
	var n12 = _make_node(12, 6, 0, RunMapData.NodeType.ELITE, P + "elite_room_01.tscn")   # Tiefer Tempel
	var n13 = _make_node(13, 6, 1, RunMapData.NodeType.SHOP, P + "shop_room_01.tscn")     # Letzter Haendler

	# Row 7: Boss
	var n14 = _make_node(14, 7, 0, RunMapData.NodeType.BOSS, P + "boss_room_01.tscn")     # Heldengruppe-Arena

	# ---- Connections ----
	# Row 0 → Row 1 (all choices)
	_connect(n0, [2, 3, 4])
	_connect(n1, [2, 3, 4])
	# Row 1 → Rest
	_connect(n2, [5])
	_connect(n3, [5])
	_connect(n4, [5])
	# Row 2 → New elite
	_connect(n5, [6])
	# Row 3 → Existing elite
	_connect(n6, [7])
	# Row 4 → Temple hub (all 4 doors)
	_connect(n7, [8, 9, 10, 11])
	# Temple hub: non-combat → same-row combat
	_connect(n8, [10, 11])
	_connect(n9, [10, 11])
	# Temple hub: combat → pre-boss
	_connect(n10, [12, 13])
	_connect(n11, [12, 13])
	# Pre-boss → Boss
	_connect(n12, [14])
	_connect(n13, [14])

	# Build map
	for n in [n0, n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14]:
		map.nodes[n.id] = n
	map.rows = [[0, 1], [2, 3, 4], [5], [6], [7], [8, 9, 10, 11], [12, 13], [14]]

	return map


# ============ WELT 2: DAS KOLLEKTIV ============
# Row 0: [Neon-Gassen] [Kneipen] [Wohnung]                  (Wahl, Event → same-row combat)
# Row 1: [Kollektiv-Mecha]                                    (Elite, Pflicht)
# Row 2: [Schmuggler-Versteck]                                (Rast, Pflicht)
# Row 3: [Aufzuege] [Wolkenkratzer]                           (Wahl)
# Row 4: [Docks auf den Daechern]                             (Combat, Pflicht)
# Row 5: [Tech-Schatzkammer] [AI-Assassine]                   (Wahl, Treasure → same-row Elite)
# Row 6: [Schwarzmarkt]                                       (Shop, Pflicht)
# Row 7: [Kollektiv-Arena]                                    (Boss)

static func _generate_fixed_w2() -> RunMapData.Map:
	var map = RunMapData.Map.new()
	map.world_id = RunMapData.WorldId.KOLLEKTIV
	var P = "res://worlds/run_rooms/kollektiv/"

	# Row 0: Slum choices
	var n0 = _make_node(0, 0, 0, RunMapData.NodeType.COMBAT, P + "combat_room_01.tscn")   # Neon-Gassen
	var n1 = _make_node(1, 0, 1, RunMapData.NodeType.COMBAT, P + "combat_room_02.tscn")   # Kneipen
	var n2 = _make_node(2, 0, 2, RunMapData.NodeType.EVENT, P + "event_room_01.tscn")     # Wohnung

	# Row 1: Mandatory elite
	var n3 = _make_node(3, 1, 0, RunMapData.NodeType.ELITE, P + "elite_room_01.tscn")     # Kollektiv-Mecha

	# Row 2: Mandatory rest
	var n4 = _make_node(4, 2, 0, RunMapData.NodeType.REST, P + "rest_room_01.tscn")       # Schmuggler-Versteck

	# Row 3: Combat choices
	var n5 = _make_node(5, 3, 0, RunMapData.NodeType.COMBAT, P + "combat_room_03.tscn")   # Aufzuege
	var n6 = _make_node(6, 3, 1, RunMapData.NodeType.COMBAT, P + "combat_room_04.tscn")   # Wolkenkratzer

	# Row 4: Mandatory combat
	var n7 = _make_node(7, 4, 0, RunMapData.NodeType.COMBAT, P + "combat_room_05.tscn")   # Docks auf den Daechern

	# Row 5: Treasure/Elite choice
	var n8 = _make_node(8, 5, 0, RunMapData.NodeType.TREASURE, P + "treasure_room_01.tscn") # Tech-Schatzkammer
	var n9 = _make_node(9, 5, 1, RunMapData.NodeType.ELITE, P + "elite_room_02.tscn")     # AI-Assassine

	# Row 6: Mandatory shop
	var n10 = _make_node(10, 6, 0, RunMapData.NodeType.SHOP, P + "shop_room_01.tscn")     # Schwarzmarkt

	# Row 7: Boss
	var n11 = _make_node(11, 7, 0, RunMapData.NodeType.BOSS, P + "boss_room_01.tscn")     # Kollektiv-Arena

	# ---- Connections ----
	# Row 0: Event → same-row combat, combat → elite
	_connect(n0, [3])
	_connect(n1, [3])
	_connect(n2, [0, 1])       # Wohnung → must do combat first
	# Row 1 → Rest
	_connect(n3, [4])
	# Row 2 → Combat choices
	_connect(n4, [5, 6])
	# Row 3 → Docks
	_connect(n5, [7])
	_connect(n6, [7])
	# Row 4 → Treasure/Elite
	_connect(n7, [8, 9])
	# Row 5: Treasure → same-row Elite
	_connect(n8, [9])
	_connect(n9, [10])         # Elite → Shop
	# Row 6 → Boss
	_connect(n10, [11])

	# Build map
	for n in [n0, n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11]:
		map.nodes[n.id] = n
	map.rows = [[0, 1, 2], [3], [4], [5, 6], [7], [8, 9], [10], [11]]

	return map


# ============ WELT 3: DER ABGRUND ============
# Row 0: [Verzerrte Zeit] [Tiefe] [Augen] [Elysium]         (Wahl, Event → same-row combat)
# Row 1: [Alptraum-Vision]                                    (Elite, Pflicht)
# Row 2: [Das letzte Licht] [Urgathon]                        (Wahl)
# Row 3: [Fleisch] [Abstieg] [Verzerrte Schatzkammer]         (Wahl, Treasure → same-row combat)
# Row 4: [Stimme der Leere]                                   (Elite, Pflicht)
# Row 5: [Loch im Abgrund]                                    (Shop, Pflicht)
# Row 6: [Gehirn]                                             (Combat, Pflicht)
# Row 7: [Nurdurun]                                           (Pre-Boss: Wahl Arena/Boss)
# Row 8: [Lythrun-Arena] [Das Siegel]                         (Arena + Boss)

static func _generate_fixed_w3() -> RunMapData.Map:
	var map = RunMapData.Map.new()
	map.world_id = RunMapData.WorldId.ABGRUND
	var P = "res://worlds/run_rooms/abgrund/"

	# Row 0: Abyss entry choices
	var n0 = _make_node(0, 0, 0, RunMapData.NodeType.COMBAT, P + "combat_room_01.tscn")   # Verzerrte Zeit
	var n1 = _make_node(1, 0, 1, RunMapData.NodeType.COMBAT, P + "combat_room_02.tscn")   # Tiefe
	var n2 = _make_node(2, 0, 2, RunMapData.NodeType.COMBAT, P + "combat_room_03.tscn")   # Augen
	var n3 = _make_node(3, 0, 3, RunMapData.NodeType.EVENT, P + "event_room_01.tscn")     # Elysium

	# Row 1: Mandatory elite
	var n4 = _make_node(4, 1, 0, RunMapData.NodeType.ELITE, P + "elite_room_01.tscn")     # Alptraum-Vision

	# Row 2: Rest/Event choice
	var n5 = _make_node(5, 2, 0, RunMapData.NodeType.REST, P + "rest_room_01.tscn")       # Das letzte Licht
	var n6 = _make_node(6, 2, 1, RunMapData.NodeType.EVENT, P + "event_room_02.tscn")     # Urgathon

	# Row 3: Combat/Treasure choice
	var n7 = _make_node(7, 3, 0, RunMapData.NodeType.COMBAT, P + "combat_room_04.tscn")   # Fleisch
	var n8 = _make_node(8, 3, 1, RunMapData.NodeType.COMBAT, P + "combat_room_05.tscn")   # Abstieg
	var n9 = _make_node(9, 3, 2, RunMapData.NodeType.TREASURE, P + "treasure_room_01.tscn") # Verzerrte Schatzkammer

	# Row 4: Mandatory elite
	var n10 = _make_node(10, 4, 0, RunMapData.NodeType.ELITE, P + "elite_room_02.tscn")   # Stimme der Leere

	# Row 5: Mandatory shop
	var n11 = _make_node(11, 5, 0, RunMapData.NodeType.SHOP, P + "shop_room_01.tscn")     # Loch im Abgrund

	# Row 6: Mandatory combat
	var n12 = _make_node(12, 6, 0, RunMapData.NodeType.COMBAT, P + "combat_room_06.tscn") # Gehirn

	# Row 7: Pre-boss (Nurdurun — choice between Arena and Boss)
	var n13 = _make_node(13, 7, 0, RunMapData.NodeType.REST, P + "pre_boss_room.tscn")    # Nurdurun
	n13.display_name = "Nurdurun"

	# Row 8: Arena + Boss
	var n14 = _make_node(14, 8, 0, RunMapData.NodeType.ARENA,
		"res://worlds/world_1_ruins/section_4_tempel/room_15_boss_urgathon.tscn")          # Lythrun-Arena
	var n15 = _make_node(15, 8, 1, RunMapData.NodeType.BOSS, P + "boss_room_01.tscn")     # Das Siegel

	# ---- Connections ----
	# Row 0: Event → same-row combat, combat → elite
	_connect(n0, [4])
	_connect(n1, [4])
	_connect(n2, [4])
	_connect(n3, [0, 1, 2])    # Elysium → must do combat first
	# Row 1 → Rest/Event choice
	_connect(n4, [5, 6])
	# Row 2 → Row 3 (all choices)
	_connect(n5, [7, 8, 9])
	_connect(n6, [7, 8, 9])
	# Row 3: Treasure → same-row combat, combat → elite
	_connect(n7, [10])
	_connect(n8, [10])
	_connect(n9, [7, 8])       # Verzerrte Schatzkammer → must do combat first
	# Row 4 → Shop
	_connect(n10, [11])
	# Row 5 → Combat
	_connect(n11, [12])
	# Row 6 → Pre-boss
	_connect(n12, [13])
	# Row 7 → Arena + Boss
	_connect(n13, [14, 15])
	# Arena → Boss
	_connect(n14, [15])

	# Build map
	for n in [n0, n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15]:
		map.nodes[n.id] = n
	map.rows = [[0, 1, 2, 3], [4], [5, 6], [7, 8, 9], [10], [11], [12], [13], [14, 15]]

	return map


# ============ VISUAL POSITIONING ============

static func _assign_positions(map: RunMapData.Map) -> void:
	"""Assigns visual positions for UI rendering
	Y: top to bottom by row. X: spread evenly within row.
	"""
	var row_height: float = 140.0
	var col_width: float = 200.0
	var map_width: float = 800.0

	for row_index in range(map.rows.size()):
		var row: Array = map.rows[row_index]
		var y: float = 80.0 + row_index * row_height
		var row_width: float = (row.size() - 1) * col_width
		var start_x: float = (map_width - row_width) / 2.0

		for col_index in range(row.size()):
			var node: RunMapData.MapNode = map.nodes[row[col_index]]
			node.position = Vector2(start_x + col_index * col_width, y)


# ============ REWARD HELPERS ============

static func _get_default_reward(type: RunMapData.NodeType) -> String:
	match type:
		RunMapData.NodeType.COMBAT: return "gold"
		RunMapData.NodeType.ELITE: return "gold"
		RunMapData.NodeType.TREASURE: return "item"
		RunMapData.NodeType.REST: return "heal"
		RunMapData.NodeType.EVENT: return "event"
		RunMapData.NodeType.BOSS: return "magicka"
		RunMapData.NodeType.SHOP: return "shop"
		RunMapData.NodeType.ARENA: return "arena"
	return "gold"


# ============ DEBUG ============

static func print_map(map: RunMapData.Map) -> void:
	"""Prints a text representation of the map for debugging"""
	print("=== RUN MAP ===")
	for row_index in range(map.rows.size()):
		var row_str: String = "Row %d: " % row_index
		var row: Array = map.rows[row_index]
		for node_id in row:
			var node: RunMapData.MapNode = map.nodes[node_id]
			row_str += "[%d:%s]" % [node.id, node.get_display_name()]
			if not node.connections.is_empty():
				row_str += "→%s " % str(node.connections)
			else:
				row_str += " "
		print(row_str)
	print("===============")
