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

## Run-Kontext-Keys fuer automatisches Mapping (z.B. "w0_combat", "w1_elite", "w2_boss").
## Format: w{welt_index}_{typ} — Typen: combat, elite, treasure, rest, event, boss, shop
## Leer = kein Run-Mapping (nutzt stattdessen level_paths oder force_play_scene).
@export var run_keys: Array[String] = []
