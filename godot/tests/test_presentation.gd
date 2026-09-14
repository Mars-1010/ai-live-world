extends SceneTree

const Presentation = preload("res://scripts/presentation.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Fixtures = preload("res://tests/test_protocol.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var state := Fixtures.fixture()
	check(Presentation.reaction(state, "", 0) == "neutral", "idle is neutral")
	check(Presentation.reaction(state, "food_drop", 0.3) == "happy", "food causes a happy face")
	check(Presentation.reaction(state, "rain", 0.2) == "shocked", "rain begins with shock")
	check(Presentation.reaction(state, "rain", 0.8) == "annoyed", "rain settles into annoyance")
	check(Presentation.reaction(state, "meteor_strike", 0.2) == "shocked", "meteor warning shows shock")
	check(Presentation.reaction(state, "meteor_strike", 0.8) == "panicked", "meteor impact shows panic")
	state.world.power = false
	state.world.hazards = ["meteor_strike"]
	check(Presentation.reaction(state, "", 0) == "defeated", "outage aftermath is defeated")
	check(Presentation.reaction(state, "food_drop", 0.3) == "happy", "new food temporarily wins over aftermath")
	state = Fixtures.fixture()
	state.world.weather = "rain"
	check(Presentation.reaction(state, "", 0) == "annoyed", "rain mood persists without replay")
	var previous_tier := 0
	var previous_duration := 0.0
	for effect in ["food_drop", "rain", "meteor_strike"]:
		var style: Dictionary = Presentation.GIFT_STYLES[effect]
		check(style.tier > previous_tier, "gift intensity tiers ascend")
		check(style.duration > previous_duration and style.duration <= 3.0, "tier timing increases within three seconds")
		previous_tier = style.tier
		previous_duration = style.duration
		for phrase in style.copy:
			check(phrase.length() <= 8, "copy stays short")
			for character in phrase:
				check(WorldView.MEME_FONT.has_char(character.unicode_at(0)), "bundled font covers gift copy")
		check(Presentation.phrase(effect, 7) == Presentation.phrase(effect, 7), "copy selection is deterministic")
		check(Presentation.phrase(effect, 1) != Presentation.phrase(effect, 2), "copy mapping supports variants")
	for phrase in Presentation.LABELS.values() + Presentation.ACTION_COPY.values() + Presentation.REACTION_COPY.values():
		for character in phrase:
			check(WorldView.MEME_FONT.has_char(character.unicode_at(0)), "bundled font covers scene copy")
	var view = WorldView.new()
	view.update_state(state)
	var before: Dictionary = view.snapshot.duplicate(true)
	view.receive_events([Fixtures.gift(1)], false)
	view._process(0.1)
	check(view.current_reaction() == "happy", "live queue activates reaction")
	check(view.effect_time == Presentation.duration("food_drop"), "effect duration comes from mapping")
	view._process(2.0)
	check(view.active_effect.is_empty(), "finished reaction expires")
	check(view.snapshot == before, "reactions and poses never change canonical state")
	view.reset_session()
	check(view.active_effect.is_empty() and view.effect_queue.is_empty(), "reset clears reactions")
	view.free()
	print("Godot presentation tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
