class_name ArenaController
extends Node

## Reusable, Inspector-configurable arena combat system.
## Attach as a child node to any room, configure waves/spawns/doors in Inspector.
## Uses WaveSpawner internally for enemy tracking and wave logic.
##
## Usage:
##   1. Add ArenaController node to your room scene
##   2. Create ArenaWaveConfig resources and assign to wave_configs
##   3. Place Marker2D spawn points in your scene, assign their paths
##   4. Optionally assign exit doors, entry doors, checkpoint
##   5. Set start_mode and trigger_area as needed

# ============================================================================
# CONFIGURATION - ARENA IDENTITY
# ============================================================================

@export_group("Arena")
## Unique ID for persistence (e.g. "world_1_ruins/room_03_arena")
@export var arena_id: String = ""

# ============================================================================
# CONFIGURATION - WAVES
# ============================================================================

@export_group("Waves")
## Wave definitions - each ArenaWaveConfig holds enemy entries and timing
@export var wave_configs: Array[ArenaWaveConfig] = []

# ============================================================================
# CONFIGURATION - SPAWN POINTS
# ============================================================================

@export_group("Spawn Points")
## Marker2D nodes where enemies can spawn (randomly distributed per wave)
@export var spawn_points: Array[NodePath] = []

# ============================================================================
# CONFIGURATION - START MODE
# ============================================================================

@export_group("Start Mode")

enum StartMode {
	AUTO_ON_ENTER,  ## Starts when player enters trigger area
	INTERACT,       ## Player must press E in trigger area
	MANUAL          ## Only starts via start_arena() call from external code
}

## How the arena is triggered
@export var start_mode: StartMode = StartMode.AUTO_ON_ENTER

## Area2D node that detects the player (for AUTO_ON_ENTER and INTERACT modes)
@export var trigger_area: NodePath

## Prompt text shown in INTERACT mode when player is in range
@export var interact_text: String = "E - Arena betreten"

# ============================================================================
# CONFIGURATION - DOORS
# ============================================================================

@export_group("Doors")
## Doors to show/unlock AFTER arena is cleared (e.g. exit to next room)
@export var exit_doors: Array[NodePath] = []

## Whether exit doors are hidden before the arena is cleared
@export var hide_exits_until_clear: bool = true

## Doors to lock DURING active waves (e.g. entry door so player can't leave)
@export var entry_doors: Array[NodePath] = []

# ============================================================================
# CONFIGURATION - CHECKPOINT
# ============================================================================

@export_group("Checkpoint")
## Checkpoint node to activate after arena clear
@export var checkpoint_path: NodePath

## Whether checkpoint is hidden before arena clear
@export var hide_checkpoint_until_clear: bool = true

# ============================================================================
# CONFIGURATION - SPAWNER SETTINGS
# ============================================================================

@export_group("Spawner Settings")
## Lock all doors in "doors" group during active waves (WaveSpawner built-in)
@export var lock_doors_during_waves: bool = true

## Spawn coin rewards when a wave is cleared
@export var spawn_coins_on_clear: bool = true

## Base coins per wave (WaveSpawner multiplies by wave index)
@export var coins_per_wave: int = 10

# ============================================================================
# SIGNALS
# ============================================================================

signal arena_started
signal arena_completed
signal arena_wave_started(wave_index: int, total_waves: int)
signal arena_wave_completed(wave_index: int, total_waves: int)

# ============================================================================
# STATE
# ============================================================================

var is_cleared: bool = false
var is_started: bool = false
var player_in_trigger: bool = false
var wave_spawner: WaveSpawner = null
var _interact_prompt: Label = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	set_process(false)

	# Check persistence - skip setup if already cleared
	if arena_id != "" and WorldManager and WorldManager.is_room_cleared(arena_id):
		is_cleared = true
		_apply_cleared_state()
		print("[ArenaController:%s] Already cleared, skipping setup" % arena_id)
		return

	# Setup systems
	_create_wave_spawner()
	_setup_trigger()
	_apply_initial_state()

	print("[ArenaController:%s] Initialized (%d waves, %d spawn points, mode: %s)" % [
		arena_id, wave_configs.size(), spawn_points.size(), StartMode.keys()[start_mode]
	])


func _create_wave_spawner() -> void:
	"""Creates the internal WaveSpawner with auto_start disabled"""
	wave_spawner = WaveSpawner.new()
	wave_spawner.name = "WaveSpawner"
	wave_spawner.auto_start = false
	wave_spawner.lock_doors = lock_doors_during_waves
	wave_spawner.spawn_coins_on_clear = spawn_coins_on_clear
	wave_spawner.coins_per_wave = coins_per_wave
	add_child(wave_spawner)

	# Connect wave signals
	wave_spawner.all_waves_completed.connect(_on_all_waves_completed)
	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_completed.connect(_on_wave_completed)


