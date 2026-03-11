extends Node
## BoonEffectHandler — Executes passive boon effects (T1–T4) via EventBus signals
## Keeps BoonManager clean (data-only) and centralizes gameplay hooks here.

# ============ CONSTANTS ============
const CLONE_SCENE_COLOR := Color(0.5, 0.3, 0.8, 0.6)  # Raelear purple

# ============ NORON T1 STATE ============
var _twilight_blades_active: bool = false
var _twilight_blades_node: Node2D = null
var _blade_rotation: float = 0.0

# ============ NORON T4 STATE ============
var _kill_explosion_toggle: bool = false  # Alternates light/dark

# ============ MURRUM T2 DOT TRACKING ============
var _dot_targets: Array = []  # Array of {enemy, timer, dps}

# ============ RAELEAR CLONE TRACKING ============
var _active_clones: Array = []  # Track active clones for max limit


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

	print("[BoonEffectHandler] Initialized")


func _process(delta: float) -> void:
	# Noron T1: rotate blades
	if _twilight_blades_active and _twilight_blades_node and is_instance_valid(_twilight_blades_node):
		_blade_rotation += delta * 3.0  # Rotation speed
		_twilight_blades_node.rotation = _blade_rotation
		_process_blade_damage(delta)

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

	var every_n: int = BoonManager.get_param("arthra", 1, "every_n_hits", 3)
	if new_count % every_n != 0:
		return

	# Lightning strike on nearest enemy
	var player = _get_player()
	if not player:
		return

	var bonus_pct: float = BoonManager.get_param("arthra", 1, "bonus_damage_percent", 0.3)
	var base_damage: int = 20  # Base lightning damage
	var total_damage: int = int(base_damage * (1.0 + bonus_pct))

	var nearest: Node = _get_nearest_enemy(player.global_position, 300.0)
	if nearest:
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
		max_clones = BoonManager.get_param("raelear", 4, "max_clones", 5)
	if _active_clones.size() >= max_clones:
		return

	var duration: float = BoonManager.get_param("raelear", 1, "clone_duration", 3.0)
	var clone_dmg: int = BoonManager.get_param("raelear", 1, "clone_damage", 10)

	# Raelear T4: duration override
	if BoonManager.has_boon("raelear", 4):
		duration = BoonManager.get_param("raelear", 4, "duration_override", 8.0)

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

	# Noron T4: Kill explosion (alternating light/dark)
	if BoonManager.has_boon("noron", 4):
		_spawn_kill_explosion(position)

	# Raelear T2: Death clone
	if not BoonManager.has_boon("raelear", 2):
		return

	# Check max clones (default 2, Raelear T4: 5)
	_cleanup_dead_clones()
	var max_clones: int = 2
	if BoonManager.has_boon("raelear", 4):
		max_clones = BoonManager.get_param("raelear", 4, "max_clones", 5)
	if _active_clones.size() >= max_clones:
		return

	var duration: float = BoonManager.get_param("raelear", 2, "clone_duration", 5.0)
	var dmg_pct: float = BoonManager.get_param("raelear", 2, "damage_percent", 0.5)
	var clone_dmg: int = int(20 * dmg_pct)  # Base 20 * 50% = 10

	# Raelear T4: duration override
	if BoonManager.has_boon("raelear", 4):
		duration = BoonManager.get_param("raelear", 4, "duration_override", 8.0)

	_spawn_clone(position, duration, clone_dmg, "DeathClone")
	print("[BoonEffect] Raelear T2: Death clone at %v (%.1fs, %d/%d)" % [position, duration, _active_clones.size(), max_clones])


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
	var bonus_damage: int = BoonManager.get_param("murrum", 1, "bonus_damage", 15)
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

	var blade_radius: float = BoonManager.get_param("noron", 1, "blade_radius", 80)

	# Create 2 blade visuals (light + dark)
	for i in range(2):
		var blade := ColorRect.new()
		blade.name = "Blade_%d" % i
		blade.size = Vector2(20, 6)
		blade.position = Vector2(-10, -3)  # Center pivot
		var angle: float = i * PI  # Opposite sides
		blade.position += Vector2(cos(angle), sin(angle)) * blade_radius

		if i == 0:
			blade.color = Color(1.0, 1.0, 0.8, 0.8)  # Light blade
		else:
			blade.color = Color(0.3, 0.1, 0.4, 0.8)  # Dark blade
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

	var blade_dmg: int = BoonManager.get_param("noron", 1, "blade_damage", 8)
	var blade_radius: float = BoonManager.get_param("noron", 1, "blade_radius", 80)

	# Noron T3 bonus
	if BoonManager.has_boon("noron", 3):
		var bonus_pct: float = BoonManager.get_param("noron", 3, "blade_damage_bonus_percent", 0.3)
		blade_dmg = int(blade_dmg * (1.0 + bonus_pct))

	var enemies: Array = _get_enemies_in_radius(player.global_position, blade_radius + 20.0)
	for enemy in enemies:
		enemy.take_damage(blade_dmg, player)

		# Noron T3: Light heals HP, Dark heals Mana (alternating)
		if BoonManager.has_boon("noron", 3):
			_noron_t3_blade_heal(player)


