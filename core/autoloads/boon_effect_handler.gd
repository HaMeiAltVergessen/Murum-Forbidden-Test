extends Node
## BoonEffectHandler — Executes passive boon effects (T1–T4) via EventBus signals
## Keeps BoonManager clean (data-only) and centralizes gameplay hooks here.

# ============ CONSTANTS ============
const CLONE_SCENE: PackedScene = preload("res://player/abilities/raelear_clone.tscn")
const CLONE_SCENE_COLOR := Color(0.5, 0.3, 0.8, 0.6)  # Raelear purple

# ============ EXPLOSION VFX ============
const VFX_BASE := "res://vfx/placeholder/Free-Animated-Explosions/PNG/"

# ============ PACHRON VFX SCALING ============
## Global multiplier applied to every Pachron/Boon VFX spawned via _spawn_explosion_vfx.
## Call-sites keep their original semantic scale values; this reduces final size only.
const PACHRON_VFX_GLOBAL_SCALE: float = 0.5

# ============ PACHRON VFX SPRITESHEETS ============
const PACHRON_VFX_BASE := "res://Assets/AIPlaceholder/PachronVFX/"
# key: [filename, cols, rows, frame_count, speed]
const PACHRON_VFX := {
	"mur_fire": ["MurT1Fire.png", 3, 1, 3, 12.0],
	"mur_water": ["MurT1Wasser.png", 5, 1, 5, 12.0],
	"mur_earth": ["MurT1Erde.png", 4, 1, 4, 12.0],
	"mur_lightning": ["MurT1Blitz.png", 4, 1, 4, 12.0],
	"mur_t5": ["MurT5.png", 4, 1, 4, 10.0],
	"mur_t5_ring": ["MurT5_2.png", 4, 1, 4, 12.0],
	"arthra_mark": ["Arthra_T2T4Mark.png", 2, 1, 2, 4.0],
	"arthra_meteor": ["ArthraT3.png", 3, 2, 6, 14.0],
	"arthra_chain": ["ArthraT5.png", 3, 2, 6, 14.0],
	"sairias_block": ["SairiasT1.png", 5, 1, 5, 14.0],
	"sairias_reflect": ["SairiasT2.png", 3, 1, 3, 14.0],
	"sairias_pillar": ["SAiriasT4.png", 5, 1, 5, 12.0],
	"noron_light": ["NoronT4Light.png", 5, 1, 5, 14.0],
	"noron_dark": ["NoronT4Dark.png", 5, 1, 5, 14.0],
	"noron_t5": ["NoronT5.png", 2, 2, 4, 10.0],
	"raelear_explosion": ["RealerT1_explosion.png", 5, 1, 5, 14.0],
	"raelear_t5": ["RealearT5_Explosion.png", 5, 1, 5, 14.0],
	"sync_arthra_mur": ["Sync_Arthra+Mur.png", 4, 1, 4, 10.0],
	"sync_arthra_noron": ["Sync_Noron+Arthra.png", 4, 1, 4, 12.0],
	"sync_arthra_sairias": ["Sync_Arthra+Airis.png", 5, 1, 5, 14.0],
	"sync_arthra_raelear": ["Sync_Arthra+Real.png", 5, 1, 5, 14.0],
	"sync_raelear_mur": ["Sync_Realear+Mur.png", 2, 2, 4, 10.0],
	"sync_raelear_noron": ["Sync_Noron+Real.png", 4, 1, 4, 12.0],
	"sync_raelear_sairias": ["Sync_Ariris+Realer.png", 5, 1, 5, 14.0],
	"sync_murrum_noron": ["Sync_Noron+Mur.png", 4, 1, 4, 12.0],
	"sync_murrum_sairias": ["Sync_Airis+Mur.png", 5, 1, 5, 14.0],
	"sync_noron_sairias": ["Sync_Airis+Noron.png", 4, 1, 4, 10.0],
}

# Path -> [primary_key, secondary_key]
const PATH_VFX := {
	"noron": ["noron_light", "noron_dark"],
	"arthra": ["arthra_chain", "arthra_meteor"],
	"sairias": ["sairias_block", "sairias_reflect"],
	"murrum": ["mur_t5_ring", "mur_fire"],
	"raelear": ["raelear_explosion", "raelear_t5"],
}

# Murrum element -> Pachron VFX key
const ELEMENT_VFX := {
	"fire": "mur_fire",
	"water": "mur_water",
	"earth": "mur_earth",
	"lightning": "mur_lightning",
}

# Element colors for fallback VFX when sprites not cached
const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.4, 0.1, 0.9),
	"water": Color(0.2, 0.5, 1.0, 0.9),
	"earth": Color(0.6, 0.4, 0.15, 0.9),
	"lightning": Color(0.8, 0.9, 1.0, 0.9),
}
const MURRUM_COLOR := Color(0.2, 0.7, 0.9, 0.8)  # Mur|rum path color

# Lightning (electro-shock) frames for Arthra T1
const LIGHTNING_VFX_PATH := "res://Assets/Placeholder/Legacy Collection/Assets/Misc/Grotto-escape-2-FX/sprites/electro-shock/"
const LIGHTNING_FRAME_COUNT: int = 9

var _vfx_cache: Dictionary = {}  # folder_key -> SpriteFrames
var _lightning_frames: SpriteFrames = null

# ============ NORON T1 STATE ============
var _twilight_blades_active: bool = false
var _twilight_blades_node: Node2D = null
var _blade_rotation: float = 0.0

# ============ NORON T4 STATE ============
var _kill_explosion_toggle: bool = false  # Alternates light/dark
var _kill_explosion_active: bool = false  # Re-entrancy guard to prevent overflow

# ============ MURRUM T2 DOT TRACKING ============
var _dot_targets: Array = []  # Array of {enemy, timer, dps}

# ============ RAELEAR CLONE TRACKING ============
var _active_clones: Array = []  # Track active clones for max limit

# ============ STAFF TRACKING ============
var _staff_projectile: Node = null  # Reference to active staff projectile

# ============ SYNC SKILL STATE ============
var _sync_urteil_clone_cooldown: float = 0.0       # Arthra×Raelear: cooldown for urteil-death clones
var _sync_lightning_toggle: bool = false             # Arthra×Noron: alternates light/dark lightning
var _sync_block_charge: int = 0                      # Murrum×Sairias: blocks stored for element burst
var _sync_guardian_shield_active: bool = false        # Noron×Sairias: twilight shield active
var _sync_guardian_shield_timer: float = 0.0         # Noron×Sairias: shield remaining duration
var _sync_clone_absorb_cooldown: float = 0.0         # Raelear×Sairias: hit absorption cooldown
var _sync_element_cycle_timer: float = 0.0           # Murrum×Noron: blade element cycle timer
var _sync_current_blade_element: String = "fire"     # Murrum×Noron: current element on blades
var _sync_clone_light_toggle: bool = false            # Raelear×Noron: alternates light/dark clones


