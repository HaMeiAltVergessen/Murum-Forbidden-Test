extends RefCounted
## Generates Hades-style node network maps for each world
## Each world has a specific layout defined by WorldConfig
class_name RunMapGenerator

# ============ WORLD CONFIGS ============
# Predefined configs for all 3 worlds

static var world_configs: Dictionary = {}
static var _configs_initialized: bool = false

static func _init_configs() -> void:
	if _configs_initialized:
		return
	_configs_initialized = true

	# Welt 1: Das Niemandsland (Fantasy)
	# 3 Reihen + Boss, 8-9 Knoten, ~10-15 Min
	# Rast in Reihe 2 (Mitte)
	world_configs[RunMapData.WorldId.NIEMANDSLAND] = RunMapData.WorldConfig.new(
		RunMapData.WorldId.NIEMANDSLAND,
		"Das Niemandsland",
		3,     # 3 rows before boss
		2, 3,  # 2-3 nodes per row
		1,     # Rest at row 1 (middle, 0-indexed)
		0      # No events in Welt 1
	)

	# Welt 2: Das Kollektiv (Sci-Fi)
	# 4 Reihen + Boss, 12-13 Knoten, ~15-20 Min
	# Rast in Reihe 2 (middle-ish)
	world_configs[RunMapData.WorldId.KOLLEKTIV] = RunMapData.WorldConfig.new(
		RunMapData.WorldId.KOLLEKTIV,
		"Das Kollektiv",
		4,     # 4 rows before boss
		3, 4,  # 3-4 nodes per row
		2,     # Rest at row 2
		1      # 1 event per run
	)

	# Welt 3: Der Abgrund (Kosmischer Horror)
	# 6 Reihen + Boss, 18-20 Knoten, ~25-30 Min
	# Rast in Reihe 3 (middle)
	# Schwellensicht ab Reihe 3
	world_configs[RunMapData.WorldId.ABGRUND] = RunMapData.WorldConfig.new(
		RunMapData.WorldId.ABGRUND,
		"Der Abgrund",
		6,     # 6 rows before boss
		3, 4,  # 3-4 nodes per row
		3,     # Rest at row 3
		2,     # 2 events per run
		true,  # Has Schwellensicht
		3      # Schwellensicht starts at row 3
	)


# ============ GENERATION ============

static func generate_map(world_id: RunMapData.WorldId, rng_seed: int = -1) -> RunMapData.Map:
	"""Generates a complete node-network map for the given world"""
	_init_configs()

	var config: RunMapData.WorldConfig = world_configs.get(world_id)
	if not config:
		push_error("[RunMapGenerator] No config for world %d" % world_id)
		return null

	var rng = RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var map = RunMapData.Map.new()
	map.world_id = world_id

	var next_id: int = 0

	# ---- Generate rows ----
	for row_index in range(config.num_rows):
		var row_node_ids: Array = []
		var num_nodes: int = rng.randi_range(config.nodes_per_row_min, config.nodes_per_row_max)

		# Rest row: exactly 1 REST node
		if row_index == config.rest_row:
			var rest_node = RunMapData.MapNode.new(next_id, row_index, 0, RunMapData.NodeType.REST)
			rest_node.reward_type = "heal"
			map.nodes[next_id] = rest_node
			row_node_ids.append(next_id)
			next_id += 1
			map.rows.append(row_node_ids)
			continue

		# Determine node types for this row
		var node_types: Array = _generate_row_types(row_index, num_nodes, config, rng)

		for col_index in range(node_types.size()):
			var node = RunMapData.MapNode.new(next_id, row_index, col_index, node_types[col_index])
			node.reward_type = _get_default_reward(node.type)
			map.nodes[next_id] = node
			row_node_ids.append(next_id)
			next_id += 1

		map.rows.append(row_node_ids)

	# ---- W3: Pre-Boss room (single node) → Arena + Boss row ----
	if world_id == RunMapData.WorldId.ABGRUND:
		# Pre-Boss row: 1 REST node (safe room before final choice)
		var pre_boss_row_index: int = config.num_rows
		var pre_boss_node = RunMapData.MapNode.new(next_id, pre_boss_row_index, 0, RunMapData.NodeType.REST)
		pre_boss_node.reward_type = "heal"
		map.nodes[next_id] = pre_boss_node
		map.rows.append([next_id])
		var pre_boss_id: int = next_id
		next_id += 1

		# Boss row: Arena + Boss — pre-boss connects to both
		var boss_row_index: int = pre_boss_row_index + 1
		var arena_node = RunMapData.MapNode.new(next_id, boss_row_index, 0, RunMapData.NodeType.ARENA)
		arena_node.reward_type = "arena"
		map.nodes[next_id] = arena_node
		var arena_id: int = next_id
		next_id += 1

		var boss_node = RunMapData.MapNode.new(next_id, boss_row_index, 1, RunMapData.NodeType.BOSS)
		boss_node.reward_type = "boss"
		map.nodes[next_id] = boss_node
		var boss_id: int = next_id
		next_id += 1

		# Pre-boss connects to both Arena and Boss
		pre_boss_node.connections.append(arena_id)
		pre_boss_node.connections.append(boss_id)
		# Arena connects to Boss (after arena → boss)
		arena_node.connections.append(boss_id)

		map.rows.append([arena_id, boss_id])
	else:
		# W1/W2: Boss row (single BOSS node)
		var boss_row_index: int = config.num_rows
		var boss_node = RunMapData.MapNode.new(next_id, boss_row_index, 0, RunMapData.NodeType.BOSS)
		boss_node.reward_type = "boss"
		map.nodes[next_id] = boss_node
		map.rows.append([next_id])
		next_id += 1

	# ---- Place shops (1 per world) ----
	_place_shop(map, config, rng)

	# ---- Place events (Welt 2+) ----
	if config.events_per_run > 0:
		_place_events(map, config, rng)

	# ---- Connect rows ----
	_connect_rows(map, rng)

	# ---- Assign visual positions ----
	_assign_positions(map)

	print("[RunMapGenerator] Generated map for '%s': %d nodes, %d rows" % [
		config.world_name, map.nodes.size(), map.rows.size()
	])

	return map


