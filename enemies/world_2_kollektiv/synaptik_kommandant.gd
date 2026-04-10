extends CharacterBody2D
class_name SynaptikKommandant

## Synaptik-Kommandant — Pre-Boss Elite of Welt 2 (Das Kollektiv)
## Ranged commander with parryable cone volleys and a charged radial burst.
## Buff-Aura grants allied enemies +40% damage and -50% damage taken.

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_HP: int = 300
const MOVE_SPEED: float = 70.0
const GRAVITY: float = 980.0
const DETECTION_RANGE: float = 550.0
const PREFERRED_DISTANCE: float = 280.0
const FRONT_ARMOR: float = 0.7  # 30% reduction

# Cone-Puls (ranged, parryable on middle bolt)
const CONE_COOLDOWN: float = 2.5
const CONE_WINDUP: float = 0.4
const CONE_BOLT_COUNT: int = 5
const CONE_SPREAD_DEG: float = 30.0
const CONE_BOLT_DAMAGE: int = 14
const CONE_BOLT_SPEED: float = 360.0

# Overload-Schockwelle (heavy, charged)
const OVERLOAD_COOLDOWN: float = 12.0
const OVERLOAD_CHARGE_TIME: float = 2.5
const OVERLOAD_RELEASE_TIME: float = 0.4
const OVERLOAD_RADIUS: float = 260.0
const OVERLOAD_DAMAGE: int = 35
const OVERLOAD_KNOCKBACK: float = 520.0
const OVERLOAD_STUN: float = 1.5

# Buff-Aura
const AURA_RADIUS: float = 350.0
const AURA_TICK: float = 0.4

# Sprite frame regions placeholder (populated when spritesheet exists)
# 0=IDLE, 1=REPOSITION, 2=CONE_WINDUP, 3=CONE_FIRE,
# 4=OVERLOAD_CHARGE, 5=OVERLOAD_RELEASE, 6=STUNNED, 7=DEATH
const FRAME_REGIONS: Array = []

const ENERGY_BOLT_SCENE: PackedScene = preload("res://traps/world_2/scenes/energy_bolt.tscn")

# ============================================================================
# STATE
# ============================================================================

enum State {
	IDLE,
	REPOSITION,
	CONE_WINDUP,
	CONE_FIRE,
	OVERLOAD_CHARGE,
	OVERLOAD_RELEASE,
	STUNNED,
	COOLDOWN,
}

var current_hp: int = MAX_HP
var is_stunned: bool = false
var stun_duration: float = 0.0
var target: CharacterBody2D = null
var state: State = State.IDLE
var facing_right: bool = true
var cone_cooldown: float = 1.5
var overload_cooldown: float = 4.0
var windup_timer: float = 0.0
var release_timer: float = 0.0
var aura_tick_timer: float = 0.0
var _buffed_allies: Array = []
var _hp_thresholds_triggered: Array[float] = []
var _default_modulate: Color = Color.WHITE

# Visual helpers for placeholder
var _charge_ring: ColorRect = null

# ============================================================================
# REFERENCES
# ============================================================================

@onready var sprite: Node2D = $Sprite2D if has_node("Sprite2D") else null
@onready var body_visual: ColorRect = $BodyVisual if has_node("BodyVisual") else null
@onready var hurtbox: Area2D = $HurtboxComponent
@onready var hitbox: Area2D = $HitboxComponent if has_node("HitboxComponent") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null

# ============================================================================
# SIGNALS
# ============================================================================

signal health_changed(current: int, maximum: int)
signal died
signal stunned_signal(duration: float)
signal stun_ended

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("synaptik_kommandant")
	add_to_group("mini_boss")
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
	if hitbox:
		hitbox.monitoring = false
	_find_target()
	CombatManager.register_enemy(self)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

func _process(delta: float) -> void:
	_update_buff_aura(delta)
	if is_stunned:
		stun_duration -= delta
		if stun_duration <= 0.0:
			_end_stun()
		return
	_update_ai(delta)

