"""Session-local state and an ordered event log, committed together."""

from threading import RLock

from .events import apply_event
from .models import CommentEvent, EventRecord, EventResult, GiftEvent, WorldState


class WorldStore:
    def __init__(self) -> None:
        self._state = WorldState()
        self._events: list[EventRecord] = []
        self._lock = RLock()

    def snapshot(self) -> WorldState:
        with self._lock:
            return self._state.model_copy(deep=True)

    def events_after(self, after: int) -> list[EventRecord]:
        with self._lock:
            return [event.model_copy(deep=True) for event in self._events if event.id > after]

    def submit(self, event: CommentEvent | GiftEvent) -> EventResult:
        with self._lock:
            next_state, record = apply_event(self._state, event)
            self._events.append(record.model_copy(deep=True))
            self._state = next_state
            return EventResult(event=record, state=next_state).model_copy(deep=True)
