# cutscene_player.gd
# Spielt externe Cutscenes ab (Video, Bilder, Audio)
# Unterstützt VideoStreamPlayer, Bildsequenzen und Audio-Overlay

extends CanvasLayer

## Signals
signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String, was_skipped: bool)
signal progress_updated(progress: float)

## Cutscene-Typen
enum CutsceneType {
	VIDEO,        # .ogv, .webm Video-Dateien
	IMAGE,        # Einzelbild oder Bildsequenz
	AUDIO_ONLY    # Nur Audio mit schwarzem Bildschirm
}

## Konstanten
const FADE_DURATION: float = 0.5
const IMAGE_DISPLAY_DURATION: float = 5.0  # Standard-Anzeigedauer für Bilder

## State
var _cutscene_id: String = ""
var _cutscene_type: CutsceneType = CutsceneType.VIDEO
var _is_playing: bool = false
var _is_paused: bool = false
var _was_skipped: bool = false
var _skippable: bool = true
var _show_skip_warning: bool = false

## Cutscene-Daten
var _video_path: String = ""
var _audio_path: String = ""
var _image_paths: Array[String] = []
var _subtitle_path: String = ""
var _duration: float = 0.0
var _current_time: float = 0.0

## UI Nodes
var _background: ColorRect
var _video_player: VideoStreamPlayer
var _texture_rect: TextureRect
var _audio_player: AudioStreamPlayer
var _subtitle_display: Node

## Tweens
var _fade_tween: Tween = null
var _image_timer: Timer = null


func _ready() -> void:
	layer = 90  # Unter Untertiteln aber über Gameplay
	_setup_ui()
	set_process(false)


func _process(delta: float) -> void:
	if not _is_playing or _is_paused:
		return

	_current_time += delta

	# Update progress
	if _duration > 0:
		var progress = clampf(_current_time / _duration, 0.0, 1.0)
		progress_updated.emit(progress)

	# Sync subtitles
	if _subtitle_display and _subtitle_display.has_method("set_playback_time"):
		_subtitle_display.set_playback_time(_current_time)


## Erstellt die UI-Struktur
func _setup_ui() -> void:
	# Schwarzer Hintergrund
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color.BLACK
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Video Player
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoPlayer"
	_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.autoplay = false
	_video_player.visible = false
	_video_player.finished.connect(_on_video_finished)
	add_child(_video_player)

	# Texture Rect für Bilder
	_texture_rect = TextureRect.new()
	_texture_rect.name = "ImageDisplay"
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.visible = false
	add_child(_texture_rect)

	# Audio Player für Voice-Over oder Audio-Only
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	_audio_player.bus = "SFX"  # Oder eigener "Cutscene" Bus
	_audio_player.finished.connect(_on_audio_finished)
	add_child(_audio_player)

	# Image Timer
	_image_timer = Timer.new()
	_image_timer.name = "ImageTimer"
	_image_timer.one_shot = true
	_image_timer.timeout.connect(_on_image_timer_timeout)
	add_child(_image_timer)

	# Initial versteckt
	_background.modulate.a = 0.0
	visible = false


## Spielt eine Video-Cutscene ab
func play_video(video_path: String, cutscene_id: String = "", subtitle_path: String = "", skippable: bool = true, show_warning: bool = false) -> void:
	_reset_state()

	_cutscene_id = cutscene_id if not cutscene_id.is_empty() else video_path.get_file().get_basename()
	_cutscene_type = CutsceneType.VIDEO
	_video_path = video_path
	_subtitle_path = subtitle_path
	_skippable = skippable
	_show_skip_warning = show_warning

	# Lade Video
	var stream = load(video_path)
	if not stream:
		push_error("CutscenePlayer: Failed to load video: " + video_path)
		cutscene_finished.emit(_cutscene_id, true)
		return

	_video_player.stream = stream
	_video_player.visible = true
	_texture_rect.visible = false

	# Setup Subtitles
	_setup_subtitles()

	# Fade In und Start
	_start_playback()