# ============================================================================
# AI
# ============================================================================

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _update_ai(delta: float) -> void:
	if not target or not is_instance_valid(target):
		_find_target()
		return

	cone_cooldown -= delta
	overload_cooldown -= delta
	_check_hp_thresholds()

	var dist := get_distance_to_target()

	match state:
		State.IDLE:
			_set_sprite_frame(0)
			velocity.x = 0
			if dist <= DETECTION_RANGE:
				state = State.REPOSITION
		State.REPOSITION:
			_set_sprite_frame(1)
			_face_target()
			if dist > DETECTION_RANGE:
				state = State.IDLE
				velocity.x = 0
				return
			# Heavy attack has priority when ready
			if overload_cooldown <= 0.0:
				_start_overload_charge()
				return
			# Cone attack when cooldown ready
			if cone_cooldown <= 0.0 and dist <= DETECTION_RANGE * 0.9:
				state = State.CONE_WINDUP
				windup_timer = 0.0
				velocity.x = 0
				return
			# Otherwise hold preferred distance
			var dir := get_direction_to_target()
			if dist < PREFERRED_DISTANCE - 60.0:
				velocity.x = -dir.x * MOVE_SPEED
			elif dist > PREFERRED_DISTANCE + 60.0:
				velocity.x = dir.x * MOVE_SPEED
			else:
				velocity.x = 0
		State.CONE_WINDUP:
			_set_sprite_frame(2)
			_face_target()
			velocity.x = 0
			windup_timer += delta
			if windup_timer >= CONE_WINDUP:
				_fire_cone_volley()
				state = State.CONE_FIRE
				windup_timer = 0.0
		State.CONE_FIRE:
			_set_sprite_frame(3)
			velocity.x = 0
			windup_timer += delta
			if windup_timer >= 0.2:
				state = State.COOLDOWN
				cone_cooldown = CONE_COOLDOWN
				windup_timer = 0.0
		State.OVERLOAD_CHARGE:
			_set_sprite_frame(4)
			velocity.x = 0
			windup_timer += delta
			_update_charge_ring(windup_timer / OVERLOAD_CHARGE_TIME)
			if windup_timer >= OVERLOAD_CHARGE_TIME:
				_release_overload()
				state = State.OVERLOAD_RELEASE
				release_timer = 0.0
		State.OVERLOAD_RELEASE:
			_set_sprite_frame(5)
			velocity.x = 0
			release_timer += delta
			if release_timer >= OVERLOAD_RELEASE_TIME:
				state = State.COOLDOWN
				overload_cooldown = OVERLOAD_COOLDOWN
				_clear_charge_ring()
		State.COOLDOWN:
			_set_sprite_frame(0)
			_face_target()
			velocity.x = 0
			state = State.REPOSITION
		State.STUNNED:
			_set_sprite_frame(6)
			velocity.x = 0

# ============================================================================
# CONE-PULS (RANGED, PARRYABLE)
# ============================================================================

func _fire_cone_volley() -> void:
	if not target or not is_instance_valid(target):
		return
	var base_dir := get_direction_to_target()
	var base_angle := base_dir.angle()
	var spread_rad := deg_to_rad(CONE_SPREAD_DEG)
	var middle_index := CONE_BOLT_COUNT / 2
	for i in range(CONE_BOLT_COUNT):
		var t: float = 0.0 if CONE_BOLT_COUNT == 1 else float(i) / float(CONE_BOLT_COUNT - 1)
		var angle: float = base_angle - spread_rad * 0.5 + spread_rad * t
		var dir := Vector2(cos(angle), sin(angle))
		_spawn_cone_bolt(dir, i == middle_index)
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/energy_fire", global_position, 0.3)

func _spawn_cone_bolt(dir: Vector2, is_middle: bool) -> void:
	if not ENERGY_BOLT_SCENE:
		return
	var bolt = ENERGY_BOLT_SCENE.instantiate()
	bolt.damage = CONE_BOLT_DAMAGE
	bolt.speed = CONE_BOLT_SPEED
	bolt.direction = dir
	bolt.can_be_parried = is_middle
	bolt.global_position = global_position + dir * 40.0
	get_tree().current_scene.add_child(bolt)

