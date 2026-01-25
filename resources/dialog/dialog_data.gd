@tool
extends Resource
class_name DialogData
## Container for a complete dialog sequence

@export var dialog_id: String = ""
@export var entries: Array[DialogEntry] = []
