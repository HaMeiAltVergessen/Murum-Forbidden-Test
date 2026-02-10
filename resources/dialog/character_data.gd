@tool
extends Resource
class_name CharacterData
## Definiert einen Charakter fuer das Dialogsystem.
##
## Jeder Charakter hat einen Namen, ein Standard-Sprite und optionale Mood-Sprites.
## Im Inspektor kann man weitere Mood-Sprites hinzufuegen (z.B. "wuetend", "ruhig").
## Wenn mood_sprites gesetzt sind, wird fuers Erste zufaellig eines davon gewaehlt.
## Spaeter kann die Mood-Auswahl an Gameplay-Logik gekoppelt werden.
##
## VERWENDUNG:
##   1. Rechtsklick im FileSystem -> "New Resource" -> "CharacterData"
##   2. Name und default_sprite setzen
##   3. Optional: mood_sprites Dictionary befuellen (Key = Mood-Name, Value = Sprite)
##   4. Die CharacterData-Resource dem DialogManager zuweisen (characters-Array)

## Name des Charakters - muss exakt mit speaker_name in DialogEntry uebereinstimmen
@export var character_name: String = ""

## Standard-Sprite das angezeigt wird wenn kein Mood gesetzt ist
@export var default_sprite: Texture2D = null

## Optionale Mood-Sprites: Key = Mood-Name (z.B. "wuetend"), Value = Texture2D
## Im Inspektor einfach neue Eintraege hinzufuegen.
## Wird fuers Erste zufaellig ausgewaehlt wenn vorhanden.
@export var mood_sprites: Dictionary = {}


## Gibt das passende Sprite zurueck.
## Wenn mood angegeben und vorhanden -> mood_sprite
## Wenn mood_sprites nicht leer und kein mood angegeben -> zufaelliges mood_sprite
## Sonst -> default_sprite
func get_sprite(mood: String = "") -> Texture2D:
	# Bestimmtes Mood angefragt
	if not mood.is_empty() and mood_sprites.has(mood):
		var sprite = mood_sprites[mood]
		if sprite is Texture2D:
			return sprite

	# Zufaelliges Mood-Sprite wenn vorhanden
	if not mood_sprites.is_empty():
		var valid_sprites: Array[Texture2D] = []
		for value in mood_sprites.values():
			if value is Texture2D:
				valid_sprites.append(value)
		if not valid_sprites.is_empty():
			return valid_sprites[randi() % valid_sprites.size()]

	# Fallback: Default-Sprite
	return default_sprite
