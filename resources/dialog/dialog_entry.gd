@tool
extends Resource
class_name DialogEntry
## Single dialog entry with speaker, text, and optional choices

@export var speaker_name: String = ""
@export var speaker_sprite: Texture2D = null
@export var text: String = ""
@export var text_speed: float = 30.0
@export var choices: Array[DialogChoice] = []