func _ready() -> void:
	# Connect to EventBus signals — T1/T2
	EventBus.combo_increased.connect(_on_combo_increased)
	EventBus.combo_finisher_executed.connect(_on_combo_finisher_executed)
	EventBus.combo_broken.connect(_on_combo_broken)
	EventBus.dodge_completed.connect(_on_dodge_completed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.attack_blocked.connect(_on_attack_blocked)
	EventBus.perfect_parry_executed.connect(_on_perfect_parry_executed)

	# T3/T4 signals
	EventBus.wolkenbruch_impact.connect(_on_wolkenbruch_impact)

	# Raelear T4: every attack spawns clone
	EventBus.player_attacked.connect(_on_player_attacked_raelear)

	# Raelear T3: mirror abilities
	EventBus.wolkenbruch_impact.connect(_on_wolkenbruch_for_mirror)
	EventBus.machtbruch_released.connect(_on_machtbruch_for_mirror)
	EventBus.machtstoss_activated.connect(_on_machtstoss_for_mirror)

	# Staff signals
	EventBus.staff_thrown.connect(_on_staff_thrown)
	EventBus.staff_caught.connect(_on_staff_caught)
	EventBus.staff_hit_enemy.connect(_on_staff_hit_enemy)

	_preload_vfx()
	_preload_pachron_vfx()
	_preload_lightning_vfx()
	print("[BoonEffectHandler] Initialized")


func _process(delta: float) -> void:
	# Noron T1: rotate blades
	if _twilight_blades_active and _twilight_blades_node and is_instance_valid(_twilight_blades_node):
		_blade_rotation += delta * 3.0  # Rotation speed
		_twilight_blades_node.rotation = _blade_rotation

		# If staff is thrown, blades orbit the staff instead of the player
		if _staff_projectile and is_instance_valid(_staff_projectile):
			_twilight_blades_node.global_position = _staff_projectile.global_position
		else:
			_twilight_blades_node.position = Vector2.ZERO  # Reset to player center

		_process_blade_damage(delta)

	# Staff boon effects (while staff is in flight)
	if _staff_projectile and is_instance_valid(_staff_projectile) and _is_in_run():
		_process_staff_boons(delta)

	# Murrum T2: process DoTs
	_process_dots(delta)

	# Sync skill process effects
	_process_sync_effects(delta)


# ============ COMBO INCREASED HANDLER (Arthra T1 + Raelear T1) ============
func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	if not _is_in_run():
		return

	# Noron T1: activate blades during combo
	if BoonManager.has_boon("noron", 1) and not _twilight_blades_active:
		_activate_twilight_blades()

	# Arthra T1: Lightning every 3rd hit
	if BoonManager.has_boon("arthra", 1):
		var every_n: int = BoonManager.get_scaled_param("arthra", 1, "every_n_hits", 3)
		if new_count % every_n == 0:
			var player = _get_player()
			if player:
				var bonus_pct: float = BoonManager.get_scaled_param("arthra", 1, "bonus_damage_percent", 0.3)
				var base_damage: int = 20
				var total_damage: int = int(base_damage * (1.0 + bonus_pct))
				var nearest: Node = _get_nearest_enemy(player.global_position, 300.0)
				if nearest and nearest.has_method("take_damage"):
					# Sync 3: Arthra×Noron — lightning alternates light/dark
					if SyncSkillManager and SyncSkillManager.has_sync("arthra_noron"):
						total_damage = _sync_twilight_wrath_modify_lightning(total_damage, player)

					nearest.take_damage(total_damage, player)
					_spawn_lightning_vfx(nearest.global_position)

					# Sync 2: Arthra×Murrum — lightning creates element zone
					if SyncSkillManager and SyncSkillManager.has_sync("arthra_murrum"):
						_sync_storm_fire_zone(nearest.global_position)

					print("[BoonEffect] Arthra T1: Lightning strike! %d damage on %s" % [total_damage, nearest.name])

	# Raelear T1: Clone every 3rd hit (skip if T4 active — T4 spawns on every attack)
	if BoonManager.has_boon("raelear", 1) and not BoonManager.has_boon("raelear", 4):
		if new_count % 3 == 0:
			var player = _get_player()
			if player:
				_spawn_raelear_clone(player.global_position)
				print("[BoonEffect] Raelear T1: Combo clone at hit %d" % new_count)


# ============ RAELEAR T1 (legacy dodge handler — no longer spawns clones) ============
func _on_dodge_completed() -> void:
	pass


# ============ RAELEAR T4: ARMEE DER VERZWEIFLUNG (Every Attack Clone) ============
func _on_player_attacked_raelear(_attack_number: int) -> void:
	"""T4: Every attack spawns a clone."""
	if not BoonManager.has_boon("raelear", 4):
		return
	if not BoonManager.has_boon("raelear", 1):
		return  # Need at least T1
	if not _is_in_run():
		return

	var player = _get_player()
	if not player:
		return

	_spawn_raelear_clone(player.global_position)


# ============ RAELEAR T2: SCHATTEN DER FINSTERNIS (Death Clone) ============
func _on_enemy_died(enemy: Node, position: Vector2) -> void:
	if not _is_in_run():
		return

	# Arthra T5: Urteil chain — if marked enemy died, mark nearby enemies
	if BoonManager.has_boon("arthra", 5) and is_instance_valid(enemy):
		if enemy.has_meta("urteil_marked"):
			_arthra_t5_chain_urteil(position)

	# Noron T4: Kill explosion (alternating light/dark) — guard against recursion
	if BoonManager.has_boon("noron", 4) and not _kill_explosion_active:
		_spawn_kill_explosion(position)

	# Sync 1: Arthra×Raelear — Urteil death spawns clone
	if SyncSkillManager and SyncSkillManager.has_sync("arthra_raelear"):
		if is_instance_valid(enemy) and enemy.has_meta("urteil_marked"):
			if _sync_urteil_clone_cooldown <= 0.0:
				_spawn_raelear_clone(position)
				_sync_urteil_clone_cooldown = SyncSkillManager.get_sync_param("arthra_raelear", "extra_clone_cooldown", 1.0)
				_spawn_explosion_vfx(position, "sync_arthra_raelear", 0.8)
				print("[SyncEffect] Arthra×Raelear: Urteil-death clone at %v" % position)

	# Sync 2: Arthra×Murrum — Elemental kill triggers bonus lightning
	if SyncSkillManager and SyncSkillManager.has_sync("arthra_murrum"):
		if is_instance_valid(enemy) and enemy.has_meta("dot_original_modulate"):
			# Enemy had elemental DoT = elemental kill
			_sync_storm_fire_bonus_lightning(position)

	# Raelear T2: Death clone
	if not BoonManager.has_boon("raelear", 2):
		return

	_spawn_raelear_clone(position)
	_spawn_raelear_vfx(position, 60.0)
	print("[BoonEffect] Raelear T2: Death clone at %v" % position)


# ============ RAELEAR T3: SPIEGELUNG (Mirror Abilities) ============
func _on_ability_used_raelear(ability_name: String) -> void:
	if not BoonManager.has_boon("raelear", 3):
		return
	if not _is_in_run():
		return

	_cleanup_dead_clones()
	var dmg_pct: float = BoonManager.get_scaled_param("raelear", 3, "damage_percent", 0.5)
	for clone in _active_clones:
		if is_instance_valid(clone) and clone.has_method("mirror_ability"):
			clone.mirror_ability(ability_name, dmg_pct)


func _on_wolkenbruch_for_mirror(_powered: bool) -> void:
	_on_ability_used_raelear("wolkenbruch")


func _on_machtbruch_for_mirror(_tier: int, _damage: int, _radius: float) -> void:
	_on_ability_used_raelear("machtbruch")


func _on_machtstoss_for_mirror(_position: Vector2) -> void:
	_on_ability_used_raelear("machtstoss")


# ============ MURRUM T1: ELEMENT-FINISHER ============
func _on_combo_finisher_executed(_combo_count: int) -> void:
	if not _is_in_run():
		return

	if not BoonManager.has_boon("murrum", 1):
		return

	var player = _get_player()
	if not player:
		return

	var elements: Array = BoonManager.get_param("murrum", 1, "elements", ["fire", "water", "earth", "lightning"])
	var bonus_damage: int = BoonManager.get_scaled_param("murrum", 1, "bonus_damage", 15)
	var element: String = elements[randi() % elements.size()]

	# AoE around player
	var radius: float = 120.0
	var enemies: Array = _get_enemies_in_radius(player.global_position, radius)

	var total_elemental_damage: int = 0
	for enemy in enemies:
		enemy.take_damage(bonus_damage, player)
		total_elemental_damage += bonus_damage
		# Murrum T2: apply DoT
		if BoonManager.has_boon("murrum", 2):
			_apply_dot(enemy)

	# Murrum T5: Elemental lifesteal
	if BoonManager.has_boon("murrum", 5) and total_elemental_damage > 0:
		_murrum_t5_lifesteal(player, total_elemental_damage)

	# Murrum T1: extra-kompaktes VFX (auf 25% des Originals skaliert)
	_spawn_element_vfx(player.global_position, element, 1.0)
	print("[BoonEffect] Murrum T1: %s finisher! %d enemies hit" % [element, enemies.size()])


# ============ NORON T1: KLINGEN DES ZWIELICHTS ============
func _on_combo_broken(_final_count: int) -> void:
	_deactivate_twilight_blades()


func _activate_twilight_blades() -> void:
	if _twilight_blades_active:
		return

	var player = _get_player()
	if not player:
		return

	_twilight_blades_active = true
	_twilight_blades_node = Node2D.new()
	_twilight_blades_node.name = "TwilightBlades"
	player.add_child(_twilight_blades_node)

	var blade_radius: float = BoonManager.get_scaled_param("noron", 1, "blade_radius", 80)

	# Create 2 blade visuals (light + dark) using Noron crescent sprites
	var light_tex := _get_blade_atlas(PACHRON_VFX_BASE + "NoronT1Light.png", 4, 2)
	var dark_tex := _get_blade_atlas(PACHRON_VFX_BASE + "NoronT1Dark.png", 4, 2)

	for i in range(2):
		var blade := Sprite2D.new()
		blade.name = "Blade_%d" % i
		blade.scale = Vector2(0.5, 0.5)
		var angle: float = i * PI  # Opposite sides
		blade.position = Vector2(cos(angle), sin(angle)) * blade_radius

		if i == 0:
			blade.texture = light_tex
			blade.modulate = Color(1.0, 1.0, 0.8, 0.8)  # Light blade
		else:
			blade.texture = dark_tex
			blade.modulate = Color(0.5, 0.2, 0.6, 0.8)  # Dark blade
		_twilight_blades_node.add_child(blade)

	print("[BoonEffect] Noron T1: Twilight blades activated")


func _deactivate_twilight_blades() -> void:
	if not _twilight_blades_active:
		return
	_twilight_blades_active = false
	if _twilight_blades_node and is_instance_valid(_twilight_blades_node):
		_twilight_blades_node.queue_free()
	_twilight_blades_node = null


func _process_blade_damage(delta: float) -> void:
	"""Deals damage to enemies near the orbiting blades (tick-based)"""
	# Only damage every 0.5s
	if not _twilight_blades_node:
		return

	var player = _get_player()
	if not player:
		return

	# Use a meta counter for tick rate
	var tick: float = _twilight_blades_node.get_meta("tick", 0.0) + delta
	_twilight_blades_node.set_meta("tick", tick)
	if tick < 0.5:
		return
	_twilight_blades_node.set_meta("tick", 0.0)

	var blade_dmg: int = BoonManager.get_scaled_param("noron", 1, "blade_damage", 8)
	var blade_radius: float = BoonManager.get_scaled_param("noron", 1, "blade_radius", 80)

	# Noron T3 bonus
	if BoonManager.has_boon("noron", 3):
		var bonus_pct: float = BoonManager.get_scaled_param("noron", 3, "blade_damage_bonus_percent", 0.3)
		blade_dmg = int(blade_dmg * (1.0 + bonus_pct))

	# Blade damage center: staff position if thrown, player position otherwise
	var blade_center: Vector2 = player.global_position
	if _staff_projectile and is_instance_valid(_staff_projectile):
		blade_center = _staff_projectile.global_position

	var enemies: Array = _get_enemies_in_radius(blade_center, blade_radius + 20.0)
	for enemy in enemies:
		enemy.take_damage(blade_dmg, player)

		# Noron T3: Light heals HP, Dark heals Mana (alternating)
		if BoonManager.has_boon("noron", 3):
			_noron_t3_blade_heal(player)

		# Sync 3: Arthra×Noron — every blade hit triggers mini-lightning
		if SyncSkillManager and SyncSkillManager.has_sync("arthra_noron"):
			_sync_twilight_wrath_blade_lightning(enemy)

		# Sync 8: Murrum×Noron — blade hits deal current element + DoT
		if SyncSkillManager and SyncSkillManager.has_sync("murrum_noron"):
			_sync_prism_blade_element_hit(enemy, player)


func _noron_t3_blade_heal(player: Node) -> void:
	"""Noron T3: Blades heal HP (light) and Mana (dark) on hit"""
	var light_heal: int = BoonManager.get_scaled_param("noron", 3, "light_heal_per_hit", 3)
	var dark_mana: int = BoonManager.get_scaled_param("noron", 3, "dark_mana_per_hit", 3)

	# Alternate between light and dark heal
	var toggle: bool = _twilight_blades_node.get_meta("heal_toggle", false)
	_twilight_blades_node.set_meta("heal_toggle", not toggle)

	if toggle:
		# Light blade: heal HP
		var health = player.get_node_or_null("HealthComponent")
		if health and health.has_method("heal"):
			health.heal(light_heal)
	else:
		# Dark blade: heal Mana
		var mana = player.get_node_or_null("ManaComponent")
		if mana:
			mana.current_mana = minf(mana.current_mana + dark_mana, mana.max_mana)
			mana.mana_changed.emit(mana.current_mana, mana.max_mana)


# ============ ENEMY DAMAGED HANDLER (multiple boons) ============
func _on_enemy_damaged(enemy: Node, _damage: int) -> void:
	if not _is_in_run():
		return
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.get("is_destroyed") or enemy.get("is_dead"):
		return

	# Noron T2: Worte des Wahns — 15% confusion
	if BoonManager.has_boon("noron", 2):
		var chance: float = BoonManager.get_scaled_param("noron", 2, "chance_percent", 0.15)
		if randf() <= chance:
			var duration: float = BoonManager.get_scaled_param("noron", 2, "confusion_duration", 3.0)
			_apply_confusion(enemy, duration)

	# Arthra T4: Richter des Todes — auto Urteil mark on hit
	if BoonManager.has_boon("arthra", 4):
		_apply_auto_urteil(enemy)

	# Murrum T3: Elementare Überladung — +20% extra elemental damage on all hits
	var elemental_damage_dealt: int = 0
	if BoonManager.has_boon("murrum", 3):
		var bonus_pct: float = BoonManager.get_scaled_param("murrum", 3, "bonus_damage_percent", 0.2)
		var extra_dmg: int = int(_damage * bonus_pct)
		if extra_dmg > 0:
			enemy.take_damage(extra_dmg, _get_player())
			elemental_damage_dealt += extra_dmg
			# VFX: small element flash on enemy
			_spawn_element_hit_vfx(enemy.global_position, 0.5)
			# Murrum T2: DoT from elemental damage
			if BoonManager.has_boon("murrum", 2):
				_apply_dot(enemy)

	# Murrum T4: Herr der Elemente — all 4 elements as extra damage
	if BoonManager.has_boon("murrum", 4):
		var per_element: int = BoonManager.get_scaled_param("murrum", 4, "per_element_damage", 5)
		var total: int = per_element * 4
		enemy.take_damage(total, _get_player())
		elemental_damage_dealt += total
		# VFX: 4-element burst around enemy
		_spawn_multi_element_vfx(enemy.global_position)

	# Murrum T5: Elemental lifesteal from T3/T4 damage
	if BoonManager.has_boon("murrum", 5) and elemental_damage_dealt > 0:
		var player = _get_player()
		if player:
			_murrum_t5_lifesteal(player, elemental_damage_dealt)
			# VFX: heal glow on player
			_spawn_lifesteal_vfx(player.global_position)

	# Noron T4: enemies 20% slower (applied once via meta)
	if BoonManager.has_boon("noron", 4):
		if not enemy.has_meta("noron_slowed"):
			enemy.set_meta("noron_slowed", true)
			var slow_pct: float = BoonManager.get_scaled_param("noron", 4, "enemy_slow_percent", 0.2)
			if "move_speed" in enemy:
				enemy.move_speed *= (1.0 - slow_pct)


# ============ ARTHRA T3: URTEIL DER STERNE (Wolkenbruch Meteors) ============
func _on_wolkenbruch_impact(_powered: bool) -> void:
	if not BoonManager.has_boon("arthra", 3):
		return
	if not _is_in_run():
		return

	var player = _get_player()
	if not player:
		return

	var meteor_count: int = BoonManager.get_scaled_param("arthra", 3, "meteor_count", 3)
	var dmg_mult: float = BoonManager.get_scaled_param("arthra", 3, "damage_multiplier", 2.0)
	var radius: float = BoonManager.get_scaled_param("arthra", 3, "radius", 150)
	var base_damage: int = 30
	var meteor_damage: int = int(base_damage * dmg_mult)

	# Spawn meteors at staff position if thrown, otherwise around player
	var meteor_center: Vector2 = player.global_position
	if _staff_projectile and is_instance_valid(_staff_projectile):
		meteor_center = _staff_projectile.global_position

	for i in range(meteor_count):
		var offset := Vector2(randf_range(-200, 200), randf_range(-200, 200))
		var target_pos: Vector2 = meteor_center + offset

		# Delayed meteor impact
		get_tree().create_timer(0.3 + i * 0.2).timeout.connect(func():
			var enemies: Array = _get_enemies_in_radius(target_pos, radius)
			for enemy in enemies:
				enemy.take_damage(meteor_damage, player)
			_spawn_meteor_vfx(target_pos, radius)
		)

	print("[BoonEffect] Arthra T3: %d meteors spawning! (%d damage each)" % [meteor_count, meteor_damage])


# ============ ARTHRA T4: RICHTER DES TODES (Auto-Urteil) ============
func _apply_auto_urteil(enemy: Node) -> void:
	"""Automatically applies Urteil mark on hit"""
	if not is_instance_valid(enemy):
		return
	if enemy.has_meta("urteil_marked"):
		return  # Already marked

	enemy.set_meta("urteil_marked", true)
	# Find Urteil system to set as marker
	var player = _get_player()
	if player:
		var urteil = player.get_node_or_null("CombatSystem/Urteil")
		if urteil:
			enemy.set_meta("urteil_marker", urteil)

	# Visual mark (arthra mark sprite above enemy)
	_spawn_explosion_vfx(enemy.global_position + Vector2(0, -60), "arthra_mark", 0.4, Color(1.0, 0.8, 0.4))

	print("[BoonEffect] Arthra T4: Auto-Urteil on %s" % enemy.name)


# ============ NORON T4: NORONS WAHNSINN (Kill Explosions) ============
func _spawn_kill_explosion(position: Vector2) -> void:
	"""Spawns alternating light/dark explosion on kill"""
	var player = _get_player()
	if not player:
		return

	_kill_explosion_active = true

	var dmg: int = BoonManager.get_scaled_param("noron", 4, "kill_explosion_damage", 30)
	var radius: float = BoonManager.get_scaled_param("noron", 4, "kill_explosion_radius", 120)

	var enemies: Array = _get_enemies_in_radius(position, radius)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(dmg, player)

	# Alternate light/dark explosion
	_spawn_noron_vfx(position, radius, _kill_explosion_toggle)
	_kill_explosion_toggle = not _kill_explosion_toggle

	_kill_explosion_active = false
	print("[BoonEffect] Noron T4: Kill explosion! %d enemies hit" % enemies.size())


# ============ SAIRIAS T3: HIMMEL UND ERDE (Block Launch/Slam) ============
func _block_launch_slam(enemy: Node) -> void:
	"""Launches grounded enemies, slams airborne enemies"""
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return

	var launch_force: float = BoonManager.get_scaled_param("sairias", 3, "launch_force", 400)
	var slam_damage: int = BoonManager.get_scaled_param("sairias", 3, "slam_damage", 20)

	if enemy.has_method("is_on_floor") and enemy.is_on_floor():
		# Launch upward
		if enemy is CharacterBody2D:
			enemy.velocity.y = -launch_force
		if enemy.has_method("enter_juggle_state"):
			enemy.enter_juggle_state()
		print("[BoonEffect] Sairias T3: Launched %s" % enemy.name)
	else:
		# Slam down + damage
		if enemy is CharacterBody2D:
			enemy.velocity.y = launch_force
		enemy.take_damage(slam_damage, _get_player())
		print("[BoonEffect] Sairias T3: Slammed %s for %d" % [enemy.name, slam_damage])


# ============ SAIRIAS T4: SÄULEN DER SCHÖPFUNG (Parry Light Pillars) ============
func _spawn_light_pillars(center: Vector2) -> void:
	"""Spawns light pillars around player on perfect parry"""
	var player = _get_player()
	if not player:
		return

	var pillar_count: int = BoonManager.get_scaled_param("sairias", 4, "pillar_count", 3)
	var pillar_dmg: int = BoonManager.get_scaled_param("sairias", 4, "pillar_damage", 40)
	var pillar_radius: float = BoonManager.get_scaled_param("sairias", 4, "pillar_radius", 60)
	var spawn_range: float = BoonManager.get_scaled_param("sairias", 4, "spawn_range", 200)

	for i in range(pillar_count):
		var offset := Vector2(randf_range(-spawn_range, spawn_range), randf_range(-spawn_range, spawn_range))
		var pillar_pos: Vector2 = center + offset

		# Delayed pillar impact
		get_tree().create_timer(0.1 + i * 0.15).timeout.connect(func():
			var enemies: Array = _get_enemies_in_radius(pillar_pos, pillar_radius)
			for enemy in enemies:
				enemy.take_damage(pillar_dmg, player)
			_spawn_pillar_vfx(pillar_pos, pillar_radius)
		)

	print("[BoonEffect] Sairias T4: %d light pillars!" % pillar_count)


# ============ SAIRIAS T1: UMLEITUNG (Block AoE) ============
func _on_attack_blocked(enemy: Node, _damage_reduction: float) -> void:
	if not _is_in_run():
		return
	_trigger_block_effects(enemy)


func _trigger_block_effects(enemy: Node) -> void:
	"""Shared body for Sairias T1/T3 + Sync 9. Called from both normal block
	and perfect parry so T1 AoE/T3 Launch/Sync9 charge are not lost on quick taps."""
	var player = _get_player()
	if not player:
		return

	# Sairias T1: Block AoE damage
	if BoonManager.has_boon("sairias", 1):
		var aoe_damage: int = BoonManager.get_scaled_param("sairias", 1, "block_aoe_damage", 10)
		var aoe_radius: float = BoonManager.get_scaled_param("sairias", 1, "block_aoe_radius", 100)

		# Sync 4: Arthra×Sairias — kill stacks boost block AoE
		if SyncSkillManager and SyncSkillManager.has_sync("arthra_sairias"):
			aoe_damage = int(aoe_damage * (1.0 + BoonManager.arthra_kill_bonus))

		var enemies: Array = _get_enemies_in_radius(player.global_position, aoe_radius)
		for e in enemies:
			e.take_damage(aoe_damage, player)

		_spawn_block_aoe_vfx(player.global_position, aoe_radius)
		print("[BoonEffect] Sairias T1: Block AoE! %d enemies hit for %d" % [enemies.size(), aoe_damage])

	# Sync 9: Murrum×Sairias — charge element burst on block
	if SyncSkillManager and SyncSkillManager.has_sync("murrum_sairias"):
		_sync_elemental_counter_block()

	# Sairias T3: Himmel und Erde — launch/slam blocked enemy
	if BoonManager.has_boon("sairias", 3) and is_instance_valid(enemy):
		_block_launch_slam(enemy)


# ============ SAIRIAS T2: PERFEKTE UMLEITUNG (Parry Reflect) ============
func _on_perfect_parry_executed(enemy: Node) -> void:
	if not _is_in_run():
		return

	# Activate Noron T1 blades on parry too (attacking = parrying)
	if BoonManager.has_boon("noron", 1) and not _twilight_blades_active:
		_activate_twilight_blades()

	var player = _get_player()

	# Sairias T2: Reflect damage
	if BoonManager.has_boon("sairias", 2) and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var reflect_damage: int = 0
		if "attack_damage" in enemy:
			reflect_damage = enemy.attack_damage
		else:
			reflect_damage = 20  # Fallback

		enemy.take_damage(reflect_damage, player)

		_spawn_reflect_vfx(enemy.global_position)
		print("[BoonEffect] Sairias T2: Parry reflect! %d damage to %s" % [reflect_damage, enemy.name])

	# Sairias T4: Säulen der Schöpfung — light pillars on parry
	if BoonManager.has_boon("sairias", 4) and player:
		_spawn_light_pillars(player.global_position)

	# Sairias T5: Unbrechbar — perfect parry heals 10% max HP
	if BoonManager.has_boon("sairias", 5) and player:
		var heal_pct: float = BoonManager.get_scaled_param("sairias", 5, "parry_heal_percent", 0.1)
		var health = player.get_node_or_null("HealthComponent")
		if health and health.has_method("heal"):
			var heal_amount: int = int(health.max_health * heal_pct)
			health.heal(heal_amount)
			print("[BoonEffect] Sairias T5: Parry heal +%d HP" % heal_amount)

		# T5 heal VFX: golden radial burst around player
		_spawn_explosion_vfx(player.global_position, "sairias_block", 1.8, Color(1.2, 1.1, 0.7))
		_spawn_explosion_vfx(player.global_position + Vector2(0, -40), "sairias_pillar", 1.2, Color(1.0, 0.95, 0.6))

	# Perfect Parry also triggers T1 AoE, T3 Launch/Slam, Sync 9 charge
	# (a perfect parry is a "perfect block" — should include all block rewards)
	_trigger_block_effects(enemy)

	# Sync 4: Arthra×Sairias — parry triggers lightning storm
	if SyncSkillManager and SyncSkillManager.has_sync("arthra_sairias") and player:
		_sync_thunder_retribution_storm(player.global_position)

	# Sync 7: Raelear×Sairias — parry makes all clones dash+explode on enemy
	if SyncSkillManager and SyncSkillManager.has_sync("raelear_sairias") and is_instance_valid(enemy):
		_sync_phantom_counter_parry(enemy)

	# Sync 9: Murrum×Sairias — parry triggers element nova
	if SyncSkillManager and SyncSkillManager.has_sync("murrum_sairias") and player:
		_sync_elemental_counter_nova(player.global_position)

	# Sync 10: Noron×Sairias — parry creates twilight shield
	if SyncSkillManager and SyncSkillManager.has_sync("noron_sairias") and player:
		_sync_eternal_guardian_activate()


# ============ T5 CAPSTONE EFFECTS ============

# -- Noron T5: Ewige Dämmerung — counter explosion on miss --
func noron_t5_counter(pos: Vector2) -> void:
	"""Called from HurtboxComponent when Noron T5 miss triggers"""
	var counter_dmg: int = BoonManager.get_scaled_param("noron", 5, "counter_explosion_damage", 50)
	var counter_radius: float = BoonManager.get_scaled_param("noron", 5, "counter_explosion_radius", 150)

	var player = _get_player()
	var enemies: Array = _get_enemies_in_radius(pos, counter_radius)
	for enemy in enemies:
		enemy.take_damage(counter_dmg, player)

	_spawn_explosion_vfx(pos, "noron_t5", counter_radius / 80.0)
	print("[BoonEffect] Noron T5: Counter explosion! %d enemies hit for %d" % [enemies.size(), counter_dmg])


# -- Raelear T5: Clone Death Save --
func consume_clone_for_death_save(player_pos: Vector2) -> void:
	"""Called from Murum when death save triggers — destroys nearest clone"""
	_cleanup_dead_clones()
	if _active_clones.is_empty():
		_spawn_raelear_vfx(player_pos, 60.0)
		return

	# Find and destroy nearest clone
	var nearest_clone: Node2D = null
	var nearest_dist: float = INF
	for clone in _active_clones:
		if is_instance_valid(clone):
			var dist: float = clone.global_position.distance_to(player_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_clone = clone

	if nearest_clone:
		_spawn_raelear_vfx(nearest_clone.global_position, 80.0)
		if nearest_clone is RaelearClone:
			nearest_clone.is_dead = true
		nearest_clone.queue_free()
		_active_clones.erase(nearest_clone)
		print("[BoonEffect] Raelear T5: Clone sacrificed!")


# -- Murrum T5: Ewiges Element — elemental damage heals HP + Mana --
func _murrum_t5_lifesteal(player: Node, elemental_damage: int) -> void:
	var heal_pct: float = BoonManager.get_scaled_param("murrum", 5, "heal_percent", 0.02)
	var mana_pct: float = BoonManager.get_scaled_param("murrum", 5, "mana_percent", 0.02)

	var health = player.get_node_or_null("HealthComponent")
	if health and health.has_method("heal"):
		var heal: int = maxi(1, int(elemental_damage * heal_pct * 10))  # Scale with damage
		health.heal(heal)

	var mana = player.get_node_or_null("ManaComponent")
	if mana:
		var mana_restore: float = maxf(1.0, elemental_damage * mana_pct * 10)
		mana.current_mana = minf(mana.current_mana + mana_restore, mana.max_mana)
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)


# -- Arthra T5: Urteil Chain — explosion on marked enemy applies marks to nearby --
func _arthra_t5_chain_urteil(position: Vector2) -> void:
	"""When an Urteil-marked enemy dies and explodes, mark all nearby enemies too"""
	var chain_radius: float = BoonManager.get_scaled_param("arthra", 5, "chain_radius", 200)
	var enemies: Array = _get_enemies_in_radius(position, chain_radius)

	for enemy in enemies:
		if not enemy.has_meta("urteil_marked"):
			_apply_auto_urteil(enemy)

	if not enemies.is_empty():
		print("[BoonEffect] Arthra T5: Urteil chain! %d enemies marked" % enemies.size())


# ============ STAFF BOON INTERACTIONS ============
func _on_staff_thrown(staff_proj: Node) -> void:
	_staff_projectile = staff_proj

	# Murrum T3: start element trail tracking
	if BoonManager.has_boon("murrum", 3) and staff_proj:
		staff_proj.set_meta("trail_tick", 0.0)

func _on_staff_caught() -> void:
	_staff_projectile = null

	# Reset blade position to player center (in case they were following staff)
	if _twilight_blades_active and _twilight_blades_node and is_instance_valid(_twilight_blades_node):
		_twilight_blades_node.position = Vector2.ZERO

func _on_staff_hit_enemy(enemy: Node, staff_state: int, staff_pos: Vector2) -> void:
	if not _is_in_run():
		return
	if not is_instance_valid(enemy):
		return

	# Noron T2: 100% confusion during staff rotation (instead of 15%)
	if BoonManager.has_boon("noron", 2) and staff_state == 1:  # 1 = ROTATING_AT_END
		var duration: float = BoonManager.get_scaled_param("noron", 2, "confusion_duration", 3.0)
		_apply_confusion(enemy, duration)
		print("[BoonEffect] Noron T2 + Staff: Guaranteed confusion on %s" % enemy.name)

	# Sairias T3: staff return launches enemies upward
	if BoonManager.has_boon("sairias", 3) and staff_state == 2:  # 2 = RETURNING
		if enemy is CharacterBody2D:
			var launch_force: float = BoonManager.get_scaled_param("sairias", 3, "launch_force", 400)
			enemy.velocity.y = -launch_force
			if enemy.has_method("enter_juggle_state"):
				enemy.enter_juggle_state()
			_spawn_explosion_vfx(enemy.global_position, PATH_VFX["sairias"][0], 0.4)
			print("[BoonEffect] Sairias T3 + Staff: Launched %s on return" % enemy.name)

	# Raelear T2: staff kill spawns clone at staff position (instead of enemy death pos)
	# Handled in _on_enemy_died via _staff_projectile reference


# ============ STAFF PROCESS EFFECTS (per-frame while staff is in flight) ============
func _process_staff_boons(delta: float) -> void:
	var staff_pos: Vector2 = _staff_projectile.global_position
	var player = _get_player()

	# Sairias T1: Staff destroys enemy projectiles in flight
	if BoonManager.has_boon("sairias", 1):
		var projectiles = get_tree().get_nodes_in_group("enemy_attacks")
		for proj in projectiles:
			if not is_instance_valid(proj) or proj == _staff_projectile:
				continue
			if proj.global_position.distance_to(staff_pos) < 50.0:
				_spawn_explosion_vfx(proj.global_position, PATH_VFX["sairias"][1], 0.3)
				proj.queue_free()
				print("[BoonEffect] Sairias T1 + Staff: Blocked projectile")

	# Murrum T3: Element trail along staff flight path (every 0.15s)
	if BoonManager.has_boon("murrum", 3) and _staff_projectile.current_state == 0:  # 0 = FLYING_OUT
		var trail_tick: float = _staff_projectile.get_meta("trail_tick", 0.0) + delta
		_staff_projectile.set_meta("trail_tick", trail_tick)
		if trail_tick >= 0.15:
			_staff_projectile.set_meta("trail_tick", 0.0)
			var elements: Array = ["fire", "water", "earth", "lightning"]
			var element: String = elements[randi() % elements.size()]
			var trail_pos: Vector2 = staff_pos

			# Small AoE damage at trail position
			var trail_dmg: int = int(BoonManager.get_scaled_param("murrum", 3, "bonus_damage_percent", 0.2) * 20)
			if trail_dmg < 1:
				trail_dmg = 1
			var trail_enemies: Array = _get_enemies_in_radius(trail_pos, 40.0)
			for enemy in trail_enemies:
				enemy.take_damage(trail_dmg, player)
				if BoonManager.has_boon("murrum", 2):
					_apply_dot(enemy)

			# Element VFX at trail point
			_spawn_element_vfx(trail_pos, element, 0.3)

	# Noron T4: Light/dark AoE pulses during staff rotation
	if BoonManager.has_boon("noron", 4) and _staff_projectile.current_state == 1:  # 1 = ROTATING_AT_END
		var pulse_tick: float = _staff_projectile.get_meta("pulse_tick", 0.0) + delta
		_staff_projectile.set_meta("pulse_tick", pulse_tick)
		# Pulse every 0.4s (roughly once per rotation at 25 rad/s)
		if pulse_tick >= 0.4:
			_staff_projectile.set_meta("pulse_tick", 0.0)
			var pulse_dmg: int = BoonManager.get_scaled_param("noron", 4, "kill_explosion_damage", 30) / 2
			var pulse_radius: float = BoonManager.get_scaled_param("noron", 4, "kill_explosion_radius", 120)
			var pulse_enemies: Array = _get_enemies_in_radius(staff_pos, pulse_radius)
			for enemy in pulse_enemies:
				enemy.take_damage(pulse_dmg, player)
			_spawn_noron_vfx(staff_pos, pulse_radius, _kill_explosion_toggle)
			_kill_explosion_toggle = not _kill_explosion_toggle
			print("[BoonEffect] Noron T4 + Staff: Rotation pulse! %d enemies hit" % pulse_enemies.size())


# ============ MURRUM T2: DOT SYSTEM ============
func _apply_dot(enemy: Node) -> void:
	"""Applies elemental DoT to an enemy"""
	if not is_instance_valid(enemy):
		return

	var dot_duration: float = BoonManager.get_scaled_param("murrum", 2, "dot_duration", 3.0)
	var dot_dps: int = BoonManager.get_scaled_param("murrum", 2, "dot_damage_per_sec", 5)

	# Check if already has DoT — refresh timer
	for dot in _dot_targets:
		if dot["enemy"] == enemy:
			dot["timer"] = dot_duration
			return

	_dot_targets.append({"enemy": enemy, "timer": dot_duration, "dps": dot_dps, "tick": 0.0})

	# VFX: tint enemy with elemental color
	var sprite = enemy.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if sprite and not enemy.has_meta("dot_original_modulate"):
		enemy.set_meta("dot_original_modulate", sprite.modulate)
		sprite.modulate = MURRUM_COLOR.lerp(sprite.modulate, 0.4)
	_spawn_element_hit_vfx(enemy.global_position, 0.4)


func _process_dots(delta: float) -> void:
	"""Processes active DoTs"""
	if _dot_targets.is_empty():
		return

	var player = _get_player()
	var to_remove: Array = []

	for i in range(_dot_targets.size()):
		var dot: Dictionary = _dot_targets[i]
		var dot_enemy = dot["enemy"]
		if not is_instance_valid(dot_enemy) or dot_enemy.get("is_dead") or dot_enemy.get("is_destroyed"):
			if is_instance_valid(dot_enemy):
				_restore_dot_tint(dot_enemy)
			to_remove.append(i)
			continue
		if not dot_enemy.has_method("take_damage"):
			_restore_dot_tint(dot_enemy)
			to_remove.append(i)
			continue

		dot["timer"] -= delta
		dot["tick"] += delta

		# Damage every 1 second
		if dot["tick"] >= 1.0:
			dot["tick"] -= 1.0
			dot_enemy.take_damage(dot["dps"], player)
			# VFX: small element flash on DoT tick
			_spawn_element_hit_vfx(dot_enemy.global_position, 0.3)

		if dot["timer"] <= 0.0:
			# VFX: restore original tint
			_restore_dot_tint(dot_enemy)
			to_remove.append(i)

	# Remove expired/dead DoTs (reverse order)
	to_remove.reverse()
	for i in to_remove:
		_dot_targets.remove_at(i)


# ============ CONFUSION SYSTEM ============
func _apply_confusion(enemy: Node, duration: float) -> void:
	"""Makes enemy confused — stuns and tints purple"""
	if not is_instance_valid(enemy):
		return

	# Use stun as a simple confusion (enemy stops attacking)
	if enemy.has_method("stun"):
		enemy.stun(duration)

	# Purple tint to indicate confusion
	var sprite = enemy.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(0.8, 0.4, 1.0)
		# Reset after duration
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(enemy) and is_instance_valid(sprite):
				sprite.modulate = Color.WHITE
		)

	print("[BoonEffect] Noron T2: %s confused for %.1fs" % [enemy.name, duration])


