extends Node
## PF Tek cake widget in 3D: a cake on a jar lid that colonizes, pins, fruits fat
## mushrooms and decays, slowly turning and bouncing to whatever the Mac is playing.
## It shows only the cake. Hover the window for Mist / Harvest / close; drag to move.
## Dev flags (after `--`): --progress=75 starts at a stage without saving,
## --shot=/abs/path.png saves one frame and quits (--size=N sets its pixel size),
## --species=N picks the species, --bg=<hex> swaps transparency for a solid backdrop,
## --track=<file> --seconds=N [--grow-to=X] is for rendering clips (tools/render_loop.sh),
## --input=<device name> listens to
## a microphone instead of system audio, --meter prints the audio levels each second.

const SAVE_PATH := "user://mushroom.cfg"
const IDLE_RATE := 0.035  # % per second with no music: roughly an hour per cake
const MUSIC_RATE := 0.085  # % per second of music: roughly 20-30 minutes of music per cake
const HUMIDITY_DECAY := 0.004  # per second
const MIST_AMOUNT := 0.25
const LEVELS_PORT := 47808  # the Mushroom Ears helper sends audio levels here
const PING_PORT := 47809  # and stays alive while we ping it here
const TURN_SPEED := 0.035  # radians per second: one full turn every 3 minutes

# Cake: a birthed half-pint jar cake, wide end down. Units are arbitrary "metres".
const CAKE_H := 0.9
const CAKE_R_BOT := 0.7
const CAKE_R_TOP := 0.6
const STEM_H := 0.78
const CAP_R := 0.6
const CAP_RY := 0.42

