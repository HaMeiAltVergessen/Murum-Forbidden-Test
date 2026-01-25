extends CanvasLayer
## Minimal DialogUI - displays text, speaker, sprite and choices

signal text_completed
signal choice_selected(choice_index: int)
signal advance_requested

@onready var blur_background: ColorRect = $BlurBackground
@onready var character_sprite: TextureRect = $CharacterSprite
@onready var dialog_box: Panel = $DialogBox
@onready var speaker_label: Label = $DialogBox/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $DialogBox/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $DialogBox/MarginContainer/VBoxContainer/ChoicesContainer

var current_entry: DialogEntry = null
var typewriter_timer: Timer = null
var is_typing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_setup_typewriter_timer()
	_clear_choices()


func _setup_typewriter_timer() -> void:
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = false
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(typewriter_timer)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		get_viewport().set_input_as_handled()
		advance_requested.emit()


func show_entry(entry: DialogEntry) -> void:
	current_entry = entry

	if entry.speaker_sprite:
		character_sprite.texture = entry.speaker_sprite
		character_sprite.visible = true
	else:
		character_sprite.visible = false

	if entry.speaker_name.is_empty():
		speaker_label.visible = false
	else:
		speaker_label.text = entry.speaker_name
		speaker_label.visible = true

	text_label.text = entry.text
	text_label.visible_characters = 0

	_clear_choices()
	_start_typewriter(entry.text_speed)


func _start_typewriter(chars_per_second: float) -> void:
	is_typing = true
	typewriter_timer.wait_time = 1.0 / chars_per_second
	typewriter_timer.start()


func _on_typewriter_tick() -> void:
	text_label.visible_characters += 1

	if text_label.visible_characters >= text_label.text.length():
		_stop_typewriter()
		text_completed.emit()


func _stop_typewriter() -> void:
	typewriter_timer.stop()
	is_typing = false


func complete_text_immediately() -> void:
	if is_typing:
		text_label.visible_characters = text_label.text.length()
		_stop_typewriter()
		text_completed.emit()


func show_choices(choices: Array[DialogChoice]) -> void:
	_clear_choices()

	for i in choices.size():
		var button := Button.new()
		button.text = choices[i].choice_text
		button.custom_minimum_size = Vector2(400, 40)
		button.pressed.connect(_on_choice_button_pressed.bind(i))
		choices_container.add_child(button)

	choices_container.visible = true

	if choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()


func _on_choice_button_pressed(index: int) -> void:
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