# ============ RAELEAR CLONE SPAWNING ============
func _cleanup_dead_clones() -> void:
	"""Removes freed clones from tracking array"""
	_active_clones = _active_clones.filter(func(c): return is_instance_valid(c))


func _get_raelear_max_clones() -> int:
	"""Returns current max clone limit based on active boons."""
	if BoonManager.has_boon("raelear", 4):
		return BoonManager.get_scaled_param("raelear", 4, "max_clones", 3)
	if BoonManager.has_boon("raelear", 2):
		return BoonManager.get_scaled_param("raelear", 2, "max_clones", 2)
	return BoonManager.get_scaled_param("raelear", 1, "max_clones", 1)


func _get_raelear_clone_mode() -> int:
	"""Returns clone mode: 0=CHASE, 1=MIRROR."""
	if BoonManager.has_boon("raelear", 3):
		return 1  # RaelearClone.Mode.MIRROR
	return 0  # RaelearClone.Mode.CHASE


func _spawn_raelear_clone(pos: Vector2) -> void:
	"""Spawns a Raelear shadow clone (scene-based) at position."""
	_cleanup_dead_clones()
	var max_clones: int = _get_raelear_max_clones()
	if _active_clones.size() >= max_clones:
		return

	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var clone: RaelearClone = CLONE_SCENE.instantiate()
	clone.global_position = pos

	# Set params from boon data
	if BoonManager.has_boon("raelear", 4):
		clone.clone_damage = BoonManager.get_scaled_param("raelear", 4, "clone_damage", 20)
		clone.duration = BoonManager.get_scaled_param("raelear", 4, "clone_duration", 8.0)
	elif BoonManager.has_boon("raelear", 2):
		clone.clone_damage = BoonManager.get_scaled_param("raelear", 2, "clone_damage", 20)
		clone.duration = BoonManager.get_scaled_param("raelear", 2, "clone_duration", 8.0)
	else:
		clone.clone_damage = BoonManager.get_scaled_param("raelear", 1, "clone_damage", 15)
		clone.duration = BoonManager.get_scaled_param("raelear", 1, "clone_duration", 6.0)

	clone.mode = _get_raelear_clone_mode()

	# Sync 5: Raelear×Murrum — clone gets random element
	if SyncSkillManager and SyncSkillManager.has_sync("raelear_murrum"):
		var elements: Array = ["fire", "water", "earth", "lightning"]
		var element: String = elements[randi() % elements.size()]
		clone.set_meta("sync_element", element)
		clone.set_meta("sync_element_damage", SyncSkillManager.get_sync_param("raelear_murrum", "clone_element_damage", 15))
		# Tint clone with element color
		var tint: Color = ELEMENT_COLORS.get(element, MURRUM_COLOR)
		clone.modulate = tint.lerp(CLONE_SCENE_COLOR, 0.4)
		_spawn_explosion_vfx(pos, "sync_raelear_mur", 0.5, tint)

	# Sync 6: Raelear×Noron — clone is light or dark variant
	if SyncSkillManager and SyncSkillManager.has_sync("raelear_noron"):
		var is_light: bool = _sync_clone_light_toggle
		_sync_clone_light_toggle = not _sync_clone_light_toggle
		clone.set_meta("sync_twilight_type", "light" if is_light else "dark")
		if is_light:
			clone.modulate = Color(1.0, 1.0, 0.8, 0.7)  # Light
		else:
			clone.modulate = Color(0.5, 0.2, 0.6, 0.7)  # Dark
			# Dark clone: +60% damage
			var bonus: float = SyncSkillManager.get_sync_param("raelear_noron", "dark_damage_bonus_percent", 0.6)
			clone.clone_damage = int(clone.clone_damage * (1.0 + bonus))
		_spawn_explosion_vfx(pos, "sync_raelear_noron", 0.5)

	scene_root.add_child(clone)
	_active_clones.append(clone)

	# Sync 6: Raelear×Noron — light clone heals player passively (via meta)
	if clone.has_meta("sync_twilight_type") and clone.get_meta("sync_twilight_type") == "light":
		clone.set_meta("sync_heal_tick", 0.0)

	print("[BoonEffect] Raelear clone spawned (%s) at %v (%d/%d)" % [
		"MIRROR" if clone.mode == 1 else "CHASE",
		pos, _active_clones.size(), max_clones
	])


