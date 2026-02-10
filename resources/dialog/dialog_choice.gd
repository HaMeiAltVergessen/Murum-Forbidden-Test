@tool
extends Resource
class_name DialogChoice
## Eine Auswahlmoeglichkeit im Dialog.
##
## FELDER:
##   choice_text:      Text der Auswahl-Schaltflaeche (z.B. "Ja, erzaehl mir mehr")
##   response_speaker: Wer antwortet auf diese Wahl (z.B. "Umbra")
##   response_text:    Direkte Antwort auf die Wahl (optional)
##   next_entries:     Weitere DialogEntry-Eintraege die NACH der Antwort folgen.
##                     So verknuepft man Dialog-Abschnitte miteinander!
##
## BEISPIELE:
##   Einfache Antwort (Dialog endet danach):
##     choice_text = "Danke!"
##     response_speaker = "Umbra"
##     response_text = "Gern geschehen."
##     next_entries = []
##
##   Verzweigung (Dialog geht weiter):
##     choice_text = "Erzaehl mir mehr"
##     response_speaker = ""
##     response_text = ""
##     next_entries = [weitere_entry1, weitere_entry2, ...]
##
##   Dialog beenden:
##     choice_text = "Schweigen (...)"
##     (alles andere leer lassen)

@export var choice_text: String = ""
@export var response_speaker: String = ""
@export var response_text: String = ""
@export var next_entries: Array[DialogEntry] = []