# ============ ROW TYPE GENERATION ============

static func _generate_row_types(row_index: int, num_nodes: int,
		config: RunMapData.WorldConfig, rng: RandomNumberGenerator) -> Array:
	"""Determines what node types to place in a row"""
	var types: Array = []

	# Last row before boss: must have at least 1 Elite
	var is_pre_boss_row: bool = (row_index == config.num_rows - 1)

	for i in range(num_nodes):
		if is_pre_boss_row and i == 0:
			# First node in pre-boss row is always Elite
			types.append(RunMapData.NodeType.ELITE)
		else:
			types.append(_pick_node_type(row_index, config, rng))

	# Guarantee at least 1 Treasure in the map: place in row 0 or 1
	if row_index == 0 and types.size() >= 2:
		# Check if no treasure yet — replace last node with treasure
		var has_treasure = types.has(RunMapData.NodeType.TREASURE)
		if not has_treasure:
			types[types.size() - 1] = RunMapData.NodeType.TREASURE

	return types


static func _pick_node_type(row_index: int, config: RunMapData.WorldConfig,
		rng: RandomNumberGenerator) -> RunMapData.NodeType:
	"""Picks a random node type based on weighted probabilities"""
	# Weights: K+R is most common, with occasional treasure/elite
	var roll: float = rng.randf()

	if row_index >= config.num_rows - 1:
		# Pre-boss: higher Elite chance
		if roll < 0.5:
			return RunMapData.NodeType.COMBAT
		elif roll < 0.85:
			return RunMapData.NodeType.ELITE
		else:
			return RunMapData.NodeType.TREASURE
	else:
		# Normal row
		if roll < 0.6:
			return RunMapData.NodeType.COMBAT
		elif roll < 0.8:
			return RunMapData.NodeType.ELITE
		else:
			return RunMapData.NodeType.TREASURE


# ============ EVENT PLACEMENT ============

static func _place_events(map: RunMapData.Map, config: RunMapData.WorldConfig,
		rng: RandomNumberGenerator) -> void:
	"""Replaces some K+R nodes with Event nodes"""
	var events_placed: int = 0
	var eligible_nodes: Array = []

	# Collect K+R nodes that can be replaced (not in row 0, not pre-boss, not rest)
	for node_id in map.nodes:
		var node: RunMapData.MapNode = map.nodes[node_id]
		if node.type == RunMapData.NodeType.COMBAT:
			if node.row > 0 and node.row < config.num_rows - 1 and node.row != config.rest_row:
				eligible_nodes.append(node)

	# Shuffle and pick
	eligible_nodes.shuffle()
	for node in eligible_nodes:
		if events_placed >= config.events_per_run:
			break
		node.type = RunMapData.NodeType.EVENT
		node.reward_type = _get_default_reward(RunMapData.NodeType.EVENT)
		events_placed += 1

	print("[RunMapGenerator] Placed %d/%d events" % [events_placed, config.events_per_run])


