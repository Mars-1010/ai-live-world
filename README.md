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
