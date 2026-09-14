extends Node2D
## All motion and effects are presentation only. Stats are backend snapshots.

const CAT = preload("res://assets/cat.svg")
const Presentation = preload("res://scripts/presentation.gd")
const Faces = preload("res://scripts/cat_reactions.gd")
const MEME_FONT = preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
const INK = Color("fff4d6")
const MUTED = Color("b4bed0")
const OUTLINE = Color("182033")
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
var camera_offset := Vector2.ZERO

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
			effect_time = Presentation.duration(active_effect.effect)
	var action: String = snapshot.get("cat", {}).get("action", "idle")
	var target := action_target(action, action_time)
	if not active_effect.is_empty():
		target = Vector2(457, 501) # Cosmetic close-up; never a canonical coordinate.
	cat_position = cat_position.lerp(target, minf(delta * 10.0, 1.0))
	queue_redraw()

func effect_elapsed() -> float:
	return Presentation.duration(active_effect.get("effect", "")) - effect_time

func current_reaction() -> String:
	return Presentation.reaction(snapshot, active_effect.get("effect", ""), effect_elapsed())

static func action_target(action: String, elapsed: float) -> Vector2:
	match action:
		"walk": return Vector2(440 + sin(elapsed * 1.3) * 180, 470)
		"eat": return Vector2(580, 490)
		"sleep": return Vector2(160, 489)
		"work": return Vector2(777, 435)
		"explore": return Vector2(445 + sin(elapsed * 0.65) * 225, 463 + cos(elapsed * 1.3) * 44)
		_: return Vector2(420, 470)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("171a29"))
	draw_rect(Rect2(30, 20, 9, 82), Color("ffe14b"))
	_text(Vector2(53, 31), "AI LIVE WORLD  /  LIVE CHAOS", 12, Color("ffe14b"))
	_meme(Vector2(50, 82), Presentation.LABELS.title, 48, Color("ffe14b"))
	_meme(Vector2(620, 87), Presentation.LABELS.subtitle, 21, INK)
	draw_circle(Vector2(990, 48), 5, Color("c9ff5f") if online else Color("ff824c"))
	_text(Vector2(1006, 53), "LIVE CONNECTION" if online else "RECONNECTING", 13, INK)
	_text(Vector2(968, 81), status, 12, MUTED, 280)
	camera_offset = Vector2.ZERO
	if active_effect.get("effect") == "meteor_strike" and effect_elapsed() >= 0.55 and effect_elapsed() < 1.25:
		var strength := 14.0 * (1.0 - (effect_elapsed() - 0.55) / 0.7)
		camera_offset = Vector2(sin(time * 53) * strength, cos(time * 61) * strength * 0.6)
	draw_set_transform(camera_offset)
	_draw_room()
	_draw_cat()
	_draw_effect()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	_text(Vector2(34, 645), "BACKEND", 11, MUTED)
	_text(Vector2(34, 707), "Local audience simulator  /  Original art  /  No real payments", 12, MUTED)