# ============================================================================
# OVERLOAD-SCHOCKWELLE (HEAVY)
# ============================================================================

func _start_overload_charge() -> void:
	state = State.OVERLOAD_CHARGE
	windup_timer = 0.0
	velocity.x = 0
	_create_charge_ring()
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/energy_charge", global_position, 0.4)

func _release_overload() -> void:
	_clear_charge_ring()
	# Damage all players within radius
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var player_pos: Vector2 = player.global_position
		var d := global_position.distance_to(player_pos)
		if d <= OVERLOAD_RADIUS and player.has_method("take_damage"):
			var kb_dir: Vector2 = (player_pos - global_position).normalized()
			var player_hurtbox = player.get_node_or_null("HurtboxComponent")
			if player_hurtbox and player_hurtbox.has_method("take_damage"):
				player_hurtbox.take_damage(OVERLOAD_DAMAGE, kb_dir * OVERLOAD_KNOCKBACK, OVERLOAD_STUN, self)
			else:
				player.take_damage(OVERLOAD_DAMAGE)
	_spawn_overload_vfx()
	if AudioManager:
		AudioManager.play_sfx_at_position("traps/energy_impact", global_position, 0.5)

func _create_charge_ring() -> void:
	_clear_charge_ring()
	_charge_ring = ColorRect.new()
	_charge_ring.color = Color(0.4, 1.0, 1.3, 0.35)
	_charge_ring.size = Vector2(20, 20)
	_charge_ring.position = -_charge_ring.size * 0.5
	_charge_ring.z_index = -1
	add_child(_charge_ring)

func _update_charge_ring(progress: float) -> void:
	if not _charge_ring or not is_instance_valid(_charge_ring):
		return
	var ring_size: float = OVERLOAD_RADIUS * 2.0 * clamp(progress, 0.0, 1.0)
	_charge_ring.size = Vector2(ring_size, ring_size)
	_charge_ring.position = -_charge_ring.size * 0.5
	_charge_ring.color = Color(0.4 + progress * 0.6, 1.0, 1.3, 0.25 + progress * 0.35)

func _clear_charge_ring() -> void:
	if _charge_ring and is_instance_valid(_charge_ring):
		_charge_ring.queue_free()
	_charge_ring = null

func _spawn_overload_vfx() -> void:
	var ring := ColorRect.new()
	ring.color = Color(0.4, 1.2, 1.5, 0.6)
	var start_size: float = 30.0
	ring.size = Vector2(start_size, start_size)
	ring.position = global_position - ring.size * 0.5
	ring.z_index = -1
	get_tree().current_scene.add_child(ring)
	var target_size := OVERLOAD_RADIUS * 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "size", Vector2(target_size, target_size), 0.4)
	tween.tween_property(ring, "position", global_position - Vector2(OVERLOAD_RADIUS, OVERLOAD_RADIUS), 0.4)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)

# ============================================================================
# BUFF-AURA
# ============================================================================

func _update_buff_aura(delta: float) -> void:
	aura_tick_timer -= delta
	if aura_tick_timer > 0.0:
		return
	aura_tick_timer = AURA_TICK

	# Collect enemies in aura radius (excluding self)
	var current_targets: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self:
			continue
		if not enemy.has_method("apply_commander_buff"):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= AURA_RADIUS:
			current_targets.append(enemy)

	# Apply buff to newly in-range allies
	for ally in current_targets:
		if not _buffed_allies.has(ally):
			ally.apply_commander_buff(true)
			_buffed_allies.append(ally)

	# Remove buff from allies that left radius or died
	for i in range(_buffed_allies.size() - 1, -1, -1):
		var ally = _buffed_allies[i]
		if not is_instance_valid(ally) or not current_targets.has(ally):
			if is_instance_valid(ally) and ally.has_method("apply_commander_buff"):
				ally.apply_commander_buff(false)
			_buffed_allies.remove_at(i)

