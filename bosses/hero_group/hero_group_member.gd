extends CharacterBody2D
## Base class for all hero group members (boss fight)
## Handles HP, Mana, Movement, Stun, Death (no queue_free), Resurrect
class_name HeroGroupMember

# ============ SIGNALS ============
signal died(hero: HeroGroupMember)
signal resurrected(hero: HeroGroupMember)
signal health_changed(current_hp: float, max_hp: float)
signal last_standing_activated(hero: HeroGroupMember)
signal attack_interrupted(hero: HeroGroupMember)

# ============ ENUMS ============
enum State {
	IDLE,
	CHASE,
	ATTACK,
	STUNNED,
	DEAD,
	LAST_STANDING_TRANSITION,
	RESURRECTING,
}

# ============ EXPORTS ============
@export var hero_name: String = "Hero"
@export var max_hp: float = 100.0
@export var max_mana: float = 50.0
@export var mana_regen_rate: float = 2.0
@export var move_speed: float = 100.0
@export var gravity: float = 980.0

# ============ STATE ============
var current_hp: float
var current_mana: float
var current_state: State = State.IDLE
var is_last_standing: bool = false
var facing_direction: float = 1.0  # 1.0 = right, -1.0 = left

# Attack state
var attack_cooldowns: Dictionary = {}  # attack_name: remaining_cooldown
var current_attack: String = ""
var attack_pattern: Array[String] = []
var pattern_index: int = 0

# Stun
var stun_timer: float = 0.0

# AI targeting
var target: Node2D = null
var controller: Node = null  # HeroGroupController reference

# Sprite sheet animation
var _sprite_sheets: Dictionary = {}  # anim_name: {texture, hframes, speed}
var _current_anim: String = ""
var _anim_frame: float = 0.0
var _anim_speed: float = 10.0
var _anim_loop: bool = true

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Alias for subclass compatibility
var animated_sprite: Sprite2D:
	get: return sprite


# ============ INITIALIZATION ============
func _ready() -> void:
	current_hp = max_hp
	current_mana = max_mana

	add_to_group("enemies")
	add_to_group("hero_group")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Register with CombatManager
	if CombatManager:
		CombatManager.register_enemy(self)

	_setup_animations()
	_play_anim("idle")
	_find_target()

	print("[%s] Ready — HP: %.0f, Mana: %.0f" % [hero_name, current_hp, max_mana])


func _setup_animations() -> void:
	# Override in subclass to register sprite sheets
	pass


func _register_anim(anim_name: String, texture_path: String, hframes: int, speed: float = 10.0, loop: bool = true) -> void:
	var tex: Texture2D = load(texture_path) as Texture2D
	if tex:
		_sprite_sheets[anim_name] = {"texture": tex, "hframes": hframes, "speed": speed, "loop": loop}
	else:
		push_warning("[%s] Failed to load sprite: %s" % [hero_name, texture_path])


# ============ PHYSICS ============
func _physics_process(delta: float) -> void:
	match current_state:
		State.DEAD, State.LAST_STANDING_TRANSITION, State.RESURRECTING:
			# Apply gravity even when dead (so corpse stays on ground)
			if not is_on_floor():
				velocity.y += gravity * delta
			else:
				velocity.y = 0
			move_and_slide()
			return
		State.STUNNED:
			stun_timer -= delta
			if stun_timer <= 0.0:
				_end_stun()
			if not is_on_floor():
				velocity.y += gravity * delta
			move_and_slide()
			return

	# Mana regen
	current_mana = min(current_mana + mana_regen_rate * delta, max_mana)

	# Cooldown ticking
	for attack_name in attack_cooldowns.keys():
		attack_cooldowns[attack_name] = max(0.0, attack_cooldowns[attack_name] - delta)

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# AI behavior (override in subclass)
	if current_state != State.ATTACK:
		_ai_update(delta)

	move_and_slide()

	# Sprite sheet animation update
	_update_sprite_animation(delta)


func _update_sprite_animation(delta: float) -> void:
	if not sprite or _current_anim == "" or not _sprite_sheets.has(_current_anim):
		return
	var data: Dictionary = _sprite_sheets[_current_anim]
	var total_frames: int = data["hframes"]
	_anim_frame += _anim_speed * delta
	if _anim_frame >= total_frames:
		if _anim_loop:
			_anim_frame = fmod(_anim_frame, total_frames)
		else:
			_anim_frame = total_frames - 1
	sprite.frame = int(_anim_frame)


