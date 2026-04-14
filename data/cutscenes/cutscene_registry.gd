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

	# Typ-spezifische Felder (ohne strikte Typisierung um Fehler zu vermeiden)
	var video_path: String = ""
	var audio_path: String = ""
	var image_paths: Array = []  # Array von Strings
	var image_texts: Array = []  # Texte für jedes Bild (Exposition/Story)
	var image_duration: float = 5.0
	var engine_cutscene_path: String = ""  # Pfad zur EngineCutscene Resource

	# Für Sequenzen
	var segments: Array = []  # Array von CutsceneSegment

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
	# INTRO CUTSCENE - Wird nach "Neues Spiel" abgespielt
	# ==========================================================================

	var intro = CutsceneDefinition.new("intro", CutsceneType.VIDEO)
	intro.video_path = "res://Assets/AIVids/AIRandomvid01.ogv"
	intro.image_texts = [
		"Vor langer Zeit existierte eine Welt voller Magie und Wunder...",
		"Die alten Tempel bewahrten Geheimnisse, die kein Sterblicher verstehen sollte.",
		"Doch die Gier der Menschen kannte keine Grenzen. Sie suchten nach verbotenem Wissen.",
		"Die Ruinen, die einst prächtige Hallen waren, verfielen unter dem Fluch der Alten.",
		"Schatten erwachten in den vergessenen Kammern, hungrig nach Leben.",
		"Die Welt wurde dunkel. Hoffnung schwand wie Morgentau in der Sonne.",
		"Doch eine Prophezeiung sprach von einem Wanderer, der das Gleichgewicht wiederherstellen würde.",
		"Und so beginnt deine Reise... im Schatten der verbotenen Mauern."
	]
	#intro.audio_path = "res://Music/w1_ruins_v1.mp3"
	intro.image_duration = 9.0  # 9 Sekunden pro Bild (+ 3s Fade = ~72 Sek total)
	intro.skippable = true
	intro.show_skip_warning = false
	intro.title = "Prolog"
	intro.description = "Die Reise beginnt..."
	intro.chapter = "Prolog"
	intro.is_story_critical = false
	_register(intro)

	# ==========================================================================
	# FINAL OUTRO CUTSCENE - Wird nach Mirror-Boss Sieg auf Schwellensicht gespielt
	# ==========================================================================

	var final_outro = CutsceneDefinition.new("final_outro", CutsceneType.VIDEO)
	final_outro.video_path = "res://Assets/AIVids/Murum Introklein.ogv"
	final_outro.image_duration = 9.0
	final_outro.skippable = true
	final_outro.show_skip_warning = false
	final_outro.title = "Epilog"
	final_outro.description = "Das Gleichgewicht ist wiederhergestellt."
	final_outro.chapter = "Epilog"
	final_outro.is_story_critical = true
	_register(final_outro)


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
static func get_all_ids() -> Array:
	initialize()
	var ids: Array = []
	for key in _cutscenes.keys():
		ids.append(key)
	return ids


## Gibt alle Cutscenes eines Typs zurück
static func get_cutscenes_by_type(type: CutsceneType) -> Array:
	initialize()
	var result: Array = []
	for definition in _cutscenes.values():
		if definition.type == type:
			result.append(definition)
	return result


## Gibt alle Story-kritischen Cutscenes zurück
static func get_story_critical_cutscenes() -> Array:
	initialize()
	var result: Array = []
	for definition in _cutscenes.values():
		if definition.is_story_critical:
			result.append(definition)
	return result


## Gibt alle Cutscenes eines Kapitels zurück
static func get_cutscenes_by_chapter(chapter: String) -> Array:
	initialize()
	var result: Array = []
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
			return CutsceneType.ENGINE

	# Default: Image
	return CutsceneType.IMAGE


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
