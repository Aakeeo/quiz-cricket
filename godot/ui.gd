class_name UI extends CanvasLayer
## 2D overlay: HUD pills, timer bar, question card, result text, start/end overlay. Emits answers; holds no rules.

signal answered(i: int)   # -1 = timed out
signal start_pressed

const ACCENT := Color("ffb703")
const BAD := Color("e63946")
const GOOD := Color("2a9d2a")
const BEIGE := Color("f1dfb5")

var score_l: Label
var overs_l: Label
var left_l: Label
var timer: ProgressBar
var card: VBoxContainer
var q_l: Label
var buttons: Array[Button] = []
var result_l: Label
var comm_l: Label
var overlay: Control
var ov_title: Label
var ov_text: Label
var ov_btn: Button
var open := false


static func box(c: Color, radius := 12, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _ready() -> void:
	# HUD pills
	var hud := HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.offset_top = 12
	hud.add_theme_constant_override("separation", 10)
	add_child(hud)
	score_l = _pill(hud, "0/0")
	overs_l = _pill(hud, "0.0 ov")
	left_l = _pill(hud, "12 balls left")

	timer = ProgressBar.new()
	timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timer.custom_minimum_size = Vector2(640, 8)
	timer.offset_top = 56
	timer.min_value = 0
	timer.max_value = 1
	timer.step = 0.001
	timer.value = 0
	timer.show_percentage = false
	timer.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.25), 4, 0))
	timer.add_theme_stylebox_override("fill", box(ACCENT, 4, 0))
	add_child(timer)

	# question card
	card = VBoxContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.custom_minimum_size = Vector2(640, 0)
	card.offset_bottom = -16
	card.add_theme_constant_override("separation", 8)
	add_child(card)
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", box(Color.WHITE, 12, 16))
	card.add_child(qp)
	q_l = label("", 21, Color("111111"))
	q_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	q_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qp.add_child(q_l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color("111111"))
		b.add_theme_color_override("font_hover_color", Color("111111"))
		b.add_theme_color_override("font_pressed_color", Color("111111"))
		b.add_theme_color_override("font_disabled_color", Color("111111"))
		b.add_theme_stylebox_override("normal", box(BEIGE, 10))
		b.add_theme_stylebox_override("hover", box(BEIGE.darkened(0.08), 10))
		b.add_theme_stylebox_override("pressed", box(BEIGE.darkened(0.15), 10))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(answer.bind(i))
		grid.add_child(b)
		buttons.append(b)
	card.visible = false

	# result + commentary
	result_l = label("", 84)
	result_l.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	result_l.anchor_top = 0.84
	result_l.anchor_bottom = 0.84
	result_l.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_l.add_theme_constant_override("outline_size", 10)
	result_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(result_l)
	comm_l = label("", 20)
	comm_l.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	comm_l.anchor_top = 0.95
	comm_l.anchor_bottom = 0.95
	comm_l.grow_vertical = Control.GROW_DIRECTION_BOTH
	comm_l.add_theme_constant_override("outline_size", 6)
	comm_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(comm_l)

	# overlay
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	overlay.add_child(vb)
	ov_title = label("Quiz Cricket", 64)
	ov_title.add_theme_constant_override("outline_size", 10)
	ov_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	vb.add_child(ov_title)
	ov_text = label("", 20)
	ov_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_text.custom_minimum_size = Vector2(480, 0)
	vb.add_child(ov_text)
	ov_btn = Button.new()
	ov_btn.custom_minimum_size = Vector2(260, 56)
	ov_btn.add_theme_font_size_override("font_size", 22)
	ov_btn.add_theme_color_override("font_color", Color("111111"))
	ov_btn.add_theme_color_override("font_hover_color", Color("111111"))
	ov_btn.add_theme_color_override("font_pressed_color", Color("111111"))
	ov_btn.add_theme_stylebox_override("normal", box(ACCENT, 12, 14))
	ov_btn.add_theme_stylebox_override("hover", box(ACCENT.darkened(0.08), 12, 14))
	ov_btn.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), 12, 14))
	ov_btn.pressed.connect(func() -> void: start_pressed.emit())
	var center := CenterContainer.new()
	center.add_child(ov_btn)
	vb.add_child(center)


func _pill(parent: Control, text: String) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.55), 20, 8))
	parent.add_child(p)
	var l := label(text, 18)
	p.add_child(l)
	return l


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k >= KEY_1 and k <= KEY_4:
			answer(k - KEY_1)
		elif k == KEY_ENTER and overlay.visible:
			start_pressed.emit()


func answer(i: int) -> void:
	if not open:
		return
	open = false
	answered.emit(i)


func show_question(q: String, opts: Array) -> void:
	q_l.text = q
	for i in 4:
		buttons[i].text = "%d   %s" % [i + 1, opts[i]]
		buttons[i].disabled = false
		buttons[i].add_theme_stylebox_override("disabled", box(BEIGE, 10))
		buttons[i].add_theme_color_override("font_disabled_color", Color("111111"))
	card.visible = true
	open = true


func mark(ans: int, chosen: int) -> void:
	for i in 4:
		buttons[i].disabled = true
	buttons[ans].add_theme_stylebox_override("disabled", box(GOOD, 10))
	buttons[ans].add_theme_color_override("font_disabled_color", Color.WHITE)
	if chosen >= 0 and chosen != ans:
		buttons[chosen].add_theme_stylebox_override("disabled", box(BAD, 10))
		buttons[chosen].add_theme_color_override("font_disabled_color", Color.WHITE)


func hide_question() -> void:
	card.visible = false


func set_timer(frac: float) -> void:
	timer.value = frac


func set_hud(score: String, overs: String, left: String) -> void:
	score_l.text = score
	overs_l.text = overs
	left_l.text = left


func show_result(text: String, c: Color) -> void:
	result_l.text = text
	result_l.add_theme_color_override("font_color", c)
	result_l.pivot_offset = result_l.size / 2
	result_l.scale = Vector2(0.2, 0.2)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(result_l, "scale", Vector2.ONE, 0.45)


func set_comm(text: String) -> void:
	comm_l.text = text


func clear_result() -> void:
	result_l.text = ""
	comm_l.text = ""


func show_overlay(title: String, text: String, btn: String) -> void:
	ov_title.text = title
	ov_text.text = text
	ov_btn.text = btn
	overlay.visible = true


func hide_overlay() -> void:
	overlay.visible = false
