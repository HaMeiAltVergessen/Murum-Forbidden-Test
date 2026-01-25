# engine_cutscene_player.gd
# Spielt In-Engine Cutscenes mit Kamera-Tweening und Charakter-Aktionen ab
# Wird vom CutsceneManager instanziiert und verwaltet

extends Node2D

## Signals
signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String, was_skipped: bool)
signal keyframe_reached(index: int, keyframe: CutsceneResources.CameraKeyframe)
signal character_action_executed(action: CutsceneResources.CharacterAction)
signal progress_updated(progress: float)  # 0.0 - 1.0

## State
var _cutscene_data: CutsceneResources.EngineCutscene = null
var _is_playing: bool = false
var _is_paused: bool = false
var _was_skipped: bool = false
var _current_time: float = 0.0
var _current_keyframe_index: int = -1
var _executed_action_indices: Array[int] = []

## Scene references
var _scene_root: Node = null
var _original_camera: Camera2D = null
var _cutscene_camera: Camera2D = null
var _subtitle_display: Node = null  # SubtitleDisplay instance

## Tweens
var _camera_tween: Tween = null
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _is_playing or _is_paused:
		return

	_current_time += delta

	# Update progress
	if _cutscene_data and _cutscene_data.duration > 0:
		var progress = clampf(_current_time / _cutscene_data.duration, 0.0, 1.0)
		progress_updated.emit(progress)

	# Check for keyframes
	_check_keyframes()

	# Check for character actions
	_check_character_actions()

	# Update subtitle sync
	if _subtitle_display and _subtitle_display.has_method("set_playback_time"):
		_subtitle_display.set_playback_time(_current_time)

	# Check if finished
	if _current_time >= _cutscene_data.duration:
		_finish_cutscene(false)


## Spielt eine Engine-Cutscene ab
func play(cutscene: CutsceneResources.EngineCutscene, scene_root: Node = null) -> void:
	if _is_playing:
		push_warning("EngineCutscenePlayer: Already playing a cutscene")
		return

	_cutscene_data = cutscene
	_scene_root = scene_root if scene_root else get_tree().current_scene
	_was_skipped = false
	_current_time = 0.0
	_current_keyframe_index = -1
	_executed_action_indices.clear()

	# Setup camera
	_setup_cutscene_camera()

	# Load subtitles if available
	_setup_subtitles()

	# Play audio if available
	_play_cutscene_audio()

	# Start playback
	_is_playing = true
	_is_paused = false
	set_process(true)

	cutscene_started.emit(cutscene.cutscene_id)

	# Trigger first keyframe immediately if it starts at 0
	_check_keyframes()


## Pausiert die Cutscene
func pause() -> void:
	if not _is_playing:
		return

	_is_paused = true

	# Pausiere alle aktiven Tweens
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.pause()

	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.pause()

	# Pausiere Audio
	if AudioManager and AudioManager.has_method("pause_music"):
		AudioManager.pause_music()


## Setzt die Cutscene fort
func resume() -> void:
	if not _is_playing:
		return

	_is_paused = false

	# Setze alle Tweens fort
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.play()

	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.play()

	# Setze Audio fort
	if AudioManager and AudioManager.has_method("resume_music"):
		AudioManager.resume_music()


## Überspringt die Cutscene
func skip() -> void:
	if not _is_playing:
		return

	_finish_cutscene(true)


## Gibt zurück ob übersprungen werden kann
func can_skip() -> bool:
	return _cutscene_data != null and _cutscene_data.skippable


## Gibt zurück ob Skip-Warnung angezeigt werden soll
func should_show_skip_warning() -> bool:
	return _cutscene_data != null and _cutscene_data.show_skip_warning


## Richtet die Cutscene-Kamera ein
func _setup_cutscene_camera() -> void:
	# Finde aktuelle Kamera
	_original_camera = get_viewport().get_camera_2d()

	# Erstelle neue Cutscene-Kamera
	_cutscene_camera = Camera2D.new()
	_cutscene_camera.name = "CutsceneCamera"

	# Kopiere Position von Original-Kamera wenn vorhanden
	if _original_camera:
		_cutscene_camera.global_position = _original_camera.global_position
		_cutscene_camera.zoom = _original_camera.zoom
		_original_camera.enabled = false

	# Setze auf erste Keyframe-Position wenn vorhanden
	if _cutscene_data.camera_sequence.size() > 0:
		var first_keyframe = _cutscene_data.camera_sequence[0]
		_cutscene_camera.global_position = first_keyframe.position
		_cutscene_camera.zoom = first_keyframe.zoom
		_cutscene_camera.rotation_degrees = first_keyframe.rotation_degrees

	_cutscene_camera.enabled = true
	add_child(_cutscene_camera)


## Räumt die Cutscene-Kamera auf
func _cleanup_cutscene_camera() -> void:
	if _cutscene_camera:
		_cutscene_camera.queue_free()
		_cutscene_camera = null

	# Stelle Original-Kamera wieder her
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.enabled = true

		# Optional: Smooth zurück zum Spieler
		if _cutscene_data and _cutscene_data.return_to_gameplay:
			# Kamera ist bereits aktiviert, Position wird automatisch aktualisiert
			pass