func _draw_room() -> void:
	var world: Dictionary = snapshot.get("world", {})
	var raining: bool = world.get("weather", "clear") == "rain"
	var powered: bool = world.get("power", true)
	_box(Rect2(30, 126, 916, 490), Color("efe2ba"), 14)
	draw_rect(Rect2(31, 389, 914, 210), Color("ce854a"))
	for y in range(408, 600, 43):
		draw_line(Vector2(32, y), Vector2(944, y), Color("a35d3d"), 2)
	for x in range(70, 944, 130):
		draw_line(Vector2(x, 409), Vector2(x, 451), Color("a35d3d"), 2)
		draw_line(Vector2(x + 55, 495), Vector2(x + 55, 537), Color("a35d3d"), 2)
	draw_rect(Rect2(31, 380, 914, 12), OUTLINE)
	# Window: persistent weather comes from /state, even after a reconnect.
	_box(Rect2(84, 165, 264, 194), OUTLINE, 8)
	_box(Rect2(96, 177, 240, 170), Color("354877") if raining else Color("60c8db"), 4)
	draw_circle(Vector2(280, 217), 23, Color("637699") if raining else Color("ffe04a"))
	for i in range(5):
		draw_circle(Vector2(123 + i * 53, 330), 30, Color("388265"))
	if raining:
		for i in range(26):
			var x := 107.0 + fmod(i * 43.0, 217.0)
			var y := 179.0 + fmod(time * 165.0 + i * 29.0, 151.0)
			draw_line(Vector2(x, y), Vector2(x - 5, y + 12), Color("d4e8f1"), 2)
	draw_line(Vector2(216, 176), Vector2(216, 348), Color("f2e9d7"), 7)
	draw_line(Vector2(94, 262), Vector2(338, 262), Color("f2e9d7"), 7)
	_box(Rect2(74, 350, 286, 14), OUTLINE, 4)
	# Rug, bed, feeding bowl, work desk and plant are original vector shapes.
	_box(Rect2(285, 441, 385, 127), OUTLINE, 60)
	_box(Rect2(295, 451, 365, 107), Color("e7b939"), 48)
	_box(Rect2(65, 490, 195, 69), OUTLINE, 27)
	_box(Rect2(76, 479, 175, 65), Color("b28bbd"), 23)
	_box(Rect2(87, 482, 66, 32), Color("f8e6c2"), 15)
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
	_box(Rect2(608, 529, 79, 30), OUTLINE, 12)
	_box(Rect2(613, 529, 69, 20), Color("ed5b49"), 8)
	_box(Rect2(615, 528, 65, 8), Color("ffeb9c"), 4)
	# Lamp and persistent impact crater make a power outage legible.
	draw_line(Vector2(559, 127), Vector2(559, 190), Color("9c927a"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(526, 216), Vector2(544, 183), Vector2(574, 183), Vector2(592, 216)]), Color("bd9d63"))
	if powered:
		draw_circle(Vector2(559, 218), 9, Color("ffe9b1"))
	if "meteor_strike" in world.get("hazards", []):
		_box(Rect2(681, 534, 193, 53), OUTLINE, 26)
		draw_colored_polygon(PackedVector2Array([Vector2(726, 548), Vector2(745, 510), Vector2(778, 495), Vector2(811, 525), Vector2(804, 552)]), Color("676762"))
		draw_line(Vector2(768, 516), Vector2(786, 541), Color("ff793b"), 6)
		for i in range(5):
			var smoke_y := 504.0 - fmod(time * 26 + i * 33, 125.0)
			draw_circle(Vector2(772 + sin(i * 4.0 + time) * 23, smoke_y), 17 + i * 3, Color(0.20, 0.22, 0.29, 0.6))
	if raining:
		draw_rect(Rect2(31, 127, 914, 473), Color(0.12, 0.20, 0.46, 0.43))
		for i in range(4):
			_box(Rect2(93 + i * 209, 565 + (i % 2) * 11, 124, 12), Color("729ecc"), 6)
		for i in range(38):
			var rain_x := 55.0 + fmod(i * 113.0, 861.0)
			var rain_y := 180.0 + fmod(time * 280 + i * 79, 369.0)
			draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 9, rain_y + 23), Color(0.65, 0.85, 1.0, 0.65), 3, true)
	if not powered:
		draw_rect(Rect2(31, 127, 914, 473), Color(0.07, 0.08, 0.17, 0.62))
		if active_effect.is_empty():
			_banner(Presentation.LABELS.aftermath, Color("ffe16a"), OUTLINE, 64)
	elif active_effect.is_empty() and not snapshot.is_empty():
		_box(Rect2(520, 149, 397, 57), OUTLINE, 8)
		_meme(Vector2(538, 189), Presentation.ACTION_COPY[snapshot.cat.action], 29, Color("ffe14b"))
	_text(Vector2(54, 594), "CAT'S APARTMENT", 11, Color("fff0c4"))
	_text(Vector2(711, 594), "RAINY" if raining else "CLEAR SKIES", 11, Color("fff0c4"))

