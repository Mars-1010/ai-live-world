extends Node2D
## All motion and effects are presentation only. Stats are backend snapshots.

const CAT = preload("res://assets/cat.svg")
const INK = Color("34483f")
const MUTED = Color("768578")
const EFFECT_LABELS = {
	"food_drop": ["FOOD DELIVERY!", "A little snack, a happier cat.", Color("537c48")],
	"rain": ["HERE COMES THE RAIN", "The world outside has changed.", Color("48748b")],
	"meteor_strike": ["METEOR STRIKE!", "Impact detected. The power is out.", Color("ae5d43")],
}
var snapshot: Dictionary = {}
var online: bool = false
var status: String = "Connecting to the world..."
var time: float = 0.0
var cat_position := Vector2(420, 470)
var previous_action: String = ""
var action_time: float = 0.0
var effect_queue: Array = []
var active_effect: Dictionary = {}
var effect_time: float = 0.0
var history: Array = []

func update_state(state: Dictionary) -> void:
	snapshot = state.duplicate(true)
	if snapshot.cat.action != previous_action:
		previous_action = snapshot.cat.action
		action_time = 0.0
	queue_redraw()

func receive_events(events: Array, historical: bool) -> void:
	for event in events:
		history.append(event.duplicate(true))
		if history.size() > 4:
			history.pop_front()
		if not historical and event.type == "gift":
			effect_queue.append(event.duplicate(true))
	queue_redraw()

func update_connection(connected: bool, message: String) -> void:
	online = connected
	status = message
	queue_redraw()

func reset_session() -> void:
	snapshot = {}
	history.clear()
	effect_queue.clear()
	active_effect = {}
	effect_time = 0.0
	previous_action = ""
	cat_position = Vector2(420, 470)
	online = false
	status = "Syncing session..."

func _process(delta: float) -> void:
	time += delta
	action_time += delta
	effect_time = maxf(0.0, effect_time - delta)
	if effect_time <= 0.0:
		active_effect = {}
		if not effect_queue.is_empty():
			active_effect = effect_queue.pop_front()
			effect_time = 2.4
	var action: String = snapshot.get("cat", {}).get("action", "idle")
	cat_position = cat_position.lerp(action_target(action, action_time), minf(delta * 5.0, 1.0))
	queue_redraw()

static func action_target(action: String, elapsed: float) -> Vector2:
	match action:
		"walk": return Vector2(440 + sin(elapsed * 1.3) * 180, 470)
		"eat": return Vector2(580, 490)
		"sleep": return Vector2(160, 489)
		"work": return Vector2(777, 435)
		"explore": return Vector2(445 + sin(elapsed * 0.65) * 225, 463 + cos(elapsed * 1.3) * 44)
		_: return Vector2(420, 470)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("f1f2e9"))
	_text(Vector2(32, 32), "AI LIVE WORLD   /   AUDIENCE-POWERED", 12, MUTED)
	_text(Vector2(32, 75), "A small room. A world of possibilities.", 30, INK)
	_text(Vector2(33, 103), "One cat. Your comments. Real consequences.", 15, MUTED)
	draw_circle(Vector2(990, 48), 5, Color("6b9560") if online else Color("b67f4e"))
	_text(Vector2(1006, 53), "LIVE CONNECTION" if online else "RECONNECTING", 13, INK)
	_text(Vector2(968, 81), status, 12, MUTED, 280)
	var shake := Vector2.ZERO
	if active_effect.get("effect") == "meteor_strike" and effect_time > 1.4:
		shake = Vector2(sin(time * 70) * 5, cos(time * 83) * 3)
	draw_set_transform(shake)
	_draw_room()
	_draw_cat()
	_draw_effect()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	_text(Vector2(34, 645), "BACKEND", 11, MUTED)
	_text(Vector2(34, 707), "Change the world from the browser control panel. This window only reads backend state.", 12, MUTED)