func _noron_t3_blade_heal(player: Node) -> void:
	"""Noron T3: Blades heal HP (light) and Mana (dark) on hit"""
	var light_heal: int = BoonManager.get_param("noron", 3, "light_heal_per_hit", 3)
	var dark_mana: int = BoonManager.get_param("noron", 3, "dark_mana_per_hit", 3)

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
	if not is_instance_valid(enemy):
		return

	# Noron T2: Worte des Wahns — 15% confusion
	if BoonManager.has_boon("noron", 2):
		var chance: float = BoonManager.get_param("noron", 2, "chance_percent", 0.15)
		if randf() <= chance:
			var duration: float = BoonManager.get_param("noron", 2, "confusion_duration", 3.0)
			_apply_confusion(enemy, duration)

	# Arthra T4: Richter des Todes — auto Urteil mark on hit
	if BoonManager.has_boon("arthra", 4):
		_apply_auto_urteil(enemy)

	# Murrum T3: Elementare Überladung — +20% extra elemental damage on all hits
	var elemental_damage_dealt: int = 0
	if BoonManager.has_boon("murrum", 3):
		var bonus_pct: float = BoonManager.get_param("murrum", 3, "bonus_damage_percent", 0.2)
		var extra_dmg: int = int(_damage * bonus_pct)
		if extra_dmg > 0:
			enemy.take_damage(extra_dmg, _get_player())
			elemental_damage_dealt += extra_dmg
			# Murrum T2: DoT from elemental damage
			if BoonManager.has_boon("murrum", 2):
				_apply_dot(enemy)

	# Murrum T4: Herr der Elemente — all 4 elements as extra damage
	if BoonManager.has_boon("murrum", 4):
		var per_element: int = BoonManager.get_param("murrum", 4, "per_element_damage", 5)
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
			var slow_pct: float = BoonManager.get_param("noron", 4, "enemy_slow_percent", 0.2)
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

	var meteor_count: int = BoonManager.get_param("arthra", 3, "meteor_count", 3)
	var dmg_mult: float = BoonManager.get_param("arthra", 3, "damage_multiplier", 2.0)
	var radius: float = BoonManager.get_param("arthra", 3, "radius", 150)
	var base_damage: int = 30
	var meteor_damage: int = int(base_damage * dmg_mult)

	# Spawn meteors around player position with delay
	for i in range(meteor_count):
		var offset := Vector2(randf_range(-200, 200), randf_range(-200, 200))
		var target_pos: Vector2 = player.global_position + offset

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

	var dmg: int = BoonManager.get_param("noron", 4, "kill_explosion_damage", 30)
	var radius: float = BoonManager.get_param("noron", 4, "kill_explosion_radius", 120)

	var enemies: Array = _get_enemies_in_radius(position, radius)
	for enemy in enemies:
		enemy.take_damage(dmg, player)

	# Alternate color
	var color: Color
	if _kill_explosion_toggle:
		color = Color(1.0, 1.0, 0.8, 0.7)  # Light
	else:
		color = Color(0.3, 0.1, 0.4, 0.7)  # Dark
	_kill_explosion_toggle = not _kill_explosion_toggle

	_spawn_aoe_vfx(position, radius, color)
	print("[BoonEffect] Noron T4: Kill explosion! %d enemies hit" % enemies.size())


