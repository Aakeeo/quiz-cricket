extends Node3D
## Ball-by-ball loop. Rules live in MatchEngine, questions in Quiz, the model in Player,
## the stadium in World, the 2D overlay in UI. This file only sequences them.

enum Phase { IDLE, ANIM, QUESTION }

const STRIKER := Vector3(0, 0, 9)
const NONSTRIKER := Vector3(1.2, 0, -9)
const RUNUP := -34.0
const CREASE := -11.5
const BATCAM := [Vector3(3, 6.5, 24), Vector3(0, 1, -8)]
const BOARDCAM := [Vector3(0, 18, -46), Vector3(0, 18, -78)]
const FIELD := [[-160, 12], [-135, 45], [-95, 30], [-55, 35], [-20, 30], [20, 30], [60, 35], [95, 30], [140, 40]]
const SKIN_BAT := "res://assets/characters/cricket_player.glb"   # Claude Design model; a Kenney letter also works
const SKIN_FIELD := "b"
const SKIN_UMPIRE := "r"

# shot name + direction in degrees (0 = straight back past the bowler, + = leg side)
const SHOTS := {
	6: [["Lofted straight back over the bowler's head!", 0], ["Slog-swept deep into the stands!", 70], ["Pulled high over midwicket!", 100], ["Inside-out over extra cover, huge!", -40]],
	4: [["Cover drive, pierces the gap", -55], ["Square cut, races to the rope", -100], ["Flicked through midwicket", 60], ["Straight drive, nobody moving", 5]],
	2: [["Pushed into the covers, they come back for two", -45], ["Worked to deep square leg, two", 90]],
	1: [["Nudged to mid-on, quick single", 25], ["Dabbed down to third man, one", -140]],
}
const DOT := ["Beaten by the clock. Dot ball.", "Left alone. No run.", "Too slow, straight into the keeper's gloves."]
const OUT := ["BOWLED! Through the gate!", "Timber! The stumps are shattered!", "Clean bowled, that's the wrong answer!"]

var pace := 1.8   # multiplies every animation duration; 1 = brisk, 2 = leisurely
var world: World
var ui: UI
var innings := MatchEngine.Innings.new()
var deck: Array = []
var phase := Phase.IDLE
var t_start := 0.0
var best := 0   # ponytail: per session; ConfigFile when career stats arrive
var last_ball := "NEW INNINGS"
var look := Vector3.ZERO
var demo := false
var demo_at := 0.0

var striker: Player
var non_striker: Player
var bowler: Player
var keeper: Player
var umpire: Player
var leg_umpire: Player
var fielders: Array[Player] = []


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func dir_of(deg: float) -> Vector3:
	return Vector3(sin(deg_to_rad(deg)), 0, -cos(deg_to_rad(deg)))


