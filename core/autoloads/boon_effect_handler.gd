extends Node
## BoonEffectHandler — Executes passive boon effects (T1–T4) via EventBus signals
## Keeps BoonManager clean (data-only) and centralizes gameplay hooks here.

# ============ CONSTANTS ============
const CLONE_SCENE_COLOR := Color(0.5, 0.3, 0.8, 0.6)  # Raelear purple

# ============ EXPLOSION VFX ============
const VFX_BASE := "res://vfx/placeholder/Free-Animated-Explosions/PNG/"

# Path -> [primary_folder, secondary_folder]
const PATH_VFX := {
	"noron": ["Explosion_1", "Explosion_2"],
	"arthra": ["Explosion_3", "Explosion_4/1"],
	"sairias": ["Explosion_5", "Explosion_6"],
	"murrum": ["Explosion_8", "Explosion_7/1"],
	"raelear": ["Explosion_9", "Explosion_10"],
}

# Murrum element -> Explosion_7 subfolder
const ELEMENT_VFX := {
	"fire": "Explosion_7/1",
	"water": "Explosion_7/2",
	"earth": "Explosion_7/3",
	"lightning": "Explosion_7/4",
}

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

	# Staff signals
	EventBus.staff_thrown.connect(_on_staff_thrown)
	EventBus.staff_caught.connect(_on_staff_caught)
	EventBus.staff_hit_enemy.connect(_on_staff_hit_enemy)

	_preload_vfx()
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


# ============ ARTHRA T1: BLITZE DER MACHT ============
func _on_combo_increased(new_count: int, _multiplier: float) -> void:
	if not _is_in_run():
		return

	# Noron T1: activate blades during combo
	if BoonManager.has_boon("noron", 1) and not _twilight_blades_active:
		_activate_twilight_blades()

	if not BoonManager.has_boon("arthra", 1):
		return

	var every_n: int = BoonManager.get_scaled_param("arthra", 1, "every_n_hits", 3)
	if new_count % every_n != 0:
		return

	# Lightning strike on nearest enemy
	var player = _get_player()
	if not player:
		return

	var bonus_pct: float = BoonManager.get_scaled_param("arthra", 1, "bonus_damage_percent", 0.3)
	var base_damage: int = 20  # Base lightning damage
	var total_damage: int = int(base_damage * (1.0 + bonus_pct))

	var nearest: Node = _get_nearest_enemy(player.global_position, 300.0)
	if nearest and nearest.has_method("take_damage"):
		nearest.take_damage(total_damage, player)
		_spawn_lightning_vfx(nearest.global_position)
		print("[BoonEffect] Arthra T1: Lightning strike! %d damage on %s" % [total_damage, nearest.name])


# ============ RAELEAR T1: SCHATTENBILD (Dodge Clone) ============
func _on_dodge_completed() -> void:
	if not BoonManager.has_boon("raelear", 1):
		return
	if not _is_in_run():
		return

	var player = _get_player()
	if not player:
		return

	# Check max clones (default 2, Raelear T4: 5)
	_cleanup_dead_clones()
	var max_clones: int = 2
	if BoonManager.has_boon("raelear", 4):
		max_clones = BoonManager.get_scaled_param("raelear", 4, "max_clones", 5)
	if _active_clones.size() >= max_clones:
		return

	var duration: float = BoonManager.get_scaled_param("raelear", 1, "clone_duration", 3.0)
	var clone_dmg: int = BoonManager.get_scaled_param("raelear", 1, "clone_damage", 10)

	# Raelear T4: duration override
	if BoonManager.has_boon("raelear", 4):
		duration = BoonManager.get_scaled_param("raelear", 4, "duration_override", 8.0)

	_spawn_clone(player.global_position, duration, clone_dmg, "DodgeClone")
	print("[BoonEffect] Raelear T1: Dodge clone (%.1fs, %d/%d)" % [duration, _active_clones.size(), max_clones])


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

	# Raelear T2: Death clone
	if not BoonManager.has_boon("raelear", 2):
		return

	# Check max clones (default 2, Raelear T4: 5)
	_cleanup_dead_clones()
	var max_clones: int = 2
	if BoonManager.has_boon("raelear", 4):
		max_clones = BoonManager.get_scaled_param("raelear", 4, "max_clones", 5)
	if _active_clones.size() >= max_clones:
		return

	var duration: float = BoonManager.get_scaled_param("raelear", 2, "clone_duration", 5.0)
	var dmg_pct: float = BoonManager.get_scaled_param("raelear", 2, "damage_percent", 0.5)
	var clone_dmg: int = int(20 * dmg_pct)  # Base 20 * 50% = 10

	# Raelear T4: duration override
	if BoonManager.has_boon("raelear", 4):
		duration = BoonManager.get_scaled_param("raelear", 4, "duration_override", 8.0)

	# Raelear T2 + Staff: clone spawns at staff position instead of death position
	var clone_pos: Vector2 = position
	if _staff_projectile and is_instance_valid(_staff_projectile):
		clone_pos = _staff_projectile.global_position

	_spawn_clone(clone_pos, duration, clone_dmg, "DeathClone")
	_spawn_raelear_vfx(clone_pos, 60.0)
	print("[BoonEffect] Raelear T2: Death clone at %v (%.1fs, %d/%d)" % [clone_pos, duration, _active_clones.size(), max_clones])