## Spielt eine Bild-Cutscene ab (Einzelbild oder Sequenz)
func play_image(image_paths: Variant, duration: float = IMAGE_DISPLAY_DURATION, cutscene_id: String = "", audio_path: String = "", subtitle_path: String = "", skippable: bool = true, show_warning: bool = false) -> void:
	_reset_state()

	# Konvertiere zu Array falls einzelner Pfad
	if image_paths is String:
		_image_paths = [image_paths]
	else:
		_image_paths.assign(image_paths)

	if _image_paths.is_empty():
		push_error("CutscenePlayer: No images provided")
		cutscene_finished.emit(_cutscene_id, true)
		return

	_cutscene_id = cutscene_id if not cutscene_id.is_empty() else _image_paths[0].get_file().get_basename()
	_cutscene_type = CutsceneType.IMAGE
	_audio_path = audio_path
	_subtitle_path = subtitle_path
	_skippable = skippable
	_show_skip_warning = show_warning
	_duration = duration * _image_paths.size()

	_video_player.visible = false
	_texture_rect.visible = true

	# Lade erstes Bild
	_show_image(0)

	# Setup Audio
	if not audio_path.is_empty():
		var audio_stream = load(audio_path)
		if audio_stream:
			_audio_player.stream = audio_stream

	# Setup Subtitles
	_setup_subtitles()

	# Starte Wiedergabe
	_start_playback()

	# Starte Image Timer
	_image_timer.wait_time = duration
	_image_timer.start()


## Spielt eine Audio-Only Cutscene ab
func play_audio(audio_path: String, duration: float = 0.0, cutscene_id: String = "", subtitle_path: String = "", skippable: bool = true, show_warning: bool = false) -> void:
	_reset_state()

	_cutscene_id = cutscene_id if not cutscene_id.is_empty() else audio_path.get_file().get_basename()
	_cutscene_type = CutsceneType.AUDIO_ONLY
	_audio_path = audio_path
	_subtitle_path = subtitle_path
	_skippable = skippable
	_show_skip_warning = show_warning

	# Lade Audio
	var audio_stream = load(audio_path)
	if not audio_stream:
		push_error("CutscenePlayer: Failed to load audio: " + audio_path)
		cutscene_finished.emit(_cutscene_id, true)
		return

	_audio_player.stream = audio_stream
	_duration = duration if duration > 0 else audio_stream.get_length()

	_video_player.visible = false
	_texture_rect.visible = false

	# Setup Subtitles
	_setup_subtitles()

	# Starte Wiedergabe
	_start_playback()


## Setzt den Zustand zurück
func _reset_state() -> void:
	_is_playing = false
	_is_paused = false
	_was_skipped = false
	_current_time = 0.0
	_duration = 0.0
	_video_path = ""
	_audio_path = ""
	_image_paths.clear()
	_subtitle_path = ""

	_video_player.stop()
	_audio_player.stop()
	_image_timer.stop()

	if _subtitle_display:
		_subtitle_display.queue_free()
		_subtitle_display = null


## Richtet Untertitel ein
func _setup_subtitles() -> void:
	if _subtitle_path.is_empty():
		return

	var subtitle_scene = load("res://systems/cutscene/subtitle_display.tscn")
	if subtitle_scene:
		_subtitle_display = subtitle_scene.instantiate()
		add_child(_subtitle_display)

		if _subtitle_display.has_method("load_subtitle_file"):
			_subtitle_display.load_subtitle_file(_subtitle_path)


## Startet die Wiedergabe
func _start_playback() -> void:
	visible = true
	_is_playing = true
	set_process(true)

	# Fade In
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_background, "modulate:a", 1.0, FADE_DURATION)
	_fade_tween.tween_callback(_on_fade_in_complete)


