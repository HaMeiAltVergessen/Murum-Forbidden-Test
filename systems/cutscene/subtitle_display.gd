# subtitle_display.gd
# Untertitel-Anzeige für das Cutscene-System
# Zeigt Untertitel mit Fade-Animationen und Sprecher-Unterstützung

extends CanvasLayer

## Signals
signal subtitle_shown(text: String, speaker: String)
signal subtitle_hidden()
signal all_subtitles_finished()

## Untertitel-Größen-Enum
enum SubtitleSize { SMALL, MEDIUM, LARGE }

## Konstanten
const FADE_DURATION_DEFAULT: float = 0.3
const MARGIN_BOTTOM: int = 50
const PADDING_HORIZONTAL: int = 40
const PADDING_VERTICAL: int = 15
const MAX_WIDTH_RATIO: float = 0.8  # 80% der Bildschirmbreite

## Sprecher-Farben (können über Settings angepasst werden)
var speaker_colors: Dictionary = {
	"Murum": Color(0.4, 0.8, 1.0),      # Cyan für Protagonist
	"Umbra": Color(0.6, 0.3, 0.8),       # Lila für Umbra
	"???": Color(0.7, 0.7, 0.7),         # Grau für Unbekannt
	"System": Color(1.0, 0.9, 0.4),      # Gelb für System-Nachrichten
	"default": Color.WHITE
}

## Font-Größen für verschiedene Einstellungen
var font_sizes: Dictionary = {
	SubtitleSize.SMALL: 18,
	SubtitleSize.MEDIUM: 24,
	SubtitleSize.LARGE: 32
}

## State
var _current_subtitle: CutsceneResources.SubtitleEntry = null
var _subtitle_data: CutsceneResources.SubtitleData = null
var _current_time: float = 0.0
var _is_playing: bool = false
var _processed_entries: Array[int] = []  # Indices der bereits gezeigten Untertitel

## Settings
var _subtitles_enabled: bool = true
var _subtitle_size: SubtitleSize = SubtitleSize.MEDIUM
var _fade_duration: float = FADE_DURATION_DEFAULT

## UI Nodes
var _container: MarginContainer
var _background: ColorRect
var _vbox: VBoxContainer
var _speaker_label: Label
var _subtitle_label: RichTextLabel
var _current_tween: Tween = null


func _ready() -> void:
	layer = 100  # Über allem anderen
	_setup_ui()
	_apply_settings()
	hide_subtitle_immediate()


func _process(delta: float) -> void:
	if not _is_playing or not _subtitle_data:
		return

	_current_time += delta
	_check_for_new_subtitle()


## Erstellt die UI-Struktur
func _setup_ui() -> void:
	# Container mit Margin am unteren Rand
	_container = MarginContainer.new()
	_container.name = "SubtitleContainer"
	_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_container.anchor_top = 1.0
	_container.anchor_bottom = 1.0
	_container.offset_top = -150
	_container.offset_bottom = -MARGIN_BOTTOM
	_container.offset_left = 50
	_container.offset_right = -50
	add_child(_container)

	# Zentrierender Container
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_child(center_container)

	# Panel-Container für Hintergrund
	var panel_container = PanelContainer.new()
	panel_container.name = "PanelContainer"

	# Erstelle StyleBox für halbtransparenten Hintergrund
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = PADDING_HORIZONTAL
	style.content_margin_right = PADDING_HORIZONTAL
	style.content_margin_top = PADDING_VERTICAL
	style.content_margin_bottom = PADDING_VERTICAL
	panel_container.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel_container)

	# VBox für Sprecher + Text
	_vbox = VBoxContainer.new()
	_vbox.name = "VBoxContainer"
	_vbox.add_theme_constant_override("separation", 5)
	panel_container.add_child(_vbox)

	# Sprecher-Label
	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.add_theme_font_size_override("font_size", 16)
	_speaker_label.visible = false
	_vbox.add_child(_speaker_label)

	# Untertitel-Label (RichTextLabel für Formatierung)
	_subtitle_label = RichTextLabel.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.bbcode_enabled = true
	_subtitle_label.fit_content = true
	_subtitle_label.scroll_active = false
	_subtitle_label.custom_minimum_size = Vector2(200, 0)
	_subtitle_label.add_theme_font_size_override("normal_font_size", font_sizes[_subtitle_size])

	# Berechne maximale Breite
	var viewport_size = get_viewport().get_visible_rect().size
	_subtitle_label.custom_minimum_size.x = min(viewport_size.x * MAX_WIDTH_RATIO, 1200)

	_vbox.add_child(_subtitle_label)

	# Initial versteckt
	_container.modulate.a = 0.0
	_container.visible = false


