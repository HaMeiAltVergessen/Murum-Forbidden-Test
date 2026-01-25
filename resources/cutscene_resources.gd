# cutscene_resources.gd
# Custom Resource Definitions for the Cutscene System
# Contains: SubtitleEntry, SubtitleData, CameraKeyframe, CharacterAction, EngineCutscene

class_name CutsceneResources
extends RefCounted

# =============================================================================
# SUBTITLE SYSTEM RESOURCES
# =============================================================================

## Einzelner Untertitel-Eintrag
## Enthält Timing, Text und optionale Sprecher-Information
class SubtitleEntry extends Resource:
	## Zeitpunkt ab Cutscene-Start in Sekunden
	@export var timestamp: float = 0.0
	## Der anzuzeigende Text
	@export_multiline var text: String = ""
	## Wie lange der Untertitel sichtbar ist in Sekunden
	@export var duration: float = 2.0
	## Optional: Name des Sprechers ("Murum", "Umbra", "???", etc.)
	@export var speaker: String = ""
	## Optional: Farbe für den Sprecher (verschiedene Farben für verschiedene Charaktere)
	@export var color: Color = Color.WHITE

	func _init(p_timestamp: float = 0.0, p_text: String = "", p_duration: float = 2.0, p_speaker: String = "", p_color: Color = Color.WHITE) -> void:
		timestamp = p_timestamp
		text = p_text
		duration = p_duration
		speaker = p_speaker
		color = p_color


## Container für alle Untertitel einer Cutscene
## Wird als .tres Datei gespeichert
class SubtitleData extends Resource:
	## Alle Untertitel-Einträge, sortiert nach timestamp
	@export var entries: Array[SubtitleEntry] = []
	## Standard-Farbe wenn keine Sprecher-Farbe definiert ist
	@export var default_color: Color = Color.WHITE
	## Sprache dieser Untertitel-Datei (für Lokalisierung)
	@export var language: String = "de"

	## Fügt einen neuen Untertitel hinzu und sortiert automatisch
	func add_entry(timestamp: float, text: String, duration: float = 2.0, speaker: String = "", color: Color = Color.WHITE) -> void:
		var entry := SubtitleEntry.new(timestamp, text, duration, speaker, color)
		entries.append(entry)
		# Sortiere nach timestamp
		entries.sort_custom(func(a, b): return a.timestamp < b.timestamp)

	## Gibt den Untertitel für einen bestimmten Zeitpunkt zurück (oder null)
	func get_entry_at_time(time: float) -> SubtitleEntry:
		for entry in entries:
			if time >= entry.timestamp and time < (entry.timestamp + entry.duration):
				return entry
		return null

	## Gibt alle Untertitel zurück, die bei einem bestimmten Zeitpunkt starten sollen
	func get_entries_starting_at(time: float, tolerance: float = 0.05) -> Array[SubtitleEntry]:
		var result: Array[SubtitleEntry] = []
		for entry in entries:
			if abs(entry.timestamp - time) <= tolerance:
				result.append(entry)
		return result


# =============================================================================
# ENGINE CUTSCENE RESOURCES
# =============================================================================

## Easing-Typen für Kamera-Bewegungen
enum EasingType {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	BOUNCE,
	ELASTIC,
	BACK
}

## Aktions-Typen für Charakter-Aktionen während Cutscenes
enum ActionType {
	PLAY_ANIMATION,
	MOVE_TO,
	LOOK_AT,
	EMIT_SIGNAL,
	SET_PROPERTY,
	CALL_METHOD
}


## Kamera-Keyframe für Engine-Cutscenes
## Definiert Position, Zoom und Timing für einen Punkt in der Kamera-Sequenz
class CameraKeyframe extends Resource:
	## Zeitpunkt in der Sequenz (Sekunden)
	@export var timestamp: float = 0.0
	## Kamera-Position in Weltkoordinaten
	@export var position: Vector2 = Vector2.ZERO
	## Kamera-Zoom-Level (1,1 = normal, 2,2 = 2x Zoom)
	@export var zoom: Vector2 = Vector2.ONE
	## Easing-Typ für die Bewegung zu diesem Keyframe
	@export var easing: EasingType = EasingType.EASE_IN_OUT
	## Pause-Zeit bei diesem Keyframe (für dramatische Pausen)
	@export var wait_time: float = 0.0
	## Optional: Rotation der Kamera in Grad
	@export var rotation_degrees: float = 0.0

	func _init(p_timestamp: float = 0.0, p_position: Vector2 = Vector2.ZERO, p_zoom: Vector2 = Vector2.ONE, p_easing: EasingType = EasingType.EASE_IN_OUT) -> void:
		timestamp = p_timestamp
		position = p_position
		zoom = p_zoom
		easing = p_easing

	## Konvertiert EasingType zu Godot's Tween.TransitionType und EaseType
	func get_tween_transition() -> Tween.TransitionType:
		match easing:
			EasingType.LINEAR:
				return Tween.TRANS_LINEAR
			EasingType.EASE_IN, EasingType.EASE_OUT, EasingType.EASE_IN_OUT:
				return Tween.TRANS_SINE
			EasingType.BOUNCE:
				return Tween.TRANS_BOUNCE
			EasingType.ELASTIC:
				return Tween.TRANS_ELASTIC
			EasingType.BACK:
				return Tween.TRANS_BACK
			_:
				return Tween.TRANS_LINEAR

	func get_tween_ease() -> Tween.EaseType:
		match easing:
			EasingType.LINEAR:
				return Tween.EASE_IN_OUT
			EasingType.EASE_IN:
				return Tween.EASE_IN
			EasingType.EASE_OUT:
				return Tween.EASE_OUT
			EasingType.EASE_IN_OUT, EasingType.BOUNCE, EasingType.ELASTIC, EasingType.BACK:
				return Tween.EASE_IN_OUT
			_:
				return Tween.EASE_IN_OUT