func _draw_room() -> void:
	var world: Dictionary = snapshot.get("world", {})
	var raining: bool = world.get("weather", "clear") == "rain"
	var powered: bool = world.get("power", true)
	_box(Rect2(30, 126, 916, 490), Color("e7e7d5"), 18)
	draw_rect(Rect2(31, 389, 914, 210), Color("d3b99a"))
	for y in range(408, 600, 43):
		draw_line(Vector2(32, y), Vector2(944, y), Color("c4a88b"), 2)
	for x in range(70, 944, 130):
		draw_line(Vector2(x, 409), Vector2(x, 451), Color("c4a88b"), 2)
		draw_line(Vector2(x + 55, 495), Vector2(x + 55, 537), Color("c4a88b"), 2)
	draw_rect(Rect2(31, 380, 914, 12), Color("aa9274"))
	# Window: persistent weather comes from /state, even after a reconnect.
	_box(Rect2(84, 165, 264, 194), Color("ab977b"), 12)
	_box(Rect2(96, 177, 240, 170), Color("8ca7b2") if raining else Color("c3dddf"), 5)
	draw_circle(Vector2(280, 217), 23, Color("d6dbe0") if raining else Color("f8dfa1"))
	for i in range(5):
		draw_circle(Vector2(123 + i * 53, 330), 38, Color("738f70"))
	if raining:
		for i in range(26):
			var x := 107.0 + fmod(i * 43.0, 217.0)
			var y := 179.0 + fmod(time * 165.0 + i * 29.0, 151.0)
			draw_line(Vector2(x, y), Vector2(x - 5, y + 12), Color("d4e8f1"), 2)
	draw_line(Vector2(216, 176), Vector2(216, 348), Color("f2e9d7"), 7)
	draw_line(Vector2(94, 262), Vector2(338, 262), Color("f2e9d7"), 7)
	_box(Rect2(74, 350, 286, 14), Color("aa9274"), 4)
	# Rug, bed, feeding bowl, work desk and plant are original vector shapes.
	_box(Rect2(285, 441, 385, 127), Color("b3bd97"), 60)
	_box(Rect2(305, 455, 345, 98), Color("c6cdad"), 48)
	_box(Rect2(65, 490, 195, 69), Color("9c9f8c"), 27)
	_box(Rect2(76, 479, 175, 55), Color("c5c5ad"), 23)
	_box(Rect2(87, 482, 66, 32), Color("ece6d1"), 15)
	_box(Rect2(745, 439, 157, 14), Color("93765e"), 4)
	draw_rect(Rect2(754, 452, 9, 64), Color("93765e"))
	draw_rect(Rect2(884, 452, 9, 64), Color("93765e"))
	_box(Rect2(807, 395, 65, 42), Color("455b51"), 5)
	_box(Rect2(813, 401, 53, 29), Color("c6d9ad") if powered else Color("37473d"), 2)
	draw_line(Vector2(801, 438), Vector2(879, 438), Color("455b51"), 4)
	_box(Rect2(817, 329, 36, 44), Color("b1856a"), 7)
	for i in range(4):
		draw_line(Vector2(836, 335), Vector2(815 + i * 13, 291 + (i % 2) * 17), Color("6b885e"), 5)
		draw_circle(Vector2(815 + i * 13, 291 + (i % 2) * 17), 11, Color("849b6c"))
	draw_rect(Rect2(778, 370, 100, 9), Color("aa9274"))
	_box(Rect2(608, 529, 69, 26), Color("b9775a"), 12)
	_box(Rect2(611, 528, 63, 10), Color("eee0ba"), 5)
	# Lamp and persistent impact crater make a power outage legible.
	draw_line(Vector2(559, 127), Vector2(559, 190), Color("9c927a"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(526, 216), Vector2(544, 183), Vector2(574, 183), Vector2(592, 216)]), Color("bd9d63"))
	if powered:
		draw_circle(Vector2(559, 218), 9, Color("ffe9b1"))
	if "meteor_strike" in world.get("hazards", []):
		_box(Rect2(701, 540, 157, 40), Color("776655"), 20)
		draw_colored_polygon(PackedVector2Array([Vector2(726, 548), Vector2(745, 510), Vector2(778, 495), Vector2(811, 525), Vector2(804, 552)]), Color("676762"))
		draw_line(Vector2(768, 516), Vector2(786, 541), Color("da9b65"), 4)
	if not powered:
		draw_rect(Rect2(31, 127, 914, 473), Color(0.15, 0.20, 0.28, 0.37))
		_box(Rect2(689, 144, 235, 38), Color("48505b"), 10)
		_text(Vector2(705, 169), "POWER OUT  /  METEOR HAZARD", 13, Color("ffe0b2"))
	_text(Vector2(54, 594), "THE APARTMENT", 11, Color("695c4b"))
	_text(Vector2(711, 594), "RAINY" if raining else "CLEAR SKIES", 11, Color("695c4b"))