func _draw_cat() -> void:
	var action: String = snapshot.get("cat", {}).get("action", "idle")
	var bob := sin(action_time * 2.0) * 2
	var scale := Vector2(1.12, 1.12)
	var rotation := 0.0
	match action:
		"walk", "explore":
			bob = abs(sin(action_time * 9)) * -8
			scale.x *= 1.0 if cos(action_time * (1.3 if action == "walk" else 0.65)) >= 0 else -1.0
		"eat":
			rotation = sin(action_time * 8) * 0.075
			bob = sin(action_time * 8) * 4
		"sleep":
			scale = Vector2(1.14, 0.69 + sin(action_time * 2) * 0.02)
			rotation = -0.12
		"work":
			bob = sin(action_time * 12) * 2
	var reaction := current_reaction()
	if not active_effect.is_empty():
		scale = Vector2(1.56, 1.56)
		rotation = 0.0
		match reaction:
			"happy":
				bob = -abs(sin(time * 7)) * 18
				scale.y += sin(time * 7) * 0.07
			"shocked":
				scale = Vector2(1.4, 1.7)
				bob = -18
			"panicked":
				rotation = sin(time * 27) * 0.12
				bob = -abs(sin(time * 18)) * 17
			"annoyed":
				scale.y = 1.33
	elif reaction == "defeated" and action != "sleep":
		scale.y = 0.77
		rotation = -0.16
	draw_set_transform(camera_offset + cat_position + Vector2(0, bob), rotation, scale)
	draw_texture_rect(CAT, Rect2(-90, -135, 180, 170), false)
	Faces.draw_face(self, reaction, time)
	draw_set_transform(camera_offset)
	if reaction == "panicked":
		_meme(cat_position + Vector2(-194, -80), Presentation.REACTION_COPY.panicked_left, 55, Color("ffe456"))
		_meme(cat_position + Vector2(143, -97), Presentation.REACTION_COPY.panicked_right, 55, Color("fff0d6"))
	elif reaction == "shocked":
		_meme(cat_position + Vector2(133, -110), Presentation.REACTION_COPY.shocked, 57, Color("fff2c2"))
	elif reaction == "annoyed":
		_text(cat_position + Vector2(-140, -132), "...", 47, Color("b8def5"))
	match action:
		"sleep":
			_text(cat_position + Vector2(42, -90 - fmod(action_time * 12, 25)), "Z z z", 29, Color("d9deff"))
		"eat":
			for i in range(4):
				draw_circle(Vector2(620 + i * 10, 522 - abs(sin(action_time * 7 + i)) * 17), 3, Color("d8a457"))
		"work":
			_text(Vector2(818, 421), "..." if int(action_time * 3) % 2 else "|||", 14, Color("365343"))
			_text(cat_position + Vector2(-25, -152), "tap tap", 19, OUTLINE)
		"explore":
			_text(cat_position + Vector2(70, -130), "?", 39, OUTLINE)
			for i in range(3):
				draw_circle(cat_position + Vector2(-55 - i * 16, 33), 3, Color("a69c7d"))
	if snapshot.is_empty():
		_box(Rect2(300, 284, 390, 61), Color("fffaf0"), 12)
		_meme(Vector2(322, 325), Presentation.LABELS.waiting, 27, OUTLINE)

