extends RefCounted
const SaveStore = preload("res://scripts/save_store.gd")
var last_error = ""
func load_profile():
	return SaveStore.fresh()
func write(_data):
	last_error = "Simulated disk failure"
	return false
