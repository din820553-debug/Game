extends SceneTree
const Catalog = preload("res://data/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Preferences = preload("res://scripts/preferences.gd")
const FailingStore = preload("res://tests/failing_store.gd")
var failures = 0
var checks = 0
var paths = []

func _initialize():
	call_deferred("run_tests")

func check(condition, description):
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func isolated(name):
	var path = "user://test_" + name + ".json"
	paths.append(path)
	clean(path)
	return SaveStore.new(path)

func clean(path):
	for suffix in ["", ".bak", ".tmp"]:
		var file_path = path + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

func run_tests():
	check(Catalog.ORDERS.size() == 20, "20 order types")
	check(Catalog.events().size() == 12, "12 event types")
	var state = GameState.new(isolated("economy"), 123)
	check(state.profile["bank"] == 25, "starting bank")
	var original_offers = state.offers.duplicate(true)
	state.bank_shift()
	check(state.offers == original_offers, "empty cashout cannot reroll offers")
	var seen = {}
	for i in range(600):
		state.generate_offers()
		check(state.offers.size() == 3, "three offers")
		var ids = {}
		for order in state.offers:
			ids[order["id"]] = true
			seen[order["id"]] = true
			check(order["size"] <= state.vehicle()["capacity"], "cargo fits")
			check(order["limit"] >= 60 and order["limit"] <= 300, "short sessions")
		check(ids.size() == 3, "distinct offers")
	check(seen.size() == 20, "all types reachable")

	check(not state.buy_upgrade("engine"), "cannot overspend")
	check(not state.select_vehicle("scooter"), "cannot buy unaffordable vehicle")
	check(state.start_order(0), "start delivery")
	check(not state.start_order(1), "cannot start twice")
	check(not state.bank_shift(), "cannot bank mid-delivery")
	var payout = state.run["order"]["pay"]
	state.run["distance"] = 0
	check(state.outcome() == "delivered", "arrival")
	state.settle("delivered")
	check(state.profile["shift"] == payout, "reward credited to shift")
	check(state.profile["bank"] == 25, "bank unchanged before cashout")
	check(state.settle("delivered").is_empty(), "no duplicate payout")
	state.start_order(0)
	state.run["health"] = 0
	check(state.outcome() == "lost", "health failure")
	state.settle("lost")
	check(state.profile["shift"] == 0 and state.profile["bank"] == 25, "failure loses only shift")
	state.start_order(0)
	state.run["distance"] = 0
	state.settle("delivered")
	var amount = state.profile["shift"]
	state.bank_shift()
	check(state.profile["bank"] == 25 + amount, "cashout credits bank")
	check(state.profile["shift"] == 0 and state.profile["streak"] == 0, "cashout resets series")

	state.profile["bank"] = 50000
	check(state.select_vehicle("scooter"), "buy scooter")
	check(state.profile["bank"] == 49400, "scooter charged once")
	state.select_vehicle("bike")
	state.select_vehicle("scooter")
	check(state.profile["bank"] == 49400, "owned scooter free to select")
	var baseline = state.speed()
	check(state.buy_upgrade("engine"), "upgrade purchase")
	check(state.speed() > baseline, "engine affects speed")
	state.profile["upgrades"]["scooter"]["engine"] = 10
	check(not state.buy_upgrade("engine"), "upgrade cap")
	state.select_vehicle("bike")
	check(state.levels()["engine"] == 1, "upgrades are per vehicle")
	state.start_order(0)
	var initial_health = state.run["health"]
	check(state.collision(), "first collision hits")
	check(not state.collision(), "collision invulnerability")
	check(state.run["health"] < initial_health, "collision damage")
	check(state.nitro(), "nitro activation")
	check(not state.nitro(), "nitro cooldown")
	state.lane_change(-10)
	check(state.run["lane"] == 0, "lane lower bound")
	state.lane_change(10)
	check(state.run["lane"] == 2, "lane upper bound")
	state.run["time"] = 0
	check(state.outcome() == "timeout", "deadline enforced")
	state.settle("timeout")

	for entry in Catalog.events():
		for option in entry["choices"]:
			for effect in [option["effect"], option["failure"]]:
				state.start_order(2)
				state.apply_effect(effect)
				check(SaveStore.valid(state.profile), "event preserves save schema: " + entry["id"])
				state.settle("lost")
	state.start_order(2)
	state.run["current_event"] = Catalog.events()[0]
	var time_before = state.run["time"]
	state.tick(10)
	check(state.run["time"] == time_before, "decision pauses timer")
	check(state.resolve_choice(0), "event selection")
	check(state.run["time"] == time_before - 12, "police stop consumes time")
	check(state.run["current_event"].is_empty(), "decision consumed")
	check(not state.resolve_choice(0), "cannot resolve twice")
	state.settle("lost")
	state.start_order(2)
	payout = state.run["order"]["pay"]
	state.apply_effect({"sell": 2.0, "rep": {"2": -12}})
	check(state.outcome() == "sold", "sale ends delivery")
	state.settle("sold")
	check(state.profile["shift"] == payout * 2, "sale multiplier")
	state.start_order(2)
	state.apply_effect({"item": true})
	check(state.run["items"].size() == 1, "pending item")
	state.settle("delivered")
	check(state.profile["items"].size() > 0, "successful delivery commits items")

	var storage = isolated("save")
	var data = SaveStore.fresh()
	data["bank"] = 123
	check(storage.write(data), "write save")
	check(storage.load_profile()["bank"] == 123, "read save")
	data["bank"] = 456
	check(storage.write(data), "rotate backup")
	var broken = FileAccess.open(storage.path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	check(storage.load_profile()["bank"] == 123, "recover backup")
	var invalid = data.duplicate(true)
	invalid["upgrades"]["bike"]["engine"] = "oops"
	check(not SaveStore.valid(invalid), "reject invalid nested level")
	invalid = data.duplicate(true)
	invalid["items"]["999:0"] = 1
	check(not SaveStore.valid(invalid), "reject invalid item")
	data["shift"] = 900
	data["streak"] = 4
	data["active_delivery"] = true
	storage.write(data)
	var restored = storage.load_profile()
	check(restored["bank"] == 456 and restored["shift"] == 0, "abandoned delivery loses shift")
	check(not restored["active_delivery"], "abandoned marker cleared")

	var failed = GameState.new(FailingStore.new(), 9)
	check(not failed.start_order(0), "cannot start when save fails")
	check(failed.run.is_empty() and not failed.profile["active_delivery"], "failed start rolls back marker")
	failed.profile["bank"] = 1000
	check(not failed.buy_upgrade("engine"), "failed purchase rejected")
	check(failed.profile["bank"] == 1000 and failed.levels()["engine"] == 1, "failed upgrade rolled back")
	check(not failed.select_vehicle("scooter"), "failed vehicle purchase rejected")
	check(failed.profile["vehicle"] == "bike" and failed.profile["bank"] == 1000, "failed vehicle purchase rolled back")
	failed.profile["shift"] = 100
	check(not failed.bank_shift(), "failed cashout rejected")
	check(failed.profile["bank"] == 1000 and failed.profile["shift"] == 100, "failed cashout preserves earnings")
	var settings_path = "user://test_preferences.cfg"
	paths.append(settings_path)
	clean(settings_path)
	var preferences = Preferences.new(settings_path)
	preferences.sound = false
	preferences.quality = "low"
	check(preferences.save(), "settings saved")
	var restored_preferences = Preferences.new(settings_path)
	check(not restored_preferences.sound and restored_preferences.quality == "low", "settings roundtrip")
	restored_preferences.sound = true
	restored_preferences.quality = "high"
	var app = load("res://main.tscn").instantiate()
	app.preferences = restored_preferences
	app.game = GameState.new(isolated("ui"), 987)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	await process_frame
	check(app.screen == "home", "main menu on launch")
	var start_button = app.ui.find_child("StartShift", true, false)
	check(start_button != null, "main CTA exists")
	print("LAYOUT: viewport=", root.get_visible_rect(), " start=", start_button.get_global_rect())
	check(root.get_visible_rect().encloses(start_button.get_global_rect()), "main CTA fits portrait screen")
	app.begin_shift()
	check(app.screen == "help", "first launch tutorial")
	app.complete_tutorial()
	check(app.screen == "orders", "tutorial leads to orders")
	check(Preferences.new(settings_path).tutorial_seen, "tutorial completion saved")
	app.show_garage()
	await process_frame
	check(app.screen == "garage", "garage screen")
	app.open_collection("garage")
	await process_frame
	check(app.screen == "collection", "collection screen")
	app.close_collection()
	check(app.screen == "garage", "collection returns correctly")
	app.show_orders()
	app.start_order(0)
	await process_frame
	check(app.screen == "ride", "ride screen")
	var rider_screen = app.city.camera.unproject_position(app.city.rider.global_position + Vector3(0, 1, 0))
	check(rider_screen.y < root.get_visible_rect().size.y - 185, "courier stays above touch panel")
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(100, 20)
	touch.pressed = true
	app.drive_input(touch)
	check(app.holding, "hold accelerates")
	var drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(160, 20)
	app.drive_input(drag)
	check(app.game.run["lane"] == 2, "swipe changes lane")
	touch.pressed = false
	app.drive_input(touch)
	check(not app.holding, "release stops acceleration")
	time_before = app.game.run["time"]
	app._process(0.2)
	check(absf(app.game.run["time"] - (time_before - 0.2)) < 0.0001, "slow frames preserve timer")
	app.pause_game()
	time_before = app.game.run["time"]
	app._process(0.05)
	check(app.game.run["time"] == time_before, "pause freezes simulation")
	app.resume_game()
	check(app.screen == "ride", "resume")
	app.game.run["current_event"] = Catalog.events()[0]
	app.show_event()
	app.pause_game()
	app.resume_game()
	check(app.screen == "event", "focus pause preserves decision")
	app.choose(0)
	check(app.screen == "ride", "decision returns to ride")
	app.pause_game()
	app.confirm_abandon()
	check(app.screen == "confirm_abandon", "abandon requires confirmation")
	app.return_to_pause()
	check(app.screen == "pause", "confirmation can be cancelled")
	app.finish("abandoned")
	check(app.screen == "result", "result screen")
	app.bank_and_garage()
	check(app.screen == "garage", "result cashout")
	app.show_home()
	app.show_settings()
	app.toggle_quality()
	check(app.city.quality == "low" and not app.city.sun.shadow_enabled, "low graphics disables shadows")
	app.toggle_sound()
	check(not Preferences.new(settings_path).sound, "sound toggle saved")
	app.queue_free()
	await process_frame
	await process_frame
	for path in paths:
		clean(path)
	if failures == 0:
		print("TESTS PASSED: %d checks" % checks)
	else:
		printerr("TESTS FAILED: %d / %d" % [failures, checks])
	quit(0 if failures == 0 else 1)