func _setup_trigger() -> void:
	"""Sets up the trigger area for AUTO_ON_ENTER / INTERACT modes"""
	if start_mode == StartMode.MANUAL:
		return

	var trigger = get_node_or_null(trigger_area)

	if not trigger or not trigger is Area2D:
		if start_mode == StartMode.AUTO_ON_ENTER:
			push_warning("[ArenaController:%s] No trigger area set, auto-starting" % arena_id)
			get_tree().create_timer(1.0).timeout.connect(start_arena, CONNECT_ONE_SHOT)
		return

	trigger.body_entered.connect(_on_trigger_body_entered)
	trigger.body_exited.connect(_on_trigger_body_exited)

	# Create interact prompt for INTERACT mode
	if start_mode == StartMode.INTERACT:
		_create_interact_prompt(trigger)
		set_process(true)


func _create_interact_prompt(trigger_node: Node) -> void:
	"""Creates the E-prompt label for interact mode"""
	_interact_prompt = Label.new()
	_interact_prompt.text = interact_text
	_interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_prompt.add_theme_font_size_override("font_size", 16)
	_interact_prompt.add_theme_color_override("font_color", Color.WHITE)
	_interact_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	_interact_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_interact_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_interact_prompt.position = Vector2(-80, -50)
	_interact_prompt.visible = false
	trigger_node.add_child(_interact_prompt)


func _apply_initial_state() -> void:
	"""Hides exits and checkpoint before arena is cleared"""
	if hide_exits_until_clear:
		for path in exit_doors:
			var door = get_node_or_null(path)
			if door:
				door.visible = false
				if door is Area2D:
					door.monitoring = false
				door.modulate.a = 0.0

	if hide_checkpoint_until_clear:
		var cp = get_node_or_null(checkpoint_path)
		if cp:
			cp.visible = false
			if cp is Area2D:
				cp.monitoring = false


# ============================================================================
# TRIGGER HANDLING
# ============================================================================

func _on_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	player_in_trigger = true

	if start_mode == StartMode.AUTO_ON_ENTER and not is_started:
		start_arena()
	elif start_mode == StartMode.INTERACT and _interact_prompt:
		_interact_prompt.visible = true


func _on_trigger_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return

	player_in_trigger = false

	if _interact_prompt:
		_interact_prompt.visible = false


func _process(_delta: float) -> void:
	if is_started or is_cleared or not player_in_trigger:
		return

	var interact_pressed = false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("interact")

	if interact_pressed:
		start_arena()


# ============================================================================
# ARENA CONTROL
# ============================================================================

func start_arena() -> void:
	"""Starts the arena. Called automatically by trigger or manually from code."""
	if is_started or is_cleared:
		return

	if wave_configs.is_empty():
		push_warning("[ArenaController:%s] No waves configured!" % arena_id)
		return

	is_started = true
	set_process(false)

	# Hide interact prompt
	if _interact_prompt:
		_interact_prompt.visible = false

	# Disable trigger so it doesn't fire again
	var trigger = get_node_or_null(trigger_area)
	if trigger and trigger is Area2D:
		trigger.set_deferred("monitoring", false)

	# Build waves from config (positions resolved now, scene fully loaded)
	_configure_waves()

	# Lock entry doors
	_set_entry_doors_locked(true)

	# Start the wave spawner
	wave_spawner.start_waves()

	arena_started.emit()
	print("[ArenaController:%s] Arena started!" % arena_id)


# ============================================================================
# WAVE CONFIGURATION (built at start time)
# ============================================================================

func _configure_waves() -> void:
	"""Converts Inspector wave configs into WaveSpawner.Wave objects"""
	var positions: Array[Vector2] = _resolve_spawn_positions()

	if positions.is_empty():
		push_warning("[ArenaController:%s] No valid spawn points! Using parent position." % arena_id)
		var parent = get_parent()
		if parent is Node2D:
			positions.append(parent.global_position)
		else:
			positions.append(Vector2(640, 400))

	for config in wave_configs:
		var wave = WaveSpawner.Wave.new()
		wave.delay_before = config.delay_before
		wave.delay_after = config.delay_after

		for entry in config.enemies:
			if not entry or not entry.scene:
				push_warning("[ArenaController:%s] Skipping null enemy entry" % arena_id)
				continue

			for i in entry.count:
				var pos = positions[randi() % positions.size()]
				wave.add_enemy(entry.scene, pos)

		wave_spawner.add_wave(wave)

	print("[ArenaController:%s] Configured %d waves on %d spawn points" % [
		arena_id, wave_configs.size(), positions.size()
	])


