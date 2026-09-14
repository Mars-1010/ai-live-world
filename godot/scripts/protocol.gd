extends RefCounted
## Validate backend data and track a polling cursor; never simulate world state.

const ACTIONS = ["idle", "walk", "eat", "sleep", "work", "explore"]
const EFFECTS = ["action_suggestion", "ignored_comment", "food_drop", "rain", "meteor_strike"]
var cursor: int = 0
var state_id: int = 0
var initialized: bool = false

static func whole_number(value: Variant, minimum: int = 0, maximum: float = 9007199254740991.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["cat", "world", "meta"]:
		if not value.get(key) is Dictionary:
			return false
	var cat: Dictionary = value.cat
	for key in ["hp", "hunger", "mood"]:
		if not whole_number(cat.get(key), 0, 100):
			return false
	if not whole_number(cat.get("money")) or cat.get("action") not in ACTIONS:
		return false
	var world: Dictionary = value.world
	if world.get("weather") not in ["clear", "rain"] or not world.get("power") is bool:
		return false
	for key in ["hazards", "npcs"]:
		if not world.get(key) is Array:
			return false
		for item in world[key]:
			if not item is String:
				return false
	return whole_number(value.meta.get("last_event_id")) and whole_number(value.meta.get("tick"))

static func valid_events(value: Variant) -> bool:
	if not value is Array:
		return false
	for event in value:
		if not event is Dictionary or not whole_number(event.get("id"), 1):
			return false
		if event.get("effect") not in EFFECTS or not event.get("payload") is Dictionary:
			return false
		if event.get("type") == "comment":
			if not event.payload.get("text") is String \
				or event.effect not in ["action_suggestion", "ignored_comment"]:
				return false
		elif event.get("type") == "gift":
			var mapping = {"small": "food_drop", "medium": "rain", "large": "meteor_strike"}
			if mapping.get(event.payload.get("tier"), "") != event.effect:
				return false
		else:
			return false
	return true

func observe_state(state: Dictionary) -> bool:
	var next_id := int(state.meta.last_event_id)
	var restarted := next_id < maxi(state_id, cursor)
	if restarted:
		reset()
	state_id = next_id
	return restarted

func accept_events(events: Array) -> Array:
	# The caller validates the entire batch before this mutates the cursor.
	var ordered := events.duplicate(true)
	ordered.sort_custom(func(a, b): return a.id < b.id)
	var fresh: Array = []
	for event in ordered:
		if int(event.id) <= cursor:
			continue
		cursor = int(event.id)
		fresh.append(event)
	initialized = true
	return fresh

func reset() -> void:
	cursor = 0
	state_id = 0
	initialized = false
