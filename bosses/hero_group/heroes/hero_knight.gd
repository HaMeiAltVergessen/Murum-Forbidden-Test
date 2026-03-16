extends HeroGroupMember
## Tank — Hero Knight. Shield charge, stun bash, heavy swing.
## Last Standing: Burns, dual-wield, aggressive berserker.

const SPRITE_BASE: String = "res://Assets/placeholders/5heros/hero/Hero Knight 2/Sprites/"

func _ready() -> void:
	hero_name = "Ritter"
	max_hp = 250.0
	max_mana = 30.0
	mana_regen_rate = 2.0
	move_speed = 70.0

	attack_pattern = ["heavy_swing", "shield_charge", "heavy_swing", "stun_bash"]

	super._ready()


func _setup_animations() -> void:
	_register_anim("idle", SPRITE_BASE + "Idle.png", 11, 8.0)
	_register_anim("run", SPRITE_BASE + "Run.png", 8, 10.0)
	_register_anim("attack", SPRITE_BASE + "Attack.png", 6, 10.0, false)
	_register_anim("death", SPRITE_BASE + "Death.png", 9, 8.0, false)


func _get_preferred_range() -> float:
	return 90.0


# ============ AI OVERRIDE ============
func _ai_update(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()

	# Tank behavior: protect cleric by staying between player and backline
	if controller and not is_last_standing:
		var cleric: HeroGroupMember = controller.get_hero_by_name("Kleriker")
		if cleric and cleric.is_alive() and target and is_instance_valid(target):
			# Position between player and cleric
			var mid_x: float = (target.global_position.x + cleric.global_position.x) * 0.5
			var dist_to_mid: float = abs(global_position.x - mid_x)
			if dist_to_mid > 30.0:
				var dir: float = sign(mid_x - global_position.x)
				velocity.x = dir * move_speed
				facing_direction = sign(target.global_position.x - global_position.x)
				if animated_sprite:
					animated_sprite.flip_h = facing_direction < 0
				_play_anim("run")
				current_state = State.CHASE

				# Still try to attack if in range
				_try_next_attack()
				return

	super._ai_update(delta)


# ============ ATTACKS ============
func _execute_attack(attack_name: String) -> void:
	current_state = State.ATTACK
	current_attack = attack_name
	_advance_pattern()

	match attack_name:
		"heavy_swing":
			await _attack_heavy_swing()
		"shield_charge":
			await _attack_shield_charge()
		"stun_bash":
			await _attack_stun_bash()
		# Last Standing attacks
		"burning_slam":
			await _attack_burning_slam()
		"fire_charge":
			await _attack_fire_charge()
		"berserk_combo":
			await _attack_berserk_combo()

	if is_instance_valid(self) and current_state == State.ATTACK:
		current_state = State.IDLE
		current_attack = ""


func _attack_heavy_swing() -> void:
	# Charge
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 1.0, 0.5)
	_play_anim("attack")
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	# Swing
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	_spawn_melee_hitbox(20, 80.0, 250.0, 0.3)
	_start_cooldown("heavy_swing", 2.5)

	await get_tree().create_timer(0.4).timeout


func _attack_shield_charge() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.8, 1.5)
	_play_anim("run")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	# Dash
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	velocity.x = facing_direction * 400.0
	_spawn_melee_hitbox(12, 60.0, 350.0, 1.0, 0.3)
	_start_cooldown("shield_charge", 4.0)

	await get_tree().create_timer(0.4).timeout
	velocity.x = 0


func _attack_stun_bash() -> void:
	_play_anim("attack")
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(8, 60.0, 150.0, 1.5)
	_start_cooldown("stun_bash", 5.0)

	await get_tree().create_timer(0.3).timeout


# ============ LAST STANDING ATTACKS ============
func _attack_burning_slam() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 0.5, 0.2)
	_play_anim("attack")
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.8, 0.3)
	_spawn_aoe_hitbox(35, 120.0, 400.0, 0.4)
	_start_cooldown("burning_slam", 2.0)

	await get_tree().create_timer(0.3).timeout


func _attack_fire_charge() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 0.6, 0.1)
	_play_anim("run")
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	velocity.x = facing_direction * 500.0
	_spawn_melee_hitbox(25, 80.0, 400.0, 0.3, 0.3)
	_start_cooldown("fire_charge", 3.0)

	await get_tree().create_timer(0.5).timeout
	velocity.x = 0


func _attack_berserk_combo() -> void:
	_play_anim("attack")
	for i in range(3):
		await get_tree().create_timer(0.17).timeout
		if not is_instance_valid(self) or current_state != State.ATTACK:
			return
		_spawn_melee_hitbox(20, 80.0, 200.0, 0.1, 0.1)

	_start_cooldown("berserk_combo", 3.5)
	await get_tree().create_timer(0.3).timeout


# ============ LAST STANDING OVERRIDE ============
func _on_last_standing() -> void:
	# Shield off, burning two-hander
	attack_pattern = ["burning_slam", "fire_charge", "burning_slam", "berserk_combo"]
	pattern_index = 0
	move_speed = 100.0

	# Burning visual
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.8, 0.3)
