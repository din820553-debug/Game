extends Node3D
signal hit
const Catalog = preload("res://data/catalog.gd")
const RoadShader = preload("res://shaders/wet_road.gdshader")
var rng = RandomNumberGenerator.new()
var scenery = []
var obstacles = []
var rider: Node3D
var wheels = []
var camera: Camera3D
var sun: DirectionalLight3D
var headlight: SpotLight3D
var rain_node: MultiMeshInstance3D
var rain_positions = []
var materials = {}
var road_material: ShaderMaterial
var spawn_left = 2.0
var riding = false
var quality = "high"
var view = "menu"
var travel = 0.0
var clock = 0.0
var shake_left = 0.0

func _ready():
	rng.seed = 72019
	build()

func mat(color, emission = false, metallic = 0.0):
	var key = str(color) + str(emission) + str(metallic)
	if materials.has(key):
		return materials[key]
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.3 if metallic > 0 else 0.78
	result.metallic = metallic
	if emission:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.35
	materials[key] = result
	return result

func mesh_node(parent, mesh, at, surface):
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node

func cube(parent, size, at, surface):
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, at, surface)

func cylinder(parent, radius, height, at, surface, segments = 12):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh_node(parent, mesh, at, surface)

func sphere(parent, radius, at, surface):
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh_node(parent, mesh, at, surface)

func bar(parent, a, b, radius, surface):
	var direction = b - a
	var node = cylinder(parent, radius, direction.length(), (a + b) * 0.5, surface, 8)
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return node

func boxes(parent, positions, size, surface):
	var node = MultiMeshInstance3D.new()
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var mesh = BoxMesh.new()
	mesh.size = size
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	node.multimesh = multi
	node.material_override = surface
	parent.add_child(node)
	return node

func build():
	var sky = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#081521")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#91abc4")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky.environment = environment
	add_child(sky)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("#abcce3")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 58
	camera.far = 145
	add_child(camera)
	camera.current = true
	set_view("menu", true)

	road_material = ShaderMaterial.new()
	road_material.shader = RoadShader
	cube(self, Vector3(10, 0.12, 145), Vector3(0, -0.10, -51), road_material)
	var concrete = mat(Color("#48545c"))
	var asphalt = mat(Color("#25353c"))
	for side in [-1, 1]:
		cube(self, Vector3(2, 0.2, 145), Vector3(side * 6, -0.02, -51), asphalt)
		cube(self, Vector3(0.22, 0.28, 145), Vector3(side * 5.0, 0, -51), concrete)
		cube(self, Vector3(0.09, 0.012, 145), Vector3(side * 4.65, 0.001, -51), mat(Color("#b8a672")))

	for i in range(20):
		var group = Node3D.new()
		add_child(group)
		group.position.z = 12 - i * 6
		scenery.append(group)
		boxes(group, [Vector3(-1.4, 0, 0), Vector3(1.4, 0, 0)],
			Vector3(0.085, 0.012, 2.5), mat(Color("#839799")))
		for side in [-1, 1]:
			var height = rng.randf_range(5, 12)
			var building_color = Color("#283b46") if i % 2 == 0 else Color("#304049")
			cube(group, Vector3(5.4, height, 5.75), Vector3(side * 9.8, height / 2, 0), mat(building_color))
			cube(group, Vector3(5.6, 0.20, 5.95), Vector3(side * 9.8, height + 0.1, 0), concrete)
			var warm_windows = []
			var dark_windows = []
			for floor_index in range(2, int(height), 2):
				for z in [-1.8, 0.0, 1.8]:
					var at = Vector3(side * 7.08, floor_index, z)
					if rng.randf() > 0.45:
						warm_windows.append(at)
					else:
						dark_windows.append(at)
			boxes(group, warm_windows, Vector3(0.05, 0.95, 0.7), mat(Color("#c89c66"), true))
			boxes(group, dark_windows, Vector3(0.05, 0.95, 0.7), mat(Color("#091b28"), false, 0.4))
			# Ground-floor shop glass and metal canopy.
			cube(group, Vector3(0.08, 1.6, 3.4), Vector3(side * 7.04, 0.9, 0), mat(Color("#102b35"), false, 0.45))
			cube(group, Vector3(1.0, 0.12, 4.0), Vector3(side * 6.7, 1.85, 0), mat(Color("#203641"), false, 0.3))
			if i % 2 == 0:
				var color = Color("#4bb4c2") if side < 0 else Color("#e6a05b")
				cube(group, Vector3(0.08, 0.10, 3.8), Vector3(side * 6.2, 1.88, 0), mat(color, true))
				cylinder(group, 0.055, 3.5, Vector3(side * 5.6, 1.75, 2), mat(Color("#36444f"), false, 0.6))
				cube(group, Vector3(0.7, 0.1, 0.35), Vector3(side * 5.35, 3.5, 2), mat(Color("#f1d6a2"), true))
			if i % 4 == 0:
				var sign_label = Label3D.new()
				sign_label.text = "COFFEE / 24" if side < 0 else "NIGHT MARKET"
				sign_label.position = Vector3(side * 7.15, 2.25, 2.9)
				sign_label.font_size = 48
				sign_label.pixel_size = 0.009
				sign_label.modulate = Color("#89dedc") if side < 0 else Color("#f4c380")
				group.add_child(sign_label)
				cube(group, Vector3(0.7, 0.8, 0.75), Vector3(side * 5.9, 0.5, -1), mat(Color("#45574c")))
		if i % 6 == 0:
			var stripes = []
			for x in range(-4, 5):
				stripes.append(Vector3(x, 0.001, 2))
			boxes(group, stripes, Vector3(0.5, 0.012, 1.5), mat(Color("#aab6ad")))

	# Rain is one instanced draw call instead of a mesh node for every drop.
	var rain_mesh = BoxMesh.new()
	rain_mesh.size = Vector3(0.012, 0.32, 0.012)
	var rain_multi = MultiMesh.new()
	rain_multi.transform_format = MultiMesh.TRANSFORM_3D
	rain_multi.mesh = rain_mesh
	rain_multi.instance_count = 100
	rain_node = MultiMeshInstance3D.new()
	rain_node.multimesh = rain_multi
	rain_node.material_override = mat(Color("#6f8a98"))
	rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain_node)
	for i in range(100):
		rain_positions.append(Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 14), rng.randf_range(-36, 14)))
	set_vehicle("bike")
	set_quality("high")