# ============ SAIRIAS T3: HIMMEL UND ERDE (Block Launch/Slam) ============
func _block_launch_slam(enemy: Node) -> void:
	"""Launches grounded enemies, slams airborne enemies"""
	if not is_instance_valid(enemy):
		return

	var launch_force: float = BoonManager.get_param("sairias", 3, "launch_force", 400)
	var slam_damage: int = BoonManager.get_param("sairias", 3, "slam_damage", 20)

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

	var pillar_count: int = BoonManager.get_param("sairias", 4, "pillar_count", 3)
	var pillar_dmg: int = BoonManager.get_param("sairias", 4, "pillar_damage", 40)
	var pillar_radius: float = BoonManager.get_param("sairias", 4, "pillar_radius", 60)
	var spawn_range: float = BoonManager.get_param("sairias", 4, "spawn_range", 200)

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
		var aoe_damage: int = BoonManager.get_param("sairias", 1, "block_aoe_damage", 10)
		var aoe_radius: float = BoonManager.get_param("sairias", 1, "block_aoe_radius", 100)

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
	if BoonManager.has_boon("sairias", 2) and is_instance_valid(enemy):
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
		var heal_pct: float = BoonManager.get_param("sairias", 5, "parry_heal_percent", 0.1)
		var health = player.get_node_or_null("HealthComponent")
		if health and health.has_method("heal"):
			var heal_amount: int = int(health.max_health * heal_pct)
			health.heal(heal_amount)
			print("[BoonEffect] Sairias T5: Parry heal +%d HP" % heal_amount)


# ============ T5 CAPSTONE EFFECTS ============

# -- Noron T5: Ewige Dämmerung — counter explosion on miss --
func noron_t5_counter(pos: Vector2) -> void:
	"""Called from HurtboxComponent when Noron T5 miss triggers"""
	var counter_dmg: int = BoonManager.get_param("noron", 5, "counter_explosion_damage", 50)
	var counter_radius: float = BoonManager.get_param("noron", 5, "counter_explosion_radius", 150)

	var player = _get_player()
	var enemies: Array = _get_enemies_in_radius(pos, counter_radius)
	for enemy in enemies:
		enemy.take_damage(counter_dmg, player)

	_spawn_aoe_vfx(pos, counter_radius, Color(0.3, 0.1, 0.5, 0.7))
	print("[BoonEffect] Noron T5: Counter explosion! %d enemies hit for %d" % [enemies.size(), counter_dmg])


# -- Raelear T5: Clone Death Save --
func consume_clone_for_death_save(player_pos: Vector2) -> void:
	"""Called from Murum when death save triggers — destroys nearest clone"""
	_cleanup_dead_clones()
	if _active_clones.is_empty():
		# No clone to destroy, but death save still works
		_spawn_aoe_vfx(player_pos, 60.0, Color(0.5, 0.3, 0.8, 0.8))
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
		_spawn_aoe_vfx(nearest_clone.global_position, 80.0, Color(0.5, 0.3, 0.8, 0.9))
		nearest_clone.queue_free()
		_active_clones.erase(nearest_clone)
		print("[BoonEffect] Raelear T5: Clone sacrificed!")


# -- Murrum T5: Ewiges Element — elemental damage heals HP + Mana --
func _murrum_t5_lifesteal(player: Node, elemental_damage: int) -> void:
	var heal_pct: float = BoonManager.get_param("murrum", 5, "heal_percent", 0.02)
	var mana_pct: float = BoonManager.get_param("murrum", 5, "mana_percent", 0.02)

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
	var chain_radius: float = BoonManager.get_param("arthra", 5, "chain_radius", 200)
	var enemies: Array = _get_enemies_in_radius(position, chain_radius)

	for enemy in enemies:
		if not enemy.has_meta("urteil_marked"):
			_apply_auto_urteil(enemy)

	if not enemies.is_empty():
		print("[BoonEffect] Arthra T5: Urteil chain! %d enemies marked" % enemies.size())