const BRF := Color("8a6a48")
const MYC := Color("f3efe6")
const SPOILED := Color("8d8a70")
const VEIL := Color("efe6d0")
const BRUISE := Color("6f8fae")
const STEM := Color("f4ecd8")
const ROT := Color("6b5a4a")
# Psilocybin species, one per cake in turn. There are 200+ described; these are ten
# well-known ones. rim/mid/crown: cap colours from edge to top, gill: underside,
# glow: beat flash. Shape, relative to a fat cubensis: thin (stem width), tall (stem
# length), capw / caph (cap width / height), cone (0 dome .. 1 cone), nip (nipple).
const SPECIES := [
	{"name": "Psilocybe cubensis", "rim": Color("e9dcb8"), "mid": Color("c48f55"), "crown": Color("94501f"), "gill": Color("4a332c"), "glow": Color(1.0, 0.5, 0.12), "thin": 1.0, "tall": 1.0, "capw": 1.0, "caph": 1.0, "cone": 0.0, "nip": 0.04},
	{"name": "Psilocybe azurescens", "rim": Color("d9b98a"), "mid": Color("b9783c"), "crown": Color("8a4a1c"), "gill": Color("4b3a34"), "glow": Color(0.3, 0.6, 1.0), "thin": 0.55, "tall": 1.35, "capw": 1.05, "caph": 0.55, "cone": 0.15, "nip": 0.09},
	{"name": "Psilocybe cyanescens", "rim": Color("d6a56a"), "mid": Color("b06a30"), "crown": Color("8c4a20"), "gill": Color("5a4034"), "glow": Color(0.25, 0.7, 1.0), "thin": 0.6, "tall": 1.1, "capw": 0.95, "caph": 0.5, "cone": 0.0, "nip": 0.03},
	{"name": "Psilocybe semilanceata", "rim": Color("d8cfa4"), "mid": Color("c2b27c"), "crown": Color("a08a55"), "gill": Color("4a3b3a"), "glow": Color(0.8, 1.0, 0.4), "thin": 0.28, "tall": 1.7, "capw": 0.42, "caph": 1.5, "cone": 0.75, "nip": 0.12},
	{"name": "Psilocybe mexicana", "rim": Color("d9c79a"), "mid": Color("b99560"), "crown": Color("8f6a3a"), "gill": Color("4d3c36"), "glow": Color(1.0, 0.4, 0.5), "thin": 0.3, "tall": 1.4, "capw": 0.5, "caph": 1.0, "cone": 0.5, "nip": 0.08},
	{"name": "Psilocybe tampanensis", "rim": Color("e2cf96"), "mid": Color("c9a65a"), "crown": Color("a37a35"), "gill": Color("4a3a30"), "glow": Color(1.0, 0.8, 0.2), "thin": 0.32, "tall": 1.2, "capw": 0.5, "caph": 0.8, "cone": 0.25, "nip": 0.04},
	{"name": "Psilocybe zapotecorum", "rim": Color("a89468"), "mid": Color("7a6238"), "crown": Color("4f3f22"), "gill": Color("3a2e2c"), "glow": Color(0.5, 1.0, 0.6), "thin": 0.75, "tall": 1.5, "capw": 0.9, "caph": 1.0, "cone": 0.45, "nip": 0.1},
	{"name": "Psilocybe baeocystis", "rim": Color("9a8f6a"), "mid": Color("6f6a48"), "crown": Color("4a4a34"), "gill": Color("3b3038"), "glow": Color(0.4, 0.5, 1.0), "thin": 0.4, "tall": 1.2, "capw": 0.6, "caph": 1.0, "cone": 0.5, "nip": 0.05},
	{"name": "Psilocybe caerulescens", "rim": Color("b9a27e"), "mid": Color("8a6a48"), "crown": Color("5c4028"), "gill": Color("40302c"), "glow": Color(0.7, 0.4, 1.0), "thin": 0.6, "tall": 1.0, "capw": 0.9, "caph": 0.7, "cone": 0.1, "nip": 0.05},
	{"name": "Panaeolus cyanescens", "rim": Color("e9e6dc"), "mid": Color("cfcabb"), "crown": Color("a9a393"), "gill": Color("2b2830"), "glow": Color(0.3, 0.9, 1.0), "thin": 0.28, "tall": 1.8, "capw": 0.5, "caph": 0.95, "cone": 0.2, "nip": 0.0},
]
const STAGE_COLORS := {
	"Colonization": Color("d9d2c0"),
	"Pinning": Color("e8b04a"),
	"Fruiting": Color("7fc97a"),
	"Decay": Color("a08a78"),
}
# az: direction it leans, degrees (0 = right, -90 = toward the camera at start).
# h: height up the cake's side, or top: offset on the top face.
# s: full-grown scale, delay: growth delay in %, tilt: lean from vertical in radians.
const MUSHROOMS := [
	{"az": 215.0, "h": 0.42, "s": 0.58, "delay": 10.0, "tilt": 1.15},
	{"az": -35.0, "h": 0.55, "s": 0.7, "delay": 8.0, "tilt": 1.0},
	{"az": 170.0, "h": 0.78, "s": 0.92, "delay": 3.0, "tilt": 0.85},
	{"az": 15.0, "top": Vector2(0.32, 0.1), "s": 0.8, "delay": 6.0, "tilt": 0.45},
	{"az": 100.0, "top": Vector2(-0.08, 0.0), "s": 1.35, "delay": 0.0, "tilt": 0.05},
	# Runts: stubby little ones that never catch up.
	{"az": 60.0, "h": 0.3, "s": 0.32, "delay": 14.0, "tilt": 1.2},
	{"az": -110.0, "h": 0.2, "s": 0.28, "delay": 16.0, "tilt": 1.25},
	{"az": 130.0, "h": 0.25, "s": 0.3, "delay": 18.0, "tilt": 1.2},
	{"az": 250.0, "top": Vector2(-0.38, 0.28), "s": 0.34, "delay": 12.0, "tilt": 0.5},
	# Skinny guys: thin: stem width, tall: stem length, cap: cap size (all default 1).
	{"az": -70.0, "top": Vector2(0.1, 0.4), "s": 0.8, "delay": 5.0, "tilt": 0.35, "thin": 0.4, "tall": 1.6, "cap": 0.5},
	{"az": 95.0, "h": 0.7, "s": 0.75, "delay": 7.0, "tilt": 0.7, "thin": 0.38, "tall": 1.7, "cap": 0.45},
	{"az": -150.0, "h": 0.6, "s": 0.7, "delay": 9.0, "tilt": 0.8, "thin": 0.35, "tall": 1.5, "cap": 0.5},
]

