extends Control
class_name MainMenu

# Node References
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer

# Constants
const TEST_ROOM_PATH = "res://levels/test_room.tscn"
const WORLD_1_ENTRY_PATH = "res://worlds/world_1_ruins/rooms/room_01_entry.tscn"
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

	# Starte Musik
	if music_player:
		music_player.play()
		print("[MainMenu] Music started")

	# Signals verbinden mit Debug-Prints
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: Continue Button"))

	new_game_button.pressed.connect(_on_new_game_pressed)
	new_game_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: New Game Button"))

	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.mouse_entered.connect(func(): print("[MainMenu DEBUG] Mouse entered: Quit Button"))

	# Setup Focus Navigation (Skip disabled buttons)
	_setup_focus_neighbors()

	# Initialen Fokus setzen
	if continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

	print("[MainMenu] Initialization complete")


func _setup_focus_neighbors():
	"""Setzt Focus-Nachbarn für Keyboard/Controller Navigation mit Wrap-around"""
	# Erstelle Liste der aktiven Buttons (nicht disabled)
	var active_buttons: Array[Button] = []
	for btn in [continue_button, new_game_button, options_button, quit_button]:
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


# Button Callbacks
func _on_continue_pressed():
	print("[MainMenu] ========== CONTINUE BUTTON PRESSED ==========")
	_start_game(TEST_ROOM_PATH)


func _on_new_game_pressed():
	print("[MainMenu] ========== NEW GAME BUTTON PRESSED ==========")
	_start_game(WORLD_1_ENTRY_PATH)


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


func _on_quit_pressed():
	print("[MainMenu] ========== QUIT BUTTON PRESSED ==========")
	get_tree().quit()
