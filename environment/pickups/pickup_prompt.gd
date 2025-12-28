extends Control
## Displays "E - Aufheben" prompt for pickups

@onready var label: Label = $PanelContainer/MarginContainer/Label


func _ready() -> void:
	# Update text based on input device
	_update_prompt_text()


func _update_prompt_text() -> void:
	"""Updates the prompt text"""
	# For now, just use keyboard prompt
	# Could detect gamepad and show "A - Aufheben" instead
	label.text = "E - Aufheben"