func _draw_cat() -> void:
	var action: String = snapshot.get("cat", {}).get("action", "idle")
	var bob := sin(action_time * 2.0) * 2
	var scale := Vector2(0.79, 0.79)
	var rotation := 0.0
	match action:
		"walk", "explore":
			bob = abs(sin(action_time * 9)) * -8
			scale.x *= 1.0 if cos(action_time * (1.3 if action == "walk" else 0.65)) >= 0 else -1.0
		"eat":
			rotation = sin(action_time * 8) * 0.075
			bob = sin(action_time * 8) * 4
		"sleep":
			scale = Vector2(0.85, 0.53 + sin(action_time * 2) * 0.015)
			rotation = -0.12
		"work":
			bob = sin(action_time * 12) * 2
	draw_set_transform(cat_position + Vector2(0, bob), rotation, scale)
	draw_texture_rect(CAT, Rect2(-90, -135, 180, 170), false)
	draw_set_transform(Vector2.ZERO)
	match action:
		"sleep":
			_text(cat_position + Vector2(42, -70 - fmod(action_time * 12, 25)), "Z z z", 24, Color("687c87"))
		"eat":
			for i in range(4):
				draw_circle(Vector2(620 + i * 10, 522 - abs(sin(action_time * 7 + i)) * 17), 3, Color("d8a457"))
		"work":
			_text(Vector2(818, 421), "..." if int(action_time * 3) % 2 else "|||", 14, Color("365343"))
			_text(cat_position + Vector2(-25, -123), "tap tap", 15, INK)
		"explore":
			_text(cat_position + Vector2(36, -115), "?", 32, Color("9a8251"))
			for i in range(3):
				draw_circle(cat_position + Vector2(-55 - i * 16, 33), 3, Color("a69c7d"))
	if snapshot.is_empty():
		_box(Rect2(300, 284, 390, 61), Color("fffaf0"), 12)
		_text(Vector2(322, 320), "Waiting for the backend world...", 21, INK)

func _draw_effect() -> void:
	if active_effect.is_empty():
		return
	var effect: String = active_effect.effect
	if effect == "food_drop":
		var drop_y := lerpf(215.0, 511.0, minf((2.4 - effect_time) * 2, 1.0))
		_box(Rect2(609, drop_y, 63, 30), Color("e3ba6a"), 8)
		_text(Vector2(619, drop_y + 21), "FOOD", 12, INK)
	elif effect == "meteor_strike" and effect_time > 1.3:
		var progress := minf((2.4 - effect_time) / 0.7, 1.0)
		var point := Vector2(903, 172).lerp(Vector2(768, 521), progress)
		draw_line(point + Vector2(55, -130), point, Color("e6a256"), 23, true)
		draw_circle(point, 27, Color("716c60"))
		draw_arc(Vector2(768, 540), 30 + progress * 60, 0, TAU, 40, Color("f2ce8a"), 4, true)
	var label: Array = EFFECT_LABELS[effect]
	_box(Rect2(330, 144, 352, 73), label[2], 12)
	_text(Vector2(346, 173), "%s  #%d" % [label[0], active_effect.id], 20, Color.WHITE)
	_text(Vector2(346, 199), label[1], 13, Color("f6f2e4"))

func _draw_hud() -> void:
	_box(Rect2(966, 126, 282, 490), Color("fffdf4"), 18)
	_text(Vector2(987, 158), "WORLD STATUS", 13, MUTED)
	var cat: Dictionary = snapshot.get("cat", {})
	var names := ["hp", "hunger", "mood", "money"]
	var colors := [Color("8da66c"), Color("c4a368"), Color("8caab1"), Color("bca36c")]
	for i in range(4):
		var y := 193.0 + i * 48
		var stat: String = names[i]
		_text(Vector2(988, y), stat.to_upper(), 12, MUTED)
		_text(Vector2(1190, y), str(int(cat[stat])) if cat.has(stat) else "--", 21, INK)
		if stat != "money":
			_box(Rect2(988, y + 10, 236, 6), Color("e8ebdc"), 3)
			if cat.get(stat, 0) > 0:
				_box(Rect2(988, y + 10, 236 * cat[stat] / 100.0, 6), colors[i], 3)
	var world: Dictionary = snapshot.get("world", {})
	_text(Vector2(988, 382), "ACTION", 11, MUTED)
	_text(Vector2(1091, 382), str(cat.get("action", "--")).to_upper(), 14, INK)
	_text(Vector2(988, 409), "WEATHER", 11, MUTED)
	_text(Vector2(1091, 409), str(world.get("weather", "--")).to_upper(), 14, INK)
	_text(Vector2(988, 436), "POWER", 11, MUTED)
	_text(Vector2(1091, 436), ("ON" if world.power else "OFF") if world.has("power") else "--", 14, INK)
	_text(Vector2(988, 463), "LATEST EVENT", 11, MUTED)
	_text(Vector2(1139, 463), "#%d" % snapshot.meta.last_event_id if snapshot.has("meta") else "--", 16, INK)
	draw_line(Vector2(988, 477), Vector2(1226, 477), Color("e5e8dc"), 1)
	_text(Vector2(988, 500), "RECENT EVENTS / IN ORDER", 11, MUTED)
	for i in range(history.size()):
		var event: Dictionary = history[i]
		var title: String = event.effect.replace("_", " ")
		_text(Vector2(988, 523 + i * 22), "#%d  %s" % [event.id, title], 12, INK, 236)
	_text(Vector2(968, 643), "Higher hunger = hungrier.", 12, MUTED)
	_text(Vector2(968, 667), "Stats are owned by FastAPI.", 12, MUTED)

func _box(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _text(point: Vector2, value: String, size: int, color: Color, width: float = -1) -> void:
	draw_string(ThemeDB.fallback_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