## Richtet Untertitel ein
func _setup_subtitles() -> void:
	if _cutscene_data.subtitle_file.is_empty():
		return

	# Lade SubtitleDisplay-Szene
	var subtitle_scene = load("res://systems/cutscene/subtitle_display.tscn")
	if subtitle_scene:
		_subtitle_display = subtitle_scene.instantiate()
		add_child(_subtitle_display)

		# Lade Untertitel-Datei
		if _subtitle_display.has_method("load_subtitle_file"):
			_subtitle_display.load_subtitle_file(_cutscene_data.subtitle_file)
			_subtitle_display.start_playback()


## Spielt Cutscene-Audio ab
func _play_cutscene_audio() -> void:
	if _cutscene_data.audio_file.is_empty():
		return

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_music"):
		audio_manager.play_music(_cutscene_data.audio_file)


## Prüft und verarbeitet Keyframes
func _check_keyframes() -> void:
	if not _cutscene_data or _cutscene_data.camera_sequence.is_empty():
		return

	# Finde aktuellen und nächsten Keyframe
	var current_kf_idx = -1
	var next_kf_idx = -1

	for i in range(_cutscene_data.camera_sequence.size()):
		var kf = _cutscene_data.camera_sequence[i]
		if _current_time >= kf.timestamp:
			current_kf_idx = i
		else:
			next_kf_idx = i
			break

	# Neuer Keyframe erreicht?
	if current_kf_idx != _current_keyframe_index and current_kf_idx >= 0:
		_current_keyframe_index = current_kf_idx
		var keyframe = _cutscene_data.camera_sequence[current_kf_idx]
		keyframe_reached.emit(current_kf_idx, keyframe)

		# Tween zum nächsten Keyframe wenn vorhanden
		if next_kf_idx >= 0:
			_tween_to_keyframe(_cutscene_data.camera_sequence[next_kf_idx], keyframe)


## Tweent die Kamera zum nächsten Keyframe
func _tween_to_keyframe(target_kf: CutsceneResources.CameraKeyframe, from_kf: CutsceneResources.CameraKeyframe) -> void:
	if not _cutscene_camera:
		return

	# Stoppe vorherigen Tween
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()

	var duration = target_kf.timestamp - from_kf.timestamp - from_kf.wait_time
	if duration <= 0:
		# Sofort setzen
		_cutscene_camera.global_position = target_kf.position
		_cutscene_camera.zoom = target_kf.zoom
		_cutscene_camera.rotation_degrees = target_kf.rotation_degrees
		return

	# Warte auf wait_time des aktuellen Keyframes
	if from_kf.wait_time > 0:
		await get_tree().create_timer(from_kf.wait_time).timeout
		if not _is_playing:
			return

	# Erstelle Tween
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)

	var trans = target_kf.get_tween_transition()
	var ease_type = target_kf.get_tween_ease()

	_camera_tween.tween_property(_cutscene_camera, "global_position", target_kf.position, duration).set_trans(trans).set_ease(ease_type)
	_camera_tween.tween_property(_cutscene_camera, "zoom", target_kf.zoom, duration).set_trans(trans).set_ease(ease_type)
	_camera_tween.tween_property(_cutscene_camera, "rotation_degrees", target_kf.rotation_degrees, duration).set_trans(trans).set_ease(ease_type)

	_active_tweens.append(_camera_tween)


## Prüft und führt Charakter-Aktionen aus
func _check_character_actions() -> void:
	if not _cutscene_data:
		return

	for i in range(_cutscene_data.character_actions.size()):
		if i in _executed_action_indices:
			continue

		var action = _cutscene_data.character_actions[i]

		# Prüfe ob Aktion ausgeführt werden soll (mit kleiner Toleranz)
		if abs(_current_time - action.timestamp) <= 0.1:
			_execute_action(action)
			_executed_action_indices.append(i)


## Führt eine Charakter-Aktion aus
func _execute_action(action: CutsceneResources.CharacterAction) -> void:
	var success = action.execute(_scene_root)

	if success:
		character_action_executed.emit(action)
	else:
		push_warning("EngineCutscenePlayer: Failed to execute action at " + str(action.timestamp))


## Beendet die Cutscene
func _finish_cutscene(skipped: bool) -> void:
	_was_skipped = skipped
	_is_playing = false
	set_process(false)

	# Stoppe alle Tweens
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()

	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	# Cleanup Subtitles
	if _subtitle_display:
		if _subtitle_display.has_method("cleanup"):
			_subtitle_display.cleanup()
		_subtitle_display.queue_free()
		_subtitle_display = null

	# Cleanup Camera
	_cleanup_cutscene_camera()

	# Emit finished signal
	var cutscene_id = _cutscene_data.cutscene_id if _cutscene_data else ""
	cutscene_finished.emit(cutscene_id, skipped)


## Gibt den aktuellen Fortschritt zurück (0.0 - 1.0)
func get_progress() -> float:
	if not _cutscene_data or _cutscene_data.duration <= 0:
		return 0.0
	return clampf(_current_time / _cutscene_data.duration, 0.0, 1.0)


## Gibt zurück ob die Cutscene gerade läuft
func is_playing() -> bool:
	return _is_playing


## Gibt zurück ob die Cutscene pausiert ist
func is_paused() -> bool:
	return _is_paused


## Gibt die aktuelle Zeit zurück
func get_current_time() -> float:
	return _current_time


## Cleanup
func cleanup() -> void:
	if _is_playing:
		_finish_cutscene(true)

	_cutscene_data = null
	_scene_root = null
