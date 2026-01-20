extends Node2D
class_name TrapBase

## Base class for all traps
## Godot 4.4 compatible

# ============================================================================
# SIGNALS
# ============================================================================

signal trap_triggered()
signal player_damaged(damage: int)

# ============================================================================
# EXPORTS
# ============================================================================

@export var damage: int = 10
@export var is_active: bool = true

# ============================================================================
# REFERENCES
# ============================================================================

@onready var area: Area2D = $Area2D if has_node("Area2D") else null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	if area:
		# Godot 4.4: Explicitly set monitoring
		area.monitoring = true
		area.monitorable = true
		area.body_entered.connect(_on_body_entered)

	add_to_group("traps")

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

func trigger() -> void:
	"""Triggers the trap"""
	if not is_active:
		return

	trap_triggered.emit()
	print("[TrapBase] %s triggered" % name)

func deal_damage(body: Node2D) -> void:
	"""Deals damage to player"""
	if not body.is_in_group("player") and not body.is_in_group("player2"):
		return

	# Try to find HealthComponent
	var health_comp = body.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(damage)
		player_damaged.emit(damage)
		print("[TrapBase] %s dealt %d damage to %s" % [name, damage, body.name])

# ============================================================================
# COLLISION HANDLER (Override in child classes)
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Override this in child classes"""
	pass