func _clear_all_buffs() -> void:
	for ally in _buffed_allies:
		if is_instance_valid(ally) and ally.has_method("apply_commander_buff"):
			ally.apply_commander_buff(false)
	_buffed_allies.clear()

# ============================================================================
# HP THRESHOLDS (force overload triggers)
# ============================================================================

func _check_hp_thresholds() -> void:
	var ratio := float(current_hp) / float(MAX_HP)
	for threshold in [0.75, 0.5, 0.25]:
		if ratio <= threshold and not _hp_thresholds_triggered.has(threshold):
			_hp_thresholds_triggered.append(threshold)
			overload_cooldown = min(overload_cooldown, 0.0)

# ============================================================================
# DAMAGE / DEATH / STUN
# ============================================================================

func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	var actual := damage
	if knockback.length() > 0:
		var from_right := knockback.x < 0
		var is_front := (facing_right and from_right) or (not facing_right and not from_right)
		if is_front:
			actual = int(float(damage) * FRONT_ARMOR)
	take_damage(actual)
	# Interrupt overload charge on parry-level hitstun
	if state == State.OVERLOAD_CHARGE and hitstun >= 0.3:
		_clear_charge_ring()
		state = State.REPOSITION
		overload_cooldown = 3.0
		stun(0.6)
		return
	if knockback.length() > 0:
		velocity = knockback * 0.3
	if hitstun > 0:
		stun(hitstun)

func take_damage(amount: int, _attacker: Node = null) -> void:
	current_hp -= amount
	current_hp = max(current_hp, 0)
	health_changed.emit(current_hp, MAX_HP)
	_flash_damage()
	if current_hp <= 0:
		die()

func _flash_damage() -> void:
	var visual: CanvasItem = body_visual if body_visual else sprite
	if not visual:
		return
	visual.modulate = Color(2.0, 0.5, 0.5, _default_modulate.a)
	await get_tree().create_timer(0.1).timeout
	if visual and is_instance_valid(visual):
		visual.modulate = _default_modulate

func die() -> void:
	_clear_all_buffs()
	_clear_charge_ring()
	died.emit()
	EventBus.enemy_died.emit(self, global_position)
	CombatManager.unregister_enemy(self)
	set_physics_process(false)
	set_process(false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	_spawn_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()

func _spawn_loot() -> void:
	var coin_scene = load("res://environment/pickups/gold_coin.tscn")
	if not coin_scene:
		return
	for i in range(randi() % 6 + 10):
		var coin = coin_scene.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		coin.gold_value = 1
		get_tree().current_scene.add_child(coin)

func stun(duration: float) -> void:
	is_stunned = true
	stun_duration = duration
	state = State.STUNNED
	_set_sprite_frame(6)
	var visual: CanvasItem = body_visual if body_visual else sprite
	if visual:
		visual.modulate = Color(1.5, 1.5, 0.5, _default_modulate.a)
	stunned_signal.emit(duration)
	EventBus.enemy_stunned.emit(self, duration)

func _end_stun() -> void:
	is_stunned = false
	stun_duration = 0.0
	state = State.REPOSITION
	_set_sprite_frame(0)
	var visual: CanvasItem = body_visual if body_visual else sprite
	if visual:
		visual.modulate = _default_modulate
	stun_ended.emit()

# ============================================================================
# UTILITY
# ============================================================================

func _set_sprite_frame(index: int) -> void:
	if sprite and sprite is Sprite2D and FRAME_REGIONS.size() > index and index >= 0:
		sprite.region_rect = FRAME_REGIONS[index]

func _face_target() -> void:
	if not target:
		return
	facing_right = target.global_position.x > global_position.x
	if body_visual:
		# No flip needed for a rectangle — but use it for potential Sprite flip
		pass
	if sprite and "flip_h" in sprite:
		sprite.flip_h = not facing_right

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func is_alive() -> bool:
	return current_hp > 0
