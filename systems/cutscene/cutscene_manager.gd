# cutscene_manager.gd
# Zentraler Manager für alle Cutscenes im Spiel
# Autoload-Singleton: Zugriff über CutsceneManager

extends Node

## Signals
signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String, was_skipped: bool)
signal cutscene_paused(cutscene_id: String)
signal cutscene_resumed(cutscene_id: String)
signal engine_cutscene_started(cutscene_id: String)
signal subtitle_shown(text: String, speaker: String)
signal subtitle_hidden()
signal skip_requested(cutscene_id: String)

## State
var _is_playing: bool = false
var _is_paused: bool = false
var _current_cutscene_id: String = ""
var _current_definition: CutsceneRegistry.CutsceneDefinition = null
var _skip_requested: bool = false
var _completion_callback: Callable

## Active Players
var _cutscene_player: Node = null
var _engine_player: Node = null
var _skip_dialog: Node = null

## Sequence State (für gemischte Sequenzen)
var _current_sequence_index: int = 0
var _sequence_segments: Array = []

## Preloaded Scenes
var _cutscene_player_scene: PackedScene
var _engine_player_scene: PackedScene
var _skip_dialog_scene: PackedScene

## Skip Input Tracking
var _skip_hold_time: float = 0.0
const SKIP_HOLD_DURATION: float = 0.5  # Kurzes Halten für normales Skip


func _ready() -> void:
	# Preload Szenen
	_cutscene_player_scene = preload("res://systems/cutscene/cutscene_player.tscn")
	_engine_player_scene = preload("res://systems/cutscene/engine_cutscene_player.tscn")
	_skip_dialog_scene = preload("res://systems/cutscene/skip_warning_dialog.tscn")

	# Initialisiere Registry
	CutsceneRegistry.initialize()

	set_process_input(false)


func _input(event: InputEvent) -> void:
	if not _is_playing or _is_paused:
		return

	# Skip-Input erkennen
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_handle_skip_request()


func _process(delta: float) -> void:
	if not _is_playing:
		return

	# Track hold-to-skip
	if Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("interact"):
		_skip_hold_time += delta
		if _skip_hold_time >= SKIP_HOLD_DURATION and not _skip_requested:
			_handle_skip_request()
	else:
		_skip_hold_time = 0.0


## ==========================================================================
## PUBLIC API
## ==========================================================================

## Spielt eine Cutscene ab (automatische Typ-Erkennung)
func play_cutscene(cutscene_id: String, callback: Callable = Callable()) -> void:
	if _is_playing:
		push_warning("CutsceneManager: Already playing cutscene: " + _current_cutscene_id)
		return

	_completion_callback = callback

	# Hole Definition
	if CutsceneRegistry.has_cutscene(cutscene_id):
		_current_definition = CutsceneRegistry.get_cutscene(cutscene_id)
	else:
		# Versuche als Pfad zu interpretieren
		_current_definition = CutsceneRegistry.create_from_path(cutscene_id)

	if not _current_definition:
		push_error("CutsceneManager: Cannot find or create cutscene: " + cutscene_id)
		_invoke_callback(cutscene_id, true)
		return

	_current_cutscene_id = _current_definition.id
	_skip_requested = false
	_skip_hold_time = 0.0

	# Starte basierend auf Typ
	match _current_definition.type:
		CutsceneRegistry.CutsceneType.VIDEO:
			_play_video_cutscene()
		CutsceneRegistry.CutsceneType.IMAGE:
			_play_image_cutscene()
		CutsceneRegistry.CutsceneType.AUDIO:
			_play_audio_cutscene()
		CutsceneRegistry.CutsceneType.ENGINE:
			_play_engine_cutscene()
		CutsceneRegistry.CutsceneType.SEQUENCE:
			_play_sequence_cutscene()


## Spielt eine Engine-Cutscene direkt aus einer Resource
func play_engine_cutscene_from_resource(cutscene: CutsceneResources.EngineCutscene, callback: Callable = Callable()) -> void:
	if _is_playing:
		push_warning("CutsceneManager: Already playing cutscene")
		return

	_completion_callback = callback
	_current_cutscene_id = cutscene.cutscene_id if not cutscene.cutscene_id.is_empty() else "custom_engine_cutscene"
	_skip_requested = false
	_skip_hold_time = 0.0

	# Erstelle temporäre Definition
	_current_definition = CutsceneRegistry.CutsceneDefinition.new(_current_cutscene_id, CutsceneRegistry.CutsceneType.ENGINE)
	_current_definition.skippable = cutscene.skippable
	_current_definition.show_skip_warning = cutscene.show_skip_warning
	_current_definition.subtitle_file = cutscene.subtitle_file

	_start_engine_cutscene(cutscene)