# ============ VFX SYSTEM (Animated Explosion Sprites) ============
func _preload_vfx() -> void:
	"""Preloads all explosion sprite frames into cache"""
	var folders: Array = []
	for path_name in PATH_VFX:
		for folder in PATH_VFX[path_name]:
			if folder not in folders:
				folders.append(folder)
	for folder in ELEMENT_VFX.values():
		if folder not in folders:
			folders.append(folder)

	for folder in folders:
		var sprite_frames := SpriteFrames.new()
		sprite_frames.remove_animation("default")
		sprite_frames.add_animation("play")
		sprite_frames.set_animation_loop("play", false)
		sprite_frames.set_animation_speed("play", 20.0)

		# Try standard pattern: Explosion_1.png, Explosion_2.png, ...
		var i := 1
		while true:
			var path: String = VFX_BASE + folder + "/Explosion_%d.png" % i
			if not ResourceLoader.exists(path):
				break
			sprite_frames.add_frame("play", load(path))
			i += 1

		# If no frames found, try subfolder patterns: Explosion_X_1.png, Explosion_X_2.png, ...
		# (used by Explosion_7/2, /3, /4 with patterns like Explosion_1_1.png, Explosion_2_1.png, etc.)
		if sprite_frames.get_frame_count("play") == 0:
			for prefix in range(1, 10):
				i = 1
				while true:
					var path: String = VFX_BASE + folder + "/Explosion_%d_%d.png" % [prefix, i]
					if not ResourceLoader.exists(path):
						break
					sprite_frames.add_frame("play", load(path))
					i += 1
				if sprite_frames.get_frame_count("play") > 0:
					break

		if sprite_frames.get_frame_count("play") > 0:
			_vfx_cache[folder] = sprite_frames
			print("[BoonVFX] Cached %s: %d frames" % [folder, sprite_frames.get_frame_count("play")])


