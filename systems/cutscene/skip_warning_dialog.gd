# skip_warning_dialog.gd
# Dialog zur Bestätigung des Überspringens von wichtigen Cutscenes
# Verhindert versehentliches Überspringen von Story-relevanten Szenen

extends CanvasLayer

## Signals
signal skip_confirmed()
signal skip_cancelled()

## Konstanten
const FADE_DURATION: float = 0.2
const HOLD_DURATION: float = 1.5  # Zeit die Skip-Taste gehalten werden muss

## Texte (können lokalisiert werden)
var _title_text: String = "Cutscene überspringen?"
var _message_text: String = "Diese Szene enthält wichtige Story-Elemente.\nMöchtest du sie wirklich überspringen?"
var _confirm_text: String = "Ja, überspringen"
var _cancel_text: String = "Nein, weiterschauen"
var _hold_text: String = "Gedrückt halten zum Überspringen"

## State
var _is_visible: bool = false
var _hold_progress: float = 0.0
var _is_holding: bool = false
var _use_hold_mode: bool = false  # Alternative: Halten statt Button

## UI Nodes
var _root_container: Control  # Root container für Fade-Effekt
var _panel: PanelContainer
var _title_label: Label
var _message_label: Label
var _button_container: HBoxContainer
var _confirm_button: Button
var _cancel_button: Button
var _hold_progress_bar: ProgressBar
var _hold_label: Label

## Tweens
var _fade_tween: Tween = null


func _ready() -> void:
	layer = 110  # Über allem
	_setup_ui()
	visible = false


func _process(delta: float) -> void:
	if not _is_visible or not _use_hold_mode:
		return

	# Hold-to-Skip Logik
	if _is_holding:
		_hold_progress += delta
		_hold_progress_bar.value = (_hold_progress / HOLD_DURATION) * 100.0

		if _hold_progress >= HOLD_DURATION:
			_on_skip_confirmed()
	else:
		_hold_progress = maxf(0.0, _hold_progress - delta * 2.0)  # Schneller zurücksetzen
		_hold_progress_bar.value = (_hold_progress / HOLD_DURATION) * 100.0


func _input(event: InputEvent) -> void:
	if not _is_visible:
		return

	# Hold-to-Skip Input
	if _use_hold_mode:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("p1_interact"):
			_is_holding = true
		elif event.is_action_released("ui_accept") or event.is_action_released("p1_interact"):
			_is_holding = false

	# Escape zum Abbrechen
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_skip_cancelled()
		get_viewport().set_input_as_handled()


## Erstellt die UI-Struktur
func _setup_ui() -> void:
	# Root Container für Fade-Effekt (CanvasLayer hat kein modulate)
	_root_container = Control.new()
	_root_container.name = "RootContainer"
	_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_container)

	# Dunkler Hintergrund
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_container.add_child(bg)

	# Zentrierender Container
	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_container.add_child(center)

	# Panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(500, 200)

	# Panel Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	# VBox für Content
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(vbox)

	# Titel
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = _title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(_title_label)

	# Nachricht
	_message_label = Label.new()
	_message_label.name = "Message"
	_message_label.text = _message_text
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_message_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Button Container (für Button-Modus)
	_button_container = HBoxContainer.new()
	_button_container.name = "Buttons"
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 20)
	vbox.add_child(_button_container)

	# Confirm Button
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = _confirm_text
	_confirm_button.custom_minimum_size = Vector2(180, 45)
	_confirm_button.pressed.connect(_on_skip_confirmed)
	_button_container.add_child(_confirm_button)

	# Cancel Button
	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = _cancel_text
	_cancel_button.custom_minimum_size = Vector2(180, 45)
	_cancel_button.pressed.connect(_on_skip_cancelled)
	_button_container.add_child(_cancel_button)

	# Hold Label (für Hold-Modus)
	_hold_label = Label.new()
	_hold_label.name = "HoldLabel"
	_hold_label.text = _hold_text
	_hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_label.add_theme_font_size_override("font_size", 16)
	_hold_label.visible = false
	vbox.add_child(_hold_label)

	# Hold Progress Bar (für Hold-Modus)
	_hold_progress_bar = ProgressBar.new()
	_hold_progress_bar.name = "HoldProgress"
	_hold_progress_bar.custom_minimum_size = Vector2(300, 20)
	_hold_progress_bar.value = 0
	_hold_progress_bar.show_percentage = false
	_hold_progress_bar.visible = false
	vbox.add_child(_hold_progress_bar)

	# Initial modulate für Fade
	_root_container.modulate.a = 0.0


## Zeigt den Dialog an
func show_dialog(use_hold_mode: bool = false) -> void:
	_use_hold_mode = use_hold_mode
	_hold_progress = 0.0
	_is_holding = false

	# Wechsle zwischen Modi
	_button_container.visible = not use_hold_mode
	_hold_label.visible = use_hold_mode
	_hold_progress_bar.visible = use_hold_mode
	_hold_progress_bar.value = 0

	# Zeige Dialog
	visible = true
	_is_visible = true
	set_process(true)

	# Fade In
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_root_container, "modulate:a", 1.0, FADE_DURATION)

	# Focus auf Cancel Button (sicherer Default)
	if not use_hold_mode:
		_cancel_button.grab_focus()


## Versteckt den Dialog
func hide_dialog() -> void:
	_is_visible = false
	_is_holding = false
	set_process(false)

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_root_container, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func(): visible = false)


## Skip bestätigt
func _on_skip_confirmed() -> void:
	hide_dialog()
	skip_confirmed.emit()


## Skip abgebrochen
func _on_skip_cancelled() -> void:
	hide_dialog()
	skip_cancelled.emit()


## Setzt die Texte (für Lokalisierung)
func set_texts(title: String, message: String, confirm: String, cancel: String, hold: String = "") -> void:
	_title_text = title
	_message_text = message
	_confirm_text = confirm
	_cancel_text = cancel
	if not hold.is_empty():
		_hold_text = hold

	if _title_label:
		_title_label.text = title
	if _message_label:
		_message_label.text = message
	if _confirm_button:
		_confirm_button.text = confirm
	if _cancel_button:
		_cancel_button.text = cancel
	if _hold_label:
		_hold_label.text = _hold_text


## Gibt zurück ob der Dialog sichtbar ist
func is_showing() -> bool:
	return _is_visible