## Pausiert die aktuelle Cutscene
func pause_cutscene() -> void:
	if not _is_playing or _is_paused:
		return

	_is_paused = true

	if _cutscene_player and _cutscene_player.has_method("pause"):
		_cutscene_player.pause()

	if _engine_player and _engine_player.has_method("pause"):
		_engine_player.pause()

	cutscene_paused.emit(_current_cutscene_id)

	# Informiere EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("cutscene_paused"):
		event_bus.emit_signal("cutscene_paused", _current_cutscene_id)


## Setzt die Cutscene fort
func resume_cutscene() -> void:
	if not _is_playing or not _is_paused:
		return

	_is_paused = false

	if _cutscene_player and _cutscene_player.has_method("resume"):
		_cutscene_player.resume()

	if _engine_player and _engine_player.has_method("resume"):
		_engine_player.resume()

	cutscene_resumed.emit(_current_cutscene_id)

	# Informiere EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("cutscene_resumed"):
		event_bus.emit_signal("cutscene_resumed", _current_cutscene_id)


## Überspringt die aktuelle Cutscene
func skip_cutscene() -> void:
	if not _is_playing:
		return

	if _current_definition and not _current_definition.skippable:
		return

	_skip_requested = true

	if _cutscene_player and _cutscene_player.has_method("skip"):
		_cutscene_player.skip()

	if _engine_player and _engine_player.has_method("skip"):
		_engine_player.skip()


## Gibt zurück ob gerade eine Cutscene läuft
func is_playing() -> bool:
	return _is_playing


## Gibt zurück ob die Cutscene pausiert ist
func is_paused() -> bool:
	return _is_paused


## Gibt die aktuelle Cutscene-ID zurück
func get_current_cutscene_id() -> String:
	return _current_cutscene_id


## Gibt den aktuellen Fortschritt zurück (0.0 - 1.0)
func get_progress() -> float:
	if _cutscene_player and _cutscene_player.has_method("get_progress"):
		return _cutscene_player.get_progress()

	if _engine_player and _engine_player.has_method("get_progress"):
		return _engine_player.get_progress()

	return 0.0


## ==========================================================================
## INTERNAL: Cutscene-Typ-spezifische Methoden
## ==========================================================================

func _play_video_cutscene() -> void:
	_is_playing = true
	set_process_input(true)
	set_process(true)

	# Erstelle Player
	_cutscene_player = _cutscene_player_scene.instantiate()
	add_child(_cutscene_player)

	# Verbinde Signals
	_cutscene_player.cutscene_started.connect(_on_player_started)
	_cutscene_player.cutscene_finished.connect(_on_player_finished)

	# Starte Video
	_cutscene_player.play_video(
		_current_definition.video_path,
		_current_cutscene_id,
		_current_definition.subtitle_file,
		_current_definition.skippable,
		_current_definition.show_skip_warning
	)


func _play_image_cutscene() -> void:
	_is_playing = true
	set_process_input(true)
	set_process(true)

	# Erstelle Player
	_cutscene_player = _cutscene_player_scene.instantiate()
	add_child(_cutscene_player)

	# Verbinde Signals
	_cutscene_player.cutscene_started.connect(_on_player_started)
	_cutscene_player.cutscene_finished.connect(_on_player_finished)

	# Starte Bild
	_cutscene_player.play_image(
		_current_definition.image_paths,
		_current_definition.image_duration,
		_current_cutscene_id,
		_current_definition.audio_path,
		_current_definition.subtitle_file,
		_current_definition.skippable,
		_current_definition.show_skip_warning
	)


func _play_audio_cutscene() -> void:
	_is_playing = true
	set_process_input(true)
	set_process(true)

	# Erstelle Player
	_cutscene_player = _cutscene_player_scene.instantiate()
	add_child(_cutscene_player)

	# Verbinde Signals
	_cutscene_player.cutscene_started.connect(_on_player_started)
	_cutscene_player.cutscene_finished.connect(_on_player_finished)

	# Starte Audio
	_cutscene_player.play_audio(
		_current_definition.audio_path,
		0.0,  # Auto-detect duration
		_current_cutscene_id,
		_current_definition.subtitle_file,
		_current_definition.skippable,
		_current_definition.show_skip_warning
	)