const CAKE_SHADER := """
shader_type spatial;
uniform sampler2D noise;
uniform float spread = 0.0;
uniform float decay = 0.0;
uniform vec3 brf : source_color;
uniform vec3 myc : source_color;
uniform vec3 spoiled : source_color;
uniform vec3 bruise : source_color;
varying vec3 pos;
varying vec3 nrm;
void vertex() {
	pos = VERTEX;
	nrm = NORMAL;
}
void fragment() {
	// Sample the noise around the side and flat across the top, so patches keep
	// their shape instead of stretching.
	vec2 side_uv = vec2(atan(pos.z, pos.x) / 6.2832 * 2.0, pos.y * 0.5);
	vec2 uv = mix(side_uv, pos.xz * 0.5, step(0.7, abs(nrm.y)));
	// Mycelium takes the brown cake over in patches, following the noise.
	float n = texture(noise, uv).r;
	float fine = texture(noise, uv * 3.0 + 0.37).r;
	float m = smoothstep(n - 0.12, n + 0.12, spread * 1.5 - 0.25);
	vec3 brown = brf * (0.8 + 0.4 * fine);
	vec3 white = mix(myc * (0.9 + 0.1 * fine), bruise, 0.25 * smoothstep(0.62, 0.8, fine));
	ALBEDO = mix(mix(brown, white, m), spoiled * (0.8 + 0.3 * fine), decay);
	ROUGHNESS = 0.95;
}
"""

var progress := 0.0
var humidity := 0.5
var harvests := 0
var species := 0
var minutes := 0.0  # minutes of music this widget has grown on

var _shown := 0.0
var _time := 0.0
var _ticks := 0
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _udp := PacketPeerUDP.new()
var _raw := Vector3.ZERO
var _raw_age := 99.0
var _use_mic := false
var _bass := 0.0
var _mid := 0.0
var _high := 0.0
var _bass_avg := 0.0
var _pulse := 0.0
var _beat_cooldown := 0.0
var _meter := false
var _demo_beat := false  # dev flag --beat: hold the beat pulse on, to check the glow
var _preview := false
var _shot_path := ""
var _fade: Tween
var _bg_set := false
var _bg := Color.BLACK
var _track := ""  # --track=<audio file>: react to this file instead of live audio
var _seconds := 0.0  # --seconds=N: clip length; one full turn, then quit
var _grow_to := -1.0  # --grow-to=X: grow from --progress to X over the clip
var _grow_from := 0.0
var _db_floor := -65.0
var _db_range := 50.0
var _cap_meshes: Array[ArrayMesh] = []

var _rig: Node3D
var _cake_mat: ShaderMaterial
var _cap_mat: StandardMaterial3D
var _stem_mat: StandardMaterial3D
var _gill_mat: StandardMaterial3D
var _shrooms: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _mist: CPUParticles3D
var _spores: CPUParticles3D


func _ready():
	_load()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progress="):
			progress = clampf(float(arg.get_slice("=", 1)), 0.0, 100.0)
			_preview = true
		elif arg.begins_with("--shot="):
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--input="):
			AudioServer.input_device = arg.get_slice("=", 1)
			_use_mic = true
		elif arg == "--meter":
			_meter = true
		elif arg == "--beat":
			_demo_beat = true
		elif arg.begins_with("--species="):
			species = int(arg.get_slice("=", 1)) % SPECIES.size()
			_preview = true
		elif arg.begins_with("--bg="):
			_bg = Color.html(arg.get_slice("=", 1))
			_bg_set = true
		elif arg.begins_with("--track="):
			_track = arg.get_slice("=", 1)
			_preview = true
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
			_preview = true
		elif arg.begins_with("--grow-to="):
			_grow_to = float(arg.get_slice("=", 1))
		elif arg.begins_with("--size="):
			# Square render size in pixels, for clips and big screenshots.
			var side := int(arg.get_slice("=", 1))
			get_window().size = Vector2i(side, side)
	_shown = progress
	_grow_from = progress
	if _bg_set:
		# Solid backdrop for chroma-keying in OBS and the like.
		get_viewport().transparent_bg = false
		get_window().transparent = false
		RenderingServer.set_default_clear_color(_bg)
	if _track != "":
		_setup_track()
	elif _use_mic:
		_setup_audio()
	elif _shot_path == "" and _seconds <= 0.0:
		# Default: hear the Mac's own audio through the Mushroom Ears helper app.
		_udp.bind(LEVELS_PORT, "127.0.0.1")
		_udp.set_dest_address("127.0.0.1", PING_PORT)
		OS.create_process("open", ["-g", ProjectSettings.globalize_path("res://ears/MushroomEars.app")])

	_build_world()
	_apply_species()
	$Controls.modulate.a = 0.0
	$Controls/MistButton.pressed.connect(_on_mist)
	$Controls/HarvestButton.pressed.connect(_on_harvest)
	$Controls/CloseButton.pressed.connect(_quit)
	_update_ui()
	_pose()

	if _shot_path != "":
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


