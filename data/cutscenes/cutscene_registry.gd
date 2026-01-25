# cutscene_registry.gd
# Zentrale Registry für alle Cutscenes im Spiel
# Definiert Cutscene-Metadaten, Typen und Pfade

class_name CutsceneRegistry
extends RefCounted

## Cutscene-Typen
enum CutsceneType {
	VIDEO,      # Externe Video-Datei (.ogv, .webm)
	IMAGE,      # Einzelbild oder Bildsequenz
	AUDIO,      # Nur Audio (mit schwarzem Bildschirm oder Hintergrund)
	ENGINE,     # In-Engine Cutscene mit Kamera-Tweening
	SEQUENCE    # Gemischte Sequenz aus mehreren Segmenten
}

## Segment-Definition für gemischte Sequenzen
class CutsceneSegment extends RefCounted:
	var type: CutsceneType
	var data: Dictionary  # Typ-spezifische Daten

	func _init(p_type: CutsceneType, p_data: Dictionary) -> void:
		type = p_type
		data = p_data


## Cutscene-Definition
class CutsceneDefinition extends RefCounted:
	var id: String
	var type: CutsceneType
	var skippable: bool = true
	var show_skip_warning: bool = false
	var subtitle_file: String = ""

	# Typ-spezifische Felder
	var video_path: String = ""
	var audio_path: String = ""
	var image_paths: Array[String] = []
	var image_duration: float = 5.0
	var engine_cutscene_path: String = ""  # Pfad zur EngineCutscene Resource

	# Für Sequenzen
	var segments: Array[CutsceneSegment] = []

	# Metadaten
	var title: String = ""
	var description: String = ""
	var chapter: String = ""
	var is_story_critical: bool = false

	func _init(p_id: String, p_type: CutsceneType) -> void:
		id = p_id
		type = p_type


## Registrierte Cutscenes
static var _cutscenes: Dictionary = {}  # id -> CutsceneDefinition
static var _initialized: bool = false


## Initialisiert die Registry mit allen Cutscenes
static func initialize() -> void:
	if _initialized:
		return

	_cutscenes.clear()
	_register_all_cutscenes()
	_initialized = true


## Registriert alle Cutscenes (hier werden alle Cutscenes definiert)
static func _register_all_cutscenes() -> void:
	# ==========================================================================
	# BEISPIEL-CUTSCENES (können durch echte ersetzt werden)
	# ==========================================================================

	# Intro-Cutscene (Video)
	var intro = CutsceneDefinition.new("intro", CutsceneType.VIDEO)
	intro.video_path = "res://data/cutscenes/videos/intro.ogv"
	intro.subtitle_file = "res://data/cutscenes/subtitles/intro_subtitles.tres"
	intro.skippable = true
	intro.show_skip_warning = true
	intro.title = "Prolog"
	intro.description = "Die Geschichte beginnt..."
	intro.chapter = "Prolog"
	intro.is_story_critical = true
	_register(intro)

	# Ruinen-Intro (Video mit Untertiteln)
	var ruins_intro = CutsceneDefinition.new("intro_ruins", CutsceneType.VIDEO)
	ruins_intro.video_path = "res://data/cutscenes/videos/intro_ruins.ogv"
	ruins_intro.subtitle_file = "res://data/cutscenes/subtitles/intro_ruins_subtitles.tres"
	ruins_intro.skippable = true
	ruins_intro.show_skip_warning = false
	ruins_intro.title = "Die Ruinen"
	ruins_intro.chapter = "Kapitel 1"
	_register(ruins_intro)

	# Boss-Enthüllung (Engine-Cutscene)
	var boss_reveal = CutsceneDefinition.new("boss_reveal", CutsceneType.ENGINE)
	boss_reveal.engine_cutscene_path = "res://data/cutscenes/engine/boss_reveal.tres"
	boss_reveal.subtitle_file = "res://data/cutscenes/subtitles/boss_reveal_subtitles.tres"
	boss_reveal.skippable = true
	boss_reveal.show_skip_warning = true
	boss_reveal.title = "Der Wächter erwacht"
	boss_reveal.is_story_critical = true
	_register(boss_reveal)

	# Arena-Eingang (Engine-Cutscene, kurz)
	var arena_entrance = CutsceneDefinition.new("arena_entrance", CutsceneType.ENGINE)
	arena_entrance.engine_cutscene_path = "res://data/cutscenes/engine/arena_entrance.tres"
	arena_entrance.skippable = true
	arena_entrance.show_skip_warning = false
	arena_entrance.title = "Die Arena"
	_register(arena_entrance)

	# Boss-Niederlage (Bild + Audio)
	var boss_defeat = CutsceneDefinition.new("boss_defeat", CutsceneType.IMAGE)
	boss_defeat.image_paths = ["res://data/cutscenes/images/boss_defeat_01.png"]
	boss_defeat.audio_path = "res://data/cutscenes/audio/boss_defeat_narration.ogg"
	boss_defeat.subtitle_file = "res://data/cutscenes/subtitles/boss_defeat_subtitles.tres"
	boss_defeat.image_duration = 8.0
	boss_defeat.skippable = true
	boss_defeat.title = "Sieg"
	_register(boss_defeat)

	# Gemischte Sequenz: Boss-Intro (Video -> Engine)
	var boss_intro_sequence = CutsceneDefinition.new("boss_intro_sequence", CutsceneType.SEQUENCE)
	boss_intro_sequence.segments = [
		CutsceneSegment.new(CutsceneType.VIDEO, {
			"video_path": "res://data/cutscenes/videos/boss_approach.ogv",
			"subtitle_file": "res://data/cutscenes/subtitles/boss_approach_subtitles.tres"
		}),
		CutsceneSegment.new(CutsceneType.ENGINE, {
			"engine_path": "res://data/cutscenes/engine/boss_reveal.tres"
		})
	]
	boss_intro_sequence.skippable = true
	boss_intro_sequence.show_skip_warning = true
	boss_intro_sequence.title = "Boss-Einführung"
	boss_intro_sequence.is_story_critical = true
	_register(boss_intro_sequence)


