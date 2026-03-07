extends Node
## RunManager handles roguelike run state, lives, and run currency (Magicka)
## Manages the loop: Limbus → Run → Death/Victory → Limbus

# ============ RUN STATE ============
enum RunState {
	IDLE,       # In Limbus hub, no run active
	ACTIVE,     # Run is in progress
	ENDED       # Run just ended (transitioning back to Limbus)
}

var current_state: RunState = RunState.IDLE

# ============ LIVES ============
const BASE_LIVES: int = 1
const MAX_LIVES: int = 3

var current_lives: int = BASE_LIVES
var max_lives: int = BASE_LIVES  # Increased by perma upgrades

# ============ MAGICKA (PERSISTENT CURRENCY) ============
var magicka: int = 0

# ============ RUN DATA ============
var run_rooms_completed: int = 0
var run_enemies_killed: int = 0

# ============ SIGNALS ============
signal run_started()
signal run_ended(victory: bool)
signal lives_changed(current: int, maximum: int)
signal magicka_changed(new_amount: int)
signal player_run_death()  # Player died during run, loses a life


func _ready() -> void:
	print("[RunManager] Initialized")
	EventBus.player_died.connect(_on_player_died_in_run)


# ============ RUN LIFECYCLE ============
func start_run() -> void:
	if current_state == RunState.ACTIVE:
		push_warning("[RunManager] Run already active!")
		return

	current_state = RunState.ACTIVE
	current_lives = max_lives
	run_rooms_completed = 0
	run_enemies_killed = 0

	lives_changed.emit(current_lives, max_lives)
	run_started.emit()
	print("[RunManager] Run started with %d lives" % current_lives)


func end_run(victory: bool) -> void:
	if current_state != RunState.ACTIVE:
		return

	current_state = RunState.ENDED
	run_ended.emit(victory)
	print("[RunManager] Run ended. Victory: %s | Rooms: %d | Kills: %d" % [
		victory, run_rooms_completed, run_enemies_killed
	])

	# Return to Limbus
	_return_to_limbus()


func _return_to_limbus() -> void:
	current_state = RunState.IDLE

	# Reset run-volatile data (Gold, Consumables)
	if GameManager:
		GameManager.coins_collected = 0
		EventBus.coins_changed.emit(0)
	if InventoryManager:
		InventoryManager.inventory["consumables"].clear()
		InventoryManager.inventory_changed.emit()

	# Load Limbus scene
	get_tree().change_scene_to_file("res://worlds/limbus/limbus.tscn")
	print("[RunManager] Returned to Limbus")


# ============ LIVES ============
func lose_life() -> bool:
	"""Removes one life. Returns true if lives remain, false if run over."""
	current_lives -= 1
	lives_changed.emit(current_lives, max_lives)
	print("[RunManager] Life lost. Remaining: %d/%d" % [current_lives, max_lives])

	if current_lives <= 0:
		end_run(false)
		return false
	return true


func get_lives() -> int:
	return current_lives


func set_max_lives(new_max: int) -> void:
	max_lives = clampi(new_max, BASE_LIVES, MAX_LIVES)
	print("[RunManager] Max lives set to %d" % max_lives)


# ============ MAGICKA ============
func add_magicka(amount: int) -> void:
	magicka += amount
	magicka_changed.emit(magicka)
	print("[RunManager] Magicka gained: +%d. Total: %d" % [amount, magicka])


func spend_magicka(amount: int) -> bool:
	"""Spends Magicka. Returns false if not enough."""
	if magicka < amount:
		return false
	magicka -= amount
	magicka_changed.emit(magicka)
	print("[RunManager] Magicka spent: -%d. Total: %d" % [amount, magicka])
	return true


func get_magicka() -> int:
	return magicka


# ============ RUN TRACKING ============
func on_room_completed() -> void:
	if current_state == RunState.ACTIVE:
		run_rooms_completed += 1
		print("[RunManager] Room completed. Total: %d" % run_rooms_completed)


func on_enemy_killed() -> void:
	if current_state == RunState.ACTIVE:
		run_enemies_killed += 1


# ============ DEATH HANDLING ============
func _on_player_died_in_run() -> void:
	if current_state != RunState.ACTIVE:
		return

	print("[RunManager] Player died during run")
	player_run_death.emit()

	# Use a life
	var lives_remain = lose_life()
	if lives_remain:
		# Respawn in same room
		call_deferred("_respawn_in_room")


func _respawn_in_room() -> void:
	"""Respawns player in current room after losing a life"""
	if GameManager and GameManager.player:
		GameManager.respawn_player()
		GameManager.current_state = GameManager.GameState.PLAYING
		print("[RunManager] Player respawned (lives remaining: %d)" % current_lives)


# ============ SAVE/LOAD (Magicka is persistent) ============
func get_save_data() -> Dictionary:
	return {
		"magicka": magicka,
		"max_lives": max_lives
	}


func load_from_save(data: Dictionary) -> void:
	magicka = data.get("magicka", 0)
	max_lives = data.get("max_lives", BASE_LIVES)
	magicka_changed.emit(magicka)
	print("[RunManager] Loaded: Magicka=%d, MaxLives=%d" % [magicka, max_lives])


func is_run_active() -> bool:
	return current_state == RunState.ACTIVE
