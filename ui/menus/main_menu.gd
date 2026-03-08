extends Control
class_name MainMenu

# Node References
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var challenge_button: Button = %ChallengeButton
@onready var statistics_button: Button = %StatisticsButton
@onready var achievements_button: Button = %AchievementsButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var main_menu_container: Control = %MenuContainer
@onready var overwrite_dialog: ConfirmationDialog = %OverwriteDialog

# Options Menu
const OPTIONS_MENU_SCENE = preload("res://ui/menus/options_submenu.tscn")
const STATISTICS_SCENE = preload("res://ui/menus/statistics_screen.tscn")
const ACHIEVEMENTS_SCENE = preload("res://ui/menus/achievements_screen.tscn")
const CHALLENGE_RUN_MENU_SCENE = preload("res://ui/menus/challenge_run_menu.tscn")
var options_menu_instance: Control = null
var statistics_instance: Control = null
var achievements_instance: Control = null
var challenge_menu_instance: Node = null

# Constants
const TEST_ROOM_PATH = "res://levels/test_room.tscn"
const WORLD_1_ENTRY_PATH = "res://worlds/world_1_ruins/section_1_entrance/room_01_entry.tscn"
const LIMBUS_PATH = "res://worlds/limbus/limbus.tscn"
const MUSIC_FADE_DURATION = 1.0  # Sekunden


func _ready():
	print("[MainMenu] _ready() called")

	# Warte bis HUDManager seine HUDs geladen hat
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame für sicheres Timing

	# Verstecke HUD Autoload im Hauptmenü
	if has_node("/root/HUD"):
		var hud_autoload = get_node("/root/HUD")
		hud_autoload.visible = false
		print("[MainMenu] HUD Autoload hidden")

	# Verstecke HUDManager HUDs (inkl. p1_abilities)
	if HUDManager:
		HUDManager.hide_all_hud()
		print("[MainMenu] HUDManager HUDs hidden (including abilities)")

	# Verstecke PauseMenu im Hauptmenü (COMMIT 017: Pause Menu)
	if has_node("/root/PauseMenu"):
		var pause_menu = get_node("/root/PauseMenu")
		pause_menu.visible = false
		print("[MainMenu] PauseMenu hidden")

	# Starte Musik
	if music_player:
		music_player.play()
		print("[MainMenu] Music started")

	# Prüfe ob Save-Datei existiert (COMMIT 016: SaveManager Integration)
	var save_exists = SaveManager.has_save_file()
	continue_button.visible = save_exists
	print("[MainMenu] Save file exists: %s, Continue button visible: %s" % [save_exists, save_exists])

	# Challenge Run button - always visible
	challenge_button.visible = true

	# Signals verbinden mit Debug-Prints
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: Continue Button"))

	new_game_button.pressed.connect(_on_new_game_pressed)
	new_game_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: New Game Button"))

	challenge_button.pressed.connect(_on_challenge_pressed)
	statistics_button.pressed.connect(_on_statistics_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)

	options_button.pressed.connect(_on_options_pressed)
	options_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: Options Button"))

	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: Quit Button"))

	# Initialize Options Menu (create but keep hidden)
	_setup_options_menu()

	# Setup Overwrite Dialog (COMMIT 017: Save Overwrite Warning)
	_setup_overwrite_dialog()

	# Setup Focus Navigation (Skip disabled buttons)
	_setup_focus_neighbors()

	# Initialen Fokus setzen
	if save_exists and continue_button.visible:
		continue_button.grab_focus()
		print("[MainMenu] Focus set to Continue button")
	else:
		new_game_button.grab_focus()
		print("[MainMenu] Focus set to New Game button")

	print("[MainMenu] Initialization complete")


func _setup_focus_neighbors():
	"""Setzt Focus-Nachbarn für Keyboard/Controller Navigation mit Wrap-around"""
	# Erstelle Liste der aktiven Buttons (nicht disabled)
	var active_buttons: Array[Button] = []
	for btn in [continue_button, new_game_button, challenge_button, statistics_button, achievements_button, options_button, quit_button]:
		if btn.visible and not btn.disabled:
			active_buttons.append(btn)

	# Setze Focus-Nachbarn für Wrap-around Navigation
	for i in range(active_buttons.size()):
		var btn = active_buttons[i]
		var prev_index = (i - 1 + active_buttons.size()) % active_buttons.size()
		var next_index = (i + 1) % active_buttons.size()

		btn.focus_neighbor_top = btn.get_path_to(active_buttons[prev_index])
		btn.focus_neighbor_bottom = btn.get_path_to(active_buttons[next_index])
		btn.focus_previous = btn.get_path_to(active_buttons[prev_index])
		btn.focus_next = btn.get_path_to(active_buttons[next_index])


