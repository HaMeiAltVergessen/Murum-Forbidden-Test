# cutscene_examples.gd
# Beispiele für die Erstellung von Cutscene-Ressourcen
# Diese Datei zeigt, wie man Untertitel und Engine-Cutscenes programmatisch erstellt

class_name CutsceneExamples
extends RefCounted


## Erstellt Beispiel-Untertitel für eine Intro-Szene
static func create_intro_subtitles() -> CutsceneResources.SubtitleData:
	var subtitles = CutsceneResources.SubtitleData.new()
	subtitles.language = "de"
	subtitles.default_color = Color.WHITE

	# Erzähler-Einführung
	subtitles.add_entry(0.5, "In einer Welt, die von Schatten verschlungen wurde...", 4.0, "Erzähler", Color(0.9, 0.9, 0.7))
	subtitles.add_entry(5.0, "...erwacht ein vergessener Held.", 3.0, "Erzähler", Color(0.9, 0.9, 0.7))

	# Murum spricht
	subtitles.add_entry(9.0, "Wo... bin ich?", 2.0, "Murum", Color(0.4, 0.8, 1.0))
	subtitles.add_entry(11.5, "Diese Ruinen... sie kommen mir bekannt vor.", 3.0, "Murum", Color(0.4, 0.8, 1.0))

	# Unbekannte Stimme
	subtitles.add_entry(15.0, "Endlich bist du erwacht, Träger des Stabs.", 3.5, "???", Color(0.7, 0.3, 0.8))
	subtitles.add_entry(19.0, "Deine Reise beginnt hier.", 2.5, "???", Color(0.7, 0.3, 0.8))

	return subtitles


## Erstellt eine Beispiel-Engine-Cutscene für eine Boss-Enthüllung
static func create_boss_reveal_cutscene() -> CutsceneResources.EngineCutscene:
	var cutscene = CutsceneResources.EngineCutscene.new()
	cutscene.cutscene_id = "boss_reveal"
	cutscene.duration = 8.0
	cutscene.return_to_gameplay = true
	cutscene.skippable = true
	cutscene.show_skip_warning = true

	# Keyframe 1: Start bei Spieler-Position
	cutscene.add_keyframe(
		0.0,
		Vector2(0, 0),  # Position wird zur Laufzeit durch Spieler-Position ersetzt
		Vector2(1, 1),  # Normal Zoom
		CutsceneResources.EasingType.LINEAR
	)

	# Keyframe 2: Zoom out und Pan nach rechts
	cutscene.add_keyframe(
		2.0,
		Vector2(500, -100),  # Pan nach rechts oben
		Vector2(0.7, 0.7),    # Leicht rausgezoomt
		CutsceneResources.EasingType.EASE_OUT
	)

	# Keyframe 3: Fokus auf Boss-Arena
	var kf3 = CutsceneResources.CameraKeyframe.new()
	kf3.timestamp = 4.0
	kf3.position = Vector2(800, 0)
	kf3.zoom = Vector2(0.5, 0.5)  # Weiter rausgezoomt für Übersicht
	kf3.easing = CutsceneResources.EasingType.EASE_IN_OUT
	kf3.wait_time = 1.5  # Dramatische Pause
	cutscene.camera_sequence.append(kf3)

	# Keyframe 4: Zoom auf Boss
	cutscene.add_keyframe(
		6.5,
		Vector2(800, 50),
		Vector2(1.5, 1.5),  # Nah rangezoomt
		CutsceneResources.EasingType.EASE_IN
	)

	# Charakter-Aktionen
	# Boss-Animation starten
	cutscene.add_character_action(
		4.0,
		NodePath("Boss"),
		CutsceneResources.ActionType.PLAY_ANIMATION,
		{"animation": "awaken", "loop": false}
	)

	# Murum schaut zum Boss
	cutscene.add_character_action(
		4.5,
		NodePath("Player"),
		CutsceneResources.ActionType.LOOK_AT,
		{"target": Vector2(800, 50)}
	)

	# Murum spielt "überrascht" Animation
	cutscene.add_character_action(
		5.0,
		NodePath("Player"),
		CutsceneResources.ActionType.PLAY_ANIMATION,
		{"animation": "surprised", "loop": false}
	)

	return cutscene


