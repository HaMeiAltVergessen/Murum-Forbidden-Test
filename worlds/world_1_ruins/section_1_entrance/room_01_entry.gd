extends Node2D

## Room 01 - Entry/Tutorial Room

# ============================================================================
# PROPERTIES
# ============================================================================

const ROOM_ID: String = "room_01_entry"
const WORLD_ID: String = "world_1_ruins"

# ============================================================================
# REFERENCES
# ============================================================================

@onready var door_to_room_02: Node = $Doors/DoorToRoom02
@onready var spawn_points: Node2D = $SpawnPoints
@onready var dialog_trigger: Area2D = $DialogTrigger

var dialog_triggered: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

# Track if room content has been spawned (prevents duplicate spawns)
var has_spawned_content: bool = false

func _ready() -> void:
	print("[Room01_Entry] Initialized")

	# Only spawn checkpoint and enemies ONCE (COMMIT 018: Prevent duplicate spawns)
	if not has_spawned_content:
		_spawn_checkpoint()
		_spawn_enemies()
		has_spawned_content = true

	# Setup puzzle persistence (COMMIT 015: Puzzle System)
	_setup_puzzle_persistence()

	# Setup dialog trigger
	_setup_dialog_trigger()

	# Activate room (register with GameManager, setup player)
	call_deferred("_activate")


func _activate() -> void:
	"""Activates the room and sets up player if transitioning from another scene"""
	# Register room with GameManager
	if GameManager.has_method("register_room"):
		GameManager.register_room(self)

	# Set current room in WorldManager (COMMIT 016: Save System)
	if WorldManager:
		WorldManager.current_world = WORLD_ID
		WorldManager.current_room = ROOM_ID
		print("[Room01_Entry] WorldManager room set: %s/%s" % [WORLD_ID, ROOM_ID])

	# Check if player exists, if not spawn a new one (e.g., from main menu)
	if not GameManager.player or not is_instance_valid(GameManager.player):
		print("[Room01_Entry] No player found, spawning new player")
		_spawn_new_player()
		return

	# If player was transferred from another scene, ensure proper setup
	if GameManager.player and is_instance_valid(GameManager.player):
		var player = GameManager.player

		# Move player from root to this scene (if coming from door transition)
		if player.get_parent() == get_tree().root:
			get_tree().root.remove_child(player)
			add_child(player)
			print("[Room01_Entry] Player moved from root to scene")

			# Position player at door spawn position (COMMIT 018: Fix door spawning)
			if GameManager.player_spawn_position != Vector2.ZERO:
				player.global_position = GameManager.player_spawn_position
				print("[Room01_Entry] Player spawned at door position: ", GameManager.player_spawn_position)
				# Reset spawn position
				GameManager.player_spawn_position = Vector2.ZERO

		# Ensure player setup
		if player.get_parent() == self:
			print("[Room01_Entry] Player setup in scene")
			player.z_index = 100
			player.z_as_relative = false

			# Ensure player is on ground (not floating or falling through)
			if player is CharacterBody2D:
				player.velocity = Vector2.ZERO

			# Clear camera bounds for free following
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera.has_method("clear_room_bounds"):
				player_camera.clear_room_bounds()
				print("[Room01_Entry] Camera limits cleared")


func _spawn_new_player() -> void:
	"""Spawns a new player at the default spawn point or loaded position"""
	# Load player scene
	var player_scene = preload("res://player/murum.tscn")
	if not player_scene:
		print("[Room01_Entry] ERROR: Could not load player scene")
		return

	# Instantiate player
	var player = player_scene.instantiate()

	# Check if we have pending player data from save load (COMMIT 016)
	var has_save_data = SaveManager.pending_player_data and not SaveManager.pending_player_data.is_empty()

	# Get spawn position (COMMIT 018: Priority - Checkpoint > Door > Default)
	var spawn_pos = Vector2(50, 360)

	if has_save_data:
		# PRIORITY 1: Loading from save - ALWAYS use WorldManager.last_checkpoint_position
		# (because SaveManager saves checkpoint position, not current position)
		if WorldManager and WorldManager.last_checkpoint_position != Vector2.ZERO:
			spawn_pos = WorldManager.last_checkpoint_position
			print("[Room01_Entry] Loading from save - using WorldManager checkpoint position: ", spawn_pos)
		else:
			# Fallback: Try to get position from save data
			var pos_data = SaveManager.pending_player_data.get("position", {})
			if pos_data.has("x") and pos_data.has("y"):
				spawn_pos = Vector2(pos_data.get("x"), pos_data.get("y"))
				print("[Room01_Entry] Loading from save - using saved checkpoint position: ", spawn_pos)
			else:
				# Last fallback: default spawn point
				var default_spawn = spawn_points.get_node_or_null("Default")
				if default_spawn:
					spawn_pos = default_spawn.global_position
					print("[Room01_Entry] No saved position, using default spawn point: ", spawn_pos)
	else:
		# PRIORITY 2: Check for door spawn position (from GameManager)
		if GameManager.player_spawn_position != Vector2.ZERO:
			spawn_pos = GameManager.player_spawn_position
			print("[Room01_Entry] Using door spawn position: ", spawn_pos)
			# Reset spawn position after using
			GameManager.player_spawn_position = Vector2.ZERO
		else:
			# PRIORITY 3: Normal spawn - use default spawn point
			var default_spawn = spawn_points.get_node_or_null("Default")
			if default_spawn:
				spawn_pos = default_spawn.global_position
				print("[Room01_Entry] New game - spawning at default spawn point: ", spawn_pos)
			else:
				print("[Room01_Entry] Using fallback spawn position: ", spawn_pos)

	# Set player position
	player.global_position = spawn_pos

	# Add player to scene
	add_child(player)

	# Apply saved stats if available (COMMIT 016)
	if has_save_data:
		_apply_saved_player_data(player, SaveManager.pending_player_data)

		# Clear pending data after applying
		SaveManager.pending_player_data = {}
		print("[Room01_Entry] Saved player data applied and cleared")

	# Register with GameManager
	if GameManager.has_method("set_player"):
		GameManager.set_player(player)

	print("[Room01_Entry] Player spawned successfully at ", spawn_pos)


