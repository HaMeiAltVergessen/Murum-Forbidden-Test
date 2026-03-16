extends KollektivCore
## Cognition Core (AI Consciousness) — Center position
## Active: Projectiles have homing, laser walls faster, attacks coordinated
## Protected by separate energy shield (60 HP) that must be destroyed first
## Destroyed: Attacks chaotic/uncontrolled, overloads more frequent, no homing

# ============ CONFIGURATION ============
const SHIELD_HP: float = 60.0
const OVERLOAD_INTERVAL: float = 10.0
const OVERLOAD_DAMAGE: int = 8
const OVERLOAD_RADIUS: float = 200.0

# ============ STATE ============
var _shield: Node = null
var _shield_hp: float = SHIELD_HP
var _shield_active: bool = true
var _overload_timer: float = 0.0


func _ready() -> void:
	core_name = "Kognitionskern"
	max_hp = 180.0
	core_color = Color(0.2, 0.8, 0.9)  # Cyan
	super._ready()

	# Create energy shield
	_create_shield()


func _process(delta: float) -> void:
	if not is_systems_active or is_destroyed:
		return

	# Periodic overload (AoE around random position)
	_overload_timer += delta
	if _overload_timer >= OVERLOAD_INTERVAL / speed_mult:
		_overload_timer = 0.0
		_trigger_overload()


# ============ SHIELD ============
func _create_shield() -> void:
	"""Create destructible energy shield in front of the core"""
	_shield = Area2D.new()
	_shield.name = "EnergyShield"
	_shield.collision_layer = 1024
	_shield.collision_mask = 48
	_shield.monitoring = false
	_shield.monitorable = true
	_shield.add_to_group("enemies")
	_shield.add_to_group("kollektiv_shield")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140, 140)
	shape.shape = rect
	_shield.add_child(shape)

	# Shield visual
	var visual := ColorRect.new()
	visual.name = "ShieldVisual"
	visual.size = Vector2(140, 140)
	visual.position = Vector2(-70, -70)
	visual.color = Color(0.2, 0.8, 0.9, 0.3)
	_shield.add_child(visual)

	# Shield HP label
	var label := Label.new()
	label.name = "ShieldLabel"
	label.text = "Schild: %.0f" % _shield_hp
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -90)
	label.size = Vector2(100, 20)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.9))
	_shield.add_child(label)

	_shield.global_position = global_position
	add_child(_shield)

	# Make shield a HurtboxComponent-like receiver
	# We'll use a script to handle damage
	var hurtbox_script = HurtboxComponent.new()
	hurtbox_script.name = "ShieldHurtbox"
	hurtbox_script.collision_layer = 1024
	hurtbox_script.collision_mask = 48
	hurtbox_script.monitoring = false
	hurtbox_script.monitorable = true
	hurtbox_script.invulnerability_duration = 0.2

	var hb_shape := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(150, 150)
	hb_shape.shape = hb_rect
	hurtbox_script.add_child(hb_shape)

	hurtbox_script.damage_received.connect(_on_shield_damage)
	_shield.add_child(hurtbox_script)

	# Disable core's own hurtbox while shield is up
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)


func _on_shield_damage(damage: int, _knockback: Vector2, _hitstun: float) -> void:
	if not _shield_active:
		return

	_shield_hp -= damage
	print("[%s] Shield took %d damage — Shield HP: %.0f" % [core_name, damage, _shield_hp])

	# Update visual
	if _shield:
		var visual = _shield.get_node_or_null("ShieldVisual")
		if visual:
			visual.color.a = 0.1 + 0.2 * (_shield_hp / SHIELD_HP)
			# Flash on hit
			visual.modulate = Color(2.0, 1.0, 1.0)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(visual):
				visual.modulate = Color.WHITE

		var label = _shield.get_node_or_null("ShieldLabel")
		if label:
			label.text = "Schild: %.0f" % max(0, _shield_hp)

	if _shield_hp <= 0:
		_destroy_shield()


func _destroy_shield() -> void:
	"""Shield breaks — core becomes vulnerable"""
	_shield_active = false
	print("[%s] Shield destroyed!" % core_name)

	if _shield:
		# Shatter visual
		var visual = _shield.get_node_or_null("ShieldVisual")
		if visual:
			var tween := _shield.create_tween()
			tween.tween_property(visual, "modulate:a", 0.0, 0.3)

		# Disable shield hurtbox
		var shield_hurtbox = _shield.get_node_or_null("ShieldHurtbox")
		if shield_hurtbox:
			shield_hurtbox.set_deferred("monitorable", false)

		# Hide after fade
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(_shield):
			_shield.visible = false

	# Enable core's own hurtbox
	if hurtbox:
		hurtbox.set_deferred("monitorable", true)


func remove_shield() -> void:
	"""Called by controller when Energy Core is destroyed (shields fall)"""
	if _shield_active:
		_shield_hp = 0
		_destroy_shield()


# ============ SYSTEMS ============
func _on_systems_activated() -> void:
	set_process(true)


func _on_systems_deactivated() -> void:
	set_process(false)


func _trigger_overload() -> void:
	"""Random AoE energy burst somewhere in the arena"""
	var player: Node2D = GameManager.player if GameManager else null
	if not player or not is_instance_valid(player):
		return

	# Target area near player
	var target_pos: Vector2 = player.global_position + Vector2(randf_range(-150, 150), randf_range(-100, 100))

	# Warning indicator
	var warning := ColorRect.new()
	warning.name = "OverloadWarning"
	warning.size = Vector2(OVERLOAD_RADIUS * 2, OVERLOAD_RADIUS * 2)
	warning.position = target_pos - Vector2(OVERLOAD_RADIUS, OVERLOAD_RADIUS)
	warning.color = Color(0.2, 0.8, 0.9, 0.2)
	get_parent().add_child(warning)

	# Flash warning
	var tween := warning.create_tween()
	tween.tween_property(warning, "color:a", 0.5, 0.4)
	tween.tween_property(warning, "color:a", 0.1, 0.2)

	await get_tree().create_timer(0.8).timeout

	if is_instance_valid(warning):
		warning.queue_free()

	if is_destroyed:
		return

	# Spawn AoE hitbox
	var hitbox := HitboxComponent.new()
	hitbox.damage = int(OVERLOAD_DAMAGE * damage_mult)
	hitbox.knockback_force = 200.0
	hitbox.hitstun_duration = 0.2
	hitbox.collision_layer = 128
	hitbox.collision_mask = 1024

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = OVERLOAD_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)

	hitbox.global_position = target_pos
	get_parent().add_child(hitbox)
	hitbox.owner = self
	hitbox.activate()

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
