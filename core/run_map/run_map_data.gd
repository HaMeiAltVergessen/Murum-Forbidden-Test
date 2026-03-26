extends RefCounted
## Data classes for the roguelike Run-Map system
## Hades-style node network with rows per world
class_name RunMapData

# ============ NODE TYPES ============
enum NodeType {
	COMBAT,          # K: Kampf (Haupttyp)
	ELITE,           # E: Elite-Kampf (haerter, Pre-Boss)
	TREASURE,        # S: Schatz (Wahl aus 3 Items)
	REST,            # RAST: Mini-Hub, volle Heilung, NPCs
	EVENT,           # Er: Ereignis (Text-Event, ab Welt 2)
	BOSS,            # BOSS: Fester Abschlussknoten
	SHOP,            # Haendler: Items kaufen
	ARENA            # Arena: Optionaler PvP/Boss-Kampf (W3)
}

# ============ WORLD CONFIG ============
enum WorldId {
	NIEMANDSLAND,    # Welt 1: Fantasy (3 Reihen + Boss)
	KOLLEKTIV,       # Welt 2: Sci-Fi (4 Reihen + Boss)
	ABGRUND          # Welt 3: Kosmischer Horror (6 Reihen + Boss)
}

# ============ NODE ============
class MapNode:
	var id: int                          # Unique node ID within the map
	var row: int                         # Row index (0 = first row)
	var column: int                      # Column position within the row
	var type: NodeType                   # Node type (K+R, E+R, S, RAST, Er, BOSS)
	var connections: Array[int] = []     # IDs of connected nodes in the NEXT row
	var room_scene_path: String = ""     # Path to the room scene (set by room pool)
	var display_name: String = ""        # Thematic room name shown on doors and map
	var reward_type: String = ""         # Reward preview icon key (gold, item, relic, etc.)
	var is_completed: bool = false       # Player has cleared this node
	var is_accessible: bool = false      # Player can currently select this node
	var position: Vector2 = Vector2.ZERO # Visual position on the map UI

	func _init(p_id: int, p_row: int, p_column: int, p_type: NodeType) -> void:
		id = p_id
		row = p_row
		column = p_column
		type = p_type

	func get_display_name() -> String:
		if display_name != "":
			return display_name
		return get_type_name()

	func get_type_name() -> String:
		match type:
			NodeType.COMBAT: return "Kampf"
			NodeType.ELITE: return "Elite"
			NodeType.TREASURE: return "Schatz"
			NodeType.REST: return "Rast"
			NodeType.EVENT: return "Ereignis"
			NodeType.BOSS: return "Boss"
			NodeType.SHOP: return "Haendler"
			NodeType.ARENA: return "Arena"
		return "?"

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"row": row,
			"column": column,
			"type": type,
			"connections": connections,
			"room_scene_path": room_scene_path,
			"display_name": display_name,
			"reward_type": reward_type,
			"is_completed": is_completed,
		}

	static func from_dict(data: Dictionary) -> MapNode:
		var node = MapNode.new(
			data.get("id", 0),
			data.get("row", 0),
			data.get("column", 0),
			data.get("type", NodeType.COMBAT)
		)
		node.connections = Array(data.get("connections", []), TYPE_INT, "", null)
		node.room_scene_path = data.get("room_scene_path", "")
		node.display_name = data.get("display_name", "")
		node.reward_type = data.get("reward_type", "")
		node.is_completed = data.get("is_completed", false)
		return node

# ============ WORLD CONFIG ============
class WorldConfig:
	var world_id: WorldId
	var world_name: String
	var num_rows: int              # Rows BEFORE boss (excluding boss row)
	var nodes_per_row_min: int     # Min nodes per row
	var nodes_per_row_max: int     # Max nodes per row
	var rest_row: int              # Which row is the RAST hub (-1 = none)
	var events_per_run: int        # How many Ereignis nodes to place
	var has_schwellensicht: bool   # Schwellensicht activates mid-run
	var schwellensicht_row: int    # Row where Schwellensicht starts (-1 = never)

	func _init(p_id: WorldId, p_name: String, p_rows: int, p_min: int, p_max: int,
			p_rest: int, p_events: int, p_schwelle: bool = false, p_schwelle_row: int = -1) -> void:
		world_id = p_id
		world_name = p_name
		num_rows = p_rows
		nodes_per_row_min = p_min
		nodes_per_row_max = p_max
		rest_row = p_rest
		events_per_run = p_events
		has_schwellensicht = p_schwelle
		schwellensicht_row = p_schwelle_row

# ============ MAP (full generated map for one world) ============
class Map:
	var world_id: WorldId
	var nodes: Dictionary = {}          # id -> MapNode
	var rows: Array = []                # Array of Arrays: row_index -> [node_ids]
	var current_node_id: int = -1       # Node the player is currently at (-1 = not started)
	var completed_node_ids: Array[int] = []

	func get_node(node_id: int) -> MapNode:
		return nodes.get(node_id, null)

	func get_accessible_nodes() -> Array[MapNode]:
		"""Returns nodes the player can select next"""
		var accessible: Array[MapNode] = []
		if current_node_id == -1:
			# Run not started: first row is accessible
			if rows.size() > 0:
				for node_id in rows[0]:
					var node: MapNode = nodes[node_id]
					node.is_accessible = true
					accessible.append(node)
		else:
			# Nodes connected from current node
			var current: MapNode = nodes.get(current_node_id, null)
			if current:
				for next_id in current.connections:
					var node: MapNode = nodes.get(next_id, null)
					if node and not node.is_completed:
						node.is_accessible = true
						accessible.append(node)
		return accessible

	func select_node(node_id: int) -> MapNode:
		"""Selects a node — marks it as current, returns it"""
		var node: MapNode = nodes.get(node_id, null)
		if not node:
			return null
		current_node_id = node_id
		# Reset all accessibility
		for n in nodes.values():
			n.is_accessible = false
		return node

	func complete_current_node() -> void:
		"""Marks the current node as completed"""
		if current_node_id >= 0:
			var node: MapNode = nodes.get(current_node_id, null)
			if node:
				node.is_completed = true
				completed_node_ids.append(current_node_id)

	func is_boss_reached() -> bool:
		"""Check if the current node is the boss"""
		if current_node_id < 0:
			return false
		var node: MapNode = nodes.get(current_node_id, null)
		return node != null and node.type == NodeType.BOSS

	func get_all_nodes_in_row(row_index: int) -> Array[MapNode]:
		var result: Array[MapNode] = []
		if row_index >= 0 and row_index < rows.size():
			for node_id in rows[row_index]:
				result.append(nodes[node_id])
		return result

	func to_dict() -> Dictionary:
		var nodes_data: Dictionary = {}
		for node_id in nodes:
			nodes_data[str(node_id)] = nodes[node_id].to_dict()
		return {
			"world_id": world_id,
			"nodes": nodes_data,
			"rows": rows,
			"current_node_id": current_node_id,
			"completed_node_ids": completed_node_ids,
		}

	static func from_dict(data: Dictionary) -> Map:
		var map = Map.new()
		map.world_id = data.get("world_id", WorldId.NIEMANDSLAND)
		map.current_node_id = data.get("current_node_id", -1)
		map.completed_node_ids = Array(data.get("completed_node_ids", []), TYPE_INT, "", null)
		map.rows = data.get("rows", [])
		var nodes_data: Dictionary = data.get("nodes", {})
		for key in nodes_data:
			var node = MapNode.from_dict(nodes_data[key])
			map.nodes[node.id] = node
		return map