# ============ SHOP PLACEMENT ============

static func _place_shop(map: RunMapData.Map, config: RunMapData.WorldConfig,
		rng: RandomNumberGenerator) -> void:
	"""Places exactly 1 SHOP node per world — replaces a COMBAT node"""
	var eligible_nodes: Array = []

	for node_id in map.nodes:
		var node: RunMapData.MapNode = map.nodes[node_id]
		if node.type == RunMapData.NodeType.COMBAT:
			# Not in row 0, not pre-boss, not rest row
			if node.row > 0 and node.row < config.num_rows - 1 and node.row != config.rest_row:
				eligible_nodes.append(node)

	if eligible_nodes.is_empty():
		push_warning("[RunMapGenerator] No eligible node for SHOP placement")
		return

	eligible_nodes.shuffle()
	var chosen: RunMapData.MapNode = eligible_nodes[0]
	chosen.type = RunMapData.NodeType.SHOP
	chosen.reward_type = "shop"
	print("[RunMapGenerator] Placed SHOP at row %d, col %d" % [chosen.row, chosen.column])


# ============ CONNECTION LOGIC ============

static func _connect_rows(map: RunMapData.Map, rng: RandomNumberGenerator) -> void:
	"""Connects nodes between adjacent rows (Hades-style web)
	Rules:
	- Every node must have at least 1 connection forward
	- Every node (except row 0) must be reachable from at least 1 node in previous row
	- Connections should not cross too much (keeps the graph readable)
	"""
	for row_index in range(map.rows.size() - 1):
		var current_row: Array = map.rows[row_index]
		var next_row: Array = map.rows[row_index + 1]

		if current_row.is_empty() or next_row.is_empty():
			continue

		# Step 1: Ensure every node in current row has at least 1 forward connection
		for i in range(current_row.size()):
			var node: RunMapData.MapNode = map.nodes[current_row[i]]
			# Map column proportionally to next row
			var proportional_col: int = clampi(
				roundi(float(i) / max(current_row.size() - 1, 1) * (next_row.size() - 1)),
				0, next_row.size() - 1
			)
			if not node.connections.has(next_row[proportional_col]):
				node.connections.append(next_row[proportional_col])

		# Step 2: Ensure every node in next row is reachable
		var reachable: Dictionary = {}
		for node_id in current_row:
			var node: RunMapData.MapNode = map.nodes[node_id]
			for conn in node.connections:
				reachable[conn] = true

		for j in range(next_row.size()):
			if not reachable.has(next_row[j]):
				# Not reachable — connect from nearest node in current row
				var nearest_i: int = clampi(
					roundi(float(j) / max(next_row.size() - 1, 1) * (current_row.size() - 1)),
					0, current_row.size() - 1
				)
				var node: RunMapData.MapNode = map.nodes[current_row[nearest_i]]
				node.connections.append(next_row[j])

		# Step 3: Add some extra connections for branching (30% chance per pair)
		for i in range(current_row.size()):
			var node: RunMapData.MapNode = map.nodes[current_row[i]]
			for j in range(next_row.size()):
				if node.connections.has(next_row[j]):
					continue
				# Only connect to adjacent columns (prevent wild crossings)
				var proportional: float = float(i) / max(current_row.size() - 1, 1) * (next_row.size() - 1)
				if absf(j - proportional) <= 1.2 and rng.randf() < 0.3:
					node.connections.append(next_row[j])


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
		RunMapData.NodeType.ELITE: return "relic"
		RunMapData.NodeType.TREASURE: return "item"
		RunMapData.NodeType.REST: return "heal"
		RunMapData.NodeType.EVENT: return "event"
		RunMapData.NodeType.BOSS: return "boss"
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
			row_str += "[%d:%s]" % [node.id, node.get_type_name()]
			if not node.connections.is_empty():
				row_str += "→%s " % str(node.connections)
			else:
				row_str += " "
		print(row_str)
	print("===============")
