class_name CombatWaveHolder
extends Node

## Holds Inspector-configurable wave configs for combat rooms.
## Add this node as a child of any combat/elite room .tscn.
## RunNodeRoom will use these waves instead of the auto-generated fallback.

## Wave 1 enemies — first wave after entering the room
@export var wave_1: ArenaWaveConfig

## Wave 2 enemies — spawns after wave 1 is cleared
@export var wave_2: ArenaWaveConfig

## Optional wave 3 — for elite rooms or harder encounters
@export var wave_3: ArenaWaveConfig


func get_wave_configs() -> Array[ArenaWaveConfig]:
	"""Returns all non-null wave configs in order."""
	var configs: Array[ArenaWaveConfig] = []
	if wave_1:
		configs.append(wave_1)
	if wave_2:
		configs.append(wave_2)
	if wave_3:
		configs.append(wave_3)
	return configs
