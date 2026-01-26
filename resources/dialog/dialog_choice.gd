@tool
extends Resource
class_name DialogChoice
## Choice for dialog system - can optionally show a response before ending

@export var choice_text: String = ""
@export var response_speaker: String = ""
@export var response_text: String = ""
