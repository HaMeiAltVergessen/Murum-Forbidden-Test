extends Node
class_name WaveSpawner

## Reusable wave-based enemy spawning system
## Spawns enemies in sequential waves with delays

# ============================================================================
# WAVE DEFINITION
# ============================================================================

class Wave:
	var enemies: Array[Dictionary] = []  # [{scene: PackedScene, spawn_point: Vector2}]
	var delay_before: float = 1.0  # Delay before spawning this wave
	var delay_after: float = 2.0   # Delay after wave clear before next

	func add_enemy(enemy_scene: PackedScene, spawn_position: Vector2) -> void:
		enemies.append({
			"scene": enemy_scene,
			"spawn_point": spawn_position
		})

# ============================================================================
# PROPERTIES
# ============================================================================

@export var auto_start: bool = true
@export var lock_doors: bool = true
@export var spawn_coins_on_clear: bool = true
@export var coins_per_wave: int = 10

# ============================================================================
# STATE
# ============================================================================

var waves: Array[Wave] = []
var current_wave_index: int = -1
var is_active: bool = false
var spawned_enemies: Array[Node] = []
var _spawning_in_progress: bool = false  # Guard against race condition during stagger
var _spawn_parent: Node = null  # Parent node for spawned enemies (room, not root)

# ============================================================================
# SIGNALS
# ============================================================================

