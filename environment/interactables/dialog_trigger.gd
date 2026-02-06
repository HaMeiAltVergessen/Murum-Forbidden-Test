extends Node2D
class_name DialogTrigger

## Wiederverwendbare Dialog-Blaupause
## Leuchtet schwach, P1 interagiert mit E, Dialogtext im Inspektor auswaehlbar.
## Unterstuetzt separate Dialoge fuer Singleplayer und Coop (2 Spieler).
## "Schweigen (...)" beendet den Dialog immer - andere Optionen gehen tiefer.

# ============================================================================
# INSPECTOR - Dialog Konfiguration
# ============================================================================

@export_group("Dialog")
## Dialog fuer Singleplayer (Murum allein / mit Umbra)
@export var dialog_singleplayer: DialogData = null
## Dialog fuer Coop (wenn Lythrun dabei ist)
@export var dialog_coop: DialogData = null
## Einmalig abspielen (wird in WorldManager gespeichert)
@export var one_shot: bool = true

@export_group("Interaktion")
## Interaktionstext ueber dem Trigger
@export var prompt_text: String = "E - Sprechen"
## Reichweite der Interaktionszone (Breite x Hoehe)
@export var interaction_size: Vector2 = Vector2(120, 80)

@export_group("Leuchten")
## Farbe des schwachen Leuchtens
@export var glow_color: Color = Color(0.6, 0.8, 1.0, 0.6)
## Leucht-Energie (Helligkeit)
@export var glow_energy: float = 0.4
## Leucht-Radius (Textur-Skalierung)
@export var glow_radius: float = 1.5

# ============================================================================
# STATE
# ============================================================================

var player_in_range: bool = false
var has_been_triggered: bool = false
var _trigger_id: String = ""

# ============================================================================
# REFERENCES
# ============================================================================

var interaction_area: Area2D
var prompt_label: Label
var glow_light: PointLight2D
var glow_tween: Tween

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_generate_trigger_id()
	_build_nodes()
	_check_persistence()
	add_to_group("dialog_triggers")
	print("[DialogTrigger] Ready: %s" % _trigger_id)


func _generate_trigger_id() -> void:
	_trigger_id = "%s/%s/%s" % [
		WorldManager.current_world if WorldManager else "unknown",
		WorldManager.current_room if WorldManager else "unknown",
		name
	]


func _build_nodes() -> void:
	# --- PointLight2D (schwaches Leuchten) ---
	glow_light = PointLight2D.new()
	glow_light.color = glow_color
	glow_light.energy = glow_energy
	glow_light.texture_scale = glow_radius
	# Einfache Gradient-Textur als Lichtquelle
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.width = 128
	gradient_tex.height = 128
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.5)
	gradient_tex.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient_tex.gradient = gradient
	glow_light.texture = gradient_tex
	add_child(glow_light)
	_start_glow_pulse()

	# --- Area2D (Interaktionszone) ---
	interaction_area = Area2D.new()
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 2 | 4  # Layer 2 = Player1, Layer 4 = Player2
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = interaction_size
	col_shape.shape = rect_shape
	interaction_area.add_child(col_shape)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	add_child(interaction_area)

	# --- Label (Interaktions-Prompt) ---
	prompt_label = Label.new()
	prompt_label.text = prompt_text
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-60, -50)
	prompt_label.size = Vector2(120, 20)
	prompt_label.visible = false
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("outline_size", 3)
	add_child(prompt_label)


func _check_persistence() -> void:
	if not one_shot:
		return
	if WorldManager and WorldManager.is_dialog_played(_trigger_id):
		has_been_triggered = true
		_disable_visuals()
		print("[DialogTrigger] Already triggered: %s" % _trigger_id)

# ============================================================================
# GLOW PULSE
# ============================================================================

func _start_glow_pulse() -> void:
	if not is_instance_valid(glow_light):
		return
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow_light, "energy", glow_energy * 1.5, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow_light, "energy", glow_energy * 0.5, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _disable_visuals() -> void:
	if glow_tween:
		glow_tween.kill()
	if glow_light:
		glow_light.energy = 0.0
	if prompt_label:
		prompt_label.visible = false

# ============================================================================
# INTERACTION
# ============================================================================

func _process(_delta: float) -> void:
	if not player_in_range or has_been_triggered:
		return

	var interact_pressed := false
	if InputManager:
		interact_pressed = InputManager.is_p1_action_just_pressed("interact")
	else:
		interact_pressed = Input.is_action_just_pressed("p1_interact")

	if interact_pressed:
		_trigger_dialog()


func _trigger_dialog() -> void:
	if DialogManager and DialogManager.is_active:
		return

	# Coop oder Singleplayer Dialog waehlen
	var use_coop := CoopManager != null and CoopManager.is_p2_active
	var selected_dialog: DialogData = dialog_coop if use_coop and dialog_coop else dialog_singleplayer

	if selected_dialog == null:
		push_warning("[DialogTrigger] No dialog assigned for %s (coop: %s)" % [_trigger_id, use_coop])
		return

	print("[DialogTrigger] Starting dialog: %s (coop: %s)" % [selected_dialog.dialog_id, use_coop])

	if one_shot:
		has_been_triggered = true
		_disable_visuals()

	# Dialog abspielen
	DialogManager.play_dialog_resource(selected_dialog)

	# Persistence: Dialog als gespielt markieren
	if one_shot and WorldManager:
		# Erst bei dialog_finished markieren
		if EventBus and EventBus.has_signal("dialog_finished"):
			EventBus.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

# ============================================================================
# PLAYER DETECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if has_been_triggered:
		return
	if body.is_in_group("player") or body.name == "Murum":
		player_in_range = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Murum":
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

# ============================================================================
# PERSISTENCE
# ============================================================================

func _on_dialog_finished(dialog_id: String) -> void:
	if WorldManager:
		WorldManager.mark_dialog_played(_trigger_id)
		print("[DialogTrigger] Marked as played: %s" % _trigger_id)
