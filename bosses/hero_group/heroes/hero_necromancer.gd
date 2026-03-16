extends HeroGroupMember
## Necromancer — Evil Wizard 3. Dark projectiles, resurrect allies.
## Last Standing: Mass resurrect (all dead allies at 50% HP, 9s channel, interruptible).

# ============ NECRO STATE ============
var is_channeling_resurrect: bool = false
var resurrect_timer: float = 0.0
var resurrect_target: HeroGroupMember = null
var mass_resurrect_attempted: bool = false

const SPRITE_BASE: String = "res://Assets/placeholders/5heros/necro/Evil Wizard 3/Sprites/"

func _ready() -> void:
	hero_name = "Nekromant"
	max_hp = 100.0
	max_mana = 80.0
	mana_regen_rate = 4.0
	move_speed = 75.0

	attack_pattern = ["dark_projectile", "dark_projectile", "projectile_spread"]

	super._ready()


func _setup_animations() -> void:
	_register_anim("idle", SPRITE_BASE + "Idle.png", 10, 8.0)
	_register_anim("run", SPRITE_BASE + "Run.png", 8, 10.0)
	_register_anim("attack", SPRITE_BASE + "Attack.png", 13, 12.0, false)
	_register_anim("death", SPRITE_BASE + "Death.png", 18, 8.0, false)


func _get_preferred_range() -> float:
	return 250.0  # Maximum distance


# ============ AI OVERRIDE ============
func _ai_update(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()

	# Handle channeling resurrect
	if is_channeling_resurrect:
		_process_resurrect_channel(delta)
		velocity.x = 0
		return

	# Keep maximum distance
	if target and is_instance_valid(target):
		var dist: float = global_position.distance_to(target.global_position)
		var keep_dist: float = get_meta("keep_distance") if has_meta("keep_distance") else 250.0

		if dist < keep_dist - 30:
			# Move away
			velocity.x = -sign(target.global_position.x - global_position.x) * move_speed
			_play_anim("run")
			current_state = State.CHASE

			facing_direction = sign(target.global_position.x - global_position.x)
			if animated_sprite:
				animated_sprite.flip_h = facing_direction < 0

			_try_next_attack()
			return

	super._ai_update(delta)


# ============ ATTACK OVERRIDE ============
func _try_next_attack() -> bool:
	# Priority: resurrect dead allies if possible
	if not is_last_standing and controller and current_mana >= 50:
		var dead: Array = controller.get_dead_heroes()
		if not dead.is_empty() and attack_cooldowns.get("resurrect_ally", 0.0) <= 0:
			_execute_attack("resurrect_ally")
			return true

	return super._try_next_attack()


func _has_mana_for(attack_name: String) -> bool:
	match attack_name:
		"dark_projectile": return current_mana >= 15
		"projectile_spread": return current_mana >= 25
		"resurrect_ally": return current_mana >= 50
		"empowered_projectile": return current_mana >= 15
		"death_nova": return current_mana >= 20
	return true


func _is_in_range_for(attack_name: String) -> bool:
	match attack_name:
		"resurrect_ally", "mass_resurrect":
			return true
		"dark_projectile", "projectile_spread", "empowered_projectile":
			return get_distance_to_target() <= 400.0
		"death_nova":
			return get_distance_to_target() <= 130.0
	return super._is_in_range_for(attack_name)


# ============ ATTACKS ============
func _execute_attack(attack_name: String) -> void:
	current_state = State.ATTACK
	current_attack = attack_name
	_advance_pattern()

	match attack_name:
		"dark_projectile":
			await _attack_dark_projectile()
		"projectile_spread":
			await _attack_projectile_spread()
		"resurrect_ally":
			_start_resurrect_channel()
			return  # Don't reset state — channel handles it
		"mass_resurrect":
			_start_mass_resurrect_channel()
			return
		"empowered_projectile":
			await _attack_empowered_projectile()
		"death_nova":
			await _attack_death_nova()

	if is_instance_valid(self) and current_state == State.ATTACK:
		current_state = State.IDLE
		current_attack = ""


func _attack_dark_projectile() -> void:
	_spend_mana(15)
	if animated_sprite:
		animated_sprite.modulate = Color(0.6, 0.2, 0.8)
	_play_anim("attack")
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if target and is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		_spawn_projectile(15, 280.0, dir, 350.0)

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	_start_cooldown("dark_projectile", 2.5)
	await get_tree().create_timer(0.3).timeout


func _attack_projectile_spread() -> void:
	_spend_mana(25)
	if animated_sprite:
		animated_sprite.modulate = Color(0.8, 0.1, 1.0)
	_play_anim("attack")
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	# 3-projectile fan
	if target and is_instance_valid(target):
		var base_dir: Vector2 = (target.global_position - global_position).normalized()
		for angle_offset in [-0.3, 0.0, 0.3]:
			var dir: Vector2 = base_dir.rotated(angle_offset)
			_spawn_projectile(10, 260.0, dir, 300.0)

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	_start_cooldown("projectile_spread", 4.0)
	await get_tree().create_timer(0.3).timeout


# ============ RESURRECT ============
func _start_resurrect_channel() -> void:
	if not controller:
		return

	var dead: Array = controller.get_dead_heroes()
	if dead.is_empty():
		current_state = State.IDLE
		current_attack = ""
		return

	resurrect_target = dead[0]
	_spend_mana(50)
	is_channeling_resurrect = true
	resurrect_timer = 3.0
	current_attack = "resurrect_ally"

	# Visual: glowing purple
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.5, 1.5)
	_play_anim("attack")

	print("[Necromancer] Channeling resurrect for %s (3.0s)..." % resurrect_target.hero_name)


