class_name World extends Node3D
## Builds the stadium: sky, light, outfield, pitch, crowd, floodlights, stumps, scoreboard, ball, camera.
## Holds the references the game loop animates. No game logic here.

var camera: Camera3D
var ball: MeshInstance3D
var striker_stumps: Node3D
var bails: Array[MeshInstance3D] = []
var board := {}   # label name → Label3D


static func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func mesh(m: Mesh, c: Color, pos: Vector3, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material(c)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ready() -> void:
	_sky_and_light()
	_ground()
	_crowd_and_lights()
	_stumps()
	_scoreboard()

	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	ball = mesh(bm, Color("c81e1e"), Vector3.ZERO)

	camera = Camera3D.new()
	camera.fov = 50
	camera.far = 400
	camera.position = Vector3(30, 25, 50)
	add_child(camera)
	camera.make_current()


func _sky_and_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)

	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4a90d9")
	sm.sky_horizon_color = Color("a8d4f5")
	sm.ground_horizon_color = Color("a8d4f5")
	var sky := Sky.new()
	sky.sky_material = sm
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)


func _ground() -> void:
	# one 160 m plane; the texture carries the dark surround, the striped oval and the white rope
	const PX := 1024
	const M_PER_PX := 160.0 / PX
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGB8)
	img.fill(Color("2d6b22"))
	var r_out := 62.0 / M_PER_PX
	var r_in := 61.2 / M_PER_PX
	var light := Color("3f8f2f")
	var dark := Color("378428")
	for y in PX:
		var dy := y + 0.5 - PX / 2.0
		if absf(dy) >= r_out:
			continue
		var half := sqrt(r_out * r_out - dy * dy)
		var x0 := int(PX / 2.0 - half)
		var x1 := int(PX / 2.0 + half)
		if absf(dy) >= r_in:
			img.fill_rect(Rect2i(x0, y, x1 - x0, 1), Color.WHITE)
			continue
		var h2 := sqrt(r_in * r_in - dy * dy)
		var i0 := int(PX / 2.0 - h2)
		var i1 := int(PX / 2.0 + h2)
		for band in 16:
			var bx0 := maxi(i0, band * 64)
			var bx1 := mini(i1, (band + 1) * 64)
			if bx1 > bx0:
				img.fill_rect(Rect2i(bx0, y, bx1 - bx0, 1), light if band % 2 == 0 else dark)
		img.fill_rect(Rect2i(x0, y, maxi(1, i0 - x0), 1), Color.WHITE)
		img.fill_rect(Rect2i(i1, y, maxi(1, x1 - i1), 1), Color.WHITE)

	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	var ground := mesh(pm, Color.WHITE, Vector3.ZERO, false)
	var gm := ground.material_override as StandardMaterial3D
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var pitch := PlaneMesh.new()
	pitch.size = Vector2(3.2, 24)
	mesh(pitch, Color("d8c08a"), Vector3(0, 0.01, 0), false)
	for z in [11.2, -11.2]:
		var crease := PlaneMesh.new()
		crease.size = Vector2(3.2, 0.12)
		mesh(crease, Color.WHITE, Vector3(0, 0.02, z), false)


