extends CanvasLayer
## Minimal DialogUI - displays text, speaker, sprite and choices

signal text_completed
signal choice_selected(choice_index: int)
signal advance_requested

@onready var blur_background: ColorRect = $BlurBackground
@onready var character_sprite: TextureRect = $CharacterSprite
@onready var dialog_box: PanelContainer = $DialogBox
@onready var speaker_label: Label = $DialogBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $DialogBox/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $DialogBox/MarginContainer/VBoxContainer/ChoicesContainer

var current_entry: DialogEntry = null
var typewriter_timer: Timer = null
var is_typing: bool = false
var current_char_index: int = 0
var full_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# Ensure all UI elements can process during pause
	blur_background.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_box.process_mode = Node.PROCESS_MODE_ALWAYS
	choices_container.process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_typewriter_timer()
	_clear_choices()
	print("[DialogUI] Initialized - layer: ", layer)


func _setup_typewriter_timer() -> void:
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = false
	typewriter_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(typewriter_timer)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Only handle dialog-specific inputs
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("p1_interact"):
		get_viewport().set_input_as_handled()
		advance_requested.emit()
		return

	# Also accept left mouse click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		advance_requested.emit()


func show_entry(entry: DialogEntry) -> void:
	current_entry = entry
	print("[DialogUI] show_entry called - speaker: ", entry.speaker_name)

	# Character sprite
	if entry.speaker_sprite:
		character_sprite.texture = entry.speaker_sprite
		character_sprite.visible = true
	else:
		character_sprite.visible = false

	# Speaker name
	if entry.speaker_name.is_empty():
		speaker_label.visible = false
	else:
		speaker_label.text = entry.speaker_name
		speaker_label.visible = true

	# Setup text for typewriter
	full_text = entry.text
	current_char_index = 0
	text_label.text = ""

	_clear_choices()
	_start_typewriter(entry.text_speed)


func _start_typewriter(chars_per_second: float) -> void:
	is_typing = true
	typewriter_timer.wait_time = 1.0 / chars_per_second
	typewriter_timer.start()
	print("[DialogUI] Typewriter started - speed: ", chars_per_second)


func _on_typewriter_tick() -> void:
	if current_char_index < full_text.length():
		current_char_index += 1
		text_label.text = full_text.substr(0, current_char_index)

	if current_char_index >= full_text.length():
		_stop_typewriter()


func _stop_typewriter() -> void:
	typewriter_timer.stop()
	is_typing = false
	text_label.text = full_text
	print("[DialogUI] Typewriter stopped - text complete")


func complete_text_immediately() -> void:
	if is_typing:
		current_char_index = full_text.length()
		text_label.text = full_text
		_stop_typewriter()


func is_text_fully_shown() -> bool:
	return not is_typing and current_char_index >= full_text.length()


func show_choices(choices: Array[DialogChoice]) -> void:
	_clear_choices()
	print("[DialogUI] Showing ", choices.size(), " choices")

	for i in choices.size():
		var button := Button.new()
		button.text = choices[i].choice_text
		button.custom_minimum_size = Vector2(400, 50)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_choice_button_pressed.bind(i))
		choices_container.add_child(button)
		print("[DialogUI] Created choice button: ", choices[i].choice_text)

	choices_container.visible = true

	# Focus first button after frame
	await get_tree().process_frame
	if choices_container.get_child_count() > 0:
		var first_button = choices_container.get_child(0)
		first_button.grab_focus()
		print("[DialogUI] Focused first choice button")


func _on_choice_button_pressed(index: int) -> void:
	print("[DialogUI] Choice button pressed: ", index)
	choice_selected.emit(index)


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.visible = false


func hide_dialog() -> void:
	visible = false
	_stop_typewriter()
	_clear_choices()
	character_sprite.visible = false
	print("[DialogUI] Dialog hidden")