signal wave_spawner_started
signal wave_started(wave_index: int, total_waves: int)
signal wave_completed(wave_index: int, total_waves: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node, wave_index: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to EventBus
	EventBus.enemy_died.connect(_on_enemy_died)

	# Auto-start if enabled
	if auto_start:
		await get_tree().create_timer(0.5).timeout
		start_waves()


func _exit_tree() -> void:
	"""Clean up spawned enemies when this spawner is removed from scene"""
	_cleanup_spawned_enemies()


func _cleanup_spawned_enemies() -> void:
	"""Frees all enemies spawned by this spawner"""
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.queue_free()
	spawned_enemies.clear()

# ============================================================================
# WAVE MANAGEMENT
# ============================================================================

func add_wave(wave: Wave) -> void:
	"""Adds a wave to the sequence"""
	waves.append(wave)
	print("[WaveSpawner] Wave added (%d enemies)" % wave.enemies.size())

func start_waves() -> void:
	"""Starts wave sequence"""

	if is_active:
		push_warning("[WaveSpawner] Already active")
		return

	if waves.is_empty():
		push_error("[WaveSpawner] No waves configured!")
		return

	print("[WaveSpawner] Starting waves (total: %d)" % waves.size())

	is_active = true
	current_wave_index = -1

	# Lock doors
	if lock_doors:
		_lock_arena_doors()

	# Emit signal
	wave_spawner_started.emit()
	EventBus.wave_spawner_started.emit()

	# Start first wave
	_start_next_wave()

func _start_next_wave() -> void:
	"""Starts next wave in sequence"""

	current_wave_index += 1

	print("[WaveSpawner] _start_next_wave called, index now: %d, total waves: %d" % [current_wave_index, waves.size()])

	if current_wave_index >= waves.size():
		# All waves complete
		print("[WaveSpawner] All waves completed! Calling _on_all_waves_completed()")
		_on_all_waves_completed()
		return

	var wave = waves[current_wave_index]

	print("[WaveSpawner] Starting wave %d/%d with %d enemies" % [current_wave_index + 1, waves.size(), wave.enemies.size()])

	# Emit signal
	wave_started.emit(current_wave_index, waves.size())
	EventBus.wave_started.emit(current_wave_index, waves.size())

	# Delay before spawn
	await get_tree().create_timer(wave.delay_before).timeout

	# Spawn wave
	_spawn_wave(wave)

func _spawn_wave(wave: Wave) -> void:
	"""Spawns all enemies in wave"""

	spawned_enemies.clear()
	_spawning_in_progress = true

	# Determine spawn parent: use the room (grandparent) instead of root
	# so enemies are cleaned up when the room is freed
	_spawn_parent = _find_spawn_parent()

	for enemy_data in wave.enemies:
		var enemy_scene: PackedScene = enemy_data["scene"]
		var spawn_pos: Vector2 = enemy_data["spawn_point"]

		# Instantiate enemy
		var enemy = enemy_scene.instantiate()

		# Add to room (not root!) so enemies are freed with the room
		if is_instance_valid(_spawn_parent):
			_spawn_parent.add_child(enemy)
		else:
			get_tree().root.add_child(enemy)
		enemy.global_position = spawn_pos

		# Track
		spawned_enemies.append(enemy)

		# Spawn effect
		_play_spawn_effect(spawn_pos)

		# Emit signal
		enemy_spawned.emit(enemy, current_wave_index)

		# Brief delay between spawns (stagger)
		await get_tree().create_timer(0.2).timeout

	_spawning_in_progress = false

	print("[WaveSpawner] Spawned %d enemies for wave %d" % [
		spawned_enemies.size(),
		current_wave_index + 1
	])

	# Check completion after all spawns are done (in case enemies died during stagger)
	_check_wave_completion()


func _find_spawn_parent() -> Node:
	"""Finds the best parent for spawned enemies (the room node)"""
	# Walk up to find the RunNodeRoom or scene root
	var node: Node = self
	while node:
		if node is Node2D and node.get_parent() == get_tree().root:
			return node  # This is the room (top-level scene node)
		node = node.get_parent()
	return get_tree().root  # Fallback

# ============================================================================
# WAVE COMPLETION
# ============================================================================

func _on_enemy_died(enemy: Node, _position: Vector2) -> void:
	"""Called when any enemy dies"""

	if not is_active:
		return

	# Check if enemy was from this spawner
	if enemy not in spawned_enemies:
		return

	# Remove from tracking
	spawned_enemies.erase(enemy)

	print("[WaveSpawner] Enemy died, remaining: %d" % spawned_enemies.size())

	# Don't check completion while still spawning (stagger race condition)
	if _spawning_in_progress:
		return

	# Check if wave clear (also clean up invalid enemies)
	_check_wave_completion()

func _check_wave_completion() -> void:
	"""Checks if wave is complete, removing invalid enemies from tracking"""

	# Remove any invalid/freed enemies from tracking
	var valid_enemies: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			valid_enemies.append(enemy)
		else:
			print("[WaveSpawner] Removed invalid enemy from tracking")

	spawned_enemies = valid_enemies

	# Check if wave cleared
	if spawned_enemies.is_empty():
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	"""Called when current wave is cleared"""

	var wave = waves[current_wave_index]

	print("[WaveSpawner] Wave %d/%d cleared!" % [current_wave_index + 1, waves.size()])

	# Emit signal
	wave_completed.emit(current_wave_index, waves.size())
	EventBus.wave_completed.emit(current_wave_index, waves.size())

	# Spawn coins
	if spawn_coins_on_clear:
		_spawn_wave_coins()

	# Delay before next wave
	print("[WaveSpawner] Waiting %.1fs before next wave..." % wave.delay_after)
	await get_tree().create_timer(wave.delay_after).timeout

	# Start next wave
	print("[WaveSpawner] Delay complete, starting next wave...")
	_start_next_wave()

func _on_all_waves_completed() -> void:
	"""Called when all waves are cleared"""

	print("[WaveSpawner] All waves completed!")

	is_active = false

	# Unlock doors
	if lock_doors:
		_unlock_arena_doors()

	# Emit signal
	all_waves_completed.emit()
	EventBus.all_waves_completed.emit()

	# Visual feedback
	_play_completion_effect()

# ============================================================================
# DOOR MANAGEMENT
# ============================================================================

func _lock_arena_doors() -> void:
	"""Locks all doors in arena"""
	var doors = get_tree().get_nodes_in_group("doors")

	for door in doors:
		if door.has_method("lock"):
			door.lock()

func _unlock_arena_doors() -> void:
	"""Unlocks all doors in arena"""
	var doors = get_tree().get_nodes_in_group("doors")

	for door in doors:
		if door.has_method("unlock"):
			door.unlock()

# ============================================================================
# REWARDS
# ============================================================================

func _spawn_wave_coins() -> void:
	"""Spawns coins for wave completion"""

	# Calculate coin count (increases per wave)
	var coin_count = coins_per_wave * (current_wave_index + 1)

	# TODO: Spawn coin pickups
	# Placeholder: Just log
	print("[WaveSpawner] Would spawn %d coins" % coin_count)

# ============================================================================
# EFFECTS
# ============================================================================

func _play_spawn_effect(_position: Vector2) -> void:
	"""Visual effect for enemy spawn"""

	# TODO: Spawn particle effect at _position
	# Placeholder: Camera shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.1)

func _play_completion_effect() -> void:
	"""Visual effect for all waves complete"""

	# Camera shake for completion effect
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.3)

	# Audio
	if AudioManager:
		AudioManager.play_sfx("ui/waves_complete", 0.0)

	# Notification
	EventBus.show_notification.emit("All Waves Cleared!", 3.0)

# ============================================================================
# UTILITY
# ============================================================================

func get_current_wave_index() -> int:
	"""Returns current wave index (0-based)"""
	return current_wave_index

func get_total_waves() -> int:
	"""Returns total wave count"""
	return waves.size()

func get_remaining_enemies() -> int:
	"""Returns remaining enemies in current wave"""
	return spawned_enemies.size()

func is_waves_active() -> bool:
	"""Returns true if waves are active"""
	return is_active
