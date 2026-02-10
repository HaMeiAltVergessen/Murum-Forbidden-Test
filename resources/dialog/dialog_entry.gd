@tool
extends Resource
class_name DialogEntry
## Ein einzelner Dialog-Eintrag: Wer spricht, was wird gesagt, gibt es Auswahlmoeglichkeiten?
##
## FELDER:
##   speaker_name:   Name des Sprechers (z.B. "Murum", "Umbra", "Der Eremit")
##                   -> Sprite wird automatisch aus der Character-Registry geholt!
##                   Leer lassen fuer Erzaehltext / Narration.
##   speaker_sprite: OPTIONAL - Ueberschreibt das Registry-Sprite fuer diesen Eintrag.
##                   Normalerweise leer lassen - die Registry regelt das.
##   text:           Der angezeigte Dialogtext.
##   text_speed:     Zeichen pro Sekunde beim Typewriter-Effekt (Standard: 30).
##   choices:        Array von DialogChoice. Leer = Dialog geht zum naechsten Entry.
##                   Gefuellt = Spieler muss eine Option waehlen.

@export var speaker_name: String = ""
@export var speaker_sprite: Texture2D = null
@export var text: String = ""
@export var text_speed: float = 30.0
@export var choices: Array[DialogChoice] = []