## Wendet Settings an (wird von SettingsManager aufgerufen)
func _apply_settings() -> void:
	# Hole Settings vom SettingsManager wenn verfügbar
	if Engine.has_singleton("SettingsManager") or has_node("/root/SettingsManager"):
		var settings = get_node_or_null("/root/SettingsManager")
		if settings:
			_subtitles_enabled = settings.get_setting("subtitles_enabled", true)
			_subtitle_size = settings.get_setting("subtitle_size", SubtitleSize.MEDIUM)
			_fade_duration = settings.get_setting("subtitle_fade_speed", FADE_DURATION_DEFAULT)

	# Wende Font-Größe an
	if _subtitle_label:
		_subtitle_label.add_theme_font_size_override("normal_font_size", font_sizes[_subtitle_size])


## Lädt Untertitel-Daten aus einer Resource
func load_subtitle_data(data: CutsceneResources.SubtitleData) -> void:
	_subtitle_data = data
	_processed_entries.clear()
	_current_time = 0.0


## Lädt Untertitel-Daten aus einer Datei
func load_subtitle_file(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("SubtitleDisplay: Subtitle file not found: " + path)
		return false

	var data = ResourceLoader.load(path)
	if data is CutsceneResources.SubtitleData:
		load_subtitle_data(data)
		return true

	push_warning("SubtitleDisplay: Invalid subtitle resource: " + path)
	return false


## Startet die Untertitel-Wiedergabe
func start_playback() -> void:
	if not _subtitles_enabled:
		return

	_is_playing = true
	_current_time = 0.0
	_processed_entries.clear()


## Stoppt die Untertitel-Wiedergabe
func stop_playback() -> void:
	_is_playing = false
	hide_subtitle()


## Setzt die Wiedergabe-Zeit (für Sync mit Video/Cutscene)
func set_playback_time(time: float) -> void:
	_current_time = time

	# Prüfe ob aktueller Untertitel noch gültig ist
	if _current_subtitle:
		var end_time = _current_subtitle.timestamp + _current_subtitle.duration
		if time < _current_subtitle.timestamp or time > end_time:
			hide_subtitle()
			_current_subtitle = null

	# Aktualisiere processed entries für seek
	_processed_entries.clear()
	if _subtitle_data:
		for i in range(_subtitle_data.entries.size()):
			var entry = _subtitle_data.entries[i]
			if entry.timestamp + entry.duration < time:
				_processed_entries.append(i)


## Prüft ob ein neuer Untertitel angezeigt werden soll
func _check_for_new_subtitle() -> void:
	if not _subtitle_data:
		return

	for i in range(_subtitle_data.entries.size()):
		if i in _processed_entries:
			continue

		var entry = _subtitle_data.entries[i]

		# Prüfe ob dieser Untertitel jetzt starten soll
		if _current_time >= entry.timestamp and _current_time < (entry.timestamp + entry.duration):
			show_subtitle_entry(entry)
			_processed_entries.append(i)
			return

		# Prüfe ob Untertitel übersprungen wurde (z.B. durch Seek)
		if _current_time > (entry.timestamp + entry.duration):
			_processed_entries.append(i)

	# Prüfe ob aktueller Untertitel ausgeblendet werden soll
	if _current_subtitle:
		var end_time = _current_subtitle.timestamp + _current_subtitle.duration
		if _current_time >= end_time:
			hide_subtitle()
			_current_subtitle = null

			# Prüfe ob alle Untertitel fertig sind
			if _processed_entries.size() >= _subtitle_data.entries.size():
				all_subtitles_finished.emit()


## Zeigt einen Untertitel-Eintrag an
func show_subtitle_entry(entry: CutsceneResources.SubtitleEntry) -> void:
	if not _subtitles_enabled:
		return

	_current_subtitle = entry
	_show_subtitle_internal(entry.text, entry.speaker, entry.color)


## Zeigt einen Untertitel manuell an (ohne SubtitleData)
func show_subtitle(speaker: String, text: String, duration: float = 3.0, color: Color = Color.WHITE) -> void:
	if not _subtitles_enabled:
		return

	# Erstelle temporären Eintrag
	var entry = CutsceneResources.SubtitleEntry.new(0.0, text, duration, speaker, color)
	_current_subtitle = entry

	_show_subtitle_internal(text, speaker, color)

	# Timer für automatisches Ausblenden
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if _current_subtitle == entry:
			hide_subtitle()
	)