# ============ AI (override in subclasses) ============
func _ai_update(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			current_state = State.IDLE
			velocity.x = 0
			return

	# Face target
	var dir: float = sign(target.global_position.x - global_position.x)
	if dir != 0:
		facing_direction = dir
		if animated_sprite:
			animated_sprite.flip_h = facing_direction < 0

	# Try next attack in pattern
	if _try_next_attack():
		return

	# Default: chase target
	_chase_target()


func _chase_target() -> void:
	if not target or not is_instance_valid(target):
		return

	var distance: float = global_position.distance_to(target.global_position)
	var preferred_range: float = _get_preferred_range()

	if distance > preferred_range + 20.0:
		current_state = State.CHASE
		velocity.x = facing_direction * move_speed
		_play_anim("run")
	else:
		current_state = State.IDLE
		velocity.x = 0
		_play_anim("idle")


func _get_preferred_range() -> float:
	return 80.0  # Override per hero


# ============ ATTACK SYSTEM ============
func _try_next_attack() -> bool:
	if attack_pattern.is_empty():
		return false

	var attack_name: String = attack_pattern[pattern_index]

	# Check cooldown
	if attack_cooldowns.get(attack_name, 0.0) > 0.0:
		return false

	# Check range
	if not _is_in_range_for(attack_name):
		return false

	# Check mana
	if not _has_mana_for(attack_name):
		return false

	# Execute
	_execute_attack(attack_name)
	return true


func _execute_attack(_attack_name: String) -> void:
	# Override in subclass
	pass


func _advance_pattern() -> void:
	pattern_index = (pattern_index + 1) % attack_pattern.size()


func _is_in_range_for(_attack_name: String) -> bool:
	if not target or not is_instance_valid(target):
		return false
	return global_position.distance_to(target.global_position) <= _get_preferred_range() + 40.0


func _has_mana_for(_attack_name: String) -> bool:
	return true  # Override if attack costs mana


func _start_cooldown(attack_name: String, duration: float) -> void:
	attack_cooldowns[attack_name] = duration


func _spend_mana(amount: float) -> void:
	current_mana = max(0.0, current_mana - amount)


# ============ DAMAGE ============
func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	if current_state == State.DEAD or current_state == State.RESURRECTING:
		return

	take_damage(damage)

	if knockback.length() > 0 and current_state != State.ATTACK:
		velocity = knockback * 0.5  # Reduced knockback for bosses

	if hitstun > 0 and current_state != State.ATTACK:
		stun(hitstun * 0.5)  # Reduced hitstun for bosses


func take_damage(amount: float, _attacker: Node = null) -> void:
	if current_hp <= 0:
		return

	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	_flash_damage()

	print("[%s] Took %.0f damage — HP: %.0f/%.0f" % [hero_name, amount, current_hp, max_hp])

	if current_hp <= 0:
		die()


func _flash_damage() -> void:
	if not animated_sprite:
		return
	var original: Color = animated_sprite.modulate
	animated_sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and animated_sprite:
		animated_sprite.modulate = original


# ============ STUN ============
func stun(duration: float) -> void:
	if current_state == State.DEAD:
		return
	current_state = State.STUNNED
	stun_timer = duration

	# Interrupt current attack
	if current_attack != "":
		attack_interrupted.emit(self)
		current_attack = ""

	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)

	EventBus.enemy_stunned.emit(self, duration)


func _end_stun() -> void:
	current_state = State.IDLE
	stun_timer = 0.0
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


# ============ DEATH ============
func die() -> void:
	if current_state == State.DEAD:
		return

	print("[%s] Died!" % hero_name)
	current_state = State.DEAD
	current_hp = 0
	current_attack = ""

	# Disable combat but keep in scene
	_disable_combat()

	_play_anim("death")
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Emit signals
	died.emit(self)
	EventBus.enemy_died.emit(self, global_position)
	CombatManager.unregister_enemy(self)


func _disable_combat() -> void:
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	# Disable physics collision for body
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)


func _enable_combat() -> void:
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)  # Hurtbox is monitorable, not monitoring
		hurtbox.set_deferred("monitorable", true)
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)