# ============ MURRUM T1: ELEMENT-FINISHER ============
func _on_combo_finisher_executed(_combo_count: int) -> void:
	if not BoonManager.has_boon("murrum", 1):
		return
	if not _is_in_run():
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

	_spawn_element_vfx(player.global_position, element)
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

	# Create 2 blade visuals (light + dark) using Noron explosion sprites
	var light_tex: Texture2D = load(VFX_BASE + "Explosion_1/Explosion_1.png")
	var dark_tex: Texture2D = load(VFX_BASE + "Explosion_2/Explosion_1.png")

	for i in range(2):
		var blade := Sprite2D.new()
		blade.name = "Blade_%d" % i
		blade.scale = Vector2(0.15, 0.15)
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
			# Murrum T2: DoT from elemental damage
			if BoonManager.has_boon("murrum", 2):
				_apply_dot(enemy)

	# Murrum T4: Herr der Elemente — all 4 elements as extra damage
	if BoonManager.has_boon("murrum", 4):
		var per_element: int = BoonManager.get_scaled_param("murrum", 4, "per_element_damage", 5)
		var total: int = per_element * 4
		enemy.take_damage(total, _get_player())
		elemental_damage_dealt += total

	# Murrum T5: Elemental lifesteal from T3/T4 damage
	if BoonManager.has_boon("murrum", 5) and elemental_damage_dealt > 0:
		var player = _get_player()
		if player:
			_murrum_t5_lifesteal(player, elemental_damage_dealt)

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

	# Visual mark (red tint)
	var sprite = enemy.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.2, 0.5, 0.5)

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

	var player = _get_player()
	if not player:
		return

	# Sairias T1: Block AoE damage
	if BoonManager.has_boon("sairias", 1):
		var aoe_damage: int = BoonManager.get_scaled_param("sairias", 1, "block_aoe_damage", 10)
		var aoe_radius: float = BoonManager.get_scaled_param("sairias", 1, "block_aoe_radius", 100)

		var enemies: Array = _get_enemies_in_radius(player.global_position, aoe_radius)
		for e in enemies:
			e.take_damage(aoe_damage, player)

		_spawn_block_aoe_vfx(player.global_position, aoe_radius)
		print("[BoonEffect] Sairias T1: Block AoE! %d enemies hit for %d" % [enemies.size(), aoe_damage])

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

	_spawn_noron_vfx(pos, counter_radius, false)
	print("[BoonEffect] Noron T5: Counter explosion! %d enemies hit for %d" % [enemies.size(), counter_dmg])


# -- Raelear T5: Clone Death Save --
func consume_clone_for_death_save(player_pos: Vector2) -> void:
	"""Called from Murum when death save triggers — destroys nearest clone"""
	_cleanup_dead_clones()
	if _active_clones.is_empty():
		# No clone to destroy, but death save still works
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
			var folder: String = ELEMENT_VFX.get(element, PATH_VFX["murrum"][0])
			_spawn_explosion_vfx(trail_pos, folder, 0.3)

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
			to_remove.append(i)
			continue
		if not dot_enemy.has_method("take_damage"):
			to_remove.append(i)
			continue

		dot["timer"] -= delta
		dot["tick"] += delta

		# Damage every 1 second
		if dot["tick"] >= 1.0:
			dot["tick"] -= 1.0
			dot_enemy.take_damage(dot["dps"], player)

		if dot["timer"] <= 0.0:
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