## Interne Methode zum Anzeigen des Untertitels
func _show_subtitle_internal(text: String, speaker: String, color: Color) -> void:
	# Stoppe vorherigen Tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	# Setze Sprecher
	if not speaker.is_empty():
		_speaker_label.text = speaker
		var speaker_color = speaker_colors.get(speaker, speaker_colors["default"])
		if color != Color.WHITE:
			speaker_color = color
		_speaker_label.add_theme_color_override("font_color", speaker_color)
		_speaker_label.visible = true
	else:
		_speaker_label.visible = false

	# Setze Text
	var text_color = color if color != Color.WHITE else Color.WHITE
	_subtitle_label.clear()
	_subtitle_label.push_color(text_color)
	_subtitle_label.append_text(text)
	_subtitle_label.pop()

	# Fade In
	_container.visible = true
	_current_tween = create_tween()
	_current_tween.tween_property(_container, "modulate:a", 1.0, _fade_duration)

	subtitle_shown.emit(text, speaker)


## Blendet den aktuellen Untertitel aus
func hide_subtitle() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.tween_property(_container, "modulate:a", 0.0, _fade_duration)
	_current_tween.tween_callback(func():
		_container.visible = false
		_current_subtitle = null
		subtitle_hidden.emit()
	)


## Blendet sofort aus (ohne Animation)
func hide_subtitle_immediate() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_container.modulate.a = 0.0
	_container.visible = false
	_current_subtitle = null
	_is_playing = false


## Setzt die Untertitel-Größe
func set_subtitle_size(size: SubtitleSize) -> void:
	_subtitle_size = size
	if _subtitle_label:
		_subtitle_label.add_theme_font_size_override("normal_font_size", font_sizes[size])


## Aktiviert/Deaktiviert Untertitel
func set_subtitles_enabled(enabled: bool) -> void:
	_subtitles_enabled = enabled
	if not enabled:
		hide_subtitle_immediate()


## Setzt die Fade-Geschwindigkeit
func set_fade_duration(duration: float) -> void:
	_fade_duration = clampf(duration, 0.1, 1.0)


## Fügt eine Sprecher-Farbe hinzu
func add_speaker_color(speaker: String, color: Color) -> void:
	speaker_colors[speaker] = color


## Gibt zurück ob Untertitel gerade angezeigt werden
func is_showing() -> bool:
	return _container.visible and _container.modulate.a > 0.1


## Gibt den aktuellen Untertitel-Text zurück
func get_current_text() -> String:
	if _current_subtitle:
		return _current_subtitle.text
	return ""


## Cleanup
func cleanup() -> void:
	hide_subtitle_immediate()
	_subtitle_data = null
	_processed_entries.clear()
	_current_time = 0.0