func _draw_effect() -> void:
	if active_effect.is_empty():
		return
	var effect: String = active_effect.effect
	var elapsed := effect_elapsed()
	if effect == "food_drop":
		for i in range(12):
			var direction := Vector2.from_angle(i * TAU / 12.0 + 0.1)
			var center := Vector2(457, 425)
			draw_line(center + direction * 155, center + direction * 181, Color("ffe85b"), 7, true)
		var drop_y := lerpf(250.0, 455.0, minf(elapsed * 3, 1.0))
		# Giant original fish-shaped snack, immediately readable without a label.
		draw_colored_polygon(PackedVector2Array([Vector2(707, drop_y), Vector2(770, drop_y - 36), Vector2(770, drop_y + 36)]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(713, drop_y), Vector2(761, drop_y - 25), Vector2(761, drop_y + 25)]), Color("ff9754"))
		_box(Rect2(607, drop_y - 39, 126, 78), OUTLINE, 38)
		_box(Rect2(614, drop_y - 32, 112, 64), Color("ffba57"), 30)
		draw_circle(Vector2(640, drop_y - 8), 7, OUTLINE)
		draw_line(Vector2(680, drop_y - 25), Vector2(680, drop_y + 25), OUTLINE, 4)
	elif effect == "rain":
		# Local storm cloud and heavy streaks reinforce the persistent blue tint.
		for i in range(5):
			draw_circle(Vector2(278 + i * 86, 278), 51, Color("384566"))
		for i in range(9):
			var y := 309.0 + fmod(time * 270 + i * 37, 140.0)
			draw_line(Vector2(277 + i * 47, y), Vector2(263 + i * 47, y + 29), Color("8ad5ff"), 5, true)
	elif effect == "meteor_strike":
		var progress := clampf(elapsed / 0.6, 0, 1)
		var point := Vector2(903, 225).lerp(Vector2(756, 531), progress)
		if elapsed < 0.8:
			draw_line(point + Vector2(54, -158), point, Color("ff5932"), 61, true)
			draw_line(point + Vector2(31, -100), point, Color("ffc242"), 32, true)
			draw_circle(point, 46, OUTLINE)
			draw_circle(point, 37, Color("74677e"))
		if elapsed >= 0.55 and elapsed < 1.8:
			for i in range(13):
				var direction := Vector2.from_angle(PI + i * PI / 12)
				var distance := 50 + (elapsed - 0.55) * 125
				draw_line(Vector2(756, 550) + direction * distance, Vector2(756, 550) + direction * (distance + 26), Color("ffc84d"), 7, true)
			draw_arc(Vector2(756, 545), 58 + (elapsed - 0.55) * 75, PI, TAU, 32, Color("ffdf68"), 9, true)
		# A single warm impact pulse, not a repeated strobe; HUD stays stable.
		if elapsed >= 0.55 and elapsed < 0.72:
			draw_rect(Rect2(31, 127, 914, 473), Color(1.0, 0.8, 0.35, (0.72 - elapsed) * 3.8))
		draw_rect(Rect2(39, 135, 898, 464), Color("ff603b"), false, 10)
		for i in range(17):
			var x := 40.0 + i * 52
			draw_colored_polygon(PackedVector2Array([Vector2(x, 600), Vector2(x + 22, 600), Vector2(x + 37, 577), Vector2(x + 15, 577)]), Color("ffc34c"))
	draw_set_transform(Vector2.ZERO)
	var style: Dictionary = Presentation.GIFT_STYLES[effect]
	var copy := Presentation.phrase(effect, int(active_effect.id))
	if effect == "meteor_strike" and elapsed < 0.55:
		copy = Presentation.LABELS.warning
	_banner(copy, style.color, style.ink, 86 if copy.length() <= 5 else 72)

func _banner(copy: String, color: Color, ink: Color, size: int) -> void:
	_box(Rect2(70, 153, 840, 124), OUTLINE, 9)
	_box(Rect2(62, 144, 840, 124), color, 9)
	var text_width := MEME_FONT.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_meme(Vector2(482 - text_width / 2, 238), copy, size, ink)

func _draw_hud() -> void:
	_box(Rect2(966, 126, 282, 490), Color("252b40"), 14)
	_text(Vector2(987, 158), "WORLD STATUS", 13, Color("ffe14b"))
	var cat: Dictionary = snapshot.get("cat", {})
	var names := ["hp", "hunger", "mood", "money"]
	var colors := [Color("c9ff62"), Color("ffae4b"), Color("70d6ff"), Color("ffe14b")]
	for i in range(4):
		var y := 193.0 + i * 48
		var stat: String = names[i]
		_text(Vector2(988, y), stat.to_upper(), 12, MUTED)
		_text(Vector2(1190, y), str(int(cat[stat])) if cat.has(stat) else "--", 21, INK)
		if stat != "money":
			_box(Rect2(988, y + 10, 236, 6), Color("46516c"), 3)
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
	draw_line(Vector2(988, 477), Vector2(1226, 477), Color("46516c"), 1)
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

func _meme(point: Vector2, value: String, size: int, color: Color) -> void:
	draw_string_outline(MEME_FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, OUTLINE)
	draw_string(MEME_FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
