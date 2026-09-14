# Architecture — AI Live World MVP

## Components

### 1. Godot 4 client
Responsible for:
- rendering the room/world
- rendering the cat and visible state
- executing a bounded action set
- showing audience events and consequences

### 2. FastAPI backend
Responsible for:
- canonical world state
- event ingestion
- deterministic gift mapping
- event queue
- AI Director orchestration
- persistence during the local session

### 3. Fake Douyin Event Simulator
A local control panel that can emit:
- comments
- small gifts
- medium gifts
- large gifts
- premium free-form requests

This replaces real platform integration during MVP development.

### 4. AI Director
Only handles requests that require interpretation.

Rules:
- never execute arbitrary code
- only choose from an allow-listed action/event schema
- output structured JSON
- reject or downgrade impossible/unsafe requests
- deterministic gift effects bypass the model

## Event flow

```text
Fake Douyin Simulator
        |
        v
FastAPI Event Gateway
        |
        +--> deterministic event mapper --> world state
        |
        +--> AI Director --> validated action plan --> world state
        |
        v
Godot polls/subscribes to state + events
        |
        v
Visible consequence
```

## Initial API sketch

- `GET /health`
- `GET /state`
- `POST /event/comment`
- `POST /event/gift`
- `POST /event/wish`
- `POST /world/tick`
- `GET /events?after=<id>`

## Initial data model

```json
{
  "cat": {
    "hp": 100,
    "hunger": 40,
    "mood": 70,
    "money": 20,
    "action": "idle"
  },
  "world": {
    "weather": "clear",
    "power": true,
    "hazards": [],
    "npcs": []
  },
  "meta": {
    "tick": 0,
    "last_event_id": 0
  }
}
```

## Development order

1. backend state + deterministic events
2. local simulator
3. Godot room + cat + stats
4. Godot/backend integration
5. autonomous behavior
6. AI Director
7. OBS capture test
8. only after product validation: real Douyin integration