# ============ RESURRECT ============
func resurrect(hp_percent: float = 0.3) -> void:
	if current_state != State.DEAD:
		return

	print("[%s] Resurrecting at %.0f%% HP!" % [hero_name, hp_percent * 100])
	current_state = State.RESURRECTING

	# Restore HP
	current_hp = max_hp * hp_percent
	health_changed.emit(current_hp, max_hp)

	# Re-enable combat
	_enable_combat()

	# Re-register with CombatManager
	if CombatManager:
		CombatManager.register_enemy(self)

	# Visual feedback
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.8)
		await tween.finished

	current_state = State.IDLE
	_current_anim = ""  # Force anim reset
	_play_anim("idle")

	resurrected.emit(self)
	print("[%s] Resurrect complete — HP: %.0f/%.0f" % [hero_name, current_hp, max_hp])


# ============ LAST STANDING ============
func activate_last_standing() -> void:
	if is_last_standing:
		return

	print("[%s] LAST STANDING activated!" % hero_name)
	current_state = State.LAST_STANDING_TRANSITION
	is_last_standing = true

	# Heal to full
	current_hp = max_hp
	current_mana = max_mana
	health_changed.emit(current_hp, max_hp)

	# Visual flash
	if animated_sprite:
		animated_sprite.modulate = Color(3.0, 1.0, 1.0, 1.0)
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 1.0)

	# Override in subclass for specific transformations
	_on_last_standing()

	await get_tree().create_timer(1.5).timeout

	if is_instance_valid(self) and current_state == State.LAST_STANDING_TRANSITION:
		current_state = State.IDLE
		last_standing_activated.emit(self)


func _on_last_standing() -> void:
	# Override in subclass
	pass


# ============ UTILITY ============
func _find_target() -> void:
	target = GameManager.player if GameManager and is_instance_valid(GameManager.player) else null


func _play_anim(anim_name: String) -> void:
	if anim_name == _current_anim:
		return
	if not _sprite_sheets.has(anim_name):
		return
	_current_anim = anim_name
	_anim_frame = 0.0
	var data: Dictionary = _sprite_sheets[anim_name]
	_anim_speed = data["speed"]
	_anim_loop = data["loop"]
	if sprite:
		sprite.texture = data["texture"]
		sprite.hframes = data["hframes"]
		sprite.frame = 0


func get_hp_percent() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0


func is_alive() -> bool:
	return current_hp > 0 and current_state != State.DEAD


func get_distance_to_target() -> float:
	if not target or not is_instance_valid(target):
		return 99999.0
	return global_position.distance_to(target.global_position)


# ============ HITBOX SPAWNING HELPERS ============
func _spawn_melee_hitbox(damage_amount: int, range_px: float, knockback: float = 200.0, hitstun: float = 0.2, duration: float = 0.15) -> void:
	var hitbox := HitboxComponent.new()
	hitbox.damage = damage_amount
	hitbox.knockback_force = knockback
	hitbox.hitstun_duration = hitstun
	# owner will be set after add_child via _set_hitbox_owner
	# Collision: Layer 128 (enemy attacks), Mask 1024 (player hurtbox)
	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(range_px, 40)
	shape.shape = rect
	shape.position = Vector2(facing_direction * range_px * 0.5, 0)
	hitbox.add_child(shape)

	add_child(hitbox)
	hitbox.owner = self
	hitbox.activate()

	await get_tree().create_timer(duration).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _spawn_aoe_hitbox(damage_amount: int, radius: float, knockback: float = 300.0, hitstun: float = 0.3, duration: float = 0.2) -> void:
	var hitbox := HitboxComponent.new()
	hitbox.damage = damage_amount
	hitbox.knockback_force = knockback
	hitbox.hitstun_duration = hitstun
	hitbox.owner = self

	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)

	add_child(hitbox)
	hitbox.owner = self
	hitbox.activate()

	await get_tree().create_timer(duration).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _spawn_projectile(damage_amount: int, speed: float, direction: Vector2, max_range: float = 350.0) -> void:
	var proj := HeroProjectile.new()
	proj.name = "HeroProjectile"
	proj.collision_layer = 128
	proj.collision_mask = 1024
	proj.proj_speed = speed
	proj.proj_dir = direction.normalized()
	proj.proj_damage = damage_amount
	proj.proj_max_range = max_range
	proj.proj_owner = self

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	proj.add_child(shape)

	# Visual placeholder
	var visual := ColorRect.new()
	visual.size = Vector2(12, 12)
	visual.position = Vector2(-6, -6)
	visual.color = Color(0.8, 0.2, 0.9)
	proj.add_child(visual)

	proj.global_position = global_position + Vector2(facing_direction * 20, -10)
	get_parent().add_child(proj)