func wheel(parent, at, radius, detailed = true):
	var root = Node3D.new()
	root.position = at
	parent.add_child(root)
	if detailed:
		var tire = TorusMesh.new()
		tire.inner_radius = radius * 0.78
		tire.outer_radius = radius
		tire.rings = 16
		tire.ring_segments = 8
		var tire_node = mesh_node(root, tire, Vector3.ZERO, mat(Color("#101719")))
		tire_node.rotation.z = PI / 2
		var rim = TorusMesh.new()
		rim.inner_radius = radius * 0.70
		rim.outer_radius = radius * 0.77
		rim.rings = 16
		rim.ring_segments = 6
		var rim_node = mesh_node(root, rim, Vector3.ZERO, mat(Color("#9babaf"), false, 0.8))
		rim_node.rotation.z = PI / 2
		for i in range(4):
			var angle = i * PI / 4
			var end = Vector3(0, cos(angle), sin(angle)) * radius * 0.74
			bar(root, -end, end, 0.009, mat(Color("#8fa4ab"), false, 0.7))
	else:
		var tire = cylinder(root, radius, 0.22, Vector3.ZERO, mat(Color("#101719")))
		tire.rotation.z = PI / 2
		var rim = cylinder(root, radius * 0.60, 0.235, Vector3.ZERO, mat(Color("#8a999e"), false, 0.65))
		rim.rotation.z = PI / 2
	return root

