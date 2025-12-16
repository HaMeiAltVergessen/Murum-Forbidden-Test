extends Node2D
## SpikeTrap - Cycling damage hazard
class_name SpikeTrap

# ============ TRAP STATES ============
enum TrapState {
	RETRACTED,
	EXTENDING,
	EXTENDED,
	RETRACTING
}

# ============ REFERENCES ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_area: Area2D = $DamageArea
@onready var cycle_timer: Timer = $CycleTimer

# ============ CONFIGURATION ============
@export var damage: int = 20
@export var retracted_duration: float = 3.0
@export var extending_duration: float = 0.3
@export var extended_duration: float = 2.0
@export var retracting_duration: float = 0.3

# ============ STATE ============
var current_state: TrapState = TrapState.RETRACTED
var bodies_in_area: Array[Node2D] = []


func _ready() -> void:
	# Setup damage area
	if damage_area:
		damage_area.body_entered.connect(_on_body_entered)
		damage_area.body_exited.connect(_on_body_exited)
		damage_area.monitoring = false

	# Setup cycle timer
	if cycle_timer:
		cycle_timer.timeout.connect(_on_cycle_timer_timeout)
		cycle_timer.one_shot = true

	# Start cycle
	_change_state(TrapState.RETRACTED)

	print("[SpikeTrap] Initialized at ", global_position)


# ============ STATE MACHINE ============
func _change_state(new_state: TrapState) -> void:
	"""Changes trap state"""
	current_state = new_state

	match current_state:
		TrapState.RETRACTED:
			_enter_retracted()
		TrapState.EXTENDING:
			_enter_extending()
		TrapState.EXTENDED:
			_enter_extended()
		TrapState.RETRACTING:
			_enter_retracting()


func _enter_retracted() -> void:
	"""Spikes are hidden, safe"""
	damage_area.monitoring = false

	# Visual: Gray color
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 1)

	# Start timer for next cycle
	cycle_timer.start(retracted_duration)

	print("[SpikeTrap] Retracted")


func _enter_extending() -> void:
	"""Spikes are extending, not yet dangerous"""
	damage_area.monitoring = false

	# Visual: Yellow warning
	if sprite:
		sprite.modulate = Color(1, 1, 0, 1)

	# Play sound
	AudioManager.play_sfx("spike_extend")

	# Animate extension
	_animate_extension()

	# Start timer
	cycle_timer.start(extending_duration)


func _enter_extended() -> void:
	"""Spikes are fully extended and dangerous"""
	damage_area.monitoring = true

	# Visual: Red danger
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)

	# Emit signal
	EventBus.trap_activated.emit(self)

	# Damage any bodies already in area
	_damage_bodies_in_area()

	# Start timer
	cycle_timer.start(extended_duration)

	print("[SpikeTrap] Extended - DANGEROUS")


func _enter_retracting() -> void:
	"""Spikes are retracting, no longer dangerous"""
	damage_area.monitoring = false

	# Visual: Yellow
	if sprite:
		sprite.modulate = Color(1, 1, 0, 1)

	# Animate retraction
	_animate_retraction()

	# Start timer
	cycle_timer.start(retracting_duration)


func _on_cycle_timer_timeout() -> void:
	"""Advances to next state in cycle"""
	match current_state:
		TrapState.RETRACTED:
			_change_state(TrapState.EXTENDING)
		TrapState.EXTENDING:
			_change_state(TrapState.EXTENDED)
		TrapState.EXTENDED:
			_change_state(TrapState.RETRACTING)
		TrapState.RETRACTING:
			_change_state(TrapState.RETRACTED)


# ============ DAMAGE HANDLING ============
func _on_body_entered(body: Node2D) -> void:
	"""Tracks bodies entering the damage area"""
	if body not in bodies_in_area:
		bodies_in_area.append(body)

	# Damage immediately if extended
	if current_state == TrapState.EXTENDED:
		_deal_damage_to(body)


func _on_body_exited(body: Node2D) -> void:
	"""Tracks bodies leaving the damage area"""
	if body in bodies_in_area:
		bodies_in_area.erase(body)


func _damage_bodies_in_area() -> void:
	"""Damages all bodies currently in the area"""
	for body in bodies_in_area:
		_deal_damage_to(body)


func _deal_damage_to(body: Node2D) -> void:
	"""Deals damage to a single body"""
	# Check if it's the player
	if body is Murum:
		var player: Murum = body as Murum
		if player.health_component:
			player.health_component.take_damage(damage)
			print("[SpikeTrap] Damaged player for ", damage, " HP")

	# Check if it's an enemy
	elif body is BaseEnemy:
		var enemy: BaseEnemy = body as BaseEnemy
		if enemy.health_component:
			enemy.health_component.take_damage(damage)
			print("[SpikeTrap] Damaged enemy for ", damage, " HP")


# ============ ANIMATION ============
func _animate_extension() -> void:
	"""Animates spikes extending"""
	if not sprite:
		return

	# Simple scale animation
	sprite.scale = Vector2(1, 0.2)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1, 1), extending_duration)


func _animate_retraction() -> void:
	"""Animates spikes retracting"""
	if not sprite:
		return

	# Simple scale animation
	sprite.scale = Vector2(1, 1)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1, 0.2), retracting_duration)
