class_name Player extends Node3D
## One cricketer. The only script that knows which model is used. Two kinds:
##  - Kenney "Blocky Characters" (CC0): node-animated GLBs with idle / sprint / pick-up / attack-melee-right / holding-right / emote clips.
##  - rig-less GLBs (e.g. the Claude Design "cricket_player"): named groups leg_L / leg_R / arm_L / arm_R / bat,
##    which this script swings procedurally for the same clip names.
## `skin` is a Kenney letter, or a full res:// path for any other model.

const LOOPS := ["idle", "sprint", "walk", "holding-right", "holding-both", "static"]
const HEIGHT := 1.8   # metres; models are scaled to this

var anim: AnimationPlayer
var pivot: Node3D   # the clips overwrite the model's own transform every frame, so facing/scale live here
var model: Node3D
var bat: MeshInstance3D
var arm_r: Node3D
var hand_local := Vector3(0, -1, 0)   # hand position in the arm node's space
var rig := {}          # procedural limbs for rig-less models: leg_L, leg_R, arm_L, arm_R
var proc := ""         # current procedural clip
var proc_t := 0.0
const SWING_T := 0.45  # seconds for the procedural bat swing
var home := Vector3.ZERO
var idle_clip := "idle"
var _cur := ""


static func make(skin: String, with_bat: bool) -> Player:
	var p := Player.new()
	var scene: PackedScene = load(skin if skin.begins_with("res://") else "res://assets/characters/character-%s.glb" % skin)
	p.model = scene.instantiate()
	p.pivot = Node3D.new()
	p.pivot.rotation.y = PI   # glTF front is +Z, Godot forward is -Z
	p.pivot.add_child(p.model)
	p.add_child(p.pivot)
	p.anim = p.model.find_child("AnimationPlayer", true, false)
	if p.anim:
		p.anim.animation_finished.connect(p._on_finished)
		p.arm_r = p.model.find_child("arm-right", true, false)
		if p.arm_r is MeshInstance3D:
			p.hand_local = Vector3(0, (p.arm_r as MeshInstance3D).get_aabb().position.y, 0)
	else:
		for n in ["leg_L", "leg_R", "arm_L", "arm_R"]:
			p.rig[n] = p.model.find_child(n, true, false)
		p.arm_r = p.rig["arm_R"]
		p.hand_local = Vector3(0, -0.63, 0)
	var own_bat := p.model.find_child("bat", true, false)
	if own_bat:
		own_bat.visible = with_bat
	if with_bat and own_bat:
		p.idle_clip = "holding-right"
	elif with_bat and p.arm_r:
		p.idle_clip = "holding-right"
		var m := BoxMesh.new()
		m.size = Vector3(0.14, 0.06, 1.6)   # long axis along the arm's -Z: hangs down when the arm is held forward
		p.bat = MeshInstance3D.new()
		p.bat.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e0c08a")
		p.bat.material_override = mat
		p.bat.position = p.hand_local + Vector3(0, 0, -0.7)
		p.arm_r.add_child(p.bat)
	return p


func _ready() -> void:
	# normalise height and put the feet on y = 0, whatever units the model came in
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if m == bat:
			continue
		var b: AABB = (m.global_transform * m.get_aabb())
		box = b if first else box.merge(b)
		first = false
	if box.size.y > 0.0:
		var s := HEIGHT / box.size.y
		pivot.scale = Vector3.ONE * s
		pivot.position.y = -(box.position.y - global_position.y) * s
	play(idle_clip)


func play(n: String) -> void:
	if anim == null:
		_play_proc(n)
		return
	if n == _cur or not anim.has_animation(n):
		return
	var a := anim.get_animation(n)
	a.loop_mode = Animation.LOOP_LINEAR if n in LOOPS else Animation.LOOP_NONE
	anim.play(n, 0.2)
	if n in LOOPS:
		anim.seek(randf() * a.length, true)   # desync the fielders
	_cur = n


## Freeze the current clip pose so code can drive the bowling arm (a paused sprint stride reads as a delivery stride).
func hold_pose() -> void:
	if anim:
		anim.pause()
	else:
		proc = "hold"


# ---------- procedural clips for rig-less models ----------

func _play_proc(n: String) -> void:
	if n in ["pick-up", "emote-yes", "emote-no", "static"]:
		n = idle_clip
	if n == proc:
		return
	proc = n
	proc_t = 0.0
	_cur = n


func _limb(n: String, x: float) -> void:
	var node: Node3D = rig.get(n)
	if node:
		node.rotation.x = x


func _process(delta: float) -> void:
	if anim != null or rig.is_empty():
		return
	proc_t += delta
	match proc:
		"sprint":
			var w := sin(proc_t * 11.0)
			_limb("leg_L", w * 0.8)
			_limb("leg_R", -w * 0.8)
			_limb("arm_L", -w * 0.9)
			_limb("arm_R", w * 0.9)
		"attack-melee-right":          # backlift behind, swing through in front
			var k := clampf(proc_t / SWING_T, 0.0, 1.0)
			var a := lerpf(0.7, -2.1, k * k)
			_limb("arm_R", a)
			_limb("arm_L", a)
			_limb("leg_L", -0.3 * k)
			if proc_t >= SWING_T + 0.25:
				_play_proc(idle_clip)
		"hold":
			pass
		_:                             # idle / holding-right: at ease, gentle sway
			var b := sin(proc_t * 1.5) * 0.04
			_limb("leg_L", 0.0)
			_limb("leg_R", 0.0)
			_limb("arm_L", b)
			_limb("arm_R", -b)


## Overarm: theta 0 = arm down, +90° = straight back, 180° = overhead, ~250° = release in front.
func set_arm(theta: float) -> void:
	if arm_r:
		arm_r.rotation = Vector3(theta, 0, 0)


func hand_pos() -> Vector3:
	return arm_r.global_transform * hand_local if arm_r else global_position + Vector3.UP * 1.5


func face(target: Vector3) -> void:
	var t := Vector3(target.x, global_position.y, target.z)
	if t.distance_to(global_position) > 0.01:
		look_at(t)


func _on_finished(n: StringName) -> void:
	if String(n) == _cur:
		_cur = ""
		play(idle_clip)
