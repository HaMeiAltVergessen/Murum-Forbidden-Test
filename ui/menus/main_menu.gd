extends Control
class_name MainMenu

# Node References
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

# Constants
const TEST_ROOM_PATH = "res://levels/test_room.tscn"
const WORLD_1_ENTRY_PATH = "res://worlds/world_1_ruins/rooms/room_01_entry.tscn"


func _ready():
	# Verstecke HUD im Hauptmenü
	if HUDManager:
		HUDManager.hide_all_hud()
		print("[MainMenu] HUD hidden")

	# Signals verbinden
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Setup Focus Navigation (Skip disabled buttons)
	_setup_focus_neighbors()

	# Initialen Fokus setzen
	if continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


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
	print("[MainMenu] Continue pressed - Loading Test Room")
	_start_game(TEST_ROOM_PATH)


func _on_new_game_pressed():
	print("[MainMenu] New Game pressed - Loading World 1 Entry")
	_start_game(WORLD_1_ENTRY_PATH)


func _start_game(scene_path: String):
	"""Zeigt HUD wieder an und lädt die Szene"""
	# HUD wieder anzeigen vor dem Szenenwechsel
	if HUDManager:
		HUDManager.show_all_hud()
		print("[MainMenu] HUD shown for gameplay")

	# Szene laden
	get_tree().change_scene_to_file(scene_path)


func _on_quit_pressed():
	print("[MainMenu] Quit pressed - Exiting game")
	get_tree().quit()
