extends Node3D
const Catalog = preload("res://data/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const City = preload("res://scripts/city.gd")

var game
var city
var ui: Control
var hud: Label
var meter: ProgressBar
var toast: Label
var toast_left = 0.0
var screen = "orders"
var previous_screen = "ride"
var holding = false
var pointer_id = -1
var origin = Vector2.ZERO
var hud_left = 0.0
var ready_done = false
var collection_origin = "orders"
var sound_on = true
var audio_player: AudioStreamPlayer
var audio_phase = 0.0

func _ready():
	# Tests inject an isolated save store before attaching this scene.
	if game == null:
		game = GameState.new()
	city = City.new()
	add_child(city)
	city.hit.connect(on_collision)
	city.set_vehicle(game.profile["vehicle"])
	build_ui()
	build_audio()
	show_orders()
	ready_done = true
	if game.last_message != "":
		notify(game.last_message)

func build_audio():
	audio_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.15
	audio_player.stream = generator
	audio_player.volume_db = -30
	add_child(audio_player)
	audio_player.play()

func tick_audio():
	var playback = audio_player.get_stream_playback()
	if playback == null:
		return
	var count = mini(playback.get_frames_available(), 3308)
	var frequency = 48.0 if game.profile["vehicle"] == "scooter" else 32.0
	for i in range(count):
		audio_phase = fmod(audio_phase + frequency / 22050.0, 1.0)
		var value = 0.0
		if sound_on and screen == "ride":
			value = sin(audio_phase * TAU) * 0.12
			value += sin(audio_phase * TAU * 2.0) * 0.03
		playback.push_frame(Vector2(value, value))

func build_ui():
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font_size = 16
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#142438")
	normal.border_color = Color("#2c5466")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	theme.set_stylebox("normal", "Button", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("#245267")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	var disabled = normal.duplicate()
	disabled.bg_color = Color("#101927")
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", Color("#e6fff9"))
	theme.set_color("font_disabled_color", "Button", Color("#65758c"))
	ui.theme = theme
	toast = Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.offset_left = -194
	toast.offset_right = 194
	toast.offset_top = -40
	toast.offset_bottom = 40
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_color_override("font_color", Color("#ffd68a"))
	toast.add_theme_color_override("font_outline_color", Color("#050914"))
	toast.add_theme_constant_override("outline_size", 8)
	toast.hide()
	layer.add_child(toast)

func clear_ui():
	holding = false
	pointer_id = -1
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func panel(title, subtitle = ""):
	clear_ui()
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.055, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	ui.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	text_label(box, "N I G H T   C O U R I E R", 13, Color("#40f6d2"))
	text_label(box, title, 29)
	if subtitle != "":
		text_label(box, subtitle, 15, Color("#a6b9cf"))
	if game.store.last_error != "":
		text_label(box, game.store.last_error, 14, Color("#ff917e"))
	return box

func text_label(parent, value, size = 16, color = Color("#edf4ff")):
	var node = Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent, value, callback, disabled = false):
	var node = Button.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.y = 54
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.disabled = disabled
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func money(value):
	return "$%d" % int(value)

func balances():
	return "Банк %s   ·   Смена %s\n%s · доставок %d" % [
		money(game.profile["bank"]), money(game.profile["shift"]),
		game.vehicle()["name"], int(game.profile["delivered"])
	]

func notify(value):
	toast.text = value
	toast_left = 3.0
	toast.show()

func show_orders():
	screen = "orders"
	var box = panel("Ночной Курьер", balances())
	text_label(box, "01 / СПАЛЬНЫЙ РАЙОН", 14, Color("#40f6d2"))
	text_label(box, "Ещё один заказ — и выхожу.", 20)
	text_label(box, "При провале потеряешь %s за смену.\nБанк защищён · бонус серии +%d%%."
		% [money(game.profile["shift"]), int(game.profile["streak"]) * 12], 14)
	for index in range(game.offers.size()):
		var order = game.offers[index]
		var description = "%s  ·  %s\n%.2f км · риск %d%% · %d с\n%s" % [
			order["name"], money(order["pay"]), order["distance"],
			order["risk"], order["limit"], Catalog.DISTRICTS[order["district"]]["name"]
		]
		button(box, description, start_order.bind(index))
	button(box, "В гараж · сохранить заработок", bank_and_garage)
	button(box, "Коллекция и репутация", open_collection.bind("orders"))
	text_label(box, "Риск — частота событий, не вероятность провала.\nЗакрытие игры в поездке завершает смену без заработка.", 13)

func bank_and_garage():
	game.bank_shift()
	show_garage()

func show_garage():
	screen = "garage"
	var box = panel("Гараж", balances())
	text_label(box, "Покупки оплачиваются из банка.", 14)
	for id in Catalog.VEHICLES:
		var v = Catalog.VEHICLES[id]
		var owned = game.profile["owned"].has(id)
		var description = v["name"]
		if game.profile["vehicle"] == id:
			description += " · выбран"
		elif owned:
			description += " · выбрать"
		else:
			description += " · " + money(v["price"])
		text_label(box, "Скорость %.0f · управление %.1f · прочность %.0f\nВместимость %d · заметность %d%%" % [
			v["speed"], v["handling"], v["durability"], v["capacity"], int(v["visibility"] * 100)
		], 14)
		button(box, description, select_vehicle.bind(id), not owned and game.profile["bank"] < v["price"])
	text_label(box, "Улучшения транспорта", 20)
	for key in Catalog.UPGRADES:
		var level = int(game.levels()[key])
		var cost = game.upgrade_cost(key)
		var description = "%s · Lv.%d" % [Catalog.UPGRADES[key], level]
		description += " · MAX" if level >= 10 else " → %d · %s" % [level + 1, money(cost)]
		button(box, description, upgrade.bind(key), level >= 10 or game.profile["bank"] < cost)
	text_label(box, "Привод: +5% скорости/уровень.\nШины: быстрее перестроение и меньше урон.\nЗащита: +12 прочности/уровень.\nНитро: дольше рывок и быстрее перезарядка.", 14)
	button(box, "Выйти на смену", show_orders)
	button(box, "Коллекция и репутация", open_collection.bind("garage"))
	button(box, "Звук: " + ("включён" if sound_on else "выключен"), toggle_sound)
	text_label(box, "MVP 0.1 · один район\nГаражи, наём и другие районы — следующий этап.", 13)

func toggle_sound():
	sound_on = not sound_on
	show_garage()

func select_vehicle(id):
	if game.select_vehicle(id):
		city.set_vehicle(id)
	show_garage()

func upgrade(key):
	game.buy_upgrade(key)
	show_garage()

func open_collection(from_screen):
	collection_origin = from_screen
	show_collection()

func item_name(key):
	var parts = key.split(":")
	return Catalog.ITEMS[int(parts[0])] + " · " + Catalog.RARITIES[int(parts[1])]

func show_collection():
	screen = "collection"
	var box = panel("Находки ночи", "Собрано %d / 35 вариантов" % game.profile["items"].size())
	for index in range(Catalog.FACTIONS.size()):
		text_label(box, "%s: %+d" % [Catalog.FACTIONS[index], int(game.profile["rep"][index])], 15)
	text_label(box, "Курьеры +20: чаще находки.\nБизнес: влияет на оплату заказов.\nПолиция ниже 0: проверки чаще.\nГруппировки +20: нет попыток кражи.\nОрганизация +20: чаще редкие предметы.", 14)
	for rarity in range(Catalog.RARITIES.size()):
		text_label(box, Catalog.RARITIES[rarity], 21, Catalog.COLORS[rarity])
		for index in range(Catalog.ITEMS.size()):
			var key = "%d:%d" % [index, rarity]
			var amount = int(game.profile["items"].get(key, 0))
			var description = "%s ×%d" % [Catalog.ITEMS[index], amount] if amount > 0 else "○ " + Catalog.ITEMS[index]
			text_label(box, description, 15, Catalog.COLORS[rarity] if amount > 0 else Color("#65788f"))
	button(box, "Назад", close_collection)

func close_collection():
	if collection_origin == "garage":
		show_garage()
	else:
		show_orders()

func start_order(index):
	if game.start_order(index):
		city.start(game.profile["vehicle"])
		show_ride()
		notify("Свайп по нижней панели: сменить полосу.\nУдержание: ускориться.")

func show_ride():
	screen = "ride"
	clear_ui()
	var top = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 40
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	hud = text_label(top, "", 17)
	hud.add_theme_constant_override("outline_size", 6)
	hud.add_theme_color_override("font_outline_color", Color("#050914"))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(meter)
	var bottom = VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -180
	bottom.offset_bottom = -30
	bottom.add_theme_constant_override("separation", 8)
	ui.add_child(bottom)
	var row = HBoxContainer.new()
	bottom.add_child(row)
	button(row, "Пауза", pause_game)
	button(row, "Нитро", activate_nitro)
	var pad = PanelContainer.new()
	pad.custom_minimum_size.y = 80
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.10, 0.15, 0.92)
	style.border_color = Color("#40f6d2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	pad.add_theme_stylebox_override("panel", style)
	var hint = text_label(pad, "←  Свайп: перестроение  →\nУдерживай: ускорение", 17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.gui_input.connect(drive_input)
	bottom.add_child(pad)
	update_hud()

func drive_input(event):
	if screen != "ride":
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -1:
			pointer_id = event.index
			origin = event.position
			holding = true
		elif not event.pressed and event.index == pointer_id:
			holding = false
			pointer_id = -1
	elif event is InputEventScreenDrag and event.index == pointer_id:
		var delta_x = event.position.x - origin.x
		if absf(delta_x) >= 35:
			game.lane_change(1 if delta_x > 0 else -1)
			origin = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding = event.pressed
		origin = event.position
	elif event is InputEventMouseMotion and holding:
		var delta_x = event.position.x - origin.x
		if absf(delta_x) >= 35:
			game.lane_change(1 if delta_x > 0 else -1)
			origin = event.position

func _input(event):
	if event is InputEventScreenTouch and not event.pressed and event.index == pointer_id:
		holding = false
		pointer_id = -1
	if event is InputEventMouseButton and not event.pressed:
		holding = false
	if screen != "ride":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				game.lane_change(-1)
			KEY_RIGHT, KEY_D:
				game.lane_change(1)
			KEY_SPACE:
				activate_nitro()
			KEY_ESCAPE:
				pause_game()

func activate_nitro():
	if screen == "ride" and game.nitro():
		notify("Рывок!")

func pause_game():
	if screen not in ["ride", "event"]:
		return
	previous_screen = screen
	screen = "pause"
	var box = panel("Пауза", "Поездка и таймер остановлены.")
	button(box, "Продолжить", resume_game)
	button(box, "Бросить заказ\nПотерять заработок смены", finish.bind("abandoned"))

func resume_game():
	if previous_screen == "event":
		show_event()
	else:
		show_ride()

func _notification(what):
	if not ready_done:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "ride" or screen == "event":
			pause_game()
		elif screen == "collection":
			close_collection()
		elif screen == "garage":
			show_orders()

func update_hud():
	if screen != "ride" or game.run.is_empty():
		return
	var run = game.run
	hud.text = "%s · %s\n%.2f км · %d с · прочность %d%%\nНитро: %s" % [
		run["order"]["name"], money(run["order"]["pay"]), maxf(0, run["distance"]),
		maxi(0, int(ceil(run["time"]))), maxi(0, int(100 * run["health"] / run["max_health"])),
		"готово" if game.nitro_cooldown <= 0 else "%d с" % int(ceil(game.nitro_cooldown))
	]
	meter.value = clampf(100 * (1 - run["distance"] / run["initial"]), 0, 100)

func on_collision():
	if screen == "ride" and game.collision():
		notify("Столкновение! Прочность снижена.")

func show_event():
	screen = "event"
	var entry = game.run["current_event"]
	var box = panel(entry["title"], entry["description"])
	text_label(box, "Таймер остановлен на время решения.", 14)
	text_label(box, "Под риском: " + money(game.profile["shift"]), 19)
	for index in range(entry["choices"].size()):
		button(box, entry["choices"][index]["title"], choose.bind(index))

func choose(index):
	if screen != "event":
		return
	game.resolve_choice(index)
	var result = game.outcome()
	if result != "":
		finish(result)
	else:
		show_ride()
		notify(game.last_message)

func finish(reason):
	var result = game.settle(reason)
	if result.is_empty():
		return
	city.stop()
	screen = "result"
	var reasons = {
		"delivered": "Клиент получил заказ.", "sold": "Груз продан. Репутация изменилась.",
		"lost": "Заказ потерян или транспорт сломан.", "timeout": "Время доставки истекло.",
		"abandoned": "Заказ отменён."
	}
	var box = panel("Доставлено" if result["success"] else "Смена окончена", reasons.get(reason, reason))
	text_label(box, "+" + money(result["gain"]) if result["success"] else "Заработок смены потерян", 27)
	text_label(box, balances())
	for key in result["found"]:
		text_label(box, "Найдено: " + item_name(key), 17, Color("#ffc964"))
	if result["success"]:
		text_label(box, "Серия повышает оплату и даёт до +20% скорости.\nВозвращение в гараж сбрасывает бонус серии.", 15)
	button(box, "Ещё один заказ", show_orders)
	button(box, "В гараж · забрать деньги", bank_and_garage)

func _process(delta):
	if not ready_done:
		return
	delta = minf(delta, 0.05)
	tick_audio()
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0:
			toast.hide()
	if screen == "ride":
		var boost = holding or Input.is_physical_key_pressed(KEY_UP)
		var speed_value = game.speed(boost)
		game.tick(delta, boost)
		city.tick(delta, speed_value, game.run["lane"], game.vehicle()["handling"] + (game.levels()["tires"] - 1) * 0.7)
		var result = game.outcome()
		if result != "":
			finish(result)
			return
		if not game.maybe_event().is_empty():
			show_event()
			return
		hud_left -= delta
		if hud_left <= 0:
			hud_left = 0.1
			update_hud()
	elif screen not in ["pause", "event"]:
		city.tick(delta)
