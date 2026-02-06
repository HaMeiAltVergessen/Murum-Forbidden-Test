extends Node
## DialogManager - handles dialog playback, state, and nested dialog trees

enum States { IDLE, SHOWING_TEXT, WAITING_FOR_CHOICE, SHOWING_RESPONSE }

const DIALOG_PATH := "res://data/dialogs/"

var current_state: States = States.IDLE
var current_dialog: DialogData = null
var current_entry_index: int = 0
var current_entries: Array[DialogEntry] = []
var entry_stack: Array = []  # Stack of {entries, index} for nested dialog navigation

var dialog_ui: Node = null

var is_active: bool:
	get:
		return current_state != States.IDLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_dialog_ui()
	print("[DialogManager] Initialized")


func _setup_dialog_ui() -> void:
	var ui_scene := preload("res://systems/dialog/dialog_ui.tscn")
	dialog_ui = ui_scene.instantiate()
	dialog_ui.visible = false
	add_child(dialog_ui)

	dialog_ui.text_completed.connect(_on_text_completed)
	dialog_ui.choice_selected.connect(_on_choice_selected)
	dialog_ui.advance_requested.connect(_on_advance_requested)


func play_dialog(dialog_id: String) -> void:
	if current_state != States.IDLE:
		push_warning("DialogManager: Dialog already active, ignoring play_dialog call")
		return

	var path := DIALOG_PATH + dialog_id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("DialogManager: Dialog not found: " + path)
		return

	current_dialog = load(path) as DialogData
	if current_dialog == null or current_dialog.entries.is_empty():
		push_error("DialogManager: Invalid or empty dialog: " + dialog_id)
		return

	current_entries = current_dialog.entries
	current_entry_index = 0
	entry_stack.clear()
	_pause_game()
	_show_entry(current_entries[0])

	if EventBus:
		EventBus.dialog_started.emit(dialog_id)


func play_dialog_resource(dialog: DialogData) -> void:
	"""Play a dialog directly from a resource (no file lookup needed)"""
	if current_state != States.IDLE:
		push_warning("DialogManager: Dialog already active")
		return

	if dialog == null or dialog.entries.is_empty():
		push_error("DialogManager: Invalid or empty dialog resource")
		return

	current_dialog = dialog
	current_entries = dialog.entries
	current_entry_index = 0
	entry_stack.clear()
	_pause_game()
	_show_entry(current_entries[0])

	if EventBus:
		EventBus.dialog_started.emit(dialog.dialog_id)


func _show_entry(entry: DialogEntry) -> void:
	current_state = States.SHOWING_TEXT
	dialog_ui.visible = true
	print("[DialogManager] Showing entry: ", entry.speaker_name, " - ", entry.text.substr(0, 30), "...")
	dialog_ui.show_entry(entry)


func _advance_to_next_entry() -> void:
	current_entry_index += 1

	if current_entry_index >= current_entries.size():
		# Current level exhausted - pop from stack or end
		if not entry_stack.is_empty():
			var parent = entry_stack.pop_back()
			current_entries = parent.entries
			current_entry_index = parent.index
			_advance_to_next_entry()
		else:
			_end_dialog()
		return

	_show_entry(current_entries[current_entry_index])


func _show_choices(choices: Array[DialogChoice]) -> void:
	current_state = States.WAITING_FOR_CHOICE
	print("[DialogManager] Showing choices: ", choices.size())
	dialog_ui.show_choices(choices)


func _end_dialog() -> void:
	var dialog_id := current_dialog.dialog_id if current_dialog else ""

	current_state = States.IDLE
	current_dialog = null
	current_entries = []
	current_entry_index = 0
	entry_stack.clear()

	dialog_ui.hide_dialog()
	_resume_game()

	if EventBus:
		EventBus.dialog_finished.emit(dialog_id)


func _pause_game() -> void:
	get_tree().paused = true
	if EventBus:
		EventBus.game_paused.emit()


func _resume_game() -> void:
	get_tree().paused = false
	if EventBus:
		EventBus.game_unpaused.emit()


func _on_text_completed() -> void:
	var entry := current_entries[current_entry_index]

	if not entry.choices.is_empty():
		_show_choices(entry.choices)
	else:
		_advance_to_next_entry()


func _on_choice_selected(choice_index: int) -> void:
	print("[DialogManager] Choice selected: ", choice_index)
	if EventBus and current_dialog:
		EventBus.dialog_choice_selected.emit(current_dialog.dialog_id, choice_index)

	var entry := current_entries[current_entry_index]
	if choice_index >= entry.choices.size():
		_end_dialog()
		return

	var choice := entry.choices[choice_index]

	# Check if choice has next_entries (deeper dialog tree)
	if not choice.next_entries.is_empty():
		if not choice.response_text.is_empty():
			_show_response_then_continue(choice.response_speaker, choice.response_text, choice.next_entries)
		else:
			_enter_nested_entries(choice.next_entries)
		return

	# No nested entries - show response or end
	if not choice.response_text.is_empty():
		_show_response(choice.response_speaker, choice.response_text)
		return

	_end_dialog()


func _enter_nested_entries(entries: Array[DialogEntry]) -> void:
	"""Push current position to stack and enter nested entries"""
	entry_stack.push_back({
		"entries": current_entries,
		"index": current_entry_index + 1
	})
	current_entries = entries
	current_entry_index = 0
	_show_entry(current_entries[0])


var _pending_nested_entries: Array[DialogEntry] = []

func _show_response_then_continue(speaker: String, text: String, next: Array[DialogEntry]) -> void:
	"""Show a response, then continue into nested entries"""
	_pending_nested_entries = next
	current_state = States.SHOWING_RESPONSE
	dialog_ui.show_response(speaker, text)


func _show_response(speaker: String, text: String) -> void:
	_pending_nested_entries = []
	current_state = States.SHOWING_RESPONSE
	print("[DialogManager] Showing response: ", speaker, " - ", text.substr(0, 30), "...")
	dialog_ui.show_response(speaker, text)


func _on_advance_requested() -> void:
	if current_state == States.SHOWING_TEXT:
		if dialog_ui.is_text_fully_shown():
			_on_text_completed()
		else:
			dialog_ui.complete_text_immediately()
	elif current_state == States.SHOWING_RESPONSE:
		if dialog_ui.is_text_fully_shown():
			if not _pending_nested_entries.is_empty():
				var next = _pending_nested_entries
				_pending_nested_entries = []
				_enter_nested_entries(next)
			else:
				_end_dialog()
		else:
			dialog_ui.complete_text_immediately()