# ============ CLONE SPAWNING ============
func _cleanup_dead_clones() -> void:
	"""Removes freed clones from tracking array"""
	_active_clones = _active_clones.filter(func(c): return is_instance_valid(c))


func _spawn_clone(pos: Vector2, duration: float, damage: int, clone_name: String) -> void:
	"""Spawns a Raelear shadow clone at position"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var clone := Node2D.new()
	clone.name = clone_name
	clone.global_position = pos
	scene_root.add_child(clone)
	_active_clones.append(clone)

	# Clone body visual (purple silhouette)
	var body := ColorRect.new()
	body.color = CLONE_SCENE_COLOR
	body.size = Vector2(30, 60)
	body.position = Vector2(-15, -60)
	clone.add_child(body)

	# Clone hitbox (damages enemies on contact)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_collision_mask_value(4, true)  # Enemy bodies (layer 4)
	area.monitoring = true

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	area.add_child(col)
	clone.add_child(area)

	# Damage on contact (with cooldown via meta)
	area.body_entered.connect(func(body_node):
		if not is_instance_valid(clone):
			return
		if body_node.is_in_group("enemies") and not body_node.get("is_dead"):
			var last_hit: float = clone.get_meta("last_hit", 0.0)
			var now: float = Time.get_ticks_msec() / 1000.0
			if now - last_hit > 1.0:  # 1s cooldown per hit
				clone.set_meta("last_hit", now)
				body_node.take_damage(damage, null)
				print("[BoonEffect] Clone hit %s for %d" % [body_node.name, damage])
	)

	# Fade-in
	body.modulate.a = 0.0
	var tween := clone.create_tween()
	tween.tween_property(body, "modulate:a", 1.0, 0.3)

	# Auto-destroy after duration
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(clone):
			var fade := clone.create_tween()
			fade.tween_property(body, "modulate:a", 0.0, 0.5)
			fade.tween_callback(clone.queue_free)
	)


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
	anim.scale = Vector2(vfx_scale, vfx_scale)
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
	anim.scale = Vector2(2.5, 2.5)
	anim.modulate = Color(0.8, 0.95, 1.0, 0.9)
	anim.z_index = 10
	scene_root.add_child(anim)
	anim.play("play")
	anim.animation_finished.connect(anim.queue_free)


func _spawn_element_vfx(pos: Vector2, element: String) -> void:
	"""Murrum: Elemental finisher VFX (4 elements = 4 explosion variants)"""
	var folder: String = ELEMENT_VFX.get(element, PATH_VFX["murrum"][0])
	# Spawn larger and offset from player center so it's visible
	_spawn_explosion_vfx(pos + Vector2(0, -60), folder, 2.0)


func _spawn_block_aoe_vfx(pos: Vector2, radius: float) -> void:
	"""Sairias: Block AoE VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["sairias"][0], radius / 80.0)


func _spawn_reflect_vfx(pos: Vector2) -> void:
	"""Sairias: Parry reflect VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["sairias"][1], 0.5)


func _spawn_meteor_vfx(pos: Vector2, radius: float) -> void:
	"""Arthra: Meteor impact VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["arthra"][1], radius / 80.0)


func _spawn_pillar_vfx(pos: Vector2, radius: float) -> void:
	"""Sairias: Light pillar VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["sairias"][0], radius / 40.0, Color(1.0, 1.0, 0.9))


func _spawn_noron_vfx(pos: Vector2, radius: float, is_light: bool) -> void:
	"""Noron: Light/dark explosion VFX"""
	var idx: int = 0 if is_light else 1
	_spawn_explosion_vfx(pos, PATH_VFX["noron"][idx], radius / 80.0)


func _spawn_raelear_vfx(pos: Vector2, radius: float) -> void:
	"""Raelear: Shadow clone VFX"""
	_spawn_explosion_vfx(pos, PATH_VFX["raelear"][0], radius / 80.0, Color(0.7, 0.4, 1.0))


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
	var nearest: Node = null
	var nearest_dist: float = max_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
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
	var result: Array = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
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