## Erstellt eine einfache Kamera-Pan Cutscene (z.B. für Raum-Einführung)
static func create_room_pan_cutscene(start_pos: Vector2, end_pos: Vector2, duration: float = 3.0) -> CutsceneResources.EngineCutscene:
	var cutscene = CutsceneResources.EngineCutscene.new()
	cutscene.cutscene_id = "room_pan"
	cutscene.duration = duration
	cutscene.return_to_gameplay = true
	cutscene.skippable = true
	cutscene.show_skip_warning = false

	# Start
	cutscene.add_keyframe(0.0, start_pos, Vector2(1, 1), CutsceneResources.EasingType.LINEAR)

	# Ende
	cutscene.add_keyframe(duration, end_pos, Vector2(1, 1), CutsceneResources.EasingType.EASE_IN_OUT)

	return cutscene


## Erstellt eine Zoom-In Cutscene (z.B. für Item-Enthüllung)
static func create_zoom_to_target(target_pos: Vector2, zoom_level: float = 2.0, duration: float = 2.0) -> CutsceneResources.EngineCutscene:
	var cutscene = CutsceneResources.EngineCutscene.new()
	cutscene.cutscene_id = "zoom_to_target"
	cutscene.duration = duration + 1.0  # Extra Zeit am Ende
	cutscene.return_to_gameplay = true
	cutscene.skippable = true

	# Start bei aktueller Kamera (wird überschrieben)
	cutscene.add_keyframe(0.0, Vector2.ZERO, Vector2(1, 1), CutsceneResources.EasingType.LINEAR)

	# Zoom zum Ziel
	var zoom_kf = CutsceneResources.CameraKeyframe.new()
	zoom_kf.timestamp = duration
	zoom_kf.position = target_pos
	zoom_kf.zoom = Vector2(zoom_level, zoom_level)
	zoom_kf.easing = CutsceneResources.EasingType.EASE_IN_OUT
	zoom_kf.wait_time = 1.0  # Kurze Pause beim Ziel
	cutscene.camera_sequence.append(zoom_kf)

	return cutscene


## Beispiel: Wie man eine Cutscene im Spiel abspielen würde
static func example_usage() -> void:
	# Methode 1: Registrierte Cutscene abspielen
	# CutsceneManager.play_cutscene("boss_reveal")

	# Methode 2: Cutscene mit Callback
	# CutsceneManager.play_cutscene("intro", func(id, skipped):
	#     print("Cutscene ", id, " beendet. Übersprungen: ", skipped)
	#     # Gameplay starten
	# )

	# Methode 3: Engine-Cutscene programmatisch erstellen und abspielen
	# var cutscene = CutsceneExamples.create_boss_reveal_cutscene()
	# CutsceneManager.play_engine_cutscene_from_resource(cutscene)

	# Methode 4: Untertitel manuell anzeigen
	# var subtitle_display = SubtitleDisplay.new()
	# subtitle_display.show_subtitle("Murum", "Hallo, Welt!", 3.0, Color.CYAN)

	pass


## Speichert eine Engine-Cutscene als Resource-Datei
static func save_engine_cutscene(cutscene: CutsceneResources.EngineCutscene, path: String) -> bool:
	var error = ResourceSaver.save(cutscene, path)
	if error != OK:
		push_error("Failed to save engine cutscene: " + str(error))
		return false
	return true


## Speichert Untertitel als Resource-Datei
static func save_subtitles(subtitles: CutsceneResources.SubtitleData, path: String) -> bool:
	var error = ResourceSaver.save(subtitles, path)
	if error != OK:
		push_error("Failed to save subtitles: " + str(error))
		return false
	return true
