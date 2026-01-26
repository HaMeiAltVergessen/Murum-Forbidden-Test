extends CanvasLayer

## Pause Menu - Ingame Pause-Menü
## Godot 4.4 kompatibel
## COMMIT 017: Pause Menu Foundation

# ============================================================================
# SIGNALS
# ============================================================================

signal pause_menu_opened()
signal pause_menu_closed()

# ============================================================================
# REFERENCES - Main Containers
# ============================================================================

@onready var pause_overlay: ColorRect = %PauseOverlay
@onready var main_panel: PanelContainer = %MainPanel
@onready var character_panel: PanelContainer = %CharacterPanel
@onready var options_container: Control = %OptionsContainer

# ============================================================================
# REFERENCES - Main Menu Buttons
# ============================================================================

@onready var resume_button: Button = %ResumeButton
@onready var load_checkpoint_button: Button = %LoadCheckpointButton
@onready var save_checkpoint_button: Button = %SaveCheckpointButton
@onready var character_button: Button = %CharacterButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

# ============================================================================
# REFERENCES - Character Stats
# ============================================================================

@onready var hp_label: Label = %HPLabel
@onready var mana_label: Label = %ManaLabel
@onready var buffs_container: VBoxContainer = %BuffsContainer
@onready var character_back_button: Button = %CharacterBackButton

# ============================================================================
# OPTIONS MENU
# ============================================================================

const OPTIONS_MENU_SCENE = preload("res://ui/menus/options_submenu.tscn")
var options_menu_instance: Control = null

# ============================================================================
# STATE
# ============================================================================

var is_paused: bool = false
var current_view: String = "main"  # "main", "character", "options"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process, even when paused

	# Setup options menu
	_setup_options_menu()

	# Connect signals
	_connect_signals()

	print("[PauseMenu] Initialized")

func _setup_options_menu() -> void:
	"""Creates and hides options menu instance"""
	options_menu_instance = OPTIONS_MENU_SCENE.instantiate()
	options_container.add_child(options_menu_instance)
	options_menu_instance.visible = false

	# Connect back signal
	options_menu_instance.back_pressed.connect(_on_options_back_pressed)

	print("[PauseMenu] Options menu initialized")