func _play_engine_cutscene() -> void:
	# Lade Engine-Cutscene Resource
	if not ResourceLoader.exists(_current_definition.engine_cutscene_path):
		push_error("CutsceneManager: Engine cutscene not found: " + _current_definition.engine_cutscene_path)
		_invoke_callback(_current_cutscene_id, true)
		return

	var cutscene = load(_current_definition.engine_cutscene_path)
	if not cutscene is CutsceneResources.EngineCutscene:
		push_error("CutsceneManager: Invalid engine cutscene resource: " + _current_definition.engine_cutscene_path)
		_invoke_callback(_current_cutscene_id, true)
		return

	# Override mit Definition-Werten
	if not _current_definition.subtitle_file.is_empty():
		cutscene.subtitle_file = _current_definition.subtitle_file

	_start_engine_cutscene(cutscene)


func _start_engine_cutscene(cutscene: CutsceneResources.EngineCutscene) -> void:
	_is_playing = true
	set_process_input(true)
	set_process(true)

	# Erstelle Engine Player
	_engine_player = _engine_player_scene.instantiate()

	# Füge zur aktuellen Szene hinzu (nicht zu diesem Node)
	var current_scene = get_tree().current_scene
	current_scene.add_child(_engine_player)

	# Verbinde Signals
	_engine_player.cutscene_started.connect(_on_engine_started)
	_engine_player.cutscene_finished.connect(_on_engine_finished)
	_engine_player.keyframe_reached.connect(_on_keyframe_reached)
	_engine_player.character_action_executed.connect(_on_action_executed)

	# Starte Cutscene
	_engine_player.play(cutscene, current_scene)

	engine_cutscene_started.emit(_current_cutscene_id)


func _play_sequence_cutscene() -> void:
	_sequence_segments = _current_definition.segments.duplicate()
	_current_sequence_index = 0

	if _sequence_segments.is_empty():
		push_error("CutsceneManager: Empty sequence")
		_invoke_callback(_current_cutscene_id, true)
		return

	_play_sequence_segment()


func _play_sequence_segment() -> void:
	if _current_sequence_index >= _sequence_segments.size():
		# Sequenz fertig
		_finish_cutscene(false)
		return

	var segment: CutsceneRegistry.CutsceneSegment = _sequence_segments[_current_sequence_index]

	# Erstelle temporäre Definition für Segment
	var segment_def = CutsceneRegistry.CutsceneDefinition.new(
		_current_cutscene_id + "_segment_" + str(_current_sequence_index),
		segment.type
	)

	# Kopiere Daten
	match segment.type:
		CutsceneRegistry.CutsceneType.VIDEO:
			segment_def.video_path = segment.data.get("video_path", "")
			segment_def.subtitle_file = segment.data.get("subtitle_file", "")
		CutsceneRegistry.CutsceneType.IMAGE:
			segment_def.image_paths = segment.data.get("image_paths", [])
			segment_def.audio_path = segment.data.get("audio_path", "")
			segment_def.image_duration = segment.data.get("duration", 5.0)
		CutsceneRegistry.CutsceneType.ENGINE:
			segment_def.engine_cutscene_path = segment.data.get("engine_path", "")

	segment_def.skippable = _current_definition.skippable
	segment_def.show_skip_warning = false  # Nur am Ende der Sequenz warnen

	# Speichere aktuelle Definition und spiele Segment
	var saved_definition = _current_definition
	_current_definition = segment_def

	match segment.type:
		CutsceneRegistry.CutsceneType.VIDEO:
			_is_playing = true
			set_process_input(true)
			set_process(true)
			_cutscene_player = _cutscene_player_scene.instantiate()
			add_child(_cutscene_player)
			_cutscene_player.cutscene_finished.connect(_on_sequence_segment_finished)
			_cutscene_player.play_video(segment_def.video_path, segment_def.id, segment_def.subtitle_file, true, false)

		CutsceneRegistry.CutsceneType.ENGINE:
			var cutscene = load(segment_def.engine_cutscene_path)
			if cutscene:
				_start_engine_cutscene(cutscene)
				if _engine_player:
					_engine_player.cutscene_finished.disconnect(_on_engine_finished)
					_engine_player.cutscene_finished.connect(_on_sequence_segment_finished)

	_current_definition = saved_definition