# ---------------------------------------------------------------- 3D scene

func _build_world():
	get_viewport().msaa_3d = Viewport.MSAA_4X

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.84, 0.95)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var camera := Camera3D.new()
	camera.fov = 35.0
	add_child(camera)
	camera.position = Vector3(0, 2.3, 7.4)
	camera.look_at(Vector3(0, 1.45, 0))

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -38, 0)
	key.light_color = Color(1.0, 0.96, 0.88)
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 20.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 140, 0)
	fill.light_color = Color(0.75, 0.85, 1.0)
	fill.light_energy = 0.4
	add_child(fill)

	_rig = Node3D.new()
	add_child(_rig)

	# Jar lid.
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color("aab0b6")
	lid_mat.metallic = 0.25
	lid_mat.roughness = 0.35
	_add_mesh(_rig, _lathe([
		[Vector2(0.0, -0.08), Color.WHITE], [Vector2(0.93, -0.08), Color.WHITE],
		[Vector2(0.96, -0.05), Color.WHITE], [Vector2(0.96, 0.0), Color.WHITE],
		[Vector2(0.9, 0.0), Color.WHITE], [Vector2(0.88, -0.02), Color.WHITE],
		[Vector2(0.0, -0.02), Color.WHITE],
	]), lid_mat)

	# Cake, with a shader that colonizes it patch by patch.
	var noise := FastNoiseLite.new()
	noise.seed = 808
	noise.frequency = 0.02
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	var shader := Shader.new()
	shader.code = CAKE_SHADER
	_cake_mat = ShaderMaterial.new()
	_cake_mat.shader = shader
	_cake_mat.set_shader_parameter("noise", noise_tex)
	_cake_mat.set_shader_parameter("brf", BRF)
	_cake_mat.set_shader_parameter("myc", MYC)
	_cake_mat.set_shader_parameter("spoiled", SPOILED)
	_cake_mat.set_shader_parameter("bruise", BRUISE)
	_add_mesh(_rig, _lathe([
		[Vector2(0.0, -0.02), Color.WHITE], [Vector2(CAKE_R_BOT - 0.04, -0.02), Color.WHITE],
		[Vector2(CAKE_R_BOT, 0.04), Color.WHITE], [Vector2(CAKE_R_TOP, CAKE_H - 0.05), Color.WHITE],
		[Vector2(CAKE_R_TOP - 0.05, CAKE_H), Color.WHITE], [Vector2(0.0, CAKE_H), Color.WHITE],
	]), _cake_mat)

	# Shared mushroom materials; decay tints them all at once.
	_cap_mat = _vertex_mat(0.45)
	_cap_mat.emission_enabled = true
	_cap_mat.emission = Color(1.0, 0.5, 0.12)
	_cap_mat.emission_energy_multiplier = 0.0
	_stem_mat = _vertex_mat(0.75)
	_gill_mat = StandardMaterial3D.new()
	_gill_mat.roughness = 1.0
	_gill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stem_mesh := _stem_mesh()
	for sp in SPECIES:
		_cap_meshes.append(_cap_mesh(sp))
	var gill_mesh := _lathe([[Vector2(0.1, 0.07), Color.WHITE], [Vector2(CAP_R * 0.97, 0.0), Color.WHITE]])
	var skirt := TorusMesh.new()
	skirt.inner_radius = 0.1
	skirt.outer_radius = 0.2
	for m in MUSHROOMS:
		var pivot := Node3D.new()
		var az := deg_to_rad(m.az)
		if m.has("top"):
			pivot.position = Vector3(m.top.x, CAKE_H - 0.02, m.top.y)
		else:
			var r := lerpf(CAKE_R_BOT, CAKE_R_TOP, m.h) - 0.05
			pivot.position = Vector3(cos(az) * r, CAKE_H * m.h, -sin(az) * r)
		_rig.add_child(pivot)
		var stem := _add_mesh(pivot, stem_mesh, _stem_mat)
		var ring := _add_mesh(pivot, skirt, _gill_mat)
		var cap := Node3D.new()
		pivot.add_child(cap)
		var cap_dome := _add_mesh(cap, _cap_meshes[0], _cap_mat)
		var gills := _add_mesh(cap, gill_mesh, _gill_mat)
		_shrooms.append({
			"pivot": pivot, "stem": stem, "cap": cap, "dome": cap_dome, "gills": gills, "ring": ring,
			"az": az, "s": m.s, "delay": m.delay, "tilt": m.tilt,
			"thin": m.get("thin", 1.0), "tall": m.get("tall", 1.0), "capk": m.get("cap", 1.0),
		})

	# Beat rings on the table, mist and spores.
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.97
		torus.outer_radius = 1.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var node := _add_mesh(self, torus, mat)
		node.position.y = -0.06
		node.scale.y = 0.3
		node.visible = false
		_rings.append({"node": node, "mat": mat, "t": 1.0})
	_mist = _particles(Color(0.62, 0.82, 1.0), Vector3(0, 2.9, 0), Vector3(1.2, 0.1, 1.2), Vector3.DOWN, 2.2, Vector3(0, -3, 0))
	_spores = _particles(Color(0.95, 0.78, 0.4), Vector3(0, 1.7, 0), Vector3(1.2, 0.5, 1.2), Vector3.UP, 1.2, Vector3(0, 0.4, 0))