func _connect_signals() -> void:
	"""Connects all button signals"""
	# Main menu buttons
	resume_button.pressed.connect(_on_resume_pressed)
	load_checkpoint_button.pressed.connect(_on_load_checkpoint_pressed)
	save_checkpoint_button.pressed.connect(_on_save_checkpoint_pressed)
	character_button.pressed.connect(_on_character_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Character back button
	character_back_button.pressed.connect(_on_character_back_pressed)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	# Don't allow pause in main menu
	if _is_in_main_menu():
		return

	# Don't allow pause during dialog or cutscene
	if _is_dialog_or_cutscene_active():
		return

	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			# If in submenu, go back
			if current_view == "character":
				_on_character_back_pressed()
			elif current_view == "options":
				_on_options_back_pressed()
			else:
				# Resume game
				_on_resume_pressed()
		else:
			# Pause game
			toggle_pause()
		get_viewport().set_input_as_handled()

func _is_in_main_menu() -> bool:
	"""Checks if currently in main menu"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene is MainMenu or current_scene.name == "MainMenu"
	return false


func _is_dialog_or_cutscene_active() -> bool:
	"""Checks if dialog or cutscene is currently active"""
	# Check dialog
	if DialogManager and DialogManager.is_active:
		return true

	# Check cutscene
	if CutsceneManager and CutsceneManager.has_method("is_playing") and CutsceneManager.is_playing():
		return true

	return false

# ============================================================================
# PAUSE CONTROL
# ============================================================================

func toggle_pause() -> void:
	"""Toggles pause state"""
	if is_paused:
		unpause()
	else:
		pause()

func pause() -> void:
	"""Pauses the game and shows menu"""
	is_paused = true
	get_tree().paused = true
	visible = true
	current_view = "main"

	# Show main panel
	main_panel.visible = true
	character_panel.visible = false
	options_container.visible = false

	# Update character stats
	_update_character_stats()

	# Update checkpoint button states
	_update_checkpoint_buttons()

	# Focus resume button
	resume_button.grab_focus()

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_open")

	pause_menu_opened.emit()
	print("[PauseMenu] Game paused")

func unpause() -> void:
	"""Unpauses the game and hides menu"""
	is_paused = false
	get_tree().paused = false
	visible = false

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_close")

	pause_menu_closed.emit()
	print("[PauseMenu] Game resumed")

# ============================================================================
# CHECKPOINT MANAGEMENT
# ============================================================================

func _update_checkpoint_buttons() -> void:
	"""Updates checkpoint button availability"""
	var has_checkpoint = WorldManager and WorldManager.last_checkpoint != ""

	load_checkpoint_button.disabled = not has_checkpoint
	save_checkpoint_button.disabled = not has_checkpoint

	if has_checkpoint:
		load_checkpoint_button.tooltip_text = "Letzter Checkpoint: %s" % WorldManager.last_checkpoint
		save_checkpoint_button.tooltip_text = "Letzter Checkpoint: %s" % WorldManager.last_checkpoint
	else:
		load_checkpoint_button.tooltip_text = "Kein Checkpoint verfügbar"
		save_checkpoint_button.tooltip_text = "Kein Checkpoint verfügbar"

# ============================================================================
# CHARACTER STATS
# ============================================================================

func _update_character_stats() -> void:
	"""Updates character stats display"""
	# Get player reference (P1)
	var player = _get_player()

	if not player:
		hp_label.text = "HP: --/--"
		mana_label.text = "Mana: --/--"
		_clear_buffs()
		return

	# Update HP
	var current_hp = player.get("current_hp") if "current_hp" in player else 0
	var max_hp = player.get("max_hp") if "max_hp" in player else 0
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]

	# Update Mana
	var current_mana = player.get("current_mana") if "current_mana" in player else 0
	var max_mana = player.get("max_mana") if "max_mana" in player else 0
	mana_label.text = "Mana: %d/%d" % [current_mana, max_mana]

	# Update buffs
	_update_buffs_display(player)

func _get_player() -> Node:
	"""Gets the player node (P1)"""
	# Try to find player in current scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _update_buffs_display(player: Node) -> void:
	"""Updates active buffs display"""
	_clear_buffs()

	# Check for active buffs/effects
	var buffs_found = false

	# Check for invincibility
	if "is_invincible" in player and player.is_invincible:
		_add_buff_label("Unverwundbar", Color.GOLD)
		buffs_found = true

	# Check for dash cooldown
	if "can_dash" in player and not player.can_dash:
		_add_buff_label("Dash Cooldown", Color.GRAY)
		buffs_found = true

	# Check for attacking state
	if "is_attacking" in player and player.is_attacking:
		_add_buff_label("Angriff", Color.RED)
		buffs_found = true

	# Check for blocking
	if "is_blocking" in player and player.is_blocking:
		_add_buff_label("Blocken", Color.STEEL_BLUE)
		buffs_found = true

	if not buffs_found:
		_add_buff_label("Keine aktiven Effekte", Color.GRAY)

func _add_buff_label(text: String, color: Color) -> void:
	"""Adds a buff label to the container"""
	var label = Label.new()
	label.text = "• " + text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	buffs_container.add_child(label)

func _clear_buffs() -> void:
	"""Clears all buff labels"""
	for child in buffs_container.get_children():
		child.queue_free()

# ============================================================================
# BUTTON HANDLERS - MAIN MENU
# ============================================================================

func _on_resume_pressed() -> void:
	"""Resumes the game"""
	print("[PauseMenu] Resume pressed")
	unpause()

func _on_load_checkpoint_pressed() -> void:
	"""Loads last checkpoint"""
	print("[PauseMenu] Load checkpoint pressed")

	if not WorldManager or WorldManager.last_checkpoint == "":
		push_warning("[PauseMenu] No checkpoint to load")
		return

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

	# Unpause first
	unpause()

	# Load from checkpoint (this will restore position and reload scene if needed)
	if SaveManager:
		SaveManager.load_current_game()
		print("[PauseMenu] Checkpoint loaded: %s" % WorldManager.last_checkpoint)

func _on_save_checkpoint_pressed() -> void:
	"""Saves to last checkpoint"""
	print("[PauseMenu] Save checkpoint pressed")

	if not WorldManager or WorldManager.last_checkpoint == "":
		push_warning("[PauseMenu] No checkpoint to save to")
		return

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

	# Save current game
	if SaveManager:
		SaveManager.save_current_game()
		print("[PauseMenu] Game saved to checkpoint: %s" % WorldManager.last_checkpoint)

	# Teleport player to checkpoint position
	var player = _get_player()
	if player and WorldManager.last_checkpoint_position != Vector2.ZERO:
		player.global_position = WorldManager.last_checkpoint_position
		print("[PauseMenu] Player teleported to checkpoint position: %s" % str(WorldManager.last_checkpoint_position))

	# Show brief feedback
	_show_save_feedback()

func _show_save_feedback() -> void:
	"""Shows visual feedback that game was saved"""
	# Create a temporary label
	var feedback = Label.new()
	feedback.text = "Gespeichert!"
	feedback.add_theme_font_size_override("font_size", 32)
	feedback.add_theme_color_override("font_color", Color.GREEN)
	feedback.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, 100)
	add_child(feedback)

	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(feedback, "modulate:a", 0.0, 1.0).set_delay(1.0)
	tween.tween_callback(feedback.queue_free)

func _on_character_pressed() -> void:
	"""Shows character stats screen"""
	print("[PauseMenu] Character pressed")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

	# Switch view
	current_view = "character"
	main_panel.visible = false
	character_panel.visible = true

	# Update stats
	_update_character_stats()

	# Focus back button
	character_back_button.grab_focus()

func _on_options_pressed() -> void:
	"""Shows options menu"""
	print("[PauseMenu] Options pressed")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_accept")

	# Switch view
	current_view = "options"
	main_panel.visible = false
	options_container.visible = true

	if options_menu_instance:
		options_menu_instance.visible = true

func _on_quit_pressed() -> void:
	"""Returns to main menu"""
	print("[PauseMenu] Quit pressed")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_back")

	# Unpause
	is_paused = false
	get_tree().paused = false

	# Save before quitting
	if SaveManager:
		SaveManager.save_current_game()

	# Return to main menu
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")

# ============================================================================
# BUTTON HANDLERS - SUBMENUS
# ============================================================================

func _on_character_back_pressed() -> void:
	"""Returns from character screen to main menu"""
	print("[PauseMenu] Character back pressed")

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("ui/menu_back")

	# Switch view
	current_view = "main"
	character_panel.visible = false
	main_panel.visible = true

	# Focus character button
	character_button.grab_focus()

func _on_options_back_pressed() -> void:
	"""Returns from options to main menu"""
	print("[PauseMenu] Options back pressed")

	# Switch view
	current_view = "main"
	options_container.visible = false

	if options_menu_instance:
		options_menu_instance.visible = false

	main_panel.visible = true

	# Focus options button
	options_button.grab_focus()