func _on_sequence_segment_finished(_id: String, was_skipped: bool) -> void:
	# Cleanup aktuelles Segment
	if _cutscene_player:
		_cutscene_player.queue_free()
		_cutscene_player = null

	if _engine_player:
		_engine_player.queue_free()
		_engine_player = null

	if was_skipped:
		# Überspringe gesamte Sequenz
		_finish_cutscene(true)
		return

	# Nächstes Segment
	_current_sequence_index += 1
	_play_sequence_segment()


## ==========================================================================
## INTERNAL: Skip-Logik
## ==========================================================================

func _handle_skip_request() -> void:
	if not _current_definition or not _current_definition.skippable:
		return

	skip_requested.emit(_current_cutscene_id)

	# Zeige Warnung wenn nötig
	if _current_definition.show_skip_warning:
		_show_skip_warning()
	else:
		skip_cutscene()


func _show_skip_warning() -> void:
	if _skip_dialog:
		return

	# Pausiere Cutscene während Dialog
	pause_cutscene()

	# Erstelle Dialog
	_skip_dialog = _skip_dialog_scene.instantiate()
	add_child(_skip_dialog)

	_skip_dialog.skip_confirmed.connect(_on_skip_confirmed)
	_skip_dialog.skip_cancelled.connect(_on_skip_cancelled)
	_skip_dialog.show_dialog(false)


func _on_skip_confirmed() -> void:
	_cleanup_skip_dialog()
	resume_cutscene()
	skip_cutscene()


func _on_skip_cancelled() -> void:
	_cleanup_skip_dialog()
	resume_cutscene()


func _cleanup_skip_dialog() -> void:
	if _skip_dialog:
		_skip_dialog.queue_free()
		_skip_dialog = null


## ==========================================================================
## INTERNAL: Player Callbacks
## ==========================================================================

func _on_player_started(id: String) -> void:
	cutscene_started.emit(id)

	# Informiere EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("cutscene_started"):
		event_bus.emit_signal("cutscene_started", id)


func _on_player_finished(id: String, was_skipped: bool) -> void:
	_finish_cutscene(was_skipped)


func _on_engine_started(id: String) -> void:
	cutscene_started.emit(id)

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("cutscene_started"):
		event_bus.emit_signal("cutscene_started", id)


func _on_engine_finished(id: String, was_skipped: bool) -> void:
	_finish_cutscene(was_skipped)


func _on_keyframe_reached(index: int, keyframe: CutsceneResources.CameraKeyframe) -> void:
	# Kann für zusätzliche Logik verwendet werden (z.B. Sound-Effekte)
	pass


func _on_action_executed(action: CutsceneResources.CharacterAction) -> void:
	# Kann für zusätzliche Logik verwendet werden
	pass


## ==========================================================================
## INTERNAL: Cleanup
## ==========================================================================

func _finish_cutscene(was_skipped: bool) -> void:
	var finished_id = _current_cutscene_id

	# Cleanup Players
	if _cutscene_player:
		if _cutscene_player.has_method("cleanup"):
			_cutscene_player.cleanup()
		_cutscene_player.queue_free()
		_cutscene_player = null

	if _engine_player:
		if _engine_player.has_method("cleanup"):
			_engine_player.cleanup()
		_engine_player.queue_free()
		_engine_player = null

	_cleanup_skip_dialog()

	# Reset State
	_is_playing = false
	_is_paused = false
	_current_cutscene_id = ""
	_current_definition = null
	_skip_requested = false
	_sequence_segments.clear()
	_current_sequence_index = 0

	set_process_input(false)
	set_process(false)

	# Emit Signals
	cutscene_finished.emit(finished_id, was_skipped)

	# Informiere EventBus
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("cutscene_finished"):
		event_bus.emit_signal("cutscene_finished", finished_id, was_skipped)

	# Invoke Callback
	_invoke_callback(finished_id, was_skipped)


func _invoke_callback(cutscene_id: String, was_skipped: bool) -> void:
	if _completion_callback.is_valid():
		_completion_callback.call(cutscene_id, was_skipped)
		_completion_callback = Callable()


## ==========================================================================
## DEBUG / UTILITY
## ==========================================================================

## Debug: Listet alle registrierten Cutscenes auf
func debug_list_cutscenes() -> void:
	CutsceneRegistry.debug_print_all()


## Prüft ob eine Cutscene existiert
func has_cutscene(cutscene_id: String) -> bool:
	return CutsceneRegistry.has_cutscene(cutscene_id)


## Gibt die Cutscene-Definition zurück
func get_cutscene_definition(cutscene_id: String) -> CutsceneRegistry.CutsceneDefinition:
	return CutsceneRegistry.get_cutscene(cutscene_id)