func set_vehicle(id):
	if is_instance_valid(rider):
		remove_child(rider)
		rider.queue_free()
	wheels.clear()
	rider = Node3D.new()
	add_child(rider)
	rider.position = Vector3(0, 0, 4)
	var frame = mat(Color("#407f82") if id == "bike" else Color("#b9c8c4"), false, 0.65)
	var dark = mat(Color("#18252c"))
	var silver = mat(Color("#a1b3b6"), false, 0.8)
	var radius = 0.40 if id == "bike" else 0.32
	for z in [-0.72, 0.72]:
		wheels.append(wheel(rider, Vector3(0, radius, z), radius, id == "bike"))
	if id == "bike":
		var a = Vector3(0, 0.42, 0.72)
		var b = Vector3(0, 0.46, 0)
		var c = Vector3(0, 1.02, 0.26)
		var d = Vector3(0, 1.00, -0.55)
		for edge in [[a, b], [a, c], [b, c], [c, d], [b, d], [d, Vector3(0, 0.4, -0.72)]]:
			bar(rider, edge[0], edge[1], 0.035, frame)
	else:
		cube(rider, Vector3(0.48, 0.18, 1.05), Vector3(0, 0.5, 0.1), frame)
		var fairing = cube(rider, Vector3(0.50, 0.7, 0.25), Vector3(0, 0.88, -0.45), frame)
		fairing.rotation.x = -0.15
		cube(rider, Vector3(0.48, 0.35, 0.60), Vector3(0, 0.73, 0.44), frame)
	bar(rider, Vector3(-0.33, 1.12, -0.54), Vector3(0.33, 1.12, -0.54), 0.035, silver)
	cube(rider, Vector3(0.30, 0.1, 0.4), Vector3(0, 1.05, 0.3), dark)
	var jacket = mat(Color("#b9a167"))
	var pants = mat(Color("#243745"))
	var skin = mat(Color("#bd9279"))
	# Articulated courier silhouette: torso, arms, bent legs, helmet and bag.
	var torso = sphere(rider, 0.25, Vector3(0, 1.37, 0.12), jacket)
	torso.scale = Vector3(0.85, 1.4, 0.72)
	torso.rotation.x = -0.25
	for side in [-1, 1]:
		bar(rider, Vector3(side * 0.20, 1.5, 0.02), Vector3(side * 0.28, 1.20, -0.23), 0.07, jacket)
		bar(rider, Vector3(side * 0.28, 1.20, -0.23), Vector3(side * 0.29, 1.13, -0.53), 0.06, jacket)
		sphere(rider, 0.055, Vector3(side * 0.29, 1.13, -0.53), dark)
		bar(rider, Vector3(side * 0.12, 1.12, 0.2), Vector3(side * 0.20, 0.78, -0.05), 0.085, pants)
		bar(rider, Vector3(side * 0.20, 0.78, -0.05), Vector3(side * 0.19, 0.44, 0.17), 0.07, pants)
		cube(rider, Vector3(0.14, 0.10, 0.27), Vector3(side * 0.19, 0.40, 0.09), dark)
	sphere(rider, 0.13, Vector3(0, 1.79, -0.09), skin)
	var helmet = sphere(rider, 0.17, Vector3(0, 1.88, -0.06), mat(Color("#ccd3c6"), false, 0.2))
	helmet.scale.y = 0.8
	cube(rider, Vector3(0.24, 0.10, 0.035), Vector3(0, 1.83, -0.22), mat(Color("#152a32"), false, 0.7))
	cube(rider, Vector3(0.48, 0.48, 0.34), Vector3(0, 1.38, 0.47), mat(Color("#c0643c")))
	cube(rider, Vector3(0.50, 0.06, 0.36), Vector3(0, 1.37, 0.47), mat(Color("#dce3c6"), true))
	cube(rider, Vector3(0.20, 0.07, 0.03), Vector3(0, 0.75, 0.92), mat(Color("#fb6654"), true))
	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 1.02, -0.65)
	headlight.rotation_degrees.x = -16
	headlight.light_color = Color("#d3efe9")
	headlight.light_energy = 4
	headlight.spot_range = 22
	headlight.spot_angle = 31
	rider.add_child(headlight)
	set_quality(quality)

func set_quality(value):
	quality = value
	sun.shadow_enabled = quality == "high"
	if is_instance_valid(headlight):
		headlight.shadow_enabled = quality == "high"
	road_material.set_shader_parameter("detailed", quality == "high")
	rain_node.multimesh.visible_instance_count = 100 if quality == "high" else 32

func set_view(value, immediate = false):
	view = value
	if immediate:
		camera.position = Vector3(5.6, 3.3, 10) if view == "menu" else Vector3(0, 13.8, 14)
		camera.look_at(Vector3(0, 1.0, 3.6) if view == "menu" else Vector3(0, 0, -9))

