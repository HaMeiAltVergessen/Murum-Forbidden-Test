@tool
extends Resource
class_name DialogData
## Container fuer eine komplette Dialog-Sequenz.
##
## ERSTELLEN:
##   Rechtsklick im FileSystem -> "New Resource" -> "DialogData"
##   Speichern unter res://data/dialogs/mein_dialog.tres
##
## AUFBAU:
##   dialog_id: Eindeutiger Name (z.B. "eremit_encounter")
##   entries:   Array von DialogEntry - wird der Reihe nach abgespielt
##
## ABSPIELEN:
##   Per Code:     DialogManager.play_dialog("mein_dialog")
##   Per Trigger:  DialogTrigger in Szene platzieren und diese Resource zuweisen

@export var dialog_id: String = ""
@export var entries: Array[DialogEntry] = []
