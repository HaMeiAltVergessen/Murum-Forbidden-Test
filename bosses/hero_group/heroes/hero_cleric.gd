extends HeroGroupMember
## Cleric — Evil Wizard 2. Heals allies, shoots light bolts.
## Last Standing: Dark damage mode — dark bolts, burst, life drain.

const SPRITE_BASE: String = "res://Assets/placeholders/5heros/cleric/EVil Wizard 2/Sprites/"

func _ready() -> void:
	hero_name = "Kleriker"
	max_hp = 150.0
	max_mana = 100.0
	mana_regen_rate = 5.0
	move_speed = 80.0

	attack_pattern = ["heal_ally", "light_bolt", "heal_ally", "light_bolt"]

	super._ready()


func _setup_animations() -> void:
	_register_anim("idle", SPRITE_BASE + "Idle.png", 8, 8.0)
	_register_anim("run", SPRITE_BASE + "Run.png", 8, 10.0)
	_register_anim("attack", SPRITE_BASE + "Attack1.png", 8, 10.0, false)
	_register_anim("death", SPRITE_BASE + "Death.png", 7, 8.0, false)


func _get_preferred_range() -> float:
	if is_last_standing:
		return 120.0
	return 200.0  # Stay at range


# ============ AI OVERRIDE ============
func _ai_update(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()

	if not is_last_standing:
		# Stay behind tank or keep distance
		var ideal_x = get_meta("ideal_x") if has_meta("ideal_x") else -1.0
		if ideal_x > 0 and target and is_instance_valid(target):
			var dist_to_ideal: float = abs(global_position.x - ideal_x)
			if dist_to_ideal > 40.0:
				velocity.x = sign(ideal_x - global_position.x) * move_speed
				_play_anim("run")
				current_state = State.CHASE

				# Face player
				if target:
					facing_direction = sign(target.global_position.x - global_position.x)
					if animated_sprite:
						animated_sprite.flip_h = facing_direction < 0

				_try_next_attack()
				return

		# Fallback: keep distance from player
		if target and is_instance_valid(target):
			var dist: float = global_position.distance_to(target.global_position)
			if dist < 150.0:
				velocity.x = -sign(target.global_position.x - global_position.x) * move_speed
				_play_anim("run")
				current_state = State.CHASE
				_try_next_attack()
				return

	super._ai_update(delta)


# ============ ATTACK PATTERN OVERRIDE ============
func _try_next_attack() -> bool:
	if attack_pattern.is_empty():
		return false

	# Heal priority: if any ally <60% HP and we have mana, prioritize heal
	if not is_last_standing and controller:
		var weakest: HeroGroupMember = controller.get_weakest_alive_hero()
		if weakest and weakest != self and weakest.get_hp_percent() < 0.6:
			if current_mana >= 30 and attack_cooldowns.get("heal_ally", 0.0) <= 0:
				_execute_attack("heal_ally")
				return true

	return super._try_next_attack()


func _has_mana_for(attack_name: String) -> bool:
	match attack_name:
		"heal_ally": return current_mana >= 30
		"light_bolt": return current_mana >= 10
		"dark_bolt": return current_mana >= 15
		"dark_burst": return current_mana >= 25
		"life_drain": return current_mana >= 20
	return true


func _is_in_range_for(attack_name: String) -> bool:
	match attack_name:
		"heal_ally":
			return true  # Can heal anyone
		"light_bolt", "dark_bolt":
			return get_distance_to_target() <= 300.0
		"dark_burst":
			return get_distance_to_target() <= 120.0
		"life_drain":
			return get_distance_to_target() <= 180.0
	return super._is_in_range_for(attack_name)


# ============ ATTACKS ============
func _execute_attack(attack_name: String) -> void:
	current_state = State.ATTACK
	current_attack = attack_name
	_advance_pattern()

	match attack_name:
		"heal_ally":
			await _attack_heal_ally()
		"light_bolt":
			await _attack_light_bolt()
		"dark_bolt":
			await _attack_dark_bolt()
		"dark_burst":
			await _attack_dark_burst()
		"life_drain":
			await _attack_life_drain()

	if is_instance_valid(self) and current_state == State.ATTACK:
		current_state = State.IDLE
		current_attack = ""


func _attack_heal_ally() -> void:
	if not controller:
		return

	var weakest: HeroGroupMember = controller.get_weakest_alive_hero()
	if not weakest or weakest == self or not weakest.is_alive():
		# No valid target, do light bolt instead
		if _has_mana_for("light_bolt"):
			await _attack_light_bolt()
		return

	_spend_mana(30)

	# Cast animation
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 1.5, 0.5)
	_play_anim("attack")
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	# Heal
	var heal_amount: float = 40.0
	weakest.current_hp = min(weakest.current_hp + heal_amount, weakest.max_hp)
	weakest.health_changed.emit(weakest.current_hp, weakest.max_hp)

	# Visual: green flash on target
	if weakest.animated_sprite:
		weakest.animated_sprite.modulate = Color(0.5, 2.0, 0.5)
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(weakest) and weakest.animated_sprite:
			weakest.animated_sprite.modulate = Color.WHITE

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

	_start_cooldown("heal_ally", 3.0)
	print("[Cleric] Healed %s for %.0f HP" % [weakest.hero_name, heal_amount])


func _attack_light_bolt() -> void:
	_spend_mana(10)
	_play_anim("attack")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if target and is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		_spawn_projectile(8, 250.0, dir, 350.0)

	_start_cooldown("light_bolt", 2.0)
	await get_tree().create_timer(0.3).timeout


# ============ LAST STANDING ATTACKS ============
func _attack_dark_bolt() -> void:
	_spend_mana(15)
	if animated_sprite:
		animated_sprite.modulate = Color(0.6, 0.2, 0.8)
	_play_anim("attack")
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if target and is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		_spawn_projectile(25, 300.0, dir, 400.0)

	if animated_sprite:
		animated_sprite.modulate = Color(0.8, 0.4, 1.0)
	_start_cooldown("dark_bolt", 1.5)
	await get_tree().create_timer(0.2).timeout


func _attack_dark_burst() -> void:
	_spend_mana(25)
	if animated_sprite:
		animated_sprite.modulate = Color(0.8, 0.1, 1.0)
	_play_anim("attack")
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_aoe_hitbox(30, 100.0, 350.0, 0.4)
	_start_cooldown("dark_burst", 4.0)
	await get_tree().create_timer(0.3).timeout


func _attack_life_drain() -> void:
	_spend_mana(20)
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.8, 0.2)
	_play_anim("attack")
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(20, 150.0, 200.0, 0.3)

	# Self-heal
	current_hp = min(current_hp + 15, max_hp)
	health_changed.emit(current_hp, max_hp)

	if animated_sprite:
		animated_sprite.modulate = Color(0.8, 0.4, 1.0)
	_start_cooldown("life_drain", 3.0)
	await get_tree().create_timer(0.2).timeout


# ============ LAST STANDING ============
func _on_last_standing() -> void:
	attack_pattern = ["dark_bolt", "dark_burst", "dark_bolt", "life_drain"]
	pattern_index = 0
	move_speed = 100.0

	if animated_sprite:
		animated_sprite.modulate = Color(0.8, 0.4, 1.0)