func _preload_spritesheet_vfx(key: String, path: String, cols: int, rows: int, frame_count: int, speed: float = 15.0) -> void:
	"""Loads a spritesheet as SpriteFrames using AtlasTexture regions"""
	var tex := load(path) as Texture2D
	if not tex:
		return
	var fw: int = tex.get_width() / cols
	var fh: int = tex.get_height() / rows
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_loop("play", false)
	sf.set_animation_speed("play", speed)
	var count: int = 0
	for r in range(rows):
		for c in range(cols):
			if count >= frame_count:
				break
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * fw, r * fh, fw, fh)
			sf.add_frame("play", atlas)
			count += 1
	if sf.get_frame_count("play") > 0:
		_vfx_cache[key] = sf
		print("[BoonVFX] Cached spritesheet %s: %d frames" % [key, sf.get_frame_count("play")])


func _preload_pachron_vfx() -> void:
	"""Preloads all Pachron VFX spritesheets into cache"""
	for key in PACHRON_VFX:
		var def: Array = PACHRON_VFX[key]
		var path: String = PACHRON_VFX_BASE + def[0]
		_preload_spritesheet_vfx(key, path, def[1], def[2], def[3], def[4])


func _get_blade_atlas(path: String, cols: int, frame_index: int) -> AtlasTexture:
	"""Returns a single AtlasTexture frame from a horizontal spritesheet"""
	var tex := load(path) as Texture2D
	if not tex:
		return null
	var fw: int = tex.get_width() / cols
	var fh: int = tex.get_height()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(frame_index * fw, 0, fw, fh)
	return atlas


