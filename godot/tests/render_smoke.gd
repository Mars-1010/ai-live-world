extends SceneTree
## Render deterministic fixture frames using Godot itself, not desktop capture.
## Requires a graphics display; --headless cannot produce these image frames.

const WorldView = preload("res://scripts/world_view.gd")
const Fixtures = preload("res://tests/test_protocol.gd")
const Presentation = preload("res://scripts/presentation.gd")
const PHONE_PREVIEWS = ["idle", "food_drop", "rain", "meteor_impact", "power_off_aftermath", "work"]
var output_dir: String = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	if output_dir.is_empty():
		push_error("Pass -- --output-dir=<absolute directory> for rendered fixture PNGs.")
		quit(1)
		return
	call_deferred("render_frames")

func render_frames() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.client.stop()
	var view = scene.view
	view.set_process(false)
	view.update_connection(true, "Connected / visual test fixture")
	for action in ["idle", "walk", "eat", "sleep", "work", "explore"]:
		view.reset_session()
		view.update_connection(true, "Connected / visual test fixture")
		var state := Fixtures.fixture()
		state.cat.action = action
		view.update_state(state)
		view.time = 0.8
		view.action_time = 0.8
		view.cat_position = WorldView.action_target(action, 0.8)
		await save_frame(view, action)
	for effect in ["food_drop", "rain", "meteor_strike"]:
		view.reset_session()
		view.update_connection(true, "Connected / visual test fixture")
		var state := Fixtures.fixture()
		state.meta.last_event_id = 1
		if effect == "food_drop":
			state.cat.hunger = 20
			state.cat.mood = 75
			state.cat.action = "eat"
		elif effect == "rain":
			state.world.weather = "rain"
		else:
			state.cat.hp = 70
			state.cat.mood = 50
			state.world.power = false
			state.world.hazards = ["meteor_strike"]
		view.update_state(state)
		view.time = 0.8
		view.action_time = 0.8
		view.cat_position = Vector2(457, 501)
		view.active_effect = {"id": 1, "effect": effect}
		view.effect_time = Presentation.duration(effect) - 0.85
		if effect == "meteor_strike":
			await save_frame(view, "meteor_impact")
			view.effect_time = Presentation.duration(effect) - 0.3
			await save_frame(view, "meteor_warning")
			view.effect_time = Presentation.duration(effect) - 0.6
			await save_frame(view, "meteor_flash")
			view.active_effect = {}
			view.effect_time = 0.0
			view.cat_position = WorldView.action_target("idle", 0.8)
			await save_frame(view, "power_off_aftermath")
		else:
			await save_frame(view, effect)
	print("Rendered 12 fixture frames and six phone previews to " + output_dir)
	quit()

func save_frame(view: Node2D, name: String) -> void:
	view.queue_redraw()
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var error := frame.save_png(output_dir.path_join(name + ".png"))
	if error != OK:
		push_error("Could not save frame: " + name)
		quit(1)
		return
	if name in PHONE_PREVIEWS:
		frame.resize(384, 216, Image.INTERPOLATE_LANCZOS)
		if frame.save_png(output_dir.path_join(name + "_phone.png")) != OK:
			push_error("Could not save phone preview: " + name)
			quit(1)
