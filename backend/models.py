"""Validated API inputs and canonical world-state models."""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid", validate_assignment=True)


Stat = Annotated[int, Field(strict=True, ge=0, le=100)]
Counter = Annotated[int, Field(strict=True, ge=0)]
Action = Literal["walk", "eat", "sleep", "work", "explore", "idle"]
GiftTier = Literal["small", "medium", "large"]
CommentText = Annotated[
    str, StringConstraints(strict=True, strip_whitespace=True, min_length=1, max_length=500)
]


class Cat(Model):
    hp: Stat = 100
    hunger: Stat = 40
    mood: Stat = 70
    money: Counter = 20
    action: Action = "idle"


class World(Model):
    weather: Literal["clear", "rain"] = "clear"
    power: bool = True
    hazards: list[Literal["meteor_strike"]] = Field(default_factory=list)
    npcs: list[str] = Field(default_factory=list)


class Meta(Model):
    tick: Counter = 0
    last_event_id: Counter = 0


class WorldState(Model):
    cat: Cat = Field(default_factory=Cat)
    world: World = Field(default_factory=World)
    meta: Meta = Field(default_factory=Meta)


class CommentEvent(Model):
    text: CommentText


class GiftEvent(Model):
    tier: GiftTier


class EventRecord(Model):
    id: Annotated[int, Field(strict=True, ge=1)]
    type: Literal["comment", "gift"]
    payload: CommentEvent | GiftEvent
    effect: Literal["action_suggestion", "ignored_comment", "food_drop", "rain", "meteor_strike"]


class EventResult(Model):
    event: EventRecord
    state: WorldState
