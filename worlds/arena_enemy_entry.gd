class_name ArenaEnemyEntry
extends Resource

## A single enemy type entry for arena wave configuration.
## Used inside ArenaWaveConfig to define which enemies spawn and how many.

## The enemy scene to spawn
@export var scene: PackedScene

## How many of this enemy type to spawn in the wave
@export var count: int = 1
