extends Control

## FeedbackScreen - Allows players to write and save feedback

const FEEDBACK_DIR = "user://feedback/"

@onready var feedback_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/FeedbackLabel
@onready var text_edit: TextEdit = $CenterContainer/Panel/MarginContainer/VBoxContainer/TextEdit
@onready var save_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

signal feedback_closed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	# Ensure feedback directory exists
	_ensure_feedback_dir()

	# Focus text edit
	text_edit.grab_focus()

	print("[FeedbackScreen] Initialized")


func _ensure_feedback_dir() -> void:
	"""Creates the feedback directory if it doesn't exist"""
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("feedback"):
			dir.make_dir("feedback")
			print("[FeedbackScreen] Created feedback directory")


func _get_next_feedback_number() -> int:
	"""Returns the next available feedback number"""
	var dir = DirAccess.open(FEEDBACK_DIR)
	if not dir:
		return 1

	var highest_number = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with("feedback_") and file_name.ends_with(".txt"):
			# Extract number from filename (feedback_0001.txt -> 1)
			var number_str = file_name.replace("feedback_", "").replace(".txt", "")
			var number = number_str.to_int()
			if number > highest_number:
				highest_number = number
		file_name = dir.get_next()

	dir.list_dir_end()
	return highest_number + 1


func _on_save_pressed() -> void:
	"""Saves the feedback to a file"""
	var feedback_text = text_edit.text.strip_edges()

	if feedback_text.is_empty():
		print("[FeedbackScreen] No feedback to save (empty)")
		_show_notification("Bitte schreibe etwas Feedback!")
		return

	# Get next feedback number
	var feedback_number = _get_next_feedback_number()
	var filename = "feedback_%04d.txt" % feedback_number
	var filepath = FEEDBACK_DIR + filename

	# Save feedback
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		# Add timestamp header
		var datetime = Time.get_datetime_dict_from_system()
		var timestamp = "%04d-%02d-%02d %02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]

		file.store_line("=== Feedback #%04d ===" % feedback_number)
		file.store_line("Datum: %s" % timestamp)
		file.store_line("========================")
		file.store_line("")
		file.store_line(feedback_text)
		file.close()

		print("[FeedbackScreen] Feedback saved: %s" % filepath)
		_show_notification("Feedback gespeichert! Danke!")

		# Clear text and close
		text_edit.text = ""
		await get_tree().create_timer(1.0).timeout
		_close()
	else:
		push_error("[FeedbackScreen] Failed to save feedback!")
		_show_notification("Fehler beim Speichern!")


func _on_cancel_pressed() -> void:
	"""Closes without saving"""
	print("[FeedbackScreen] Cancelled - not saving")
	_close()


func _close() -> void:
	"""Closes the feedback screen"""
	feedback_closed.emit()
	queue_free()


func _show_notification(text: String) -> void:
	"""Shows a brief notification"""
	if EventBus:
		EventBus.show_notification.emit(text, 2.0)