func _resolve_spawn_positions() -> Array[Vector2]:
	"""Resolves spawn point NodePaths to world positions"""
	var positions: Array[Vector2] = []

	for path in spawn_points:
		var marker = get_node_or_null(path)
		if marker and marker is Node2D:
			positions.append(marker.global_position)
		else:
			push_warning("[ArenaController:%s] Invalid spawn point: %s" % [arena_id, str(path)])

	return positions


# ============================================================================
# WAVE EVENTS
# ============================================================================

func _on_wave_started(wave_index: int, total_waves: int) -> void:
	arena_wave_started.emit(wave_index, total_waves)
	EventBus.show_notification.emit("Welle %d/%d" % [wave_index + 1, total_waves], 2.0)


func _on_wave_completed(wave_index: int, total_waves: int) -> void:
	arena_wave_completed.emit(wave_index, total_waves)


func _on_all_waves_completed() -> void:
	"""Called when every wave has been cleared"""
	is_cleared = true

	# Persist
	if arena_id != "" and WorldManager:
		WorldManager.mark_room_cleared(arena_id)

	# Unlock entry doors
	_set_entry_doors_locked(false)

	# Show exit doors
	_reveal_exit_doors()

	# Activate checkpoint
	_activate_checkpoint()

	# Effects
	_play_completion_effects()

	arena_completed.emit()
	print("[ArenaController:%s] Arena completed!" % arena_id)


# ============================================================================
# ALREADY-CLEARED STATE
# ============================================================================

func _apply_cleared_state() -> void:
	"""Applies the visual state for a previously cleared arena"""
	# Show exit doors immediately
	for path in exit_doors:
		var door = get_node_or_null(path)
		if door:
			door.visible = true
			if door is Area2D:
				door.monitoring = true
			door.modulate.a = 1.0

	# Activate checkpoint immediately
	var cp = get_node_or_null(checkpoint_path)
	if cp:
		cp.visible = true
		if cp is Area2D:
			cp.monitoring = true
		if cp.has_method("_update_visual"):
			cp.is_activated = true
			cp._update_visual()

	# Disable trigger
	var trigger = get_node_or_null(trigger_area)
	if trigger and trigger is Area2D:
		trigger.set_deferred("monitoring", false)


# ============================================================================
# DOOR MANAGEMENT
# ============================================================================

func _set_entry_doors_locked(locked: bool) -> void:
	"""Locks or unlocks entry doors"""
	for path in entry_doors:
		var door = get_node_or_null(path)
		if not door:
			continue
		if locked and door.has_method("lock"):
			door.lock()
		elif not locked and door.has_method("unlock"):
			door.unlock()


func _reveal_exit_doors() -> void:
	"""Fades in exit doors after arena clear"""
	for path in exit_doors:
		var door = get_node_or_null(path)
		if not door:
			continue

		door.visible = true
		if door is Area2D:
			door.monitoring = true

		var tween = create_tween()
		tween.tween_property(door, "modulate:a", 1.0, 0.5)

	if not exit_doors.is_empty():
		EventBus.show_notification.emit("Ausgang freigeschaltet!", 3.0)
		if AudioManager:
			AudioManager.play_sfx("ui/door_unlock", 0.0)


# ============================================================================
# CHECKPOINT MANAGEMENT
# ============================================================================

func _activate_checkpoint() -> void:
	"""Activates and fades in checkpoint after arena clear"""
	var cp = get_node_or_null(checkpoint_path)
	if not cp:
		return

	await get_tree().create_timer(1.0).timeout

	cp.visible = true
	if cp is Area2D:
		cp.monitoring = true

	cp.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(cp, "modulate:a", 1.0, 0.5)

	EventBus.show_notification.emit("Checkpoint freigeschaltet", 2.0)


# ============================================================================
# EFFECTS
# ============================================================================

func _play_completion_effects() -> void:
	"""Camera shake + audio + notification on arena clear"""
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").add_trauma(0.4)

	if AudioManager:
		AudioManager.play_sfx("ui/arena_complete", 0.0)

	EventBus.show_notification.emit("Arena abgeschlossen!", 3.0)


# ============================================================================
# UTILITY
# ============================================================================

func _is_player(body: Node2D) -> bool:
	return body.name == "Murum" or body is Murum


# ============================================================================
# PUBLIC API
# ============================================================================

func get_wave_count() -> int:
	return wave_configs.size()


func get_current_wave() -> int:
	if wave_spawner:
		return wave_spawner.get_current_wave_index()
	return -1


func get_remaining_enemies() -> int:
	if wave_spawner:
		return wave_spawner.get_remaining_enemies()
	return 0


func is_arena_active() -> bool:
	return is_started and not is_cleared


func is_arena_cleared() -> bool:
	return is_cleared