func _apply_saved_player_data(player: Node, player_data: Dictionary) -> void:
	"""Applies saved player stats from loaded game (COMMIT 016)"""
	print("[Room01_Entry] Applying saved player data...")

	# Apply HP
	if "current_hp" in player:
		player.current_hp = player_data.get("current_hp", player.MAX_HP if "MAX_HP" in player else 100)
		print("[Room01_Entry] Set HP to: %d" % player.current_hp)

	# Apply Mana
	if "current_mana" in player:
		player.current_mana = player_data.get("current_mana", player.MAX_MANA if "MAX_MANA" in player else 100)
		print("[Room01_Entry] Set Mana to: %d" % player.current_mana)

	# Apply facing direction
	if "facing_direction" in player:
		player.facing_direction = player_data.get("facing_direction", 1)

	print("[Room01_Entry] Player data applied successfully")


# ============================================================================
# CHECKPOINT & ENEMIES (COMMIT 016: Auto-Save)
# ============================================================================

func _spawn_checkpoint() -> void:
	"""Spawns a checkpoint in the room for auto-save"""
	var checkpoint_scene = preload("res://environment/checkpoint.tscn")
	if not checkpoint_scene:
		print("[Room01_Entry] WARNING: Checkpoint scene not found")
		return

	var checkpoint = checkpoint_scene.instantiate()
	checkpoint.global_position = Vector2(400, 570)  # Platform near start
	checkpoint.checkpoint_id = "room_01_entry/start_checkpoint"

	add_child(checkpoint)
	print("[Room01_Entry] Checkpoint spawned at ", checkpoint.global_position)


func _spawn_enemies() -> void:
	"""Spawns 8 Untote enemies for combat testing"""
	var untote_scene = preload("res://enemies/untote.tscn")
	if not untote_scene:
		print("[Room01_Entry] WARNING: Untote scene not found")
		return

	# Spawn positions spread across the room
	var spawn_positions = [
		Vector2(800, 600),
		Vector2(1000, 600),
		Vector2(1200, 600),
		Vector2(1400, 600),
		Vector2(1600, 600),
		Vector2(1800, 600),
		Vector2(2000, 600),
		Vector2(2200, 600),
	]

	for pos in spawn_positions:
		var enemy = untote_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)

	print("[Room01_Entry] Spawned %d Untote enemies" % spawn_positions.size())


# ============================================================================
# CRYSTAL PUZZLE (COMMIT 015: Puzzle System)
# ============================================================================

const PUZZLE_ID = "room_01_entry/crystal_sequence"
var hit_sequence: Array = []
var puzzle_crystals: Array = []

func _setup_puzzle_persistence() -> void:
	"""Setup puzzle persistence - removes crystals if already solved"""
	# Wait for scene to be ready
	await get_tree().process_frame

	# Find crystals in scene (they should be in a CrystalPuzzle node)
	var puzzle_node = get_node_or_null("CrystalPuzzle")
	if not puzzle_node:
		print("[Room01_Entry] No CrystalPuzzle node found")
		return

	# Get all crystal children
	puzzle_crystals = puzzle_node.get_children().filter(func(child): return child is PuzzleCrystal)

	# Check if puzzle is already solved
	if WorldManager and WorldManager.is_puzzle_solved(PUZZLE_ID):
		print("[Room01_Entry] Puzzle already solved, removing crystals")
		puzzle_node.queue_free()
		return

	# Connect crystal signals
	for crystal in puzzle_crystals:
		crystal.crystal_hit.connect(_on_crystal_hit.bind(crystal))

	print("[Room01_Entry] Crystal puzzle ready (%d crystals)" % puzzle_crystals.size())