## Charakter-Aktion während einer Engine-Cutscene
## Ermöglicht Animationen, Bewegungen und andere Aktionen
class CharacterAction extends Resource:
	## Zeitpunkt der Aktion (Sekunden ab Cutscene-Start)
	@export var timestamp: float = 0.0
	## Pfad zum Ziel-Node in der Szene
	@export var target_node: NodePath = NodePath()
	## Typ der Aktion
	@export var action_type: ActionType = ActionType.PLAY_ANIMATION
	## Parameter je nach action_type (als Dictionary)
	@export var parameters: Dictionary = {}

	func _init(p_timestamp: float = 0.0, p_target: NodePath = NodePath(), p_type: ActionType = ActionType.PLAY_ANIMATION, p_params: Dictionary = {}) -> void:
		timestamp = p_timestamp
		target_node = p_target
		action_type = p_type
		parameters = p_params

	## Führt die Aktion auf dem Ziel-Node aus
	func execute(scene_root: Node) -> bool:
		var target = scene_root.get_node_or_null(target_node)
		if not target:
			push_warning("CharacterAction: Target node not found: " + str(target_node))
			return false

		match action_type:
			ActionType.PLAY_ANIMATION:
				return _execute_play_animation(target)
			ActionType.MOVE_TO:
				return _execute_move_to(target, scene_root)
			ActionType.LOOK_AT:
				return _execute_look_at(target, scene_root)
			ActionType.EMIT_SIGNAL:
				return _execute_emit_signal(target)
			ActionType.SET_PROPERTY:
				return _execute_set_property(target)
			ActionType.CALL_METHOD:
				return _execute_call_method(target)

		return false

	func _execute_play_animation(target: Node) -> bool:
		var animation_name: String = parameters.get("animation", "")
		var loop: bool = parameters.get("loop", false)

		# Versuche AnimatedSprite2D
		if target is AnimatedSprite2D:
			target.play(animation_name)
			return true

		# Versuche AnimationPlayer
		var anim_player = target.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player is AnimationPlayer:
			if anim_player.has_animation(animation_name):
				anim_player.play(animation_name)
				return true

		# Versuche Sprite-Frames
		if target.has_method("play"):
			target.play(animation_name)
			return true

		push_warning("CharacterAction: Cannot play animation on " + target.name)
		return false

	func _execute_move_to(target: Node, scene_root: Node) -> bool:
		var position: Vector2 = parameters.get("position", Vector2.ZERO)
		var duration: float = parameters.get("duration", 1.0)
		var easing_str: String = parameters.get("easing", "ease_out")

		if not target is Node2D:
			push_warning("CharacterAction: MoveTo requires Node2D target")
			return false

		var tween = scene_root.create_tween()
		var trans = Tween.TRANS_SINE
		var ease_type = Tween.EASE_OUT

		match easing_str:
			"ease_in":
				ease_type = Tween.EASE_IN
			"ease_out":
				ease_type = Tween.EASE_OUT
			"ease_in_out":
				ease_type = Tween.EASE_IN_OUT
			"linear":
				trans = Tween.TRANS_LINEAR

		tween.tween_property(target, "position", position, duration).set_trans(trans).set_ease(ease_type)
		return true

	func _execute_look_at(target: Node, scene_root: Node) -> bool:
		var look_target: Variant = parameters.get("target", Vector2.ZERO)
		var target_node_path: Variant = parameters.get("target_node", null)

		if not target is Node2D:
			push_warning("CharacterAction: LookAt requires Node2D target")
			return false

		var look_position: Vector2

		if target_node_path != null and target_node_path is NodePath:
			var look_node = scene_root.get_node_or_null(target_node_path)
			if look_node and look_node is Node2D:
				look_position = look_node.global_position
			else:
				push_warning("CharacterAction: LookAt target node not found")
				return false
		else:
			look_position = look_target

		# Flip sprite based on direction
		var direction = look_position.x - target.global_position.x
		if target is Sprite2D or target is AnimatedSprite2D:
			target.flip_h = direction < 0
		elif target.has_property("flip_h"):
			target.flip_h = direction < 0

		return true

	func _execute_emit_signal(target: Node) -> bool:
		var signal_name: String = parameters.get("signal_name", "")
		var args: Array = parameters.get("args", [])

		if not target.has_signal(signal_name):
			push_warning("CharacterAction: Signal not found: " + signal_name)
			return false

		target.emit_signal(signal_name, args)
		return true

	func _execute_set_property(target: Node) -> bool:
		var property_name: String = parameters.get("property", "")
		var value: Variant = parameters.get("value", null)

		if property_name.is_empty():
			push_warning("CharacterAction: No property specified")
			return false

		target.set(property_name, value)
		return true

	func _execute_call_method(target: Node) -> bool:
		var method_name: String = parameters.get("method", "")
		var args: Array = parameters.get("args", [])

		if not target.has_method(method_name):
			push_warning("CharacterAction: Method not found: " + method_name)
			return false

		target.callv(method_name, args)
		return true