func _spawn_explosion_vfx(pos: Vector2, folder: String, vfx_scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	"""Spawns an animated explosion sprite at position"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var frames: SpriteFrames = _vfx_cache.get(folder)
	if not frames:
		return

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.global_position = pos
	var final_scale: float = vfx_scale * PACHRON_VFX_GLOBAL_SCALE
	anim.scale = Vector2(final_scale, final_scale)
	anim.modulate = tint
	anim.z_index = 10
	scene_root.add_child(anim)
	anim.play("play")
	anim.animation_finished.connect(anim.queue_free)


func _preload_lightning_vfx() -> void:
	"""Preloads electro-shock frames for Arthra T1 lightning"""
	_lightning_frames = SpriteFrames.new()
	_lightning_frames.remove_animation("default")
	_lightning_frames.add_animation("play")
	_lightning_frames.set_animation_loop("play", false)
	_lightning_frames.set_animation_speed("play", 18.0)

	var frame_names: Array = [
		"_0000_Layer-1.png", "_0001_Layer-2.png", "_0002_Layer-3.png",
		"_0003_Layer-4.png", "_0004_Layer-5.png", "_0005_Layer-6.png",
		"_0006_Layer-7.png", "_0007_Layer-8.png", "_0008_Layer-9.png",
	]
	for fname in frame_names:
		var path: String = LIGHTNING_VFX_PATH + fname
		if ResourceLoader.exists(path):
			_lightning_frames.add_frame("play", load(path))

	if _lightning_frames.get_frame_count("play") > 0:
		print("[BoonVFX] Lightning: %d frames loaded" % _lightning_frames.get_frame_count("play"))


func _spawn_lightning_vfx(pos: Vector2) -> void:
	"""Arthra: Lightning strike VFX using electro-shock sprites"""
	if not _lightning_frames or _lightning_frames.get_frame_count("play") == 0:
		_spawn_explosion_vfx(pos, PATH_VFX["arthra"][0], 0.5)
		return

	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _lightning_frames
	anim.global_position = pos + Vector2(0, -40)
	var lightning_scale: float = 2.5 * PACHRON_VFX_GLOBAL_SCALE
	anim.scale = Vector2(lightning_scale, lightning_scale)
	anim.modulate = Color(0.8, 0.95, 1.0, 0.9)
	anim.z_index = 10
	scene_root.add_child(anim)
	anim.play("play")
	anim.animation_finished.connect(anim.queue_free)


func _spawn_element_vfx(pos: Vector2, element: String, vfx_scale: float = 2.0) -> void:
	"""Murrum: Elemental finisher VFX (4 elements = 4 explosion variants)"""
	var folder: String = ELEMENT_VFX.get(element, PATH_VFX["murrum"][0])
	var frames: SpriteFrames = _vfx_cache.get(folder)
	if frames:
		_spawn_explosion_vfx(pos + Vector2(0, -60), folder, vfx_scale)
	else:
		# Fallback: colored circle burst
		_spawn_element_burst_vfx(pos + Vector2(0, -60), element, vfx_scale)


func _spawn_element_burst_vfx(pos: Vector2, element: String, vfx_scale: float = 1.0) -> void:
	"""Element burst VFX using Pachron sprites with element tint"""
	var color: Color = ELEMENT_COLORS.get(element, MURRUM_COLOR)
	_spawn_explosion_vfx(pos, "mur_t5_ring", vfx_scale, color)


func _spawn_element_hit_vfx(pos: Vector2, vfx_scale: float = 0.5) -> void:
	"""Small element flash on enemy hit (T2 DoT tick, T3 bonus damage)"""
	var elements: Array = ELEMENT_COLORS.keys()
	var element: String = elements[randi() % elements.size()]
	var folder: String = ELEMENT_VFX.get(element, PATH_VFX["murrum"][0])
	var offset := Vector2(randf_range(-20, 20), -40 + randf_range(-20, 20))
	_spawn_explosion_vfx(pos + offset, folder, vfx_scale * 1.5)


func _spawn_multi_element_vfx(pos: Vector2) -> void:
	"""T4: Burst of all 4 element flashes around enemy"""
	var offsets: Array = [
		Vector2(-30, -60), Vector2(30, -60),
		Vector2(-30, -25), Vector2(30, -25)
	]
	var elements: Array = ["fire", "water", "earth", "lightning"]

	for i in range(4):
		var element: String = elements[i]
		var offset: Vector2 = offsets[i]
		var folder: String = ELEMENT_VFX.get(element, PATH_VFX["murrum"][0])
		var frames: SpriteFrames = _vfx_cache.get(folder)
		if frames:
			get_tree().create_timer(i * 0.07).timeout.connect(func():
				_spawn_explosion_vfx(pos + offset, folder, 0.7)
			)
		else:
			get_tree().create_timer(i * 0.07).timeout.connect(func():
				_spawn_element_burst_vfx(pos + offset, element, 0.7)
			)


func _spawn_lifesteal_vfx(pos: Vector2) -> void:
	"""T5: Heal/mana restore glow on player"""
	_spawn_explosion_vfx(pos + Vector2(0, -60), "mur_t5", 1.5, Color(0.8, 1.0, 1.0))


func _restore_dot_tint(enemy: Node) -> void:
	"""Restores enemy sprite color after DoT expires"""
	if not is_instance_valid(enemy):
		return
	var sprite = enemy.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if sprite and enemy.has_meta("dot_original_modulate"):
		sprite.modulate = enemy.get_meta("dot_original_modulate")
		enemy.remove_meta("dot_original_modulate")


func _spawn_block_aoe_vfx(pos: Vector2, radius: float) -> void:
	"""Sairias: Block AoE VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["sairias"][0], radius / 80.0)


func _spawn_reflect_vfx(pos: Vector2) -> void:
	"""Sairias: Parry reflect VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["sairias"][1], 1.4, Color(1.3, 1.05, 0.4))
	_spawn_explosion_vfx(pos + Vector2(0, -20), PATH_VFX["sairias"][1], 0.9, Color(1.0, 0.9, 0.5, 0.7))


func _spawn_meteor_vfx(pos: Vector2, radius: float) -> void:
	"""Arthra: Meteor impact VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["arthra"][1], radius / 80.0)


