extends SceneTree
## Run against a fresh disposable backend session. This test sends fake events.

const BackendClient = preload("res://scripts/backend_client.gd")
const WorldView = preload("res://scripts/world_view.gd")
var client: Node
var view: Node2D
var sender: HTTPRequest
var base_url: String
var observed: Array = []
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	base_url = OS.get_environment("AI_LIVE_WORLD_API_URL")
	if base_url.is_empty():
		base_url = "http://127.0.0.1:8765"
	client = BackendClient.new()
	view = WorldView.new()
	sender = HTTPRequest.new()
	sender.timeout = 4.0
	root.add_child(client)
	root.add_child(view)
	root.add_child(sender)
	client.state_updated.connect(view.update_state)
	client.events_received.connect(view.receive_events)
	client.events_received.connect(func(events, _historical):
		for event in events:
			observed.append(int(event.id)))
	client.session_reset.connect(view.reset_session)
	client.connect_to(base_url)
	if not await wait_for_id(0):
		finish()
		return
	if view.snapshot.meta.last_event_id != 0:
		push_error("Live test requires a fresh disposable backend session, not a running demo.")
		failures += 1
		finish()
		return
	var expected_id := 0
	for action in ["idle", "walk", "eat", "sleep", "work", "explore"]:
		expected_id += 1
		await post("comment", {"text": action})
		await wait_for_id(expected_id)
		check(view.snapshot.cat.action == action, "rendered action follows backend: " + action)
	for tier in ["small", "medium", "large"]:
		expected_id += 1
		await post("gift", {"tier": tier})
		await wait_for_id(expected_id)
	check(view.snapshot.cat.hp == 70 and view.snapshot.cat.hunger == 20 and view.snapshot.cat.mood == 55, "gift stats match backend")
	check(view.snapshot.world.weather == "rain" and not view.snapshot.world.power, "rain and power outage reach renderer")
	check("meteor_strike" in view.snapshot.world.hazards, "persistent meteor hazard reaches renderer")
	await create_timer(1.2).timeout
	check(observed == range(1, 10), "all nine events arrive once in order across repeated polls")
	var before: Dictionary = view.snapshot.duplicate(true)
	client.stop()
	await create_timer(0.6).timeout
	check(view.snapshot == before, "animation without networking does not simulate new world state")
	client.connect_to("not-a-url")
	check(not client.running, "invalid backend URL is rejected")
	client.connect_to(base_url)
	await wait_for_id(9)
	check(view.snapshot == before, "resync restores the canonical snapshot")
	check(view.effect_queue.is_empty() and view.active_effect.is_empty(), "resync does not replay historical gift animations")
	finish()

func post(kind: String, payload: Dictionary) -> void:
	var error := sender.request(base_url + "/event/" + kind, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		check(false, "test event request starts")
		return
	var result: Array = await sender.request_completed
	check(result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, "test event accepted")

func wait_for_id(id: int) -> bool:
	for _attempt in range(70):
		if client.protocol.initialized and not view.snapshot.is_empty() \
			and view.snapshot.meta.last_event_id >= id and client.protocol.cursor >= id:
			return true
		await create_timer(0.1).timeout
	check(false, "timed out waiting for backend event #%d" % id)
	return false

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func finish() -> void:
	client.stop()
	print("Godot live FastAPI integration: %d failures" % failures)
	quit(1 if failures else 0)
