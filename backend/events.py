"""Pure deterministic mappings; no clock, randomness, or external services."""

from .models import Action, CommentEvent, EventRecord, GiftEvent, WorldState


COMMENT_ACTIONS: dict[str, Action] = {
    "go left": "walk",
    "go right": "walk",
    "walk": "walk",
    "eat": "eat",
    "sleep": "sleep",
    "work": "work",
    "explore": "explore",
    "idle": "idle",
}


def bounded(value: int) -> int:
    return max(0, min(100, value))


def apply_event(
    state: WorldState, event: CommentEvent | GiftEvent
) -> tuple[WorldState, EventRecord]:
    """Build a validated next state without mutating the supplied snapshot."""
    next_state = state.model_dump()
    cat = next_state["cat"]
    world = next_state["world"]
    if isinstance(event, CommentEvent):
        event_type = "comment"
        action = COMMENT_ACTIONS.get(event.text.casefold())
        effect = "ignored_comment"
        if action is not None:
            cat["action"] = action
            effect = "action_suggestion"
    elif isinstance(event, GiftEvent):
        event_type = "gift"
        if event.tier == "small":
            effect = "food_drop"
            cat["hunger"] = bounded(cat["hunger"] - 20)
            cat["mood"] = bounded(cat["mood"] + 5)
            cat["action"] = "eat"
        elif event.tier == "medium":
            effect = "rain"
            world["weather"] = "rain"
        else:
            effect = "meteor_strike"
            cat["hp"] = bounded(cat["hp"] - 30)
            cat["mood"] = bounded(cat["mood"] - 20)
            world["power"] = False
            if "meteor_strike" not in world["hazards"]:
                world["hazards"].append("meteor_strike")
    else:
        raise TypeError("Unsupported event type")

    event_id = state.meta.last_event_id + 1
    next_state["meta"]["last_event_id"] = event_id
    validated_state = WorldState.model_validate(next_state)
    record = EventRecord(id=event_id, type=event_type, payload=event, effect=effect)
    return validated_state, record