func _spawn_pillar_vfx(pos: Vector2, radius: float) -> void:
	"""Sairias: Light pillar VFX"""
	_spawn_explosion_vfx(pos, "sairias_pillar", radius / 40.0, Color(1.0, 1.0, 0.9))


func _spawn_noron_vfx(pos: Vector2, radius: float, is_light: bool) -> void:
	"""Noron: Light/dark explosion VFX"""
	var idx: int = 0 if is_light else 1
	_spawn_explosion_vfx(pos, PATH_VFX["noron"][idx], radius / 80.0)


func _spawn_raelear_vfx(pos: Vector2, radius: float) -> void:
	"""Raelear: Shadow clone VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["raelear"][0], radius / 80.0, Color(0.7, 0.4, 1.0))


# ============ SYNC SKILL EFFECTS ============

func _process_sync_effects(delta: float) -> void:
	"""Per-frame processing for active sync skills."""
	if not _is_in_run() or not SyncSkillManager:
		return

	# Arthra×Raelear: cooldown tick
	if _sync_urteil_clone_cooldown > 0.0:
		_sync_urteil_clone_cooldown -= delta

	# Raelear×Sairias: absorption cooldown tick
	if _sync_clone_absorb_cooldown > 0.0:
		_sync_clone_absorb_cooldown -= delta

	# Murrum×Noron: cycle blade element
	if SyncSkillManager.has_sync("murrum_noron") and _twilight_blades_active:
		var cycle_dur: float = SyncSkillManager.get_sync_param("murrum_noron", "element_cycle_duration", 2.0)
		_sync_element_cycle_timer += delta
		if _sync_element_cycle_timer >= cycle_dur:
			_sync_element_cycle_timer -= cycle_dur
			var elements: Array = ["fire", "water", "earth", "lightning"]
			var idx: int = elements.find(_sync_current_blade_element)
			_sync_current_blade_element = elements[(idx + 1) % elements.size()]
			# Update blade tints
			if _twilight_blades_node and is_instance_valid(_twilight_blades_node):
				var color: Color = ELEMENT_COLORS.get(_sync_current_blade_element, Color.WHITE)
				for blade in _twilight_blades_node.get_children():
					blade.modulate = color.lerp(blade.modulate, 0.3)

	# Noron×Sairias: twilight shield timer
	if _sync_guardian_shield_active:
		_sync_guardian_shield_timer -= delta
		# Blade speed boost
		if _twilight_blades_active and _twilight_blades_node and is_instance_valid(_twilight_blades_node):
			var speed_mult: float = SyncSkillManager.get_sync_param("noron_sairias", "blade_speed_multiplier", 2.0)
			_blade_rotation += delta * 3.0 * (speed_mult - 1.0)  # Extra rotation on top of normal
		if _sync_guardian_shield_timer <= 0.0:
			_sync_eternal_guardian_expire()

	# Raelear×Noron: light clone heals player
	if SyncSkillManager.has_sync("raelear_noron"):
		var player = _get_player()
		if player:
			_cleanup_dead_clones()
			for clone in _active_clones:
				if is_instance_valid(clone) and clone.has_meta("sync_twilight_type"):
					if clone.get_meta("sync_twilight_type") == "light":
						var tick: float = clone.get_meta("sync_heal_tick", 0.0) + delta
						clone.set_meta("sync_heal_tick", tick)
						if tick >= 1.0:
							clone.set_meta("sync_heal_tick", tick - 1.0)
							var heal_ps: int = SyncSkillManager.get_sync_param("raelear_noron", "light_heal_per_sec", 3)
							var health = player.get_node_or_null("HealthComponent")
							if health and health.has_method("heal"):
								health.heal(heal_ps)


# -- Sync 1: Arthra×Raelear — clone explosion applies Urteil (hooked externally via clone damage) --
# The urteil-death clone spawning is handled in _on_enemy_died above.
# Clone urteil application: clones deal damage via take_damage → triggers _on_enemy_damaged → auto_urteil.
# With this sync, Arthra T4 auto-urteil extends to clone damage automatically.
# No additional function needed — the existing T4 auto_urteil handles it.


# -- Sync 2: Arthra×Murrum — Sturmfeuer --
func _sync_storm_fire_zone(pos: Vector2) -> void:
	"""Creates an elemental AoE zone at lightning impact point."""
	var zone_dur: float = SyncSkillManager.get_sync_param("arthra_murrum", "zone_duration", 4.0)
	var zone_radius: float = SyncSkillManager.get_sync_param("arthra_murrum", "zone_radius", 150)
	var zone_dps: int = SyncSkillManager.get_sync_param("arthra_murrum", "zone_dps", 12)
	var elements: Array = ["fire", "water", "earth", "lightning"]
	var element: String = elements[randi() % elements.size()]
	var color: Color = ELEMENT_COLORS.get(element, MURRUM_COLOR)

	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	# Visual zone — Sprite2D from sync spritesheet (4 frames = 4 elements)
	var element_idx: int = elements.find(element)
	var zone_tex := _get_blade_atlas(PACHRON_VFX_BASE + "Sync_Arthra+Mur.png", 4, element_idx)
	var zone := Sprite2D.new()
	if zone_tex:
		zone.texture = zone_tex
		zone.scale = Vector2(zone_radius / 80.0, zone_radius / 80.0)
	zone.global_position = pos
	zone.modulate = Color(1.0, 1.0, 1.0, 0.7)
	zone.z_index = -1
	scene_root.add_child(zone)

	# Damage tick every 1s for zone_dur seconds
	var player = _get_player()
	var ticks: int = int(zone_dur)
	for i in range(ticks):
		get_tree().create_timer(float(i) + 0.5).timeout.connect(func():
			if not is_instance_valid(zone):
				return
			var enemies: Array = _get_enemies_in_radius(pos, zone_radius)
			for enemy in enemies:
				enemy.take_damage(zone_dps, player)
				if BoonManager.has_boon("murrum", 2):
					_apply_dot(enemy)
		)

	# Fade and remove
	var tween := zone.create_tween()
	tween.tween_property(zone, "modulate:a", 0.0, zone_dur).from(0.7)
	tween.tween_callback(zone.queue_free)

	_spawn_element_vfx(pos, element, 1.5)
	print("[SyncEffect] Arthra×Murrum: %s zone at %v (%.0fs)" % [element, pos, zone_dur])


func _sync_storm_fire_bonus_lightning(pos: Vector2) -> void:
	"""Bonus lightning strike triggered by elemental kill."""
	var player = _get_player()
	if not player:
		return
	var lightning_dmg: int = SyncSkillManager.get_sync_param("arthra_murrum", "bonus_lightning_damage", 25)
	var nearest: Node = _get_nearest_enemy(pos, 400.0)
	if nearest and nearest.has_method("take_damage"):
		nearest.take_damage(lightning_dmg, player)
		_spawn_lightning_vfx(nearest.global_position)
		# Chain: this lightning also creates a zone
		_sync_storm_fire_zone(nearest.global_position)
		print("[SyncEffect] Arthra×Murrum: Bonus lightning! %d dmg on %s" % [lightning_dmg, nearest.name])


# -- Sync 3: Arthra×Noron — Zorn des Zwielichts --
func _sync_twilight_wrath_blade_lightning(enemy: Node) -> void:
	"""Every blade hit triggers a mini-lightning."""
	if not is_instance_valid(enemy):
		return
	var player = _get_player()
	if not player:
		return
	var dmg_pct: float = SyncSkillManager.get_sync_param("arthra_noron", "blade_lightning_damage_percent", 0.5)
	var base_lightning: int = 20
	var bonus_pct: float = BoonManager.get_scaled_param("arthra", 1, "bonus_damage_percent", 0.3) if BoonManager.has_boon("arthra", 1) else 0.0
	var full_damage: int = int(base_lightning * (1.0 + bonus_pct))
	var mini_damage: int = int(full_damage * dmg_pct)

	# Apply light/dark alternation
	mini_damage = _sync_twilight_wrath_modify_lightning(mini_damage, player)

	enemy.take_damage(mini_damage, player)
	_spawn_lightning_vfx(enemy.global_position)
	_spawn_explosion_vfx(enemy.global_position + Vector2(0, -30), "sync_arthra_noron", 0.6)


func _sync_twilight_wrath_modify_lightning(damage: int, player: Node) -> int:
	"""Alternates lightning between light (heals) and dark (+80% damage)."""
	_sync_lightning_toggle = not _sync_lightning_toggle
	if _sync_lightning_toggle:
		# Light: heal 5% max HP
		var heal_pct: float = SyncSkillManager.get_sync_param("arthra_noron", "light_heal_percent", 0.05)
		var health = player.get_node_or_null("HealthComponent")
		if health and health.has_method("heal"):
			var heal: int = int(health.max_health * heal_pct)
			health.heal(heal)
		return damage
	else:
		# Dark: +80% damage
		var bonus: float = SyncSkillManager.get_sync_param("arthra_noron", "dark_damage_bonus_percent", 0.8)
		return int(damage * (1.0 + bonus))


# -- Sync 4: Arthra×Sairias — Donner der Vergeltung --
func _sync_thunder_retribution_storm(center: Vector2) -> void:
	"""Perfect Parry triggers lightning storm (5 strikes on random enemies)."""
	var player = _get_player()
	if not player:
		return
	var count: int = SyncSkillManager.get_sync_param("arthra_sairias", "lightning_storm_count", 5)
	var dmg: int = SyncSkillManager.get_sync_param("arthra_sairias", "lightning_storm_damage", 30)

	for i in range(count):
		get_tree().create_timer(0.1 + i * 0.12).timeout.connect(func():
			var target: Node = _get_nearest_enemy(center + Vector2(randf_range(-200, 200), randf_range(-200, 200)), 500.0)
			if target and target.has_method("take_damage"):
				target.take_damage(dmg, player)
				_spawn_lightning_vfx(target.global_position)
				_spawn_explosion_vfx(target.global_position, "sync_arthra_sairias", 0.5)
		)

	print("[SyncEffect] Arthra×Sairias: Lightning storm! %d strikes" % count)


# -- Sync 5: Raelear×Murrum — Elementargeister (clone element is set in _spawn_raelear_clone) --
# Element zone on clone death is handled by checking clone meta in process/cleanup.
# We hook into _cleanup_dead_clones to spawn zones when clones die.


# -- Sync 6: Raelear×Noron — Schatten der Daemmerung (light/dark set in _spawn_raelear_clone) --
# Light heal is processed in _process_sync_effects above.
# Dual-hit burst is checked when enemies take clone damage — handled by _on_enemy_damaged.


# -- Sync 7: Raelear×Sairias — Phantomkonter --
func _sync_phantom_counter_parry(parried_enemy: Node) -> void:
	"""All active clones dash to parried enemy and explode."""
	_cleanup_dead_clones()
	if _active_clones.is_empty():
		return

	var player = _get_player()
	var bonus_per_clone: float = SyncSkillManager.get_sync_param("raelear_sairias", "parry_clone_damage_bonus_percent", 0.3)
	var clone_count: int = _active_clones.size()
	var total_bonus: float = 1.0 + bonus_per_clone * clone_count

	for clone in _active_clones.duplicate():
		if is_instance_valid(clone) and is_instance_valid(parried_enemy):
			var dmg: int = int(clone.clone_damage * total_bonus)
			parried_enemy.take_damage(dmg, player)
			_spawn_explosion_vfx(clone.global_position, "sync_raelear_sairias", 0.8)
			clone.queue_free()

	_active_clones.clear()
	print("[SyncEffect] Raelear×Sairias: %d clones exploded on %s! (%.0f%% bonus)" % [
		clone_count, parried_enemy.name, total_bonus * 100
	])


# Called from player_damaged signal for Raelear×Sairias clone absorption
func _sync_phantom_counter_absorb(damage: int) -> bool:
	"""Tries to absorb a hit with an active clone. Returns true if absorbed."""
	if not SyncSkillManager or not SyncSkillManager.has_sync("raelear_sairias"):
		return false
	if _sync_clone_absorb_cooldown > 0.0:
		return false

	_cleanup_dead_clones()
	if _active_clones.is_empty():
		return false

	# Sacrifice nearest clone
	var player = _get_player()
	if not player:
		return false

	var nearest_clone: Node2D = null
	var nearest_dist: float = INF
	for clone in _active_clones:
		if is_instance_valid(clone):
			var dist: float = clone.global_position.distance_to(player.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_clone = clone

	if nearest_clone:
		_spawn_explosion_vfx(nearest_clone.global_position, "sync_raelear_sairias", 0.6)
		nearest_clone.queue_free()
		_active_clones.erase(nearest_clone)
		_sync_clone_absorb_cooldown = SyncSkillManager.get_sync_param("raelear_sairias", "clone_absorb_cooldown", 1.0)
		print("[SyncEffect] Raelear×Sairias: Clone absorbed %d damage!" % damage)
		return true

	return false


# -- Sync 8: Murrum×Noron — Prisma der Elemente --
func _sync_prism_blade_element_hit(enemy: Node, player: Node) -> void:
	"""Blade hit deals current cycling element damage + applies DoT."""
	if not is_instance_valid(enemy):
		return
	var element_dmg: int = SyncSkillManager.get_sync_param("murrum_noron", "blade_element_damage", 12)
	enemy.take_damage(element_dmg, player)

	# Apply DoT if Murrum T2 active
	if BoonManager.has_boon("murrum", 2):
		_apply_dot(enemy)

	# Small element VFX
	_spawn_explosion_vfx(enemy.global_position + Vector2(0, -30), "sync_murrum_noron", 0.4)


# -- Sync 9: Murrum×Sairias — Elementarer Gegenschlag --
func _sync_elemental_counter_nova(center: Vector2) -> void:
	"""Perfect Parry triggers elemental nova (all 4 elements, AoE)."""
	var player = _get_player()
	if not player:
		return

	var nova_radius: float = SyncSkillManager.get_sync_param("murrum_sairias", "nova_radius", 250)
	var dmg_per_element: int = SyncSkillManager.get_sync_param("murrum_sairias", "nova_damage_per_element", 25)
	var total_damage: int = dmg_per_element * 4

	var enemies: Array = _get_enemies_in_radius(center, nova_radius)
	for enemy in enemies:
		enemy.take_damage(total_damage, player)
		# Apply all 4 DoTs
		if BoonManager.has_boon("murrum", 2):
			_apply_dot(enemy)

	# VFX: sync sprite + 4 element explosions in sequence
	_spawn_explosion_vfx(center, "sync_murrum_sairias", nova_radius / 80.0)
	var elements: Array = ["fire", "water", "earth", "lightning"]
	for i in range(4):
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			_spawn_element_vfx(center + Vector2(randf_range(-40, 40), randf_range(-40, 40)), elements[i], 2.5)
		)

	print("[SyncEffect] Murrum×Sairias: Element nova! %d enemies hit for %d" % [enemies.size(), total_damage])


func _sync_elemental_counter_block() -> void:
	"""Increments block charge. At 3: next attack gets element burst."""
	var blocks_needed: int = SyncSkillManager.get_sync_param("murrum_sairias", "blocks_for_burst", 3)
	_sync_block_charge += 1

	if _sync_block_charge >= blocks_needed:
		_sync_block_charge = 0
		# Store burst flag on player
		var player = _get_player()
		if player:
			player.set_meta("sync_element_burst_ready", true)
			EventBus.show_notification.emit("Elementar-Burst bereit!", 2.0)
			print("[SyncEffect] Murrum×Sairias: Element burst charged!")


# -- Sync 10: Noron×Sairias — Ewiger Waechter --
func _sync_eternal_guardian_activate() -> void:
	"""Activates twilight shield on perfect parry."""
	if _sync_guardian_shield_active:
		# Refresh duration
		_sync_guardian_shield_timer = SyncSkillManager.get_sync_param("noron_sairias", "shield_duration", 5.0)
		return

	_sync_guardian_shield_active = true
	_sync_guardian_shield_timer = SyncSkillManager.get_sync_param("noron_sairias", "shield_duration", 5.0)

	# Visual: tint player with twilight glow + sync VFX
	var player = _get_player()
	if player:
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color(0.7, 0.8, 1.0, 0.9)
		_spawn_explosion_vfx(player.global_position, "sync_noron_sairias", 1.0)

	print("[SyncEffect] Noron×Sairias: Twilight shield activated (%.0fs)" % _sync_guardian_shield_timer)


func _sync_eternal_guardian_expire() -> void:
	"""Shield expires — triggers nova and restores visuals."""
	_sync_guardian_shield_active = false
	_sync_guardian_shield_timer = 0.0

	var player = _get_player()
	if player:
		# Restore sprite
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color.WHITE

		# Nova on expire
		var nova_dmg: int = SyncSkillManager.get_sync_param("noron_sairias", "nova_damage", 120)
		var nova_radius: float = SyncSkillManager.get_sync_param("noron_sairias", "nova_radius", 300)

		var enemies: Array = _get_enemies_in_radius(player.global_position, nova_radius)
		for enemy in enemies:
			enemy.take_damage(nova_dmg, player)

		# VFX: Sync nova + Light + Dark explosion
		_spawn_explosion_vfx(player.global_position, "sync_noron_sairias", nova_radius / 80.0)
		_spawn_noron_vfx(player.global_position, nova_radius, true)
		get_tree().create_timer(0.1).timeout.connect(func():
			_spawn_noron_vfx(player.global_position, nova_radius, false)
		)

		print("[SyncEffect] Noron×Sairias: Shield expired — nova! %d enemies hit for %d" % [enemies.size(), nova_dmg])


func sync_guardian_get_miss_chance() -> float:
	"""Returns extra miss chance from twilight shield (called by HurtboxComponent)."""
	if _sync_guardian_shield_active and SyncSkillManager and SyncSkillManager.has_sync("noron_sairias"):
		return SyncSkillManager.get_sync_param("noron_sairias", "shield_miss_chance", 0.5)
	return 0.0


# ============ UTILITY ============
func _get_player() -> Node:
	if GameManager and GameManager.player and is_instance_valid(GameManager.player):
		return GameManager.player
	return null


func _is_in_run() -> bool:
	return RunManager and RunManager.is_run_active()


func _get_nearest_enemy(pos: Vector2, max_range: float) -> Node:
	"""Returns nearest living damageable enemy within range"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var player = _get_player()
	var nearest: Node = null
	var nearest_dist: float = max_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# In PvP: don't target the boon owner (P1)
		if enemy == player:
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") or enemy.get("is_destroyed"):
			continue
		var dist: float = enemy.global_position.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	"""Returns all living enemies within radius that can take damage"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var player = _get_player()
	var result: Array = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# In PvP: don't target the boon owner (P1)
		if enemy == player:
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") or enemy.get("is_destroyed"):
			continue
		if enemy.global_position.distance_to(center) <= radius:
			result.append(enemy)

	return result


# ============ CLEANUP ============
func cleanup() -> void:
	"""Called on run end — cleans up active effects"""
	_deactivate_twilight_blades()
	_dot_targets.clear()
	_kill_explosion_toggle = false
	# Remove all active clones
	for clone in _active_clones:
		if is_instance_valid(clone):
			clone.queue_free()
	_active_clones.clear()
	# Sync skill state
	_sync_urteil_clone_cooldown = 0.0
	_sync_lightning_toggle = false
	_sync_block_charge = 0
	_sync_guardian_shield_active = false
	_sync_guardian_shield_timer = 0.0
	_sync_clone_absorb_cooldown = 0.0
	_sync_element_cycle_timer = 0.0
	_sync_current_blade_element = "fire"
	_sync_clone_light_toggle = false
	# Restore player sprite if shield was active
	var player = _get_player()
	if player:
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color.WHITE