## Engine-Cutscene Resource
## Definiert eine komplette In-Engine Cutscene mit Kamera-Bewegungen und Charakter-Aktionen
class EngineCutscene extends Resource:
	## Eindeutige ID der Cutscene
	@export var cutscene_id: String = ""
	## Pfad zur Szene die geladen wird (oder leer für aktuelle Szene)
	@export var scene_path: String = ""
	## Alle Kamera-Keyframes
	@export var camera_sequence: Array[CameraKeyframe] = []
	## Alle Charakter-Aktionen
	@export var character_actions: Array[CharacterAction] = []
	## Gesamtlänge der Cutscene in Sekunden
	@export var duration: float = 5.0
	## Soll die Kamera nach der Cutscene zum Spieler zurückkehren?
	@export var return_to_gameplay: bool = true
	## Optional: Pfad zur Subtitle-Datei
	@export var subtitle_file: String = ""
	## Optional: Audio-Datei die während der Cutscene gespielt wird
	@export var audio_file: String = ""
	## Kann übersprungen werden?
	@export var skippable: bool = true
	## Zeige Skip-Warnung?
	@export var show_skip_warning: bool = false

	## Fügt einen Kamera-Keyframe hinzu
	func add_keyframe(timestamp: float, position: Vector2, zoom: Vector2 = Vector2.ONE, easing: EasingType = EasingType.EASE_IN_OUT) -> void:
		var keyframe := CameraKeyframe.new(timestamp, position, zoom, easing)
		camera_sequence.append(keyframe)
		camera_sequence.sort_custom(func(a, b): return a.timestamp < b.timestamp)
		_recalculate_duration()

	## Fügt eine Charakter-Aktion hinzu
	func add_character_action(timestamp: float, target: NodePath, action_type: ActionType, params: Dictionary = {}) -> void:
		var action := CharacterAction.new(timestamp, target, action_type, params)
		character_actions.append(action)
		character_actions.sort_custom(func(a, b): return a.timestamp < b.timestamp)

	## Gibt den Keyframe für einen bestimmten Zeitpunkt zurück
	func get_keyframe_at_time(time: float) -> CameraKeyframe:
		var last_keyframe: CameraKeyframe = null
		for keyframe in camera_sequence:
			if keyframe.timestamp <= time:
				last_keyframe = keyframe
			else:
				break
		return last_keyframe

	## Gibt das nächste Keyframe nach einem Zeitpunkt zurück
	func get_next_keyframe_after(time: float) -> CameraKeyframe:
		for keyframe in camera_sequence:
			if keyframe.timestamp > time:
				return keyframe
		return null

	## Gibt alle Aktionen zurück, die zu einem Zeitpunkt ausgeführt werden sollen
	func get_actions_at_time(time: float, tolerance: float = 0.05) -> Array[CharacterAction]:
		var result: Array[CharacterAction] = []
		for action in character_actions:
			if abs(action.timestamp - time) <= tolerance:
				result.append(action)
		return result

	## Berechnet die Gesamtdauer basierend auf Keyframes neu
	func _recalculate_duration() -> void:
		var max_time: float = 0.0
		for keyframe in camera_sequence:
			var keyframe_end = keyframe.timestamp + keyframe.wait_time
			if keyframe_end > max_time:
				max_time = keyframe_end
		if max_time > duration:
			duration = max_time