func _crowd_and_lights() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var seat := BoxMesh.new()
	seat.size = Vector3(1.2, 1.2, 1.2)
	mm.mesh = seat
	mm.instance_count = 1800
	var i := 0
	for tier in 6:
		for a in 300:
			var ang := a / 300.0 * TAU + tier * 0.01
			var r := 66.0 + tier * 1.6
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(sin(ang) * r, 1.0 + tier * 1.3, cos(ang) * r)))
			mm.set_instance_color(i, Color.from_hsv(randf(), 0.6, 0.5 + randf() * 0.4))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	mmi.material_override = cm
	add_child(mmi)

	var stand := CylinderMesh.new()
	stand.top_radius = 75
	stand.bottom_radius = 66
	stand.height = 9
	stand.cap_top = false
	stand.cap_bottom = false
	var s := mesh(stand, Color("5a5a66"), Vector3(0, 4.5, 0), false)
	(s.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

	for deg in [45, 135, 225, 315]:
		var x := sin(deg_to_rad(deg)) * 80.0
		var z := cos(deg_to_rad(deg)) * 80.0
		var pole := CylinderMesh.new()
		pole.top_radius = 0.5
		pole.bottom_radius = 0.8
		pole.height = 40
		mesh(pole, Color("cccccc"), Vector3(x, 20, z))
		var lamp := BoxMesh.new()
		lamp.size = Vector3(6, 3, 1)
		var l := mesh(lamp, Color("ffffee"), Vector3(x, 41, z))
		var lm := l.material_override as StandardMaterial3D
		lm.emission_enabled = true
		lm.emission = Color("ffffcc")
		lm.emission_energy_multiplier = 0.8
		l.look_at(Vector3(0, 41, 0))


func _stumps() -> void:
	for z in [10.0, -10.0]:
		var g := Node3D.new()
		g.position = Vector3(0, 0, z)
		add_child(g)
		for x in [-0.12, 0.0, 0.12]:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.03
			cm.bottom_radius = 0.03
			cm.height = 0.75
			var st := mesh(cm, Color("f4e4c1"), Vector3(x, 0.375, 0))
			st.reparent(g, false)
		if z > 0:
			striker_stumps = g
	for x in [-0.06, 0.06]:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.11, 0.03, 0.03)
		bails.append(mesh(bm, Color("f4e4c1"), Vector3(x, 0.77, 10)))


func _scoreboard() -> void:
	var back := BoxMesh.new()
	back.size = Vector3(34, 15, 1)
	mesh(back, Color("111111"), Vector3(0, 18, -79))
	var face := BoxMesh.new()
	face.size = Vector3(32, 14, 0.1)
	mesh(face, Color("0b1a0b"), Vector3(0, 18, -78.45), false)
	for x in [-12.0, 12.0]:
		var leg := BoxMesh.new()
		leg.size = Vector3(1, 16, 1)
		mesh(leg, Color("333333"), Vector3(x, 5.5, -79))
	_label("title", 30, Color("ffb703"), Vector3(-15, 24, -78.3), HORIZONTAL_ALIGNMENT_LEFT, "QUIZ XI")
	_label("overs", 30, Color("ffb703"), Vector3(15, 24, -78.3), HORIZONTAL_ALIGNMENT_RIGHT, "OVERS 0.0")
	_label("score", 130, Color.WHITE, Vector3(0, 18.6, -78.3), HORIZONTAL_ALIGNMENT_CENTER, "0/0")
	_label("over", 36, Color("99aadd"), Vector3(0, 14.4, -78.3), HORIZONTAL_ALIGNMENT_CENTER, "THIS OVER  -")
	_label("last", 32, Color("ffb703"), Vector3(0, 12.6, -78.3), HORIZONTAL_ALIGNMENT_CENTER, "")
	_label("foot", 26, Color("777777"), Vector3(0, 11.2, -78.3), HORIZONTAL_ALIGNMENT_CENTER, "")


func _label(key: String, size: int, c: Color, pos: Vector3, align: HorizontalAlignment, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.05
	l.modulate = c
	l.horizontal_alignment = align
	l.shaded = false
	l.position = pos
	add_child(l)
	board[key] = l


func set_board(innings: MatchEngine.Innings, last: String, best: int, show_runs: int = -1) -> void:
	var r := innings.runs if show_runs < 0 else show_runs
	board.overs.text = "OVERS %s" % innings.overs()
	board.score.text = "%d/%d" % [r, innings.wkts]
	board.over.text = "THIS OVER  " + ("  ".join(innings.this_over) if innings.this_over.size() > 0 else "-")
	board.last.text = last
	board.foot.text = "BEST %d   BALLS LEFT %d" % [best, MatchEngine.BALLS - innings.balls]
