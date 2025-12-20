extends Control
## AirComboDisplay - Visual UI for air combo counter
## Shows air combo count and slam finisher availability

# ============ REFERENCES ============
@onready var container: VBoxContainer = $Container
@onready var air_combo_label: Label = $Container/AirComboLabel
@onready var slam_indicator: Label = $Container/SlamIndicator
@onready var timer_bar: ProgressBar = $Container/TimerBar

# ============ CONFIGURATION ============
@export var pulse_scale: float = 1.2  # Scale increase during pulse
@export var pulse_duration: float = 0.15  # Duration of pulse animation
@export var fade_duration: float = 0.5  # Duration of fade out

# ============ STATE ============
var current_air_combo: int = 0
var slam_ready: bool = false
var is_visible_now: bool = false
var player: CharacterBody2D = null
var air_combo_system: Node = null

# ============ COLORS ============
var color_cyan: Color = Color(0.0, 1.0, 1.0)  # Cyan for air combos
var color_white: Color = Color.WHITE
var color_gold: Color = Color(1.0, 0.84, 0.0)  # Gold for slam ready

# ============ ANIMATION ============
var pulse_tween: Tween = null


func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	is_visible_now = false
	slam_indicator.modulate.a = 0.0

	# Find player and air combo system
	await get_tree().process_frame
	_find_player()

	# Connect to EventBus aerial combat signals
	if EventBus:
		EventBus.air_combo_started.connect(_on_air_combo_started)
		EventBus.air_hit_registered.connect(_on_air_hit_registered)
		EventBus.air_combo_ended.connect(_on_air_combo_ended)
		EventBus.slam_executed.connect(_on_slam_executed)

	print("[AirComboDisplay] Initialized")


func _find_player() -> void:
	"""Finds the player in the scene"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		air_combo_system = player.get_node_or_null("AirComboSystem")
		if air_combo_system:
			print("[AirComboDisplay] Connected to AirComboSystem")
			# Connect to slam ready signal
			if air_combo_system.has_signal("slam_finisher_ready"):
				air_combo_system.slam_finisher_ready.connect(_on_slam_ready)


func _process(_delta: float) -> void:
	# Update timer bar if air combo is active
	if current_air_combo > 0 and air_combo_system:
		if air_combo_system.has_method("get_combo_progress"):
			var progress: float = air_combo_system.get_combo_progress()
			timer_bar.value = progress


# ============ AIR COMBO UPDATES ============
func _on_air_combo_started(_enemy: Node) -> void:
	"""Called when air combo starts"""
	current_air_combo = 0
	slam_ready = false

	# Show UI
	if not is_visible_now:
		_show_ui()


func _on_air_hit_registered(count: int, _enemy: Node) -> void:
	"""Called when air hit is registered"""
	current_air_combo = count

	# Update text
	_update_labels()

	# Pulse animation
	_play_pulse_animation()


func _on_air_combo_ended(_final_count: int) -> void:
	"""Called when air combo ends"""
	current_air_combo = 0
	slam_ready = false

	# Fade out UI
	_hide_ui()


func _on_slam_ready() -> void:
	"""Called when slam finisher is ready"""
	slam_ready = true
	_show_slam_indicator()


func _on_slam_executed(_enemy: Node, _damage: int) -> void:
	"""Called when slam is executed"""
	slam_ready = false
	_hide_slam_indicator()


# ============ UI UPDATES ============
func _update_labels() -> void:
	"""Updates the text labels"""
	# Air combo count label
	if current_air_combo == 1:
		air_combo_label.text = "AIR ×1"
	else:
		air_combo_label.text = "AIR ×%d" % current_air_combo

	# Update color (cyan to white gradient)
	var color: Color = color_cyan.lerp(color_white, min(current_air_combo / 10.0, 1.0))
	air_combo_label.add_theme_color_override("font_color", color)


# ============ SLAM INDICATOR ============
func _show_slam_indicator() -> void:
	"""Shows the slam finisher indicator"""
	slam_indicator.text = "⬇ SLAM READY ⬇"
	slam_indicator.add_theme_color_override("font_color", color_gold)

	# Fade in
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(slam_indicator, "modulate:a", 1.0, 0.2)

	# Pulse effect
	var pulse = create_tween()
	pulse.set_loops()
	pulse.tween_property(slam_indicator, "scale", Vector2(1.1, 1.1), 0.5)
	pulse.tween_property(slam_indicator, "scale", Vector2.ONE, 0.5)


func _hide_slam_indicator() -> void:
	"""Hides the slam finisher indicator"""
	var tween: Tween = create_tween()
	tween.tween_property(slam_indicator, "modulate:a", 0.0, 0.2)


# ============ ANIMATIONS ============
func _show_ui() -> void:
	"""Fades in the UI"""
	if is_visible_now:
		return

	is_visible_now = true

	# Create fade in tween
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _hide_ui() -> void:
	"""Fades out the UI"""
	if not is_visible_now:
		return

	is_visible_now = false

	# Create fade out tween
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)


func _play_pulse_animation() -> void:
	"""Plays a pulse animation on the container"""
	# Kill existing pulse tween
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()

	# Create new pulse tween
	pulse_tween = create_tween()
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.set_trans(Tween.TRANS_ELASTIC)

	# Pulse up
	pulse_tween.tween_property(container, "scale", Vector2(pulse_scale, pulse_scale), pulse_duration * 0.4)
	# Pulse down
	pulse_tween.tween_property(container, "scale", Vector2.ONE, pulse_duration * 0.6)


# ============ GETTERS ============
func is_showing() -> bool:
	"""Returns true if UI is currently visible"""
	return is_visible_now
