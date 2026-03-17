extends Node2D
## UrteilMark — Mirror version of Urteil: marks the player
## Player must land a combo hit within the duration or take explosion damage
class_name UrteilMark

# ============ CONFIG ============
const MARK_DURATION: float = 4.0
const EXPLOSION_DAMAGE: int = 30
const EXPLOSION_RADIUS: float = 120.0
const WARNING_PULSE_SPEED: float = 5.0

# ============ STATE ============
var target: Node2D = null
var _timer: float = 0.0
var _defused: bool = false
var _visual: ColorRect = null


func _ready() -> void:
	# Listen for player combo hits to defuse
	EventBus.hit_registered.connect(_on_hit_registered)

	# Visual indicator on target
	_visual = ColorRect.new()
	_visual.size = Vector2(30, 30)
	_visual.position = Vector2(-15, -15)
	_visual.color = Color(0.8, 0.0, 0.2, 0.7)
	add_child(_visual)


func _process(delta: float) -> void:
	if _defused:
		return

	# Follow target
	if target and is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -110)
	else:
		queue_free()
		return

	_timer += delta

	# Warning pulse (gets faster near end)
	var urgency: float = _timer / MARK_DURATION
	var pulse_speed: float = WARNING_PULSE_SPEED * (1.0 + urgency * 3.0)
	if _visual:
		var pulse: float = 0.4 + 0.6 * abs(sin(_timer * pulse_speed))
		_visual.modulate.a = pulse
		_visual.color = Color(0.8, 0.0, 0.2).lerp(Color(1.0, 0.0, 0.0), urgency)

	# Explode when time runs out
	if _timer >= MARK_DURATION:
		_explode()


func _on_hit_registered(_attacker: Node, _target: Node, _damage: int) -> void:
	"""Any hit by the player defuses the mark"""
	if _defused:
		return

	# Check if the attacker is a player
	if _attacker and (_attacker.is_in_group("player") or _attacker.is_in_group("player2")):
		_defuse()


func _defuse() -> void:
	"""Mark is defused by player hitting something"""
	_defused = true
	print("[UrteilMark] Defused by player hit!")

	# Green flash
	if _visual:
		_visual.color = Color(0.2, 0.8, 0.2, 0.8)

	# Fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _explode() -> void:
	"""Mark explodes — deal damage to target"""
	if _defused:
		return
	_defused = true

	print("[UrteilMark] EXPLOSION! Player failed to defuse!")

	if target and is_instance_valid(target):
		if target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage(EXPLOSION_DAMAGE)

	# Explosion visual
	if _visual:
		var tween := create_tween()
		_visual.color = Color(1.0, 0.3, 0.0, 1.0)
		tween.tween_property(_visual, "size", Vector2(EXPLOSION_RADIUS * 2, EXPLOSION_RADIUS * 2), 0.2)
		tween.parallel().tween_property(_visual, "position", Vector2(-EXPLOSION_RADIUS, -EXPLOSION_RADIUS), 0.2)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)


# ============ FACTORY ============
static func create_on_target(player: Node2D) -> UrteilMark:
	var mark := UrteilMark.new()
	mark.target = player
	mark.name = "UrteilMark"
	return mark
