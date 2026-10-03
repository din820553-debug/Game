extends RefCounted
const Catalog = preload("res://data/catalog.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var rng = RandomNumberGenerator.new()
var store
var profile = {}
var offers = []
var run = {}
var events = Catalog.events()
var last_message = ""
var nitro_left = 0.0
var nitro_cooldown = 0.0

func _init(custom_store = null, seed_value = -1):
	store = custom_store if custom_store != null else SaveStore.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	profile = store.load_profile()
	last_message = store.last_error
	generate_offers()

func save():
	if not store.write(profile):
		last_message = store.last_error
		return false
	return true

func vehicle():
	return Catalog.VEHICLES[profile["vehicle"]]

func levels():
	return profile["upgrades"][profile["vehicle"]]

func pick(values):
	return values[rng.randi_range(0, values.size() - 1)]

func generate_offers():
	offers.clear()
	var pools = [[], [], []]
	for row in Catalog.ORDERS:
		if row[4] > vehicle()["capacity"]:
			continue
		var tier = 0 if row[3] < 15 else (1 if row[3] < 45 else 2)
		pools[tier].append(row)
	for pool in pools:
		var row = pick(pool)
		var distance = snappedf(rng.randf_range(0.95, 1.65), 0.01)
		var bonus = (1 + profile["rep"][2] * 0.002) * (1 + profile["streak"] * 0.12)
		offers.append({
			"id": row[0], "name": row[1], "pay": maxi(1, int(row[2] * bonus)),
			"risk": row[3], "size": row[4], "distance": distance,
			"limit": int(distance / 0.010 + 40), "district": "suburb"
		})

func start_order(index):
	if not run.is_empty() or index < 0 or index >= offers.size():
		return false
	var order = offers[index].duplicate(true)
	var health = vehicle()["durability"] + (levels()["armor"] - 1) * 12
	run = {
		"order": order, "distance": order["distance"], "initial": order["distance"],
		"time": float(order["limit"]), "health": health, "max_health": health,
		"lane": 1, "elapsed": 0.0, "next_event": rng.randf_range(18, 25),
		"event_count": 0, "used_events": [], "current_event": {},
		"invincible": 0.0, "failed": false, "sold": 0.0, "items": []
	}
	nitro_left = 0
	nitro_cooldown = 0
	profile["active_delivery"] = true
	if not save():
		profile["active_delivery"] = false
		run.clear()
		return false
	return true

func speed(boost = false):
	var value = vehicle()["speed"] * (1 + (levels()["engine"] - 1) * 0.05)
	value *= 1 + minf(0.20, profile["streak"] * 0.02)
	if boost:
		value *= 1.25
	if nitro_left > 0:
		value *= 1.65
	return value

func tick(delta, boost = false):
	if run.is_empty() or not run["current_event"].is_empty():
		return
	var current_speed = speed(boost)
	nitro_left = maxf(0, nitro_left - delta)
	nitro_cooldown = maxf(0, nitro_cooldown - delta)
	run["time"] -= delta
	run["elapsed"] += delta
	run["distance"] -= current_speed * delta * 0.001
	run["invincible"] = maxf(0, run["invincible"] - delta)

func lane_change(direction):
	if not run.is_empty():
		run["lane"] = clampi(int(run["lane"]) + direction, 0, 2)

func nitro():
	if run.is_empty() or nitro_cooldown > 0 or not run["current_event"].is_empty():
		return false
	nitro_left = 1.5 + levels()["nitro"] * 0.25
	nitro_cooldown = 15 - levels()["nitro"] * 0.5
	return true

func damage(amount):
	if not run.is_empty():
		run["health"] -= amount * (1 - (levels()["tires"] - 1) * 0.035)

func collision():
	if not run.is_empty() and run["invincible"] <= 0:
		damage(24)
		run["invincible"] = 1.2
		return true
	return false

func outcome():
	if run.is_empty():
		return ""
	if run["failed"] or run["health"] <= 0:
		return "lost"
	if run["time"] <= 0:
		return "timeout"
	if run["sold"] > 0:
		return "sold"
	if run["distance"] <= 0:
		return "delivered"
	return ""

func maybe_event():
	if run.is_empty() or not run["current_event"].is_empty():
		return {}
	if run["event_count"] >= 4 or run["elapsed"] < run["next_event"]:
		return {}
	run["event_count"] += 1
	run["next_event"] += rng.randf_range(20, 30)
	var risk = run["order"]["risk"]
	var probability = risk / 100.0 + maxf(0, -profile["rep"][1]) * 0.002
	if rng.randf() >= minf(0.98, probability):
		return {}
	var pool = []
	for entry in events:
		if entry["min_risk"] > risk or run["used_events"].has(entry["id"]):
			continue
		if entry["id"] == "thief" and profile["rep"][3] >= 20:
			continue
		pool.append(entry)
		if entry["id"] == "police":
			var extra = int(maxf(0, -profile["rep"][1]) / 15 + vehicle()["visibility"] * 3)
			for i in range(extra):
				pool.append(entry)
	if pool.is_empty():
		return {}
	var selected = pick(pool)
	run["used_events"].append(selected["id"])
	run["current_event"] = selected
	return selected

func resolve_choice(index):
	if run.is_empty() or run["current_event"].is_empty():
		return false
	var choices = run["current_event"]["choices"]
	if index < 0 or index >= choices.size():
		return false
	var selected = choices[index]
	var success = rng.randf() < selected["chance"]
	apply_effect(selected["effect"] if success else selected["failure"])
	run["current_event"] = {}
	last_message = "Получилось." if success else "Не повезло. Последствия применены."
	save()
	return true

func apply_effect(effect):
	for key in effect.get("rep", {}):
		change_rep(int(key), effect["rep"][key])
	run["time"] += effect.get("time", 0)
	run["distance"] = maxf(0, run["distance"] + effect.get("distance", 0))
	run["initial"] += maxf(0, effect.get("distance", 0))
	if effect.has("damage"):
		damage(effect["damage"])
	if effect.has("pay"):
		run["order"]["pay"] = int(run["order"]["pay"] * effect["pay"])
	if effect.get("item", false):
		run["items"].append(roll_item())
	run["failed"] = effect.get("fail", false)
	run["sold"] = effect.get("sell", 0.0)

func change_rep(index, amount):
	profile["rep"][index] = clampi(int(profile["rep"][index]) + int(amount), -100, 100)

func roll_item():
	var roll = rng.randf()
	if profile["rep"][4] >= 20:
		roll = minf(0.9999, roll + 0.025)
	var rarity = 0
	if roll > 0.995:
		rarity = 4
	elif roll > 0.97:
		rarity = 3
	elif roll > 0.86:
		rarity = 2
	elif roll > 0.60:
		rarity = 1
	return "%d:%d" % [rng.randi_range(0, Catalog.ITEMS.size() - 1), rarity]

func settle(reason):
	if run.is_empty():
		return {}
	var success = reason in ["delivered", "sold"]
	var gain = 0
	var found = []
	if success:
		var multiplier = run["sold"] if reason == "sold" else 1.0
		gain = int(run["order"]["pay"] * multiplier)
		profile["shift"] += gain
		profile["streak"] = mini(10, int(profile["streak"]) + 1)
		profile["delivered"] += 1
		change_rep(0, 1)
		if reason == "delivered":
			change_rep(2, 2)
		var chance = 0.12 + run["order"]["risk"] * 0.003
		if profile["rep"][0] >= 20:
			chance += 0.12
		if rng.randf() < chance:
			run["items"].append(roll_item())
		found = run["items"].duplicate()
		for key in found:
			profile["items"][key] = int(profile["items"].get(key, 0)) + 1
	else:
		profile["shift"] = 0
		profile["streak"] = 0
		change_rep(2, -4)
	profile["active_delivery"] = false
	run.clear()
	save()
	generate_offers()
	return {"success": success, "gain": gain, "found": found, "reason": reason}

func bank_shift():
	if not run.is_empty():
		return false
	var changed = profile["shift"] > 0 or profile["streak"] > 0
	if not changed:
		return true
	var before = profile.duplicate(true)
	profile["bank"] += profile["shift"]
	profile["shift"] = 0
	profile["streak"] = 0
	if not save():
		profile = before
		return false
	generate_offers()
	return true

func select_vehicle(id):
	if not run.is_empty() or not Catalog.VEHICLES.has(id):
		return false
	var before = profile.duplicate(true)
	if not profile["owned"].has(id):
		var cost = Catalog.VEHICLES[id]["price"]
		if profile["bank"] < cost:
			return false
		profile["bank"] -= cost
		profile["owned"].append(id)
	profile["vehicle"] = id
	if not save():
		profile = before
		return false
	return true

func upgrade_cost(key):
	return 60 * int(levels()[key]) * int(levels()[key])

func buy_upgrade(key):
	if not run.is_empty() or not Catalog.UPGRADES.has(key):
		return false
	var cost = upgrade_cost(key)
	if levels()[key] >= 10 or profile["bank"] < cost:
		return false
	var before = profile.duplicate(true)
	profile["bank"] -= cost
	levels()[key] += 1
	if not save():
		profile = before
		return false
	return true
