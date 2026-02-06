@tool
extends Resource
class_name MusicScene

## Definiert eine Musik-Szene: Welche Levels gehoeren zusammen und welche Tracks laufen dort.
## Wenn der Spieler zwischen Levels der gleichen Szene wechselt, spielt die Musik weiter.

## Name der Musik-Szene (z.B. "World1Section1-3")
@export var scene_name: String = ""

## Alle Level-Pfade die zu dieser Szene gehoeren (z.B. "res://worlds/world_1_ruins/...")
@export var level_paths: Array[String] = []

## Tracks die in dieser Szene zufaellig abgespielt werden
@export var tracks: Array[AudioStream] = []