## Surface of revolution around Y. profile: [Vector2(radius, y), Color] from bottom to top.
func _lathe(profile: Array, segments := 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := profile.size()
	for i in rows:
		var p: Vector2 = profile[i][0]
		for j in segments + 1:
			var a := TAU * j / segments
			st.set_color(profile[i][1])
			st.set_uv(Vector2(float(j) / segments, float(i) / (rows - 1)))
			st.add_vertex(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	for i in rows - 1:
		for j in segments:
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			for index in [a, a + 1, b, a + 1, b + 1, b]:
				st.add_index(index)
	st.generate_normals()
	return st.commit()


## Fat stem with a bulbous, blue-bruised base, darker under the cap.
func _stem_mesh() -> ArrayMesh:
	var profile := [[Vector2(0.0, -0.05), STEM.lerp(BRUISE, 0.32)]]
	for i in 11:
		var t := i / 10.0
		var col := STEM.lerp(BRUISE, 0.32 * (1.0 - smoothstep(0.0, 0.3, t))).darkened(0.25 * smoothstep(0.75, 1.0, t))
		profile.append([Vector2(0.14 + 0.1 * pow(1.0 - t, 1.6), STEM_H * t), col])
	return _lathe(profile, 32)


## A species' cap: rim colour through mid to crown, shaped between a dome and a cone,
## with a nipple at the top.
func _cap_mesh(sp: Dictionary) -> ArrayMesh:
	var r: float = CAP_R * sp.capw
	var ry: float = CAP_RY * sp.caph
	var rim: Color = sp.rim
	var mid: Color = sp.mid
	var crown: Color = sp.crown
	var profile := [[Vector2(r * 0.97, 0.0), rim.darkened(0.15)]]
	for i in 15:
		var k := i / 14.0
		var a := PI * 0.5 * k
		var col := rim.lerp(mid, k * 2.0) if k < 0.5 else mid.lerp(crown, (k - 0.5) * 2.0)
		var out := lerpf(cos(a), 1.0 - k, sp.cone)
		var up := lerpf(sin(a), k, sp.cone)
		var nip: float = sp.nip * smoothstep(0.85, 1.0, k)
		profile.append([Vector2(r * out, 0.03 + ry * up + nip), col])
	return _lathe(profile)


## Swaps every mushroom over to the current species.
func _apply_species():
	var sp: Dictionary = SPECIES[species]
	_cap_mat.emission = sp.glow
	for m in _shrooms:
		m.dome.mesh = _cap_meshes[species]
		m.gills.scale = Vector3(sp.capw, 1.0, sp.capw)


func _vertex_mat(roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = roughness
	return mat


func _add_mesh(parent: Node, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node


func _particles(color: Color, at: Vector3, box: Vector3, direction: Vector3, speed: float, gravity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 24
	p.lifetime = 1.0
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = direction
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	var dot := SphereMesh.new()
	dot.radius = 0.028
	dot.height = 0.056
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	dot.material = mat
	p.mesh = dot
	p.position = at
	add_child(p)
	return p


## Puts every mesh where growth, decay and the music say it should be.
func _pose():
	var spread := clampf(_shown / 30.0, 0.0, 1.0)
	var decay := clampf((_shown - 90.0) / 10.0, 0.0, 1.0)
	_cake_mat.set_shader_parameter("spread", spread)
	_cake_mat.set_shader_parameter("decay", decay)
	var rot := Color.WHITE.lerp(ROT, decay * 0.85)
	_cap_mat.albedo_color = rot
	# Caps flash warm on each beat and fade with the pulse; rotten caps stay dark.
	_cap_mat.emission_energy_multiplier = _pulse * _pulse * 0.8 * (1.0 - decay)
	_stem_mat.albedo_color = Color.WHITE.lerp(ROT.lightened(0.25), decay * 0.8)

	# The whole cake turns slowly and squashes on the kick.
	var kick := maxf(_pulse, _bass * 0.6)
	# A rendered clip makes exactly one full turn, so it loops.
	_rig.rotation.y = TAU * _time / _seconds if _seconds > 0.0 else _time * TURN_SPEED
	_rig.scale = Vector3(1.0 + 0.05 * kick, 1.0 - 0.07 * kick, 1.0 + 0.05 * kick)

	var sp: Dictionary = SPECIES[species]
	for m in _shrooms:
		var g: float = smoothstep(0.0, 1.0, clampf((_shown - 28.0 - m.delay) / 58.0, 0.0, 1.0))
		var pivot: Node3D = m.pivot
		pivot.visible = g > 0.01
		if not pivot.visible:
			continue
		var open: float = smoothstep(0.35, 1.0, g)
		# Mids make the mushrooms wobble, the kick makes them swell, decay makes them droop.
		var wobble: float = sin(_time * 1.3 + m.az) * 0.025 + sin(_time * 7.0 + m.az) * 0.12 * _mid
		var tilt: float = m.tilt + wobble + decay * 0.3
		pivot.basis = Basis(Vector3.UP, m.az) * Basis(Vector3(0, 0, 1), -tilt)
		pivot.scale = Vector3.ONE * (m.s * lerpf(0.14, 1.0, g) * (1.0 + 0.12 * kick))
		# Young buttons are narrow and tall, with a pale veil underneath instead of gills.
		var wide := lerpf(0.45, 1.0, open)
		m.cap.scale = Vector3(wide, lerpf(0.8, 1.0, open) * (1.0 - 0.3 * decay), wide) * m.capk
		m.ring.visible = open > 0.5
		# Stem proportions: the species' build times this mushroom's own (runt, skinny).
		var thin: float = maxf(sp.thin * m.thin, 0.16)
		var tall: float = sp.tall * m.tall
		m.stem.scale = Vector3(thin, tall, thin)
		m.ring.position.y = STEM_H * tall * 0.6
		m.ring.scale = Vector3(thin, 0.25, thin)
		m.cap.position.y = STEM_H * tall - 0.1 * m.capk
	var open_main: float = smoothstep(0.35, 1.0, smoothstep(0.0, 1.0, clampf((_shown - 28.0) / 58.0, 0.0, 1.0)))
	_gill_mat.albedo_color = VEIL.lerp(sp.gill, smoothstep(0.3, 0.8, open_main)).lerp(ROT.darkened(0.4), decay * 0.85)

	var ring_color: Color = STAGE_COLORS[_stage()]
	for ring in _rings:
		ring.node.visible = ring.t < 1.0
		ring.node.scale = Vector3(1.0 + 0.8 * ring.t, 0.3, 1.0 + 0.8 * ring.t)
		ring.mat.albedo_color = Color(ring_color, (1.0 - ring.t) * 0.6)


# ---------------------------------------------------------------- audio

## Opt-in (--input=<device>): listens to a microphone through a silent bus with a
## spectrum analyzer. Godot 4.7 cannot read BlackHole here (AudioUnitRender -10863).
func _setup_audio():
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Listen")
	AudioServer.set_bus_volume_db(bus, -80.0)  # analyse only, never play the input back
	var fx := AudioEffectSpectrumAnalyzer.new()
	fx.buffer_length = 0.1
	AudioServer.add_bus_effect(bus, fx)
	_spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	var mic := AudioStreamPlayer.new()
	mic.stream = AudioStreamMicrophone.new()
	mic.bus = "Listen"
	add_child(mic)
	mic.play()


## --track=<file>: plays an audio file and reacts to it. Used for rendering clips,
## where the movie writer also records the audio.
func _setup_track():
	var stream: AudioStream
	match _track.get_extension().to_lower():
		"mp3": stream = AudioStreamMP3.load_from_file(_track)
		"wav": stream = AudioStreamWAV.load_from_file(_track)
		"ogg": stream = AudioStreamOggVorbis.load_from_file(_track)
	if stream == null:
		push_error("Cannot load track (mp3, wav or ogg): " + _track)
		return
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Track")
	var fx := AudioEffectSpectrumAnalyzer.new()
	fx.buffer_length = 0.1
	AudioServer.add_bus_effect(bus, fx)
	_spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	_db_floor = -60.0  # a file is much hotter than a microphone
	_db_range = 45.0
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Track"
	add_child(player)
	player.play()


## Loudness of a frequency band, 0..1, between _db_floor and _db_floor + _db_range.
func _band(from_hz: float, to_hz: float) -> float:
	var mag := _spectrum.get_magnitude_for_frequency_range(from_hz, to_hz).length()
	return clampf((linear_to_db(maxf(mag, 0.000001)) - _db_floor) / _db_range, 0.0, 1.0)


## Helper RMS to 0..1 (-50 dB maps to 0, -10 dB to 1).
func _level(rms: float) -> float:
	return clampf((linear_to_db(maxf(rms, 0.000001)) + 50.0) / 40.0, 0.0, 1.0)


func _listen(delta: float):
	var now := Vector3.ZERO
	if _spectrum != null:
		now = Vector3(_band(30, 150), _band(150, 2000), _band(2000, 10000))
	else:
		# Loudest helper packet since the last frame; silence if the helper went quiet.
		var got := false
		while _udp.get_available_packet_count() > 0:
			var parts := _udp.get_packet().get_string_from_ascii().strip_edges().split(" ")
			if parts.size() == 2 and parts[0] == "grow":
				# Feed hook: anything can send "grow 5" to add 5% (see README).
				progress = clampf(progress + float(parts[1]), 0.0, 100.0)
			elif parts.size() == 3:
				var v := Vector3(_level(float(parts[0])), _level(float(parts[1])), _level(float(parts[2])))
				_raw = v if not got else Vector3(maxf(_raw.x, v.x), maxf(_raw.y, v.y), maxf(_raw.z, v.z))
				got = true
		_raw_age = 0.0 if got else _raw_age + delta
		if _raw_age < 0.3:
			now = _raw
	var b := now.x
	var fall := 1.0 - exp(-8.0 * delta)
	_bass = maxf(b, lerpf(_bass, b, fall))
	_mid = maxf(now.y, lerpf(_mid, 0.0, fall))
	_high = maxf(now.z, lerpf(_high, 0.0, fall))

	# A beat is bass jumping clear of its own recent average.
	_bass_avg = lerpf(_bass_avg, b, 1.0 - exp(-1.5 * delta))
	_beat_cooldown -= delta
	_pulse = maxf(_pulse - delta * 3.5, 0.0)
	if b > _bass_avg + 0.12 and b > 0.25 and _beat_cooldown <= 0.0:
		_pulse = 1.0
		_beat_cooldown = 0.22
		var oldest: Dictionary = _rings[0]
		for ring in _rings:
			if ring.t > oldest.t:
				oldest = ring
		oldest.t = 0.0
		if _stage() == "Fruiting":
			_spores.restart()
			_spores.emitting = true
	for ring in _rings:
		ring.t = minf(ring.t + delta / 0.6, 1.0)
	if _demo_beat:
		_pulse = 1.0


# ---------------------------------------------------------------- growth and UI

func _stage() -> String:
	if progress > 90: return "Decay"
	if progress > 60: return "Fruiting"
	if progress > 30: return "Pinning"
	return "Colonization"


func _on_growth_timer_timeout():
	humidity = maxf(humidity - HUMIDITY_DECAY, 0.0)
	# The cake always creeps along (about an hour per cake in silence), so it can never
	# get stuck if no audio is reaching it. Music grows it about three times faster;
	# louder music and a misted cake faster still.
	var energy := (_bass + _mid + _high) / 3.0
	if _seconds <= 0.0:
		var rate := IDLE_RATE
		if energy > 0.04:
			minutes += 1.0 / 60.0
			rate = MUSIC_RATE * (0.6 + 0.8 * energy)
		progress = minf(progress + rate * (0.6 + 0.8 * humidity), 100.0)
	_ticks += 1
	if _udp.is_bound():
		_udp.put_packet("hi".to_ascii_buffer())
	if _meter:
		var source := "system audio, last packet %.1fs ago" % _raw_age
		if _track != "":
			source = "track"
		elif _use_mic:
			source = AudioServer.input_device
		print("bass %.2f  mid %.2f  high %.2f  (%s)" % [_bass, _mid, _high, source])
	if _ticks % 10 == 0:
		_save()
	_update_ui()


func _on_mist():
	humidity = minf(humidity + MIST_AMOUNT, 1.0)
	_mist.restart()
	_mist.emitting = true


func _on_harvest():
	if _stage() == "Fruiting":
		harvests += 1
	progress = 0.0
	# Every new cake is the next species.
	species = (species + 1) % SPECIES.size()
	_apply_species()
	_save()
	_update_ui()


func _update_ui():
	var stage := _stage()
	var button: Button = $Controls/HarvestButton
	button.text = "New cake" if stage == "Decay" else "Harvest"
	button.disabled = stage != "Fruiting" and stage != "Decay"
	button.tooltip_text = "%s\n%s · %d%% · %d harvested · %d min of music" % [SPECIES[species].name, stage, int(progress), harvests, int(minutes)]


func _process(delta):
	_time += delta
	_shown = lerpf(_shown, progress, 1.0 - exp(-4.0 * delta))
	_listen(delta)
	if _seconds > 0.0:
		if _grow_to >= 0.0:
			progress = lerpf(_grow_from, _grow_to, clampf(_time / _seconds, 0.0, 1.0))
		if _time >= _seconds:
			get_tree().quit()
	_pose()
	if _dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			get_window().position = DisplayServer.mouse_get_position() - _drag_offset
		else:
			_dragging = false


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_offset = DisplayServer.mouse_get_position() - get_window().position
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_quit()


func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save()
		NOTIFICATION_WM_MOUSE_ENTER:
			_show_controls(true)
		NOTIFICATION_WM_MOUSE_EXIT:
			_show_controls(false)


## The buttons only appear while the mouse is over the widget.
func _show_controls(on: bool):
	if not is_node_ready():
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property($Controls, "modulate:a", 1.0 if on else 0.0, 0.2)


func _quit():
	_save()
	get_tree().quit()


func _load():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	progress = cfg.get_value("grow", "progress", 0.0)
	humidity = cfg.get_value("grow", "humidity", 0.5)
	harvests = cfg.get_value("grow", "harvests", 0)
	species = int(cfg.get_value("grow", "species", 0)) % SPECIES.size()
	minutes = cfg.get_value("grow", "minutes", 0.0)


func _save():
	if _preview:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("grow", "progress", progress)
	cfg.set_value("grow", "humidity", humidity)
	cfg.set_value("grow", "harvests", harvests)
	cfg.set_value("grow", "species", species)
	cfg.set_value("grow", "minutes", minutes)
	cfg.save(SAVE_PATH)
