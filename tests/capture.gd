extends SceneTree
const GameState = preload("res://scripts/game_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var app

func _initialize():
	call_deferred("capture")

func snap(name):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image.save_png("res://build/screenshots/" + name + ".png") != OK:
		printerr("SCREENSHOT FAILED")
		quit(1)

func capture():
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	app = load("res://main.tscn").instantiate()
	app.game = GameState.new(SaveStore.new("user://capture_only.json"), 456)
	app.game.profile = SaveStore.fresh()
	root.add_child(app)
	app.set_process(false)
	await snap("01-orders")
	app.start_order(0)
	app.city.spawn_car()
	app.city.obstacles[0].position.z = -8
	await snap("02-ride")
	app.game.run["current_event"] = app.game.events[0]
	app.show_event()
	await snap("03-event")
	app.finish("abandoned")
	app.bank_and_garage()
	await snap("04-garage")
	app.open_collection("garage")
	await snap("05-collection")
	app.queue_free()
	await process_frame
	print("SCREENSHOTS PASSED")
	quit()