func _setup_options_menu():
	"""Creates and hides options menu instance (COMMIT 017: Options Menu)"""
	options_menu_instance = OPTIONS_MENU_SCENE.instantiate()
	add_child(options_menu_instance)
	options_menu_instance.visible = false

	# Connect back signal
	options_menu_instance.back_pressed.connect(_on_options_back_pressed)

	print("[MainMenu] Options menu initialized (hidden)")


func _setup_overwrite_dialog():
	"""Sets up the save overwrite confirmation dialog (COMMIT 017: Save Overwrite Warning)"""
	if overwrite_dialog:
		overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
		overwrite_dialog.canceled.connect(_on_overwrite_canceled)
		print("[MainMenu] Overwrite dialog initialized")


# Button Callbacks
func _on_continue_pressed():
	print("[MainMenu] ========== CONTINUE BUTTON PRESSED ==========")

	# Fade out music first
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, MUSIC_FADE_DURATION)
		tween.tween_callback(music_player.stop)
		print("[MainMenu] Music fading out...")
		await tween.finished

	# Show HUD before loading
	if has_node("/root/HUD"):
		var hud_autoload = get_node("/root/HUD")
		hud_autoload.visible = true
		print("[MainMenu] HUD Autoload shown")

	if HUDManager:
		HUDManager.show_all_hud()
		print("[MainMenu] HUDManager HUDs shown")

	# Load saved game (COMMIT 016: SaveManager Integration)
	# This will automatically transition to saved room via WorldManager
	var success = SaveManager.load_current_game()

	if not success:
		print("[MainMenu] Failed to load save, falling back to test room")
		get_tree().change_scene_to_file(TEST_ROOM_PATH)
		return

	print("[MainMenu] Save loaded successfully, WorldManager handling scene transition")


func _on_new_game_pressed():
	print("[MainMenu] ========== NEW GAME BUTTON PRESSED ==========")

	# Check if save exists - show warning dialog (COMMIT 017: Save Overwrite Warning)
	if SaveManager.has_save_file():
		print("[MainMenu] Save exists, showing overwrite dialog")
		overwrite_dialog.popup_centered()
		return

	# No save exists, start directly
	_start_new_game()


func _on_overwrite_confirmed():
	"""Called when user confirms overwriting save (COMMIT 017: Save Overwrite Warning)"""
	print("[MainMenu] User confirmed overwrite, starting new game")
	_start_new_game()


func _on_overwrite_canceled():
	"""Called when user cancels overwriting save (COMMIT 017: Save Overwrite Warning)"""
	print("[MainMenu] User canceled overwrite, returning to main menu")
	# Just close dialog, stays in main menu
	new_game_button.grab_focus()


func _start_new_game():
	"""Starts a new game (deletes old save if exists) (COMMIT 017: Save Overwrite Warning)"""
	# Delete old save if exists (fresh start)
	if SaveManager.has_save_file():
		SaveManager.delete_current_save()
		print("[MainMenu] Old save deleted for fresh start")

	# Set WorldManager to Limbus
	if WorldManager:
		WorldManager.current_world = "limbus"
		WorldManager.current_room = "limbus"
		print("[MainMenu] WorldManager preset to limbus")

	# Reset RunManager for fresh start
	if RunManager:
		RunManager.magicka = 0
		RunManager.max_lives = RunManager.BASE_LIVES
		RunManager.current_state = RunManager.RunState.IDLE

	# Create new save file with correct room data
	SaveManager.create_new_save()
	print("[MainMenu] New save created")

	# HUD Autoload wieder anzeigen
	if has_node("/root/HUD"):
		var hud_autoload = get_node("/root/HUD")
		hud_autoload.visible = true
		print("[MainMenu] HUD Autoload shown")

	# HUDManager HUDs wieder anzeigen
	if HUDManager:
		HUDManager.show_all_hud()
		print("[MainMenu] HUDManager HUDs shown")

	# Musik fade-out
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, MUSIC_FADE_DURATION)
		tween.tween_callback(music_player.stop)
		print("[MainMenu] Music fading out...")

	# Load Limbus hub directly
	print("[MainMenu] Loading Limbus hub")
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().change_scene_to_file(LIMBUS_PATH)


func _start_game(scene_path: String):
	"""Zeigt HUD wieder an und lädt die Szene mit Musik-Fade-Out"""
	print("[MainMenu] Starting game, loading scene: ", scene_path)

	# Musik fade-out
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, MUSIC_FADE_DURATION)
		tween.tween_callback(music_player.stop)
		print("[MainMenu] Music fading out...")
		await tween.finished

	# HUD Autoload wieder anzeigen
	if has_node("/root/HUD"):
		var hud_autoload = get_node("/root/HUD")
		hud_autoload.visible = true
		print("[MainMenu] HUD Autoload shown")

	# HUDManager HUDs wieder anzeigen
	if HUDManager:
		HUDManager.show_all_hud()
		print("[MainMenu] HUDManager HUDs shown")

	# Szene laden
	print("[MainMenu] Calling change_scene_to_file...")
	get_tree().change_scene_to_file(scene_path)


