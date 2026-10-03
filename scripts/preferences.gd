extends RefCounted
const PATH = "user://preferences.cfg"
var sound = true
var quality = "high"
var tutorial_seen = false
var last_error = ""
var file_path = PATH

func _init(path = PATH):
	file_path = path
	var config = ConfigFile.new()
	if config.load(path) == OK:
		sound = config.get_value("player", "sound", true) == true
		quality = str(config.get_value("player", "quality", "high"))
		if quality not in ["high", "low"]:
			quality = "high"
		tutorial_seen = config.get_value("player", "tutorial_seen", false) == true

func save():
	var config = ConfigFile.new()
	config.set_value("player", "sound", sound)
	config.set_value("player", "quality", quality)
	config.set_value("player", "tutorial_seen", tutorial_seen)
	var ok = config.save(file_path) == OK
	last_error = "" if ok else "Не удалось сохранить настройки."
	return ok