func start(id):
	clear_traffic()
	set_vehicle(id)
	spawn_left = 2
	riding = true
	set_view("ride", true)

func stop():
	riding = false
	clear_traffic()

func clear_traffic():
	for node in obstacles:
		remove_child(node)
		node.queue_free()
	obstacles.clear()

func spawn_car():
	var node = Node3D.new()
	add_child(node)
	node.position = Vector3((rng.randi_range(0, 2) - 1) * 2.8, 0, -58)
	var colors = [Color("#3c5361"), Color("#824c43"), Color("#778984")]
	var body = mat(colors[rng.randi_range(0, colors.size() - 1)], false, 0.55)
	var glass = mat(Color("#162d38"), false, 0.8)
	cube(node, Vector3(1.45, 0.48, 2.7), Vector3(0, 0.52, 0), body)
	cube(node, Vector3(1.23, 0.42, 1.2), Vector3(0, 0.96, 0.12), glass)
	cube(node, Vector3(1.26, 0.08, 1.18), Vector3(0, 1.20, 0.12), body)
	var windscreen = cube(node, Vector3(1.23, 0.44, 0.05), Vector3(0, 0.96, -0.59), glass)
	windscreen.rotation.x = -0.4
	cube(node, Vector3(1.4, 0.12, 0.08), Vector3(0, 0.35, 1.4), mat(Color("#182328")))
	cube(node, Vector3(0.4, 0.12, 0.02), Vector3(0, 0.55, 1.37), mat(Color("#c9cfba")))
	for side in [-1, 1]:
		for z in [-0.83, 0.83]:
			wheel(node, Vector3(side * 0.70, 0.30, z), 0.28, false)
		cube(node, Vector3(0.31, 0.11, 0.04), Vector3(side * 0.49, 0.66, 1.37), mat(Color("#ff6150"), true))
		cube(node, Vector3(0.32, 0.12, 0.04), Vector3(side * 0.49, 0.66, -1.37), mat(Color("#eee7cc"), true))
	obstacles.append(node)

func impact():
	shake_left = 0.23

func tick(delta, speed_value = 0.0, lane = 1, handling = 8.0):
	clock += delta
	shake_left = maxf(0, shake_left - delta)
	if riding:
		travel = fmod(travel + speed_value * delta, 120.0)
		road_material.set_shader_parameter("travel", travel)
		for group in scenery:
			group.position.z += speed_value * delta
			if group.position.z > 18:
				group.position.z -= 120
	var desired = Vector3(5.6 + sin(clock * 0.13) * 0.3, 3.3, 10) if view == "menu" else Vector3(0, 13.8, 14)
	camera.position = camera.position.lerp(desired, minf(1, delta * 6))
	if shake_left > 0:
		camera.position.x += sin(clock * 92) * shake_left * 0.22
	camera.look_at(Vector3(0, 1.0, 3.6) if view == "menu" else Vector3(0, 0, -9))
	for i in range(rain_node.multimesh.visible_instance_count):
		var p = rain_positions[i]
		p.y -= delta * 17
		p.x += delta * 2
		if p.y < 0:
			p = Vector3(rng.randf_range(-10, 10), 14, rng.randf_range(-36, 14))
		rain_positions[i] = p
		rain_node.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, 0.12), p))
	if not riding:
		return
	var target_x = (lane - 1) * 2.8
	rider.position.x = move_toward(rider.position.x, target_x, handling * delta)
	rider.rotation.z = lerpf(rider.rotation.z, (rider.position.x - target_x) * 0.09, minf(1, delta * 8))
	for node in wheels:
		node.rotate_x(-speed_value * delta * 0.8)
	spawn_left -= delta
	if spawn_left <= 0:
		spawn_car()
		spawn_left = rng.randf_range(1.7, 2.8)
	for car in obstacles.duplicate():
		car.position.z += speed_value * delta
		if absf(car.position.z - rider.position.z) < 1.45 and absf(car.position.x - rider.position.x) < 1.0:
			hit.emit()
			obstacles.erase(car)
			car.queue_free()
		elif car.position.z > 15:
			obstacles.erase(car)
			car.queue_free()
