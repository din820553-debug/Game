extends RefCounted
const Catalog = preload("res://data/catalog.gd")
var path = "user://night_courier_v1.json"
var last_error = ""

func _init(custom_path = "user://night_courier_v1.json"):
	path = custom_path

static func fresh():
	var levels = {}
	for id in Catalog.VEHICLES:
		levels[id] = {"engine": 1, "tires": 1, "armor": 1, "nitro": 1}
	return {
		"version": 1, "bank": 25, "shift": 0, "streak": 0, "delivered": 0,
		"vehicle": "bike", "owned": ["bike"], "upgrades": levels,
		"rep": [0, 0, 0, 0, 0], "items": {}, "active_delivery": false
	}

static func integer_in(value, low, high):
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value == floor(value) and value >= low and value <= high

static func valid(data):
	if not data is Dictionary:
		return false
	if data.get("version", 0) != 1:
		return false
	for key in ["bank", "shift", "delivered"]:
		if not integer_in(data.get(key), 0, 1000000000):
			return false
	if not integer_in(data.get("streak"), 0, 10):
		return false
	if not data.get("active_delivery") is bool:
		return false
	if not data.get("vehicle") is String or not Catalog.VEHICLES.has(data["vehicle"]):
		return false
	if not data.get("owned") is Array or not data["owned"].has("bike"):
		return false
	for id in data["owned"]:
		if not id is String or not Catalog.VEHICLES.has(id):
			return false
	if not data["owned"].has(data["vehicle"]):
		return false
	if not data.get("upgrades") is Dictionary:
		return false
	for id in Catalog.VEHICLES:
		if not data["upgrades"].get(id) is Dictionary:
			return false
		for key in Catalog.UPGRADES:
			if not integer_in(data["upgrades"][id].get(key), 1, 10):
				return false
	if not data.get("rep") is Array or data["rep"].size() != 5:
		return false
	for value in data["rep"]:
		if not integer_in(value, -100, 100):
			return false
	if not data.get("items") is Dictionary:
		return false
	for key in data["items"]:
		if not key is String:
			return false
		var parts = key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return false
		if int(parts[0]) < 0 or int(parts[0]) >= Catalog.ITEMS.size():
			return false
		if int(parts[1]) < 0 or int(parts[1]) >= Catalog.RARITIES.size():
			return false
		if not integer_in(data["items"][key], 1, 1000000000):
			return false
	return true

func read_file(file_path):
	if not FileAccess.file_exists(file_path):
		return null
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func load_profile():
	last_error = ""
	for candidate in [path, path + ".bak"]:
		var data = read_file(candidate)
		if valid(data):
			if data["active_delivery"]:
				data["shift"] = 0
				data["streak"] = 0
				data["active_delivery"] = false
				write(data)
			return data
	if FileAccess.file_exists(path):
		last_error = "Сохранение повреждено. Начата новая игра."
	return fresh()

func write(data):
	last_error = ""
	if not valid(data):
		last_error = "Некорректные данные сохранения."
		return false
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failed()
	file.store_string(JSON.stringify(data))
	file.flush()
	var result = file.get_error()
	file.close()
	if result != OK:
		return failed()
	var target = ProjectSettings.globalize_path(path)
	var backup = target + ".bak"
	var source = ProjectSettings.globalize_path(temporary)
	# Never replace a valid backup with a corrupt primary save.
	if valid(read_file(path)):
		if FileAccess.file_exists(path + ".bak"):
			if DirAccess.remove_absolute(backup) != OK:
				return failed()
		if DirAccess.rename_absolute(target, backup) != OK:
			return failed()
	elif FileAccess.file_exists(path):
		if DirAccess.remove_absolute(target) != OK:
			return failed()
	if DirAccess.rename_absolute(source, target) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.copy_absolute(backup, target)
		return failed()
	return true

func failed():
	last_error = "Не удалось сохранить прогресс. Проверьте свободное место."
	return false
