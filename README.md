# AI Live World

A livestream-native, audience-controlled AI world where comments and gifts can change a persistent virtual environment in real time.

## MVP thesis

The product is not "AI-generated video". The product is **paid control over a persistent AI world**.

The first milestone is a 10-minute local demo where:

- one autonomous character lives in a persistent world;
- simulated comments and gifts trigger visible world events;
- paid events have guaranteed effects;
- an AI Director handles only higher-level natural-language requests;
- the game can be captured by OBS for livestreaming.

## Initial architecture

- **Godot 4** — world rendering and character actions
- **FastAPI / Python** — world state, event gateway, orchestration
- **LLM** — AI Director for complex requests only
- **Local control panel** — fake Douyin comments/gifts for MVP testing
- **OBS** — livestream capture

## MVP constraints

- No Douyin API dependency in the first build.
- No custom model training.
- No generative-video dependency.
- Deterministic gift effects for low-latency interactions.
- Core prompts, economy rules, and event mappings stay server-side.

## Milestone 1

Create a playable local demo with one room, one cat, four visible stats, autonomous actions, and simulated audience events.

## Run the issue #1 backend

Requires Python 3.10 or newer. From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
uvicorn backend.main:app --reload
```

Open http://127.0.0.1:8000/docs for the interactive API. Run tests with
`python -m pytest -q`. For runtime-only installation, use `requirements.txt`.

Use one server worker: state and the full ordered event log live in memory for
that process. Restarting or reloading resets the session. There is no database,
background tick loop, LLM, or Douyin connection.

### API

| Route | Request | Response |
| --- | --- | --- |
| `GET /health` | — | `{"status":"ok"}` |
| `GET /state` | — | Canonical state from `ARCHITECTURE.md` |
| `POST /event/comment` | `{"text":"sleep"}` | `{"event":{...},"state":{...}}` |
| `POST /event/gift` | `{"tier":"small"}` | `{"event":{...},"state":{...}}` |
| `GET /events?after=0` | Nonnegative, exclusive event ID cursor | Ordered array of event records |

Each accepted event receives an increasing integer ID starting at 1, also stored
in `state.meta.last_event_id`. Records contain `id`, `type`, `payload`, and
`effect`. The POST response includes the state immediately after that event.
Invalid requests return HTTP 422 and leave state and history unchanged.

### Deterministic test mappings

These fixed mappings make the specification's example tiers executable for local
testing; they are not a production gift catalog or economy.

| Input | Effect |
| --- | --- |
| Comment: `go left`, `go right`, or `walk` | Suggest `walk` action |
| Comment: `eat`, `sleep`, `work`, `explore`, or `idle` | Suggest the named action |
| Other comment | Log `ignored_comment`; no cat/world change |
| Small gift | `food_drop`: hunger −20, mood +5, action `eat` |
| Medium gift | `rain`: weather becomes `rain` |
| Large gift | `meteor_strike`: HP −30, mood −20, power off; add the hazard once |

Comments ignore case and surrounding whitespace, and must contain 1–500
characters after trimming. For this foundation, recognized suggestions set the
current action; they do not grant resources or simulate completing the action.
There is no autonomous scheduler yet. Gift tiers accept exactly `small`, `medium`,
or `large`; clients cannot supply arbitrary state deltas or extra fields.

HP, hunger, and mood are integers clamped to 0–100 after gift effects. Higher
hunger means hungrier. Money is nonnegative integer currency, initially 20, with
no percentage cap; these test mappings do not change it. Repeated gifts still
create events even if their effect is already active or a stat is at its bound.
`meta.tick` remains 0 until the later autonomous behavior milestone.

```sh
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/event/comment \
  -H 'Content-Type: application/json' -d '{"text":"sleep"}'
curl -X POST http://127.0.0.1:8000/event/gift \
  -H 'Content-Type: application/json' -d '{"tier":"small"}'
curl 'http://127.0.0.1:8000/events?after=0'
curl http://127.0.0.1:8000/state
```

## Run the issue #3 event simulator

Start the backend with the command above, then open
http://127.0.0.1:8000/control-panel/ in a browser. No frontend installation or
build step is needed. FastAPI serves the plain HTML/CSS/JS in `control-panel/`
from the same origin as the API, so no CORS permissions or second server are needed.
Do not open `index.html` directly as a file.

The panel shows all four stats, weather, power, current action, and last event ID.
Click a comment preset, send a custom comment, or choose a gift tier. Gift cards
show the exact test effects; accepted gifts immediately update the state and show
a brief banner. These are simulated gifts with no real payments or platform calls.

The event feed polls `GET /events?after=<id>` once per second after the previous
poll finishes, showing events in ascending ID order without duplicates. It also
includes events sent from other tabs or API clients. Connection failures show a
retry status; requests time out after five seconds. Failed or uncertain sends
are never automatically retried. Refreshing the page reloads session history.
When polling observes an event ID lower than before (a backend restart), the panel
clears the previous feed and reloads it. If a restarted backend has already caught
up to the old ID before polling, refresh the page to reload that new history;
the current API does not expose a session identifier.

Validation:

```sh
python -m pytest -q
# Optional: Node.js 20+ runs the frontend logic tests, with no npm packages.
node --test control-panel/tests/*.test.mjs
```

For a quick manual check, click each gift tier, send a preset and a custom
comment, then keep two tabs open and confirm both show the same event order.
