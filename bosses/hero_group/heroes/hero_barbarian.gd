extends HeroGroupMember
## Barbarian — Huntress. Melee bruiser with war cry buff.
## Last Standing: All stats x2, gains rage_charge.

var war_cry_active: bool = false
var war_cry_timer: float = 0.0
var base_damage_multiplier: float = 1.0

const SPRITE_BASE: String = "res://Assets/placeholders/5heros/barbarian/Huntress/Sprites/"

func _ready() -> void:
	hero_name = "Barbar"
	max_hp = 120.0
	max_mana = 20.0
	mana_regen_rate = 1.0
	move_speed = 110.0

	attack_pattern = ["axe_swing", "overhead_smash", "axe_swing", "spear_throw", "war_cry"]

	super._ready()


func _setup_animations() -> void:
	_register_anim("idle", SPRITE_BASE + "Idle.png", 8, 8.0)
	_register_anim("run", SPRITE_BASE + "Run.png", 8, 10.0)
	_register_anim("attack", SPRITE_BASE + "Attack1.png", 5, 10.0, false)
	_register_anim("death", SPRITE_BASE + "Death.png", 8, 8.0, false)


func _get_preferred_range() -> float:
	if is_last_standing:
		return 80.0
	return 80.0


# ============ AI OVERRIDE ============
func _ai_update(delta: float) -> void:
	# War cry timer
	if war_cry_active:
		war_cry_timer -= delta
		if war_cry_timer <= 0:
			war_cry_active = false
			base_damage_multiplier = 1.0 if not is_last_standing else 2.0
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE if not is_last_standing else Color(1.5, 0.8, 0.3)

	super._ai_update(delta)


# ============ ATTACKS ============
func _execute_attack(attack_name: String) -> void:
	current_state = State.ATTACK
	current_attack = attack_name
	_advance_pattern()

	match attack_name:
		"axe_swing":
			await _attack_axe_swing()
		"overhead_smash":
			await _attack_overhead_smash()
		"spear_throw":
			await _attack_spear_throw()
		"war_cry":
			await _attack_war_cry()
		"rage_charge":
			await _attack_rage_charge()

	if is_instance_valid(self) and current_state == State.ATTACK:
		current_state = State.IDLE
		current_attack = ""


func _get_damage(base: int) -> int:
	return int(base * base_damage_multiplier)


func _attack_axe_swing() -> void:
	_play_anim("attack")
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(_get_damage(18), 70.0, 220.0, 0.2)
	_start_cooldown("axe_swing", 2.0)
	await get_tree().create_timer(0.3).timeout


func _attack_overhead_smash() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 1.0, 0.5) if not war_cry_active else Color(2.0, 1.0, 0.3)
	_play_anim("attack")
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(_get_damage(22), 80.0, 280.0, 0.3)
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE if not war_cry_active else Color(1.5, 1.2, 0.5)
	_start_cooldown("overhead_smash", 2.5)
	await get_tree().create_timer(0.3).timeout


func _attack_spear_throw() -> void:
	_play_anim("attack")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	if target and is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		_spawn_projectile(_get_damage(15), 350.0, dir, 300.0)

	_start_cooldown("spear_throw", 4.0)
	await get_tree().create_timer(0.3).timeout


func _attack_war_cry() -> void:
	# Buff self
	_play_anim("idle")
	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 1.5, 0.5)
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	war_cry_active = true
	war_cry_timer = 5.0
	base_damage_multiplier = 1.3 if not is_last_standing else 2.6
	_start_cooldown("war_cry", 8.0)

	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 1.2, 0.5)

	print("[Barbarian] WAR CRY! +30%% DMG for 5s")
	await get_tree().create_timer(0.3).timeout


func _attack_rage_charge() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 0.5, 0.2)
	_play_anim("run")
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	velocity.x = facing_direction * 400.0
	_spawn_melee_hitbox(_get_damage(30), 80.0, 400.0, 0.3, 0.3)
	_start_cooldown("rage_charge", 3.0)

	await get_tree().create_timer(0.4).timeout
	velocity.x = 0

	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.8, 0.3)


func _is_in_range_for(attack_name: String) -> bool:
	match attack_name:
		"spear_throw":
			return get_distance_to_target() <= 350.0
		"war_cry":
			return true  # Self-buff
		"rage_charge":
			return get_distance_to_target() <= 250.0
	return super._is_in_range_for(attack_name)


# ============ LAST STANDING ============
func _on_last_standing() -> void:
	# ALL stats x2
	max_hp = 240.0
	current_hp = 240.0
	move_speed = 220.0
	base_damage_multiplier = 2.0

	attack_pattern = ["axe_swing", "overhead_smash", "rage_charge", "axe_swing", "war_cry"]
	pattern_index = 0

	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.8, 0.3)

	health_changed.emit(current_hp, max_hp)
