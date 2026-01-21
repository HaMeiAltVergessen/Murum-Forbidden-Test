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

# State
var focused_button_index: int = 0
var buttons: Array[Button] = []


func _ready():
	# Button-Array aufbauen
	buttons = [continue_button, new_game_button, options_button, quit_button]

	# Signals verbinden
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Fokus setzen
	if continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _unhandled_input(event: InputEvent):
	# Navigation Down
	if event.is_action_pressed("ui_down"):
		_focus_next_button(1)  # +1 = vorwärts
		get_viewport().set_input_as_handled()

	# Navigation Up
	elif event.is_action_pressed("ui_up"):
		_focus_next_button(-1)  # -1 = rückwärts
		get_viewport().set_input_as_handled()

	# Bestätigen (Enter/Space/A-Button)
	elif event.is_action_pressed("ui_accept"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.emit_signal("pressed")
		get_viewport().set_input_as_handled()


func _focus_next_button(direction: int):
	var start_index = focused_button_index

	# Loop bis gültiger Button gefunden
	for i in range(buttons.size()):
		focused_button_index = (focused_button_index + direction) % buttons.size()

		# Negativ-Wrap-around fix
		if focused_button_index < 0:
			focused_button_index = buttons.size() - 1

		var btn = buttons[focused_button_index]

		# Überspringe disabled/invisible
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			return

	# Fallback: Bleibe bei aktuellem Button
	focused_button_index = start_index


# Button Callbacks
func _on_continue_pressed():
	print("[MainMenu] Continue pressed - Loading Test Room")
	get_tree().change_scene_to_file(TEST_ROOM_PATH)


func _on_new_game_pressed():
	print("[MainMenu] New Game pressed - Loading World 1 Entry")
	get_tree().change_scene_to_file(WORLD_1_ENTRY_PATH)


func _on_quit_pressed():
	print("[MainMenu] Quit pressed - Exiting game")
	get_tree().quit()
