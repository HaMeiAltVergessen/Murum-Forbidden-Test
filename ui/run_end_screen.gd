extends CanvasLayer
## Run-Ende-Screen — zeigt Statistiken, Magicka-Belohnung, Zurueck zum Limbus

# ============ MAGICKA REWARDS ============
const MAGICKA_PER_ROOM: int = 1
const MAGICKA_PER_BOSS: int = 3
const MAGICKA_VICTORY_BONUS: int = 5

# ============ STATE ============
var victory: bool = false
var rooms_completed: int = 0
var enemies_killed: int = 0
var run_time_seconds: int = 0
var magicka_earned: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func show_summary(p_victory: bool, p_rooms: int, p_kills: int) -> void:
	victory = p_victory
	rooms_completed = p_rooms
	enemies_killed = p_kills

	# Get run time from StatisticsManager
	if StatisticsManager:
		run_time_seconds = StatisticsManager.run_playtime_seconds

	# Calculate Magicka reward
	magicka_earned = rooms_completed * MAGICKA_PER_ROOM
	if victory:
		magicka_earned += MAGICKA_VICTORY_BONUS

	# Award Magicka
	if RunManager:
		RunManager.add_magicka(magicka_earned)

	_build_ui()
	show()
	get_tree().paused = true


func _build_ui() -> void:
	# Clear previous UI
	for child in get_children():
		child.queue_free()

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(600, 0)
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Title
	var title = Label.new()
	if victory:
		title.text = "SIEG!"
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		title.text = "NIEDERLAGE"
		title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Stats
	_add_stat(vbox, "Zeit", _format_time(run_time_seconds))
	_add_stat(vbox, "Raeume abgeschlossen", str(rooms_completed))
	_add_stat(vbox, "Gegner besiegt", str(enemies_killed))

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Magicka breakdown
	_add_stat(vbox, "Raeume (%d x %d)" % [rooms_completed, MAGICKA_PER_ROOM],
		"+%d Magicka" % (rooms_completed * MAGICKA_PER_ROOM))
	if victory:
		_add_stat(vbox, "Sieg-Bonus", "+%d Magicka" % MAGICKA_VICTORY_BONUS)

	# Total
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)
	_add_stat(vbox, "Gesamt verdient", "%d Magicka" % magicka_earned, Color(0.6, 0.4, 1.0))

	# Continue button
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.text = "Zurueck zum Limbus"
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_continue)
	vbox.add_child(btn)
	# Center the button
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _add_stat(parent: VBoxContainer, label_text: String, value_text: String,
		color: Color = Color.WHITE) -> void:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 22)
	val.add_theme_color_override("font_color", color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val)


func _format_time(total_seconds: int) -> String:
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_continue() -> void:
	get_tree().paused = false
	hide()
	if RunManager:
		RunManager._return_to_limbus()
	queue_free()