## Registriert eine Cutscene
static func _register(definition: CutsceneDefinition) -> void:
	if definition.id.is_empty():
		push_error("CutsceneRegistry: Cannot register cutscene without ID")
		return

	if _cutscenes.has(definition.id):
		push_warning("CutsceneRegistry: Overwriting existing cutscene: " + definition.id)

	_cutscenes[definition.id] = definition


## Gibt eine Cutscene-Definition zurück
static func get_cutscene(id: String) -> CutsceneDefinition:
	initialize()

	if not _cutscenes.has(id):
		push_warning("CutsceneRegistry: Cutscene not found: " + id)
		return null

	return _cutscenes[id]


## Prüft ob eine Cutscene existiert
static func has_cutscene(id: String) -> bool:
	initialize()
	return _cutscenes.has(id)


## Gibt alle Cutscene-IDs zurück
static func get_all_ids() -> Array[String]:
	initialize()
	var ids: Array[String] = []
	for key in _cutscenes.keys():
		ids.append(key)
	return ids


## Gibt alle Cutscenes eines Typs zurück
static func get_cutscenes_by_type(type: CutsceneType) -> Array[CutsceneDefinition]:
	initialize()
	var result: Array[CutsceneDefinition] = []
	for definition in _cutscenes.values():
		if definition.type == type:
			result.append(definition)
	return result


## Gibt alle Story-kritischen Cutscenes zurück
static func get_story_critical_cutscenes() -> Array[CutsceneDefinition]:
	initialize()
	var result: Array[CutsceneDefinition] = []
	for definition in _cutscenes.values():
		if definition.is_story_critical:
			result.append(definition)
	return result


## Gibt alle Cutscenes eines Kapitels zurück
static func get_cutscenes_by_chapter(chapter: String) -> Array[CutsceneDefinition]:
	initialize()
	var result: Array[CutsceneDefinition] = []
	for definition in _cutscenes.values():
		if definition.chapter == chapter:
			result.append(definition)
	return result


## Erkennt den Cutscene-Typ basierend auf Dateipfad oder ID
static func detect_type(path_or_id: String) -> CutsceneType:
	# Prüfe ob es eine registrierte Cutscene ist
	if has_cutscene(path_or_id):
		return get_cutscene(path_or_id).type

	# Erkennung basierend auf Dateiendung
	var extension = path_or_id.get_extension().to_lower()

	match extension:
		"ogv", "webm", "mp4", "avi":
			return CutsceneType.VIDEO
		"png", "jpg", "jpeg", "webp", "bmp":
			return CutsceneType.IMAGE
		"ogg", "mp3", "wav":
			return CutsceneType.AUDIO
		"tres", "res":
			# Könnte EngineCutscene sein, prüfe Resource
			if ResourceLoader.exists(path_or_id):
				var res = load(path_or_id)
				if res is CutsceneResources.EngineCutscene:
					return CutsceneType.ENGINE
			return CutsceneType.VIDEO  # Fallback

	# Default: Video
	return CutsceneType.VIDEO


## Erstellt eine temporäre Cutscene-Definition aus einem Pfad
static func create_from_path(path: String) -> CutsceneDefinition:
	var type = detect_type(path)
	var id = path.get_file().get_basename()

	var definition = CutsceneDefinition.new(id, type)

	match type:
		CutsceneType.VIDEO:
			definition.video_path = path
		CutsceneType.IMAGE:
			definition.image_paths = [path]
		CutsceneType.AUDIO:
			definition.audio_path = path
		CutsceneType.ENGINE:
			definition.engine_cutscene_path = path

	# Versuche automatisch Untertitel zu finden
	var subtitle_path = path.get_base_dir() + "/subtitles/" + id + "_subtitles.tres"
	if ResourceLoader.exists(subtitle_path):
		definition.subtitle_file = subtitle_path

	return definition


## Debug: Gibt alle registrierten Cutscenes aus
static func debug_print_all() -> void:
	initialize()
	print("=== CutsceneRegistry Debug ===")
	print("Registered cutscenes: ", _cutscenes.size())
	for id in _cutscenes:
		var def = _cutscenes[id]
		print("  - ", id, " (", CutsceneType.keys()[def.type], ")")
		if not def.title.is_empty():
			print("    Title: ", def.title)
		if def.is_story_critical:
			print("    [STORY CRITICAL]")
	print("==============================")
