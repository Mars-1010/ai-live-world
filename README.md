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

## Run the issue #5 Godot world

Install the standard [Godot 4.6 or newer editor](https://godotengine.org/download/)
(no .NET version, paid assets, or plugins needed). The client project is
`godot/project.godot`. The original cat SVG and procedural room art are committed
with the project.

**macOS:** start FastAPI from the repository root using the setup above:

```sh
source .venv/bin/activate
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

**Windows (PowerShell, repository root):**

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

On either platform, open Godot's Project Manager, choose **Import**, select
`godot/project.godot`, and press **F5**. Open
http://127.0.0.1:8000/control-panel/ alongside the Godot window to send events.
The game defaults to `http://127.0.0.1:8000`. To use another backend, edit the URL
at the bottom of the game and press **Connect / resync** or Enter.

For command-line launch on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot -- --backend-url=http://127.0.0.1:8000
```

The same `--path godot -- --backend-url=...` arguments work with the Windows
Godot executable. Alternatively set `AI_LIVE_WORLD_API_URL` before launch;
the command-line option takes precedence over that environment variable.

The Godot client only reads `/state` and `/events?after=<id>`. It polls every
0.5 seconds after the preceding state/event cycle, with four-second request
timeouts and automatic retries. HP, hunger, mood, money, weather, power, action,
and latest event ID come directly from backend snapshots. Cat movement, falling
food, rain, and impact animation are local presentation, never state simulation.
Live gift animations play in event order; bursts queue behind the current
animation (food 1.6 s, rain 2.1 s, meteor 2.8 s). The most recent four events
appear in the HUD.

Initial connection/resync loads current state and event history without replaying
old gift animations. Rain, the meteor hazard, and power-off remain visible from
the current state. A lower backend event ID resets the client automatically.
As with the browser simulator, a restart that catches up to the old ID between
polls cannot be identified without a server session ID; press **Connect / resync**
to reload that history. While disconnected, the last snapshot remains on screen
with a reconnecting indicator. It does not evolve locally.

Godot tests (use your Godot executable in place of `godot` if it is not on PATH;
on Windows prefer the `_console.exe` executable):

```sh
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/test_protocol.gd
```

Optional visual fixtures: with a graphics display, run
`godot --path godot --script res://tests/render_smoke.gd -- --output-dir=<absolute-directory>`
to export 12 deterministic PNGs of all actions and gift stages, plus six
384 × 216 phone previews.

For the live integration test, start a **fresh disposable backend** on port 8765
with `python -m uvicorn backend.main:app --port 8765`, then run:

```sh
godot --headless --path godot --script res://tests/test_live.gd
```

The live test sends six comments and three fake gifts; it requires event ID 0 at
startup and defaults to port 8765 (override with `AI_LIVE_WORLD_API_URL`). See
[the deterministic visual smoke checklist](godot/SMOKE_TEST.md) for checking all
actions, effects, duplicate handling, and restart recovery in the game window.
The Godot HTTP and drawing implementation uses the official
[HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
and [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)
APIs. There is no LLM, OBS automation, or real Douyin integration.

## Issue #7: meme-style presentation

The same Godot client now has large Chinese event banners, six original cat
expressions, stronger contrast, storm ambience, and a meteor warning/impact/outage
sequence. Food, rain, and meteor use distinct visual intensity tiers; no audio
is required. The included OFL-licensed Chinese font works without system fonts.

See [ART_DIRECTION.md](godot/ART_DIRECTION.md) for the visual rules, editable copy
mapping, six required review scenes, and phone previews. The existing run and
backend URL controls are unchanged. Additional tests:

```sh
godot --headless --path godot --script res://tests/test_presentation.gd
```
