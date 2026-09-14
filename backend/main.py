"""Run from the repository root: uvicorn backend.main:app --reload."""

from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, Query
from fastapi.staticfiles import StaticFiles

from .models import CommentEvent, EventRecord, EventResult, GiftEvent, WorldState
from .world import WorldStore


def create_app() -> FastAPI:
    app = FastAPI(title="AI Live World", version="0.1.0")
    store = WorldStore()

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/state", response_model=WorldState)
    def state() -> WorldState:
        return store.snapshot()

    @app.post("/event/comment", response_model=EventResult)
    def comment(event: CommentEvent) -> EventResult:
        return store.submit(event)

    @app.post("/event/gift", response_model=EventResult)
    def gift(event: GiftEvent) -> EventResult:
        return store.submit(event)

    @app.get("/events", response_model=list[EventRecord])
    def events(after: Annotated[int, Query(ge=0)] = 0) -> list[EventRecord]:
        return store.events_after(after)

    app.mount(
        "/control-panel",
        StaticFiles(directory=Path(__file__).resolve().parent.parent / "control-panel", html=True),
        name="control-panel",
    )

    return app


app = create_app()
