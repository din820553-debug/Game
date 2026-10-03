extends SceneTree
const GameState = preload("res://scripts/game_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Preferences = preload("res://scripts/preferences.gd")
var app

func _initialize():
	call_deferred("capture")

func snap(name, preview = false):
	for i in range(5):
		app.city.tick(0.016)
		await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image.save_png("res://build/screenshots/" + name + ".png") != OK:
		printerr("SCREENSHOT FAILED")
		quit(1)
	if preview:
		image.resize(360, int(image.get_height() * 360.0 / image.get_width()), Image.INTERPOLATE_LANCZOS)
		print("VISUAL_PREVIEW:" + name + ":" + Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.78)))

func capture():
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	app = load("res://main.tscn").instantiate()
	app.game = GameState.new(SaveStore.new("user://capture_only.json"), 456)
	app.game.profile = SaveStore.fresh()
	app.preferences = Preferences.new("user://capture_preferences.cfg")
	app.preferences.quality = "high"
	root.add_child(app)
	app.set_process(false)
	await snap("00-home", true)
	app.show_orders()
	await snap("01-orders", true)
	app.start_order(0)
	app.city.spawn_car()
	app.city.obstacles[0].position.z = -7
	app.city.spawn_car()
	app.city.obstacles[1].position = Vector3(-2.8, 0, -18)
	await snap("02-ride", true)
	app.game.run["current_event"] = app.game.events[0]
	app.show_event()
	await snap("03-event")
	app.finish("abandoned")
	app.bank_and_garage()
	await snap("04-garage")
	app.open_collection("garage")
	await snap("05-collection")
	app.show_settings()
	await snap("06-settings")
	app.show_help()
	await snap("07-tutorial")
	app.game.profile["owned"].append("scooter")
	app.game.profile["vehicle"] = "scooter"
	app.city.set_vehicle("scooter")
	app.show_home()
	await snap("08-scooter", true)
	root.size = Vector2i(390, 844)
	await process_frame
	app.show_home()
	await snap("09-tall-home")
	app.queue_free()
	await process_frame
	print("SCREENSHOTS PASSED")
	quit()
