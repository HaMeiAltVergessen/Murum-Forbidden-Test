class_name ArenaWaveConfig
extends Resource

## Configuration for a single arena wave.
## Add ArenaEnemyEntry items to define which enemies spawn.

## Enemies to spawn in this wave (each entry = scene + count)
@export var enemies: Array[ArenaEnemyEntry] = []

## Seconds to wait before spawning this wave
@export var delay_before: float = 1.0

## Seconds to wait after this wave is cleared before the next wave
@export var delay_after: float = 2.0
