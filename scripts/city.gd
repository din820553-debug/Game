extends Node3D
signal hit
const Catalog = preload("res://data/catalog.gd")
var rng = RandomNumberGenerator.new()
var scenery = []
var obstacles = []
var rain = []
var rider: Node3D
var spawn_left = 2.0
var riding = false
var materials = {}

func _ready():
	rng.randomize()
	build()

func mat(color, emission = false):
	var key = str(color) + str(emission)
	if materials.has(key):
		return materials[key]
	var value = StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.35 if emission else 0.65
	if emission:
		value.emission_enabled = true
		value.emission = color
		value.emission_energy_multiplier = 1.8
	materials[key] = value
	return value

func cube(parent, size, at, surface):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node

func build():
	var sky = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#070c20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#7190d6")
	environment.ambient_light_energy = 0.7
	sky.environment = environment
	add_child(sky)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("#96b5ff")
	sun.light_energy = 0.8
	add_child(sun)

	var camera = Camera3D.new()
	camera.position = Vector3(0, 16, 17)
	add_child(camera)
	camera.look_at(Vector3(0, 0, -8))
	camera.fov = 65
	camera.current = true

	var road = mat(Color("#111c30"))
	road.metallic = 0.6
	road.roughness = 0.23
	cube(self, Vector3(10, 0.15, 135), Vector3(0, -0.12, -48), road)
	var blue = mat(Color("#33e7f6"), true)
	var pink = mat(Color("#ff4c96"), true)
	var sidewalk = mat(Color("#26344b"))
	for side in [-1, 1]:
		cube(self, Vector3(2, 0.25, 135), Vector3(side * 6, 0, -48), sidewalk)
		cube(self, Vector3(0.07, 0.03, 135), Vector3(side * 4.8, 0.03, -48), blue if side < 0 else pink)

	for i in range(20):
		var group = Node3D.new()
		add_child(group)
		group.position.z = 12 - i * 6
		scenery.append(group)
		for x in [-1.4, 1.4]:
			cube(group, Vector3(0.07, 0.03, 2.2), Vector3(x, 0.02, 0), mat(Color("#60738c")))
		for side in [-1, 1]:
			var height = rng.randf_range(3, 8)
			cube(group, Vector3(5, height, 5), Vector3(side * 9.5, height / 2, 0),
				mat(Color("#14203a") if i % 2 == 0 else Color("#1a2940")))
			var neon = blue if (i + side) % 2 == 0 else pink
			for floor_index in range(1, int(height), 2):
				cube(group, Vector3(0.05, 0.3, 1.8), Vector3(side * 6.97, floor_index, 0), neon)
			cube(group, Vector3(0.1, 3.3, 0.1), Vector3(side * 5.7, 1.65, 1.8), sidewalk)
			cube(group, Vector3(0.65, 0.12, 0.4), Vector3(side * 5.45, 3.3, 1.8), neon)
			# Stylized wet-road light streaks; no expensive screen-space reflections.
			cube(group, Vector3(0.3, 0.015, 2.4), Vector3(side * 4.0, 0.02, 1.6),
				mat(Color("#163a50") if side < 0 else Color("#391e43"), true))
			if i % 4 == 0:
				var sign_label = Label3D.new()
				sign_label.text = "24 / 7" if side < 0 else "NIGHT"
				sign_label.position = Vector3(side * 7.1, 2.5, 2.6)
				sign_label.font_size = 42
				sign_label.pixel_size = 0.014
				sign_label.modulate = Color("#40f6d2") if side < 0 else Color("#ff70a3")
				group.add_child(sign_label)

	var rain_material = mat(Color("#405c83"))
	for i in range(70):
		var drop = cube(self, Vector3(0.018, 0.42, 0.018), random_drop(), rain_material)
		drop.rotation.z = -0.2
		rain.append(drop)
	set_vehicle("bike")

func random_drop():
	return Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 17), rng.randf_range(-45, 15))

func set_vehicle(id):
	if is_instance_valid(rider):
		remove_child(rider)
		rider.queue_free()
	rider = Node3D.new()
	add_child(rider)
	rider.position.z = 4
	var frame = mat(Catalog.VEHICLES[id]["color"], true)
	var dark = mat(Color("#07101b"))
	cube(rider, Vector3(0.35, 0.45, 1.35), Vector3(0, 0.5, 0), frame)
	if id == "scooter":
		cube(rider, Vector3(0.65, 0.65, 0.65), Vector3(0, 0.65, -0.3), frame)
	for z in [-0.55, 0.55]:
		cube(rider, Vector3(0.20, 0.55, 0.45), Vector3(0, 0.28, z), dark)
	cube(rider, Vector3(0.75, 0.1, 0.12), Vector3(0, 0.85, -0.5), frame)
	cube(rider, Vector3(0.5, 0.65, 0.4), Vector3(0, 1.1, 0.05), mat(Color("#f5c660")))
	cube(rider, Vector3(0.38, 0.35, 0.38), Vector3(0, 1.6, -0.08), dark)
	cube(rider, Vector3(0.58, 0.55, 0.4), Vector3(0, 1.0, 0.42), mat(Color("#ff7162")))
	cube(rider, Vector3(0.26, 0.08, 0.06), Vector3(0, 0.6, 0.74), mat(Color("#ff3355"), true))
	var headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 0.8, -0.6)
	headlight.rotation_degrees.x = -12
	headlight.light_color = Color("#b3fcff")
	headlight.light_energy = 3
	headlight.spot_range = 18
	headlight.spot_angle = 27
	rider.add_child(headlight)

func start(id):
	clear_traffic()
	set_vehicle(id)
	spawn_left = 2.0
	riding = true

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
	var colors = [Color("#344b73"), Color("#683153"), Color("#3b696a")]
	var body = mat(colors[rng.randi_range(0, colors.size() - 1)])
	cube(node, Vector3(1.5, 0.7, 2.6), Vector3(0, 0.5, 0), body)
	cube(node, Vector3(1.2, 0.55, 1.3), Vector3(0, 1.0, -0.1), mat(Color("#0c182c")))
	for side in [-1, 1]:
		cube(node, Vector3(0.3, 0.12, 0.06), Vector3(side * 0.5, 0.5, 1.32), mat(Color("#ff4569"), true))
	obstacles.append(node)

func tick(delta, speed_value = 1.5, lane = 1, handling = 8.0):
	for group in scenery:
		group.position.z += speed_value * delta
		if group.position.z > 18:
			group.position.z -= 120
	for drop in rain:
		drop.position.y -= delta * 18
		drop.position.x += delta * 3
		if drop.position.y < 0:
			drop.position = random_drop()
			drop.position.y = 17
	if not riding:
		return
	var target_x = (lane - 1) * 2.8
	rider.position.x = move_toward(rider.position.x, target_x, handling * delta)
	rider.rotation.z = lerpf(rider.rotation.z, (rider.position.x - target_x) * 0.1, minf(1, delta * 8))
	spawn_left -= delta
	if spawn_left <= 0:
		spawn_car()
		spawn_left = rng.randf_range(1.7, 2.8)
	for car in obstacles.duplicate():
		car.position.z += speed_value * delta
		if absf(car.position.z - rider.position.z) < 1.2 and absf(car.position.x - rider.position.x) < 1.0:
			hit.emit()
			obstacles.erase(car)
			car.queue_free()
		elif car.position.z > 15:
			obstacles.erase(car)
			car.queue_free()
