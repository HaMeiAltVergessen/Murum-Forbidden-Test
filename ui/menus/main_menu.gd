extends Control
class_name MainMenu

# Node References
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var challenge_button: Button = %ChallengeButton
@onready var statistics_button: Button = %StatisticsButton
@onready var achievements_button: Button = %AchievementsButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var main_menu_container: Control = %MenuContainer

# Sub-screens
const OPTIONS_MENU_SCENE = preload("res://ui/menus/options_submenu.tscn")
const STATISTICS_SCENE = preload("res://ui/menus/statistics_screen.tscn")
const ACHIEVEMENTS_SCENE = preload("res://ui/menus/achievements_screen.tscn")
const CHALLENGE_RUN_MENU_SCENE = preload("res://ui/menus/challenge_run_menu.tscn")
const SAVE_SLOT_SCREEN_SCENE = preload("res://ui/menus/save_slot_screen.tscn")
var options_menu_instance: Control = null
var statistics_instance: Control = null
var achievements_instance: Control = null
var challenge_menu_instance: Node = null
var save_slot_instance: Control = null

# Constants
const TEST_ROOM_PATH = "res://levels/test_room.tscn"
const WORLD_1_ENTRY_PATH = "res://worlds/world_1_ruins/section_1_entrance/room_01_entry.tscn"
const LIMBUS_PATH = "res://worlds/limbus/limbus.tscn"
const INTRO_PATH = "res://worlds/intro/weg_zum_limbus.tscn"
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

	# Check save state for button visibility
	var has_continue = SaveManager.get_last_saved_slot() > 0
	var has_any_save = SaveManager.has_any_save()
	continue_button.visible = has_continue
	load_game_button.visible = has_any_save
	challenge_button.visible = true

	# Connect signals
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	statistics_button.pressed.connect(_on_statistics_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Initialize Options Menu (create but keep hidden)
	_setup_options_menu()

	# Setup Focus Navigation (Skip disabled buttons)
	_setup_focus_neighbors()

	# Initial focus
	if has_continue and continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

	print("[MainMenu] Initialization complete")


func _setup_focus_neighbors():
	"""Setzt Focus-Nachbarn für Keyboard/Controller Navigation mit Wrap-around"""
	# Erstelle Liste der aktiven Buttons (nicht disabled)
	var active_buttons: Array[Button] = []
	for btn in [continue_button, new_game_button, load_game_button, challenge_button, statistics_button, achievements_button, options_button, quit_button]:
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


# Button Callbacks
func _on_continue_pressed():
	"""Loads the last saved slot directly"""
	print("[MainMenu] ========== CONTINUE BUTTON PRESSED ==========")

	var slot = SaveManager.get_last_saved_slot()
	if slot < 1:
		push_warning("[MainMenu] No last saved slot found")
		return

	_load_slot(slot)


func _on_new_game_pressed():
	"""Opens save slot screen in NEW_GAME mode"""
	print("[MainMenu] ========== NEW GAME BUTTON PRESSED ==========")
	_show_save_slot_screen(0)  # Mode.NEW_GAME


func _on_load_game_pressed():
	"""Opens save slot screen in LOAD_GAME mode"""
	print("[MainMenu] ========== LOAD GAME BUTTON PRESSED ==========")
	_show_save_slot_screen(1)  # Mode.LOAD_GAME


func _show_save_slot_screen(mode: int) -> void:
	if main_menu_container:
		main_menu_container.visible = false

	if save_slot_instance:
		save_slot_instance.queue_free()

	save_slot_instance = SAVE_SLOT_SCREEN_SCENE.instantiate()
	add_child(save_slot_instance)

	# Setup mode after adding to tree
	save_slot_instance.setup(mode)

	save_slot_instance.slot_selected.connect(func(slot_index: int):
		if mode == 0:  # NEW_GAME
			_start_new_game_in_slot(slot_index)
		else:  # LOAD_GAME
			_load_slot(slot_index)
	)
	save_slot_instance.back_pressed.connect(_on_save_slot_back)


func _on_save_slot_back() -> void:
	if save_slot_instance:
		save_slot_instance.queue_free()
		save_slot_instance = null

	if main_menu_container:
		main_menu_container.visible = true

	_restore_focus()


func _load_slot(slot_index: int) -> void:
	"""Loads an existing save slot"""
	print("[MainMenu] Loading slot %d" % slot_index)

	# Fade music
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, MUSIC_FADE_DURATION)
		tween.tween_callback(music_player.stop)
		await tween.finished

	_show_hud()

	var success = SaveManager.load_game(slot_index)
	if not success:
		push_warning("[MainMenu] Failed to load slot %d" % slot_index)
		get_tree().change_scene_to_file(TEST_ROOM_PATH)


func _start_new_game_in_slot(slot_index: int) -> void:
	"""Starts a new game in the selected slot"""
	print("[MainMenu] Starting new game in slot %d" % slot_index)

	# Delete old save in this slot if exists
	if SaveManager.slot_exists(slot_index):
		SaveManager.delete_save(slot_index)

	# Set active slot (but don't save yet — save happens when reaching Limbus)
	SaveManager.set_current_slot(slot_index)

	# Reset all managers for fresh start
	if WorldManager:
		WorldManager.current_world = "limbus"
		WorldManager.current_room = "limbus"

	if RunManager:
		RunManager.magicka = 0
		RunManager.max_lives = RunManager.BASE_LIVES
		RunManager.current_state = RunManager.RunState.IDLE

	if UpgradeManager:
		UpgradeManager.reset_all()

	# Fade music
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, MUSIC_FADE_DURATION)
		tween.tween_callback(music_player.stop)

	# Play intro cutscene first, then load Weg zum Limbus
	if CutsceneManager and CutsceneManager.has_cutscene("intro"):
		print("[MainMenu] Playing intro cutscene...")
		CutsceneManager.play_cutscene("intro", _on_intro_cutscene_finished)
	else:
		print("[MainMenu] No intro cutscene found, skipping to gameplay")
		_load_weg_zum_limbus()


func _on_intro_cutscene_finished(_cutscene_id: String, _was_skipped: bool) -> void:
	"""Called when intro cutscene finishes (or is skipped)"""
	print("[MainMenu] Intro cutscene finished (skipped: %s)" % _was_skipped)
	_load_weg_zum_limbus()


func _load_weg_zum_limbus() -> void:
	"""Loads the Weg zum Limbus intro sequence"""
	_show_hud()
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().change_scene_to_file(INTRO_PATH)


func _show_hud() -> void:
	if has_node("/root/HUD"):
		get_node("/root/HUD").visible = true
	if HUDManager:
		HUDManager.show_all_hud()


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

	_restore_focus()
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

	# Open slot screen for challenge run (same as new game)
	_show_save_slot_screen(0)  # Mode.NEW_GAME


func _restore_focus():
	"""Restores focus to appropriate button"""
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()