func _start_mass_resurrect_channel() -> void:
	is_channeling_resurrect = true
	resurrect_timer = 9.0
	resurrect_target = null  # Mass = all
	current_attack = "mass_resurrect"

	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 0.5, 2.0)
	_play_anim("attack")

	print("[Necromancer] MASS RESURRECT channeling (9.0s)!")


func _process_resurrect_channel(delta: float) -> void:
	resurrect_timer -= delta

	# Pulsing visual
	if animated_sprite:
		var pulse: float = 1.0 + sin(resurrect_timer * 6.0) * 0.3
		animated_sprite.modulate = Color(pulse, 0.5, pulse + 0.5)

	if resurrect_timer <= 0:
		_complete_resurrect()


func _complete_resurrect() -> void:
	is_channeling_resurrect = false

	if current_attack == "mass_resurrect":
		# Resurrect ALL dead allies at 50%
		if controller:
			var dead: Array = controller.get_dead_heroes().duplicate()
			for hero in dead:
				if is_instance_valid(hero):
					hero.resurrect(0.5)
		print("[Necromancer] MASS RESURRECT complete!")
		mass_resurrect_attempted = true
	else:
		# Single resurrect at 30%
		if resurrect_target and is_instance_valid(resurrect_target):
			resurrect_target.resurrect(0.3)
			print("[Necromancer] Resurrected %s!" % resurrect_target.hero_name)

	resurrect_target = null
	current_state = State.IDLE
	current_attack = ""
	_start_cooldown("resurrect_ally", 10.0)

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func _interrupt_resurrect() -> void:
	if not is_channeling_resurrect:
		return

	print("[Necromancer] Resurrect INTERRUPTED!")
	is_channeling_resurrect = false
	resurrect_target = null
	current_state = State.IDLE
	current_attack = ""

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


# ============ OVERRIDE: Stun interrupts channel ============
func stun(duration: float) -> void:
	if is_channeling_resurrect:
		_interrupt_resurrect()
	super.stun(duration)


func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	# Interrupt resurrect on any hit
	if is_channeling_resurrect:
		_interrupt_resurrect()
	super._on_damage_received(damage, knockback, hitstun)


# ============ LAST STANDING ATTACKS ============
func _attack_empowered_projectile() -> void:
	_spend_mana(15)
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.3, 1.5)
	_play_anim("attack")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if target and is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		_spawn_projectile(25, 300.0, dir, 400.0)

	_start_cooldown("empowered_projectile", 1.5)
	await get_tree().create_timer(0.2).timeout


func _attack_death_nova() -> void:
	_spend_mana(20)
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.1, 1.5)
	_play_anim("attack")
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_aoe_hitbox(20, 100.0, 300.0, 0.3)
	_start_cooldown("death_nova", 3.0)
	await get_tree().create_timer(0.3).timeout


# ============ LAST STANDING ============
var _mass_resurrect_cooldown: float = 0.0

func _on_last_standing() -> void:
	# Immediately try mass resurrect
	_execute_attack("mass_resurrect")

func _ai_update_last_standing(delta: float) -> void:
	# After mass resurrect (or interruption), switch to combat + retry
	if not is_channeling_resurrect and mass_resurrect_attempted:
		# Attack pattern: empowered + death nova, retry mass resurrect after 5s
		_mass_resurrect_cooldown -= delta
		if _mass_resurrect_cooldown <= 0 and not mass_resurrect_attempted:
			_execute_attack("mass_resurrect")
			_mass_resurrect_cooldown = 5.0
			return

	# Use combat pattern between attempts
	if not is_channeling_resurrect:
		super._ai_update(delta)

# Override ai_update to handle last standing properly
func _ai_update(delta: float) -> void:
	if is_last_standing and not is_channeling_resurrect:
		# After first mass resurrect attempt, fight + retry
		if mass_resurrect_attempted:
			_mass_resurrect_cooldown -= delta
			if _mass_resurrect_cooldown <= 0 and controller:
				var dead: Array = controller.get_dead_heroes()
				if not dead.is_empty():
					mass_resurrect_attempted = false
					_mass_resurrect_cooldown = 5.0
					_execute_attack("mass_resurrect")
					return

			# Fight with empowered pattern
			attack_pattern = ["empowered_projectile", "death_nova", "empowered_projectile"]
		super._ai_update(delta)
		return

	if is_channeling_resurrect:
		velocity.x = 0
		return

	super._ai_update(delta)