# ============ MURRUM T2: DOT SYSTEM ============
func _apply_dot(enemy: Node) -> void:
	"""Applies elemental DoT to an enemy"""
	if not is_instance_valid(enemy):
		return

	var dot_duration: float = BoonManager.get_param("murrum", 2, "dot_duration", 3.0)
	var dot_dps: int = BoonManager.get_param("murrum", 2, "dot_damage_per_sec", 5)

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
		if not is_instance_valid(dot["enemy"]) or dot["enemy"].is_dead:
			to_remove.append(i)
			continue

		dot["timer"] -= delta
		dot["tick"] += delta

		# Damage every 1 second
		if dot["tick"] >= 1.0:
			dot["tick"] -= 1.0
			dot["enemy"].take_damage(dot["dps"], player)

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


# ============ VFX HELPERS (placeholder visuals) ============
func _spawn_lightning_vfx(pos: Vector2) -> void:
	"""Spawns lightning VFX placeholder at position"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 0.3, 0.8)
	flash.size = Vector2(40, 40)
	flash.position = pos - Vector2(20, 20)
	scene_root.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _spawn_element_vfx(pos: Vector2, element: String) -> void:
	"""Spawns elemental VFX placeholder"""
	var colors: Dictionary = {
		"fire": Color(1.0, 0.4, 0.1),
		"water": Color(0.2, 0.5, 1.0),
		"earth": Color(0.6, 0.4, 0.2),
		"lightning": Color(1.0, 1.0, 0.3),
	}
	var color: Color = colors.get(element, Color.WHITE)

	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var flash := ColorRect.new()
	flash.color = color
	flash.color.a = 0.6
	flash.size = Vector2(80, 80)
	flash.position = pos - Vector2(40, 40)
	scene_root.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)


func _spawn_block_aoe_vfx(pos: Vector2, radius: float) -> void:
	"""Spawns block AoE VFX placeholder"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.85, 0.2, 0.4)
	flash.size = Vector2(radius * 2, radius * 2)
	flash.position = pos - Vector2(radius, radius)
	scene_root.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)


func _spawn_reflect_vfx(pos: Vector2) -> void:
	"""Spawns parry reflect VFX placeholder"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.5, 0.9)
	flash.size = Vector2(50, 50)
	flash.position = pos - Vector2(25, 25)
	scene_root.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _spawn_meteor_vfx(pos: Vector2, radius: float) -> void:
	"""Spawns meteor impact VFX placeholder"""
	_spawn_aoe_vfx(pos, radius, Color(1.0, 0.3, 0.1, 0.7))


func _spawn_pillar_vfx(pos: Vector2, radius: float) -> void:
	"""Spawns light pillar VFX placeholder"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	# Tall white pillar
	var pillar := ColorRect.new()
	pillar.color = Color(1.0, 1.0, 0.9, 0.8)
	pillar.size = Vector2(radius, 300)
	pillar.position = pos - Vector2(radius / 2.0, 300)
	scene_root.add_child(pillar)

	var tween := pillar.create_tween()
	tween.tween_property(pillar, "modulate:a", 0.0, 0.5)
	tween.tween_callback(pillar.queue_free)


func _spawn_aoe_vfx(pos: Vector2, radius: float, color: Color) -> void:
	"""Generic AoE circle VFX placeholder"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var flash := ColorRect.new()
	flash.color = color
	flash.size = Vector2(radius * 2, radius * 2)
	flash.position = pos - Vector2(radius, radius)
	scene_root.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)


# ============ UTILITY ============
func _get_player() -> Node:
	if GameManager and GameManager.player and is_instance_valid(GameManager.player):
		return GameManager.player
	return null


func _is_in_run() -> bool:
	return RunManager and RunManager.is_run_active()


func _get_nearest_enemy(pos: Vector2, max_range: float) -> Node:
	"""Returns nearest living enemy within range"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist: float = max_range

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist: float = enemy.global_position.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	"""Returns all living enemies within radius"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var result: Array = []

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
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