func _on_options_pressed():
	"""Shows options menu (COMMIT 017: Options Menu)"""
	print("[MainMenu] ========== OPTIONS BUTTON PRESSED ==========")

	# Hide main menu buttons
	if main_menu_container:
		main_menu_container.visible = false

	# Show options menu
	if options_menu_instance:
		options_menu_instance.visible = true
		print("[MainMenu] Options menu shown")


func _on_options_back_pressed():
	"""Returns from options menu to main menu (COMMIT 017: Options Menu)"""
	print("[MainMenu] ========== RETURNING FROM OPTIONS ==========")

	# Hide options menu
	if options_menu_instance:
		options_menu_instance.visible = false

	# Show main menu buttons
	if main_menu_container:
		main_menu_container.visible = true

	# Restore focus
	var save_exists = SaveManager.has_save_file()
	if save_exists and continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

	print("[MainMenu] Returned to main menu")


func _on_quit_pressed():
	print("[MainMenu] ========== QUIT BUTTON PRESSED ==========")
	get_tree().quit()


# ============================================================================
# STATISTICS, ACHIEVEMENTS & CHALLENGE RUN
# ============================================================================

func _on_statistics_pressed():
	"""Shows statistics screen"""
	print("[MainMenu] ========== STATISTICS BUTTON PRESSED ==========")

	if main_menu_container:
		main_menu_container.visible = false

	if statistics_instance:
		statistics_instance.queue_free()

	statistics_instance = STATISTICS_SCENE.instantiate()
	add_child(statistics_instance)
	statistics_instance.back_pressed.connect(_on_statistics_back_pressed)

	if statistics_instance.has_method("update_statistics"):
		statistics_instance.update_statistics()


func _on_statistics_back_pressed():
	"""Returns from statistics to main menu"""
	print("[MainMenu] ========== RETURNING FROM STATISTICS ==========")

	if statistics_instance:
		statistics_instance.queue_free()
		statistics_instance = null

	if main_menu_container:
		main_menu_container.visible = true

	_restore_focus()


func _on_achievements_pressed():
	"""Shows achievements screen"""
	print("[MainMenu] ========== ACHIEVEMENTS BUTTON PRESSED ==========")

	if main_menu_container:
		main_menu_container.visible = false

	if achievements_instance:
		achievements_instance.queue_free()

	achievements_instance = ACHIEVEMENTS_SCENE.instantiate()
	add_child(achievements_instance)
	achievements_instance.back_pressed.connect(_on_achievements_back_pressed)

	if achievements_instance.has_method("populate_achievements"):
		achievements_instance.populate_achievements()


func _on_achievements_back_pressed():
	"""Returns from achievements to main menu"""
	print("[MainMenu] ========== RETURNING FROM ACHIEVEMENTS ==========")

	if achievements_instance:
		achievements_instance.queue_free()
		achievements_instance = null

	if main_menu_container:
		main_menu_container.visible = true

	_restore_focus()


func _on_challenge_pressed():
	"""Shows challenge run modifier menu"""
	print("[MainMenu] ========== CHALLENGE BUTTON PRESSED ==========")

	if main_menu_container:
		main_menu_container.visible = false

	if challenge_menu_instance:
		challenge_menu_instance.queue_free()

	challenge_menu_instance = CHALLENGE_RUN_MENU_SCENE.instantiate()
	add_child(challenge_menu_instance)
	challenge_menu_instance.back_pressed.connect(_on_challenge_back_pressed)
	challenge_menu_instance.challenge_started.connect(_on_challenge_started)


func _on_challenge_back_pressed():
	"""Returns from challenge menu to main menu"""
	print("[MainMenu] ========== RETURNING FROM CHALLENGE MENU ==========")

	# Reset seals when leaving from main menu context
	ChallengeRunManager._reset_modifiers()

	if challenge_menu_instance:
		challenge_menu_instance.queue_free()
		challenge_menu_instance = null

	if main_menu_container:
		main_menu_container.visible = true

	_restore_focus()


func _on_challenge_started():
	"""Called when challenge run starts from challenge menu"""
	print("[MainMenu] ========== CHALLENGE RUN STARTING ==========")

	if challenge_menu_instance:
		challenge_menu_instance.queue_free()
		challenge_menu_instance = null

	# Start new game with challenge modifiers active
	_start_new_game()


func _restore_focus():
	"""Restores focus to appropriate button"""
	var save_exists = SaveManager.has_save_file()
	if save_exists and continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()
