extends HeroGroupMember
## Bloodhunter/Rogue — Fantasy Warrior. Ultra-fast, highest DPS.
## Cthulhu transformation (any time, 50 mana, 8s): enhanced attacks.

# ============ CTHULHU STATE ============
var is_transformed: bool = false
var transform_timer: float = 0.0
var transform_cooldown: float = 0.0
const TRANSFORM_DURATION: float = 8.0
const TRANSFORM_COOLDOWN: float = 15.0

const SPRITE_BASE: String = "res://Assets/placeholders/5heros/bloodhunter/Fantasy Warrior/Sprites/"

func _ready() -> void:
	hero_name = "Blutjaeger"
	max_hp = 60.0
	max_mana = 50.0
	mana_regen_rate = 3.0
	move_speed = 180.0

	attack_pattern = ["fast_slash", "triple_combo", "fast_slash", "dodge_strike"]

	super._ready()


func _setup_animations() -> void:
	_register_anim("idle", SPRITE_BASE + "Idle.png", 10, 8.0)
	_register_anim("run", SPRITE_BASE + "Run.png", 8, 12.0)
	_register_anim("attack", SPRITE_BASE + "Attack1.png", 7, 12.0, false)
	_register_anim("death", SPRITE_BASE + "Death.png", 7, 8.0, false)


func _get_preferred_range() -> float:
	return 70.0


# ============ AI OVERRIDE ============
func _ai_update(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()

	# Transform check
	if is_transformed:
		transform_timer -= delta
		if transform_timer <= 0:
			_end_transform()
	else:
		transform_cooldown = max(0.0, transform_cooldown - delta)

	# Try to transform
	if not is_transformed and _should_transform():
		_start_transform()

	# Flanking behavior
	var flank_side = get_meta("flank_side") if has_meta("flank_side") else 0.0
	if flank_side != 0 and target and is_instance_valid(target):
		# Approach from flank side
		var target_x: float = target.global_position.x + flank_side * 100.0
		var dist_to_flank: float = abs(global_position.x - target_x)

		if dist_to_flank > 30.0 and not _try_next_attack():
			velocity.x = sign(target_x - global_position.x) * move_speed
			_play_anim("run")
			current_state = State.CHASE

			facing_direction = sign(target.global_position.x - global_position.x)
			if animated_sprite:
				animated_sprite.flip_h = facing_direction < 0
			return

	super._ai_update(delta)


# ============ CTHULHU TRANSFORMATION ============
func _should_transform() -> bool:
	if transform_cooldown > 0 or current_mana < 50:
		return false
	# Transform if HP < 70% or randomly every 15-20s
	if get_hp_percent() < 0.7:
		return true
	return false


func _start_transform() -> void:
	print("[Bloodhunter] CTHULHU TRANSFORMATION!")
	is_transformed = true
	transform_timer = TRANSFORM_DURATION
	transform_cooldown = TRANSFORM_COOLDOWN
	_spend_mana(50)

	# Visual: dark red/purple
	if animated_sprite:
		animated_sprite.modulate = Color(1.2, 0.3, 0.5)

	# Switch attack pattern
	attack_pattern = ["cthulhu_slash", "cthulhu_frenzy", "cthulhu_slash", "tentacle_sweep"]
	pattern_index = 0
	move_speed = 200.0


func _end_transform() -> void:
	print("[Bloodhunter] Transformation ended")
	is_transformed = false
	transform_timer = 0.0

	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

	attack_pattern = ["fast_slash", "triple_combo", "fast_slash", "dodge_strike"]
	pattern_index = 0
	move_speed = 180.0


# ============ ATTACKS ============
func _execute_attack(attack_name: String) -> void:
	current_state = State.ATTACK
	current_attack = attack_name
	_advance_pattern()

	match attack_name:
		"fast_slash":
			await _attack_fast_slash()
		"triple_combo":
			await _attack_triple_combo()
		"dodge_strike":
			await _attack_dodge_strike()
		"cthulhu_slash":
			await _attack_cthulhu_slash()
		"cthulhu_frenzy":
			await _attack_cthulhu_frenzy()
		"tentacle_sweep":
			await _attack_tentacle_sweep()

	if is_instance_valid(self) and current_state == State.ATTACK:
		current_state = State.IDLE
		current_attack = ""


func _attack_fast_slash() -> void:
	_play_anim("attack")
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(15, 60.0, 180.0, 0.15)
	_start_cooldown("fast_slash", 1.0)
	await get_tree().create_timer(0.2).timeout


func _attack_triple_combo() -> void:
	_play_anim("attack")
	# Hit 1 + 2 (12 each)
	for i in range(2):
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self) or current_state != State.ATTACK:
			return
		_spawn_melee_hitbox(12, 60.0, 150.0, 0.1, 0.1)

	# Hit 3 (18, finisher)
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return
	_spawn_melee_hitbox(18, 60.0, 250.0, 0.2, 0.1)

	_start_cooldown("triple_combo", 2.0)
	await get_tree().create_timer(0.15).timeout


func _attack_dodge_strike() -> void:
	# Teleport behind player
	if target and is_instance_valid(target):
		var behind_offset: float = -sign(target.global_position.x - global_position.x) * 60.0
		var teleport_pos: Vector2 = target.global_position + Vector2(behind_offset, 0)

		# Fade out
		if animated_sprite:
			animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self) or current_state != State.ATTACK:
			return

		global_position = teleport_pos
		facing_direction = sign(target.global_position.x - global_position.x)
		if animated_sprite:
			animated_sprite.flip_h = facing_direction < 0
			animated_sprite.modulate = Color.WHITE

		# Strike
		_play_anim("attack")
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self) or current_state != State.ATTACK:
			return

		_spawn_melee_hitbox(20, 60.0, 200.0, 0.2)

	_start_cooldown("dodge_strike", 3.0)
	await get_tree().create_timer(0.2).timeout


# ============ CTHULHU ATTACKS ============
func _attack_cthulhu_slash() -> void:
	_play_anim("attack")
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_melee_hitbox(22, 80.0, 200.0, 0.15)
	_start_cooldown("cthulhu_slash", 0.8)
	await get_tree().create_timer(0.15).timeout


func _attack_cthulhu_frenzy() -> void:
	_play_anim("attack")
	for i in range(4):
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(self) or current_state != State.ATTACK:
			return
		_spawn_melee_hitbox(18, 70.0, 150.0, 0.1, 0.1)

	_start_cooldown("cthulhu_frenzy", 2.5)
	await get_tree().create_timer(0.2).timeout


func _attack_tentacle_sweep() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.2, 0.5)
	_play_anim("attack")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or current_state != State.ATTACK:
		return

	_spawn_aoe_hitbox(25, 120.0, 350.0, 0.3)
	if animated_sprite:
		animated_sprite.modulate = Color(1.2, 0.3, 0.5) if is_transformed else Color.WHITE
	_start_cooldown("tentacle_sweep", 3.0)
	await get_tree().create_timer(0.2).timeout


# ============ LAST STANDING — No special phase, Cthulhu is always available ============
func _on_last_standing() -> void:
	# Bloodhunter doesn't have a "last standing" phase per se
	# Cthulhu transformation IS the power-up, and it's available anytime
	# Force transform immediately when last standing
	if not is_transformed and current_mana >= 50:
		_start_transform()
	move_speed = 200.0