func _ready() -> void:
	demo = OS.get_environment("QC_DEMO") == "1" or (OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#demo")
	if OS.get_environment("QC_DEMO") == "1":
		pace = 0.25   # headless integration run: rush through an innings
	if demo:
		seed(7)       # repeatable deck and answer timings
	world = World.new()
	add_child(world)
	ui = UI.new()
	add_child(ui)
	ui.start_pressed.connect(start)

	striker = _person(SKIN_BAT, true)
	non_striker = _person(SKIN_BAT, true)
	bowler = _person(SKIN_FIELD, false)
	keeper = _person(SKIN_FIELD, false)
	umpire = _person(SKIN_UMPIRE, false)
	leg_umpire = _person(SKIN_UMPIRE, false)
	for f in FIELD:
		var p := _person(SKIN_FIELD, false)
		p.home = STRIKER + dir_of(f[0]) * f[1]
		fielders.append(p)

	reset_positions()
	world.set_board(innings, last_ball, best)
	look = Vector3.ZERO
	if demo:
		start()
	else:
		ui.show_overlay("Quiz Cricket", "Answer before the bowler reaches the crease. Faster answers hit bigger shots. A wrong answer is a wicket.\n\nKeys 1–4 to answer.", "Start innings")


func _person(skin: String, with_bat: bool) -> Player:
	var p := Player.make(skin, with_bat)
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if phase == Phase.QUESTION:
		var t := clampf((now() - t_start) / MatchEngine.CLOCK, 0.0, 1.0)
		ui.set_timer(1.0 - t)
		bowler.position.z = RUNUP + (CREASE - RUNUP) * t * 0.85
		world.ball.position = Vector3(0.8, 1.6, bowler.position.z)
		if t >= 1.0:
			ui.answer(-1)
		elif demo and now() >= demo_at:
			var ans: int = deck[innings.balls][2]
			ui.answer(ans if randf() < 0.7 else (ans + 1) % 4)
	if phase == Phase.IDLE:
		var a := now() / 20.0
		world.camera.position = Vector3(sin(a) * 55, 25, cos(a) * 55)
		look = Vector3.ZERO
	world.camera.look_at(look)


# ---------- animation helpers: every duration × pace ----------

func wait(s: float) -> void:
	await get_tree().create_timer(s * pace).timeout


func move(t: Tween, p: Player, to: Vector3, dur: float, delay := 0.0, clip := "sprint") -> void:
	var st := {}
	t.tween_callback(_move_start.bind(p, to, clip)).set_delay(delay * pace)
	t.tween_method(_move_step.bind(p, st, to), 0.0, 1.0, dur * pace).set_delay(delay * pace)
	t.tween_callback(_move_end.bind(p)).set_delay((delay + dur) * pace)


func _move_start(p: Player, to: Vector3, clip: String) -> void:
	p.face(to)
	p.play(clip)


func _move_step(k: float, p: Player, st: Dictionary, to: Vector3) -> void:
	if not st.has("from"):
		st["from"] = p.position
	p.position = st["from"].lerp(to, k)


func _move_end(p: Player) -> void:
	p.play(p.idle_clip)


func fly(t: Tween, from: Vector3, to: Vector3, peak: float, dur: float, delay := 0.0) -> void:
	t.tween_method(_fly_step.bind(from, to, peak), 0.0, 1.0, dur * pace).set_delay(delay * pace)


func _fly_step(k: float, from: Vector3, to: Vector3, peak: float) -> void:
	world.ball.position = from.lerp(to, k) + Vector3.UP * (peak * 4.0 * k * (1.0 - k))


func cam(t: Tween, pos: Vector3, target: Vector3, dur: float) -> void:
	t.tween_method(_cam_step.bind(world.camera.position, pos, look, target), 0.0, 1.0, dur * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _cam_step(k: float, p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3) -> void:
	world.camera.position = p0.lerp(p1, k)
	look = l0.lerp(l1, k)


func _bowl_step(k: float) -> void:
	bowler.set_arm(k * 1.4 * PI)          # back, over the top, release in front
	world.ball.position = bowler.hand_pos()


func _bail_step(k: float, b: MeshInstance3D, side: float) -> void:
	b.position = Vector3(side * (0.06 + k * 0.3), 0.77 + 3.0 * k * (1.0 - k), 10.0 + k * 2.0)


func _board_step(k: float, prev: int) -> void:
	world.set_board(innings, last_ball, best, prev + roundi((innings.runs - prev) * k))


# ---------- game flow ----------

func reset_positions() -> void:
	striker.position = STRIKER
	striker.face(Vector3(0, 0, -10))
	striker.play(striker.idle_clip)
	non_striker.position = NONSTRIKER
	non_striker.face(Vector3(1.2, 0, 10))
	non_striker.play(non_striker.idle_clip)
	bowler.position = Vector3(0.8, 0, RUNUP)
	bowler.face(Vector3(0.8, 0, 0))
	bowler.play("idle")
	keeper.position = Vector3(0, 0, 13.5)
	keeper.face(Vector3.ZERO)
	keeper.play("idle")
	umpire.position = Vector3(0, 0, -14.5)
	umpire.face(Vector3.ZERO)
	leg_umpire.position = Vector3(20, 0, 9)
	leg_umpire.face(STRIKER)
	for f in fielders:
		f.position = f.home
		f.face(Vector3.ZERO)
		f.play("idle")
	world.ball.position = Vector3(0.8, 1.6, RUNUP)
	world.striker_stumps.rotation = Vector3.ZERO
	for i in 2:
		world.bails[i].position = Vector3(-0.06 if i == 0 else 0.06, 0.77, 10)


func start() -> void:
	innings = MatchEngine.Innings.new()
	deck = Quiz.deck(MatchEngine.BALLS)
	last_ball = "NEW INNINGS"
	ui.hide_overlay()
	_hud()
	world.set_board(innings, last_ball, best)
	play_ball()


func _hud() -> void:
	ui.set_hud("%d/%d" % [innings.runs, innings.wkts], "%s ov" % innings.overs(), "%d balls left" % (MatchEngine.BALLS - innings.balls))


func play_ball() -> void:
	if innings.is_over():
		end_game()
		return
	phase = Phase.ANIM
	reset_positions()
	ui.clear_result()
	var t := create_tween()
	cam(t, BATCAM[0], BATCAM[1], 0.7)
	await t.finished

	var q: Array = deck[innings.balls]
	ui.show_question(q[0], q[1])
	bowler.play("sprint")
	t_start = now()
	demo_at = t_start + (randf_range(0.5, 1.5) if pace < 1.0 else randf_range(2.5, 7.5))
	phase = Phase.QUESTION
	var i: int = await ui.answered
	phase = Phase.ANIM
	ui.set_timer(0.0)
	var elapsed := now() - t_start
	var correct: Variant = null if i < 0 else (i == q[2])
	var r := MatchEngine.runs_for(correct, elapsed)
	ui.mark(q[2], i)
	await wait(0.9)   # time to read the right answer
	ui.hide_question()

	# delivery: side-on bowler cam for the final strides and the overarm, then cut behind the batter at release
	t = create_tween().set_parallel(true)
	move(t, bowler, Vector3(0.8, 0, CREASE), maxf(0.15, (CREASE - bowler.position.z) * 0.06))
	cam(t, Vector3(-9, 2.2, CREASE + 3), Vector3(0.8, 1.5, CREASE), 0.3)
	await t.finished
	bowler.hold_pose()
	t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_method(_bowl_step, 0.0, 1.0, 0.55 * pace)
	await t.finished
	var release := bowler.hand_pos()
	bowler.play("idle")
	world.camera.position = BATCAM[0]
	look = BATCAM[1]
	t = create_tween().set_parallel(true)
	fly(t, release, Vector3(0, 0.5, 9), 0.4, 0.7)
	t.tween_callback(striker.play.bind("attack-melee-right")).set_delay(0.35 * pace)
	await t.finished

	# outcome
	var prev := innings.runs
	var text := ""
	if r == -1:
		text = OUT.pick_random()
		t = create_tween().set_parallel(true)
		fly(t, world.ball.position, Vector3(0, 0.4, 10.3), 0, 0.06)
		cam(t, Vector3(3, 1.5, 15), Vector3(0, 0.5, 10), 0.3)
		await t.finished
		t = create_tween().set_parallel(true)
		t.tween_property(world.striker_stumps, "rotation:x", -1.2, 0.5 * pace)
		t.tween_method(_bail_step.bind(world.bails[0], -1.0), 0.0, 1.0, 0.6 * pace)
		t.tween_method(_bail_step.bind(world.bails[1], 1.0), 0.0, 1.0, 0.6 * pace)
		await t.finished
		await wait(0.6)
	elif r == 0:
		text = DOT.pick_random()
		t = create_tween()
		fly(t, world.ball.position, Vector3(0, 0.6, 13.3), 0.1, 0.25)
		await t.finished
		await wait(0.5)
	else:
		var shot: Array = SHOTS[r].pick_random()
		text = ("SIX! " if r == 6 else ("FOUR! " if r == 4 else "")) + shot[0]
		var dir := dir_of(shot[1])
		var dist: float = {6: 78.0, 4: 62.0, 2: 38.0, 1: 22.0}[r]
		var peak: float = {6: 20.0, 4: 2.0, 2: 4.0, 1: 1.2}[r]
		var dur: float = {6: 1.7, 4: 1.3, 2: 1.1, 1: 0.8}[r]
		var land := STRIKER + dir * dist
		land.y = 0.12
		var chaser: Player = fielders[0]
		for f in fielders:
			if f.home.distance_to(land) < chaser.home.distance_to(land):
				chaser = f
		t = create_tween().set_parallel(true)
		fly(t, world.ball.position, land, peak, dur)
		cam(t, STRIKER - dir * 14.0 + Vector3(0, 9, 0), land * 0.5, 0.5)
		if r < 6:
			move(t, chaser, land - dir * 1.2, dur + 0.3)
			t.tween_callback(chaser.play.bind("pick-up")).set_delay((dur + 0.35) * pace)
		if r >= 4:
			t.tween_callback(umpire.play.bind("emote-yes")).set_delay(dur * pace)
		var ends := [STRIKER, NONSTRIKER]
		for n in mini(r, 3):
			ends = [ends[1], ends[0]]
			move(t, striker, Vector3(0, 0, ends[0].z), 0.7, n * 0.75)
			move(t, non_striker, Vector3(1.2, 0, ends[1].z), 0.7, n * 0.75)
		await t.finished
		if r < 6:
			t = create_tween()
			fly(t, world.ball.position, Vector3(0, 0.8, 13.3), 6, 0.7)
			await t.finished

	innings.record(r)
	last_ball = text.to_upper().left(42)
	_hud()
	ui.show_result("OUT!" if r < 0 else ("•" if r == 0 else str(r)), UI.BAD if r < 0 else (UI.ACCENT if r >= 4 else Color.WHITE))
	ui.set_comm(text)

	# cut to the scoreboard, tick the score up, cut back
	t = create_tween()
	cam(t, BOARDCAM[0], BOARDCAM[1], 0.65)
	await t.finished
	t = create_tween()
	t.tween_method(_board_step.bind(prev), 0.0, 1.0, 0.65 * pace)
	await t.finished
	await wait(1.2)
	play_ball()


func end_game() -> void:
	phase = Phase.IDLE
	best = maxi(best, innings.runs)
	ui.show_overlay("%d/%d" % [innings.runs, innings.wkts],
		("All out! Revise and come back." if innings.wkts >= MatchEngine.WICKETS else "Innings complete off %d balls." % innings.balls) + " Best: %d." % best,
		"Bat again")
	if demo:
		print("DEMO innings complete: %d/%d off %d balls" % [innings.runs, innings.wkts, innings.balls])
		await wait(1.0)
		get_tree().quit()