## Callback nach Fade-In
func _on_fade_in_complete() -> void:
	match _cutscene_type:
		CutsceneType.VIDEO:
			_video_player.play()
			_duration = _video_player.get_stream_length()
		CutsceneType.IMAGE:
			if not _audio_path.is_empty():
				_audio_player.play()
		CutsceneType.AUDIO_ONLY:
			_audio_player.play()

	# Starte Subtitles
	if _subtitle_display and _subtitle_display.has_method("start_playback"):
		_subtitle_display.start_playback()

	cutscene_started.emit(_cutscene_id)


## Zeigt ein Bild aus der Sequenz
func _show_image(index: int) -> void:
	if index < 0 or index >= _image_paths.size():
		return

	var texture = load(_image_paths[index])
	if texture:
		_texture_rect.texture = texture


## Pausiert die Cutscene
func pause() -> void:
	if not _is_playing:
		return

	_is_paused = true

	match _cutscene_type:
		CutsceneType.VIDEO:
			_video_player.paused = true
		CutsceneType.IMAGE, CutsceneType.AUDIO_ONLY:
			_audio_player.stream_paused = true
			_image_timer.paused = true

	if _subtitle_display and _subtitle_display.has_method("stop_playback"):
		_subtitle_display.stop_playback()


## Setzt die Cutscene fort
func resume() -> void:
	if not _is_playing:
		return

	_is_paused = false

	match _cutscene_type:
		CutsceneType.VIDEO:
			_video_player.paused = false
		CutsceneType.IMAGE, CutsceneType.AUDIO_ONLY:
			_audio_player.stream_paused = false
			_image_timer.paused = false

	if _subtitle_display and _subtitle_display.has_method("start_playback"):
		_subtitle_display.start_playback()


## Überspringt die Cutscene
func skip() -> void:
	if not _is_playing or not _skippable:
		return

	_was_skipped = true
	_finish_cutscene()


## Gibt zurück ob übersprungen werden kann
func can_skip() -> bool:
	return _skippable


## Gibt zurück ob Skip-Warnung angezeigt werden soll
func should_show_skip_warning() -> bool:
	return _show_skip_warning


## Video-Ende Callback
func _on_video_finished() -> void:
	_finish_cutscene()


## Audio-Ende Callback
func _on_audio_finished() -> void:
	if _cutscene_type == CutsceneType.AUDIO_ONLY:
		_finish_cutscene()


## Image Timer Callback
func _on_image_timer_timeout() -> void:
	# Zeige nächstes Bild oder beende
	var current_image_index = int(_current_time / IMAGE_DISPLAY_DURATION)
	var next_index = current_image_index + 1

	if next_index < _image_paths.size():
		_show_image(next_index)
		_image_timer.start()
	else:
		_finish_cutscene()


## Beendet die Cutscene
func _finish_cutscene() -> void:
	_is_playing = false
	set_process(false)

	# Stoppe Playback
	_video_player.stop()
	_audio_player.stop()
	_image_timer.stop()

	# Cleanup Subtitles
	if _subtitle_display:
		if _subtitle_display.has_method("cleanup"):
			_subtitle_display.cleanup()
		_subtitle_display.queue_free()
		_subtitle_display = null

	# Fade Out
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_background, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func():
		visible = false
		_video_player.visible = false
		_texture_rect.visible = false
		cutscene_finished.emit(_cutscene_id, _was_skipped)
	)


## Gibt den aktuellen Fortschritt zurück (0.0 - 1.0)
func get_progress() -> float:
	if _duration <= 0:
		return 0.0

	match _cutscene_type:
		CutsceneType.VIDEO:
			return clampf(_video_player.stream_position / _duration, 0.0, 1.0)
		_:
			return clampf(_current_time / _duration, 0.0, 1.0)


## Gibt zurück ob die Cutscene gerade läuft
func is_playing() -> bool:
	return _is_playing


## Gibt zurück ob die Cutscene pausiert ist
func is_paused() -> bool:
	return _is_paused


## Gibt die Cutscene-ID zurück
func get_cutscene_id() -> String:
	return _cutscene_id


## Cleanup
func cleanup() -> void:
	if _is_playing:
		_was_skipped = true
		_finish_cutscene()
