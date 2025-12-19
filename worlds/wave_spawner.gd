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
	EventBus.enemy_killed.connect(_on_enemy_killed)

	# Auto-start if enabled
	if auto_start:
		await get_tree().create_timer(0.5).timeout
		start_waves()

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

	if current_wave_index >= waves.size():
		# All waves complete
		_on_all_waves_completed()
		return

	var wave = waves[current_wave_index]

	print("[WaveSpawner] Starting wave %d/%d" % [current_wave_index + 1, waves.size()])

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

	for enemy_data in wave.enemies:
		var enemy_scene: PackedScene = enemy_data["scene"]
		var spawn_pos: Vector2 = enemy_data["spawn_point"]

		# Instantiate enemy
		var enemy = enemy_scene.instantiate()

		# Add to scene
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

	print("[WaveSpawner] Spawned %d enemies for wave %d" % [
		spawned_enemies.size(),
		current_wave_index + 1
	])

# ============================================================================
# WAVE COMPLETION
# ============================================================================

func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	"""Called when any enemy is killed"""

	if not is_active:
		return

	# Check if enemy was from this spawner
	if enemy not in spawned_enemies:
		return

	# Remove from tracking
	spawned_enemies.erase(enemy)

	print("[WaveSpawner] Enemy killed, remaining: %d" % spawned_enemies.size())

	# Check if wave clear
	if spawned_enemies.is_empty():
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	"""Called when current wave is cleared"""

	var wave = waves[current_wave_index]

	print("[WaveSpawner] Wave %d cleared!" % (current_wave_index + 1))

	# Emit signal
	wave_completed.emit(current_wave_index, waves.size())
	EventBus.wave_completed.emit(current_wave_index, waves.size())

	# Spawn coins
	if spawn_coins_on_clear:
		_spawn_wave_coins()

	# Delay before next wave
	await get_tree().create_timer(wave.delay_after).timeout

	# Start next wave
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

	# Screen flash
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").flash(Color(1.0, 1.0, 0.5, 0.5), 0.5)

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
