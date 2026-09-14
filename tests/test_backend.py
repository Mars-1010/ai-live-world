from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from backend.events import apply_event
from backend.main import create_app
from backend.models import Cat, CommentEvent, GiftEvent, WorldState
from backend.world import WorldStore


@pytest.fixture
def client():
    with TestClient(create_app()) as client:
        yield client


def test_health_and_canonical_initial_state(client):
    assert client.get("/health").json() == {"status": "ok"}
    response = client.get("/state")
    assert response.status_code == 200
    assert response.json() == {
        "cat": {"hp": 100, "hunger": 40, "mood": 70, "money": 20, "action": "idle"},
        "world": {"weather": "clear", "power": True, "hazards": [], "npcs": []},
        "meta": {"tick": 0, "last_event_id": 0},
    }
    assert client.get("/events").json() == []


@pytest.mark.parametrize(
    "text, action",
    [("go left", "walk"), ("go right", "walk"), ("walk", "walk"),
     ("eat", "eat"), ("  SLEEP  ", "sleep"), ("work", "work"),
     ("explore", "explore"), ("idle", "idle")],
)
def test_comment_action_mapping(client, text, action):
    result = client.post("/event/comment", json={"text": text})
    assert result.status_code == 200
    assert result.json()["state"]["cat"]["action"] == action
    assert result.json()["event"]["effect"] == "action_suggestion"


def test_unknown_comment_is_logged_without_changing_cat_or_world(client):
    before = client.get("/state").json()
    result = client.post("/event/comment", json={"text": "give me a million coins"}).json()
    assert result["event"]["effect"] == "ignored_comment"
    assert result["state"]["cat"] == before["cat"]
    assert result["state"]["world"] == before["world"]
    assert result["state"]["meta"]["last_event_id"] == 1


@pytest.mark.parametrize(
    "tier, effect, cat_changes, world_changes",
    [
        ("small", "food_drop", {"hunger": 20, "mood": 75, "action": "eat"}, {}),
        ("medium", "rain", {}, {"weather": "rain"}),
        ("large", "meteor_strike", {"hp": 70, "mood": 50},
         {"power": False, "hazards": ["meteor_strike"]}),
    ],
)
def test_gift_mapping_and_persisted_state(client, tier, effect, cat_changes, world_changes):
    expected = client.get("/state").json()
    expected["cat"].update(cat_changes)
    expected["world"].update(world_changes)
    expected["meta"]["last_event_id"] = 1
    response = client.post("/event/gift", json={"tier": tier})
    assert response.status_code == 200
    result = response.json()
    assert result["state"] == expected == client.get("/state").json()
    assert result["event"] == {
        "id": 1, "type": "gift", "payload": {"tier": tier}, "effect": effect
    }


def test_repeated_gifts_clamp_stats_and_do_not_duplicate_hazards(client):
    for _ in range(25):
        assert client.post("/event/gift", json={"tier": "small"}).status_code == 200
    cat = client.get("/state").json()["cat"]
    assert cat["hunger"] == 0
    assert cat["mood"] == 100
    for _ in range(25):
        assert client.post("/event/gift", json={"tier": "large"}).status_code == 200
    state = client.get("/state").json()
    assert state["cat"]["hp"] == state["cat"]["mood"] == 0
    assert state["world"]["hazards"] == ["meteor_strike"]
    assert state["meta"]["last_event_id"] == 50


@pytest.mark.parametrize(
    "path, payload",
    [
        ("comment", {}), ("comment", {"text": "  "}),
        ("comment", {"text": "x" * 501}), ("comment", {"text": 123}),
        ("comment", {"text": "sleep", "hp": 1000}),
        ("gift", {}), ("gift", {"tier": "premium"}),
        ("gift", {"tier": 1}), ("gift", {"tier": None}),
        ("gift", {"tier": "small", "amount": -1}),
    ],
)
def test_invalid_input_is_rejected_without_state_or_log_mutation(client, path, payload):
    before = client.get("/state").json()
    assert client.post(f"/event/{path}", json=payload).status_code == 422
    assert client.get("/state").json() == before
    assert client.get("/events").json() == []


def test_event_ids_and_exclusive_cursor(client):
    client.post("/event/comment", json={"text": "sleep"})
    client.post("/event/gift", json={"tier": "small"})
    client.post("/event/gift", json={"tier": "medium"})
    assert [e["id"] for e in client.get("/events").json()] == [1, 2, 3]
    assert [e["id"] for e in client.get("/events?after=1").json()] == [2, 3]
    assert client.get("/events?after=3").json() == []
    assert client.get("/events?after=999").json() == []
    assert client.get("/events?after=-1").status_code == 422
    assert client.get("/events?after=abc").status_code == 422


@pytest.mark.parametrize("field", ["hp", "hunger", "mood"])
@pytest.mark.parametrize("value", [-1, 101, 0.5, True])
def test_world_stats_reject_invalid_values(field, value):
    with pytest.raises(ValidationError):
        Cat(**{field: value})


def test_money_is_nonnegative_currency_and_assignment_is_validated():
    cat = Cat(money=1000)
    with pytest.raises(ValidationError):
        cat.money = -1
    with pytest.raises(ValidationError):
        cat.hp = 101


def test_mapping_is_pure_and_replay_is_deterministic():
    initial = WorldState()
    sequence = [CommentEvent(text="work"), GiftEvent(tier="small"),
                GiftEvent(tier="medium"), GiftEvent(tier="large")]

    def replay():
        state = initial
        records = []
        for event in sequence:
            state, record = apply_event(state, event)
            records.append(record)
        return state, records

    assert replay() == replay()
    assert initial == WorldState()


def test_returned_snapshots_and_records_cannot_mutate_store():
    store = WorldStore()
    request = CommentEvent(text="sleep")
    result = store.submit(request)
    request.text = "work"
    result.state.cat.hp = 0
    result.event.payload.text = "explore"
    snapshot = store.snapshot()
    snapshot.world.hazards.append("meteor_strike")
    log = store.events_after(0)
    log[0].payload.text = "idle"
    assert store.snapshot().cat.hp == 100
    assert store.snapshot().world.hazards == []
    assert store.events_after(0)[0].payload.text == "sleep"


def test_concurrent_submissions_do_not_lose_events_or_reuse_ids():
    store = WorldStore()
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(
            lambda _: store.submit(GiftEvent(tier="small")), range(100)
        ))
    assert sorted(result.event.id for result in results) == list(range(1, 101))
    assert all(result.event.id == result.state.meta.last_event_id for result in results)
    assert [event.id for event in store.events_after(0)] == list(range(1, 101))
    assert store.snapshot().meta.last_event_id == 100


def test_apps_have_independent_sessions(client):
    client.post("/event/gift", json={"tier": "large"})
    with TestClient(create_app()) as other:
        assert other.get("/state").json()["meta"]["last_event_id"] == 0
        assert other.get("/events").json() == []