func _on_crystal_hit(projectile_owner: Node2D, crystal: PuzzleCrystal) -> void:
	"""Called when a crystal is hit"""
	var crystal_id = crystal.crystal_id
	print("[Room01_Entry] Crystal %d hit! Current sequence: %s" % [crystal_id, str(hit_sequence)])

	# Add to hit sequence
	hit_sequence.append(crystal_id)

	# Check if sequence is correct so far
	var correct_sequence = [1, 2, 3]
	var is_correct = true

	for i in range(hit_sequence.size()):
		if i >= correct_sequence.size() or hit_sequence[i] != correct_sequence[i]:
			is_correct = false
			break

	if not is_correct:
		# Wrong sequence - reset all crystals
		print("[Room01_Entry] Wrong sequence! Resetting...")
		if EventBus:
			EventBus.show_notification.emit("Falsche Reihenfolge!", 2.0)

		# Clear sequence
		hit_sequence.clear()

		# Reset crystals after delay
		await get_tree().create_timer(1.0).timeout
		for c in puzzle_crystals:
			if is_instance_valid(c):
				c.reset()

		return

	# Check if puzzle is complete
	if hit_sequence.size() == correct_sequence.size():
		_on_puzzle_solved()


func _on_puzzle_solved() -> void:
	"""Called when puzzle is solved"""
	print("[Room01_Entry] Puzzle solved: %s" % PUZZLE_ID)

	# Disable reset on all crystals (prevents respawn)
	for crystal in puzzle_crystals:
		if is_instance_valid(crystal):
			crystal.can_reset = false
			crystal.is_being_removed = true  # Mark for removal

	print("[Room01_Entry] Disabled crystal reset - puzzle permanently solved")

	# Mark puzzle as solved in WorldManager
	if WorldManager:
		WorldManager.mark_puzzle_solved(PUZZLE_ID)

	# Auto-save after solving puzzle
	if SaveManager:
		SaveManager.save_current_game()
		print("[Room01_Entry] Auto-saved after puzzle completion")

	# Visual/audio feedback
	if EventBus:
		EventBus.show_notification.emit("Rätsel gelöst!", 3.0)

	if AudioManager:
		AudioManager.play_sfx("puzzle/puzzle_solved")


# ============================================================================
# DIALOG TRIGGER (Murum & Umbra / Murum & Lythrun Introduction)
# ============================================================================

const DIALOG_ID = "world01room01"
const DIALOG_ID_COOP = "world01room01_coop"

func _setup_dialog_trigger() -> void:
	"""Setup the dialog trigger area for Murum-Umbra or Murum-Lythrun conversation"""
	# Check if dialog was already played (persistence) - check both versions
	if WorldManager and (WorldManager.is_dialog_played(DIALOG_ID) or WorldManager.is_dialog_played(DIALOG_ID_COOP)):
		dialog_triggered = true
		print("[Room01_Entry] Dialog already played, disabling trigger")
		return

	if dialog_trigger:
		dialog_trigger.body_entered.connect(_on_dialog_trigger_body_entered)
		print("[Room01_Entry] Dialog trigger setup complete")

	# Connect to dialog finished signal to mark as played
	if EventBus and EventBus.has_signal("dialog_finished"):
		EventBus.dialog_finished.connect(_on_dialog_finished)


func _on_dialog_trigger_body_entered(body: Node2D) -> void:
	"""Triggered when player enters the dialog area"""
	if dialog_triggered:
		return

	if body.is_in_group("player") or body.name == "Murum":
		dialog_triggered = true

		# Check if P2 (Lythrun) is active - use alternate dialog
		var use_coop_dialog = CoopManager and CoopManager.is_p2_active
		var selected_dialog = DIALOG_ID_COOP if use_coop_dialog else DIALOG_ID

		print("[Room01_Entry] Dialog triggered: %s (Coop: %s)" % [selected_dialog, use_coop_dialog])

		# Small delay before starting dialog
		await get_tree().create_timer(0.3).timeout

		if DialogManager:
			DialogManager.play_dialog(selected_dialog)


func _on_dialog_finished(dialog_id: String) -> void:
	"""Called when any dialog finishes - marks our dialog as played"""
	if dialog_id == DIALOG_ID or dialog_id == DIALOG_ID_COOP:
		if WorldManager:
			WorldManager.mark_dialog_played(dialog_id)
			print("[Room01_Entry] Dialog marked as played: %s" % dialog_id)
