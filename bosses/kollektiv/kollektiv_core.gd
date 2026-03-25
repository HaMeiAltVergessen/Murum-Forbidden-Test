extends StaticBody2D
## Base class for all Kollektiv core modules (boss fight)
## Handles HP, damage, death (no queue_free), system activation/deactivation
class_name KollektivCore

# ============ SIGNALS ============
signal destroyed(core: KollektivCore)
signal health_changed(current_hp: float, max_hp: float)

# ============ EXPORTS ============
@export var core_name: String = "Core"
@export var max_hp: float = 100.0
@export var core_color: Color = Color(0.8, 0.4, 0.2)

# ============ STATE ============
var current_hp: float
var is_destroyed: bool = false
var is_systems_active: bool = false
var controller: Node = null  # KollektivController reference

# Escalation modifiers (set by controller)
var speed_mult: float = 1.0
var damage_mult: float = 1.0
var cognition_active: bool = true  # Homing, precision, etc.

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============ INITIALIZATION ============
func _ready() -> void:
	current_hp = max_hp

	add_to_group("enemies")
	add_to_group("kollektiv_core")

	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)

	# Register with CombatManager
	if CombatManager:
		CombatManager.register_enemy(self)

	# Tint sprite
	if sprite:
		sprite.modulate = core_color

	print("[%s] Ready — HP: %.0f" % [core_name, current_hp])


# ============ DAMAGE ============
func _on_damage_received(damage: int, knockback: Vector2, hitstun: float) -> void:
	if is_destroyed:
		return
	take_damage(damage)


func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_destroyed or current_hp <= 0:
		return

	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	_flash_damage()

	print("[%s] Took %.0f damage — HP: %.0f/%.0f" % [core_name, amount, current_hp, max_hp])

	if current_hp <= 0:
		die()


func _flash_damage() -> void:
	if not sprite:
		return
	var original: Color = sprite.modulate
	sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and sprite:
		sprite.modulate = original


# ============ DEATH ============
func die() -> void:
	if is_destroyed:
		return

	print("[%s] Destroyed!" % core_name)
	is_destroyed = true
	current_hp = 0

	# Deactivate systems
	deactivate_systems()

	# Disable combat but keep visual
	_disable_combat()

	# Note: destruction VFX (explosion, fade) handled by KollektivController._play_core_destruction_vfx()

	# Emit signals
	destroyed.emit(self)
	EventBus.enemy_died.emit(self, global_position)
	if CombatManager:
		CombatManager.unregister_enemy(self)


func _disable_combat() -> void:
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)


func _enable_combat() -> void:
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)


# ============ SYSTEM ACTIVATION (override in subclasses) ============
func activate_systems() -> void:
	if is_destroyed or is_systems_active:
		return
	is_systems_active = true
	_on_systems_activated()
	print("[%s] Systems activated" % core_name)


func deactivate_systems() -> void:
	if not is_systems_active:
		return
	is_systems_active = false
	_on_systems_deactivated()
	print("[%s] Systems deactivated" % core_name)


func _on_systems_activated() -> void:
	# Override in subclass
	pass


func _on_systems_deactivated() -> void:
	# Override in subclass
	pass


# ============ UTILITY ============
func get_hp_percent() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0


func is_alive() -> bool:
	return not is_destroyed and current_hp > 0
