extends SceneTree

const Protocol = preload("res://scripts/protocol.gd")
const WorldView = preload("res://scripts/world_view.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var state := fixture()
	check(Protocol.valid_state(state), "canonical state parses")
	check(Protocol.valid_state(JSON.parse_string(JSON.stringify(state))), "JSON numbers parse")
	for bad in [null, [], {}, {"cat": []}]:
		check(not Protocol.valid_state(bad), "malformed state rejected")
	for stat in ["hp", "hunger", "mood"]:
		for bad in [-1, 101, true, 2.5, "50"]:
			var changed := fixture()
			changed.cat[stat] = bad
			check(not Protocol.valid_state(changed), "invalid %s rejected" % stat)
	var invalid := fixture()
	invalid.world.power = "false"
	check(not Protocol.valid_state(invalid), "power must be boolean")
	invalid = fixture()
	invalid.cat.action = "fly"
	check(not Protocol.valid_state(invalid), "unknown action rejected")
	invalid = fixture()
	invalid.cat.money = -1
	check(not Protocol.valid_state(invalid), "negative money rejected")
	var events := [gift(3), gift(1), gift(2), gift(2)]
	check(Protocol.valid_events(events), "gift events parse")
	check(not Protocol.valid_events([{"id": 1}]), "incomplete event rejected")
	check(not Protocol.valid_events([gift(-1)]), "negative event ID rejected")
	var bad_gift := gift(1)
	bad_gift.effect = "meteor_strike"
	check(not Protocol.valid_events([bad_gift]), "inconsistent gift payload rejected")
	var protocol = Protocol.new()
	check(not protocol.observe_state(state), "initial snapshot is not a restart")
	var ordered: Array = protocol.accept_events(events)
	check(ordered.map(func(event): return event.id) == [1, 2, 3], "ascending unique event IDs")
	check(protocol.cursor == 3, "cursor tracks last accepted event")
	check(protocol.accept_events(events).is_empty(), "repeated polls do not replay events")
	check(events[0].id == 3, "ordering does not mutate input")
	check(protocol.initialized, "history is initialized after first batch")
	state.meta.last_event_id = 3
	check(not protocol.observe_state(state), "same-session state does not reset")
	state.meta.last_event_id = 0
	check(protocol.observe_state(state), "lower ID detects a backend restart")
	check(protocol.cursor == 0 and not protocol.initialized, "restart resets cursor and history flag")
	check(protocol.accept_events([gift(1)]).size() == 1, "reused IDs accepted in new session")
	var view = WorldView.new()
	state = fixture()
	view.update_state(state)
	view.receive_events([gift(1)], true)
	check(view.effect_queue.is_empty(), "historical gifts do not animate")
	view.receive_events([gift(2), gift(3)], false)
	check(view.effect_queue.map(func(event): return event.id) == [2, 3], "live effects queued in order")
	view._process(0.1)
	check(view.active_effect.id == 2, "first gift plays first")
	check(view.snapshot == state, "animation does not change canonical stats")
	state.cat.hp = 1
	check(view.snapshot.cat.hp == 100, "renderer keeps a copied snapshot")
	view.reset_session()
	check(view.history.is_empty() and view.effect_queue.is_empty() and view.snapshot.is_empty(), "reset clears presentation")
	view.free()
	var positions: Array = []
	for action in Protocol.ACTIONS:
		positions.append(WorldView.action_target(action, 0.8))
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			check(positions[i].distance_to(positions[j]) > 5, "actions have distinct presentation targets")
	print("Godot protocol/presentation tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

static func fixture() -> Dictionary:
	return {
		"cat": {"hp": 100, "hunger": 40, "mood": 70, "money": 20, "action": "idle"},
		"world": {"weather": "clear", "power": true, "hazards": [], "npcs": []},
		"meta": {"tick": 0, "last_event_id": 0},
	}

static func gift(id: int) -> Dictionary:
	return {"id": id, "type": "gift", "payload": {"tier": "small"}, "effect": "food_drop"}
