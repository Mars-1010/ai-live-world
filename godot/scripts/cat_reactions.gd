extends RefCounted
## Reusable original vector faces, drawn in the existing cat sprite's local space.

const INK = Color("182033")
const WHITE = Color("fffdf4")

static func draw_face(canvas: CanvasItem, reaction: String, elapsed: float) -> void:
	var left := Vector2(-24, -54)
	var right := Vector2(27, -54)
	match reaction:
		"happy":
			for eye in [left, right]:
				canvas.draw_polyline(PackedVector2Array([eye + Vector2(-11, 1), eye + Vector2(0, -8), eye + Vector2(11, 1)]), INK, 5, true)
			canvas.draw_circle(Vector2(1, -27), 14, INK)
			canvas.draw_circle(Vector2(1, -20), 8, Color("f7818d"))
			canvas.draw_circle(Vector2(-37, -32), 10, Color("ef956c"))
			canvas.draw_circle(Vector2(39, -32), 10, Color("ef956c"))
		"shocked":
			for eye in [left, right]:
				canvas.draw_circle(eye, 17, INK)
				canvas.draw_circle(eye, 13, WHITE)
				canvas.draw_circle(eye, 4, INK)
			canvas.draw_circle(Vector2(1, -24), 12, INK)
		"panicked":
			for eye in [left, right]:
				canvas.draw_circle(eye, 18, WHITE)
				canvas.draw_arc(eye, 18, 0, TAU, 24, INK, 4, true)
				canvas.draw_circle(eye + Vector2(sin(elapsed * 28) * 5, 0), 5, INK)
			canvas.draw_line(Vector2(-42, -80), Vector2(-11, -72), INK, 5, true)
			canvas.draw_line(Vector2(16, -72), Vector2(46, -80), INK, 5, true)
			canvas.draw_circle(Vector2(1, -21), 17, INK)
			canvas.draw_line(Vector2(-8, -28), Vector2(10, -28), WHITE, 5)
			canvas.draw_circle(Vector2(54, -45), 7, Color("66cfff"))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(47, -46), Vector2(61, -46), Vector2(52, -64)]), Color("66cfff"))
		"annoyed":
			for eye in [left, right]:
				canvas.draw_line(eye + Vector2(-14, -3), eye + Vector2(14, -3), INK, 5, true)
				canvas.draw_line(eye + Vector2(3, 0), eye + Vector2(3, 8), INK, 5, true)
			canvas.draw_line(Vector2(-11, -23), Vector2(15, -23), INK, 5, true)
			for x in [-10, 0, 10]:
				canvas.draw_line(Vector2(x, -95), Vector2(x - 3, -77), Color("8b748d"), 3)
		"defeated":
			for eye in [left, right]:
				canvas.draw_line(eye + Vector2(-12, -4), eye + Vector2(10, 5), INK, 5, true)
				canvas.draw_line(eye + Vector2(10, 5), eye + Vector2(-4, 10), INK, 4, true)
			canvas.draw_polyline(PackedVector2Array([Vector2(-13, -18), Vector2(0, -24), Vector2(14, -18)]), INK, 4, true)
			canvas.draw_line(Vector2(16, -16), Vector2(20, -5), Color("f08091"), 7, true)
		_:
			for eye in [left, right]:
				canvas.draw_circle(eye, 6, INK)
			canvas.draw_arc(Vector2(-6, -29), 8, 0.0, PI, 12, INK, 3, true)
			canvas.draw_arc(Vector2(9, -29), 8, 0.0, PI, 12, INK, 3, true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5, -40), Vector2(7, -40), Vector2(1, -34)]), INK)
