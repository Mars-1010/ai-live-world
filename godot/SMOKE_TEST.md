# Deterministic visual smoke test

Start a fresh FastAPI process on port 8000 with one worker, run the Godot project,
and open `http://127.0.0.1:8000/control-panel/`. Keep both windows visible. Wait
for each action/effect before moving to the next step (at least 3 seconds between
gifts so their animations do not queue). No action below involves a real gift or
payment.

| Step | Browser control | Expected in Godot |
| --- | --- | --- |
| 0 | None | Connected; HP 100, hunger 40, mood 70, money 20, clear, power on, idle, ID 0. One cat and a furnished room. |
| 1 | `idle` | ID 1; cat gently bobs near the rug. |
| 2 | `walk` | ID 2; cat walks left/right, bounces, and changes facing direction. |
| 3 | `eat` | ID 3; cat moves beside the food bowl, nods, and food crumbs bounce. |
| 4 | `sleep` | ID 4; cat moves to the bed, settles into a flattened pose, with floating Zs. |
| 5 | `work` | ID 5; cat moves to the desk, types/bobs, with `tap tap` and a changing display. |
| 6 | `explore` | ID 6; cat roams a wider path at varying depth with a question mark and trail. |
| 7 | Small gift | ID 7; FOOD DELIVERY banner, falling food parcel, feeding reaction. Hunger 20, mood 75, action eat. |
| 8 | Medium gift | ID 8; rain banner and moving raindrops outside the window, weather rain. |
| 9 | Large gift | ID 9; meteor banner, falling meteor, impact ring/room shake, persistent rock/crater. Lamp and screen go dark, room dims, power OFF warning. HP 70, mood 55, hunger 20, money 20. |

Additional checks:

- Leave it running for 10 seconds. No event repeats and no stat changes on its
  own. The HUD shows the latest four events in ascending ID order.
- Quickly send small, medium, and large gifts. Each gift appears once and in
  order; animation playback queues, while stats continue following the backend.
- Open a second browser tab, send a comment there, and verify Godot sees it too.
- Click **Connect / resync**. Current stats, rain, outage, and crater remain;
  old gift animations do not replay.
- Stop the backend. Within the timeout/retry window, Godot shows reconnecting,
  preserves the last snapshot, and stays responsive. Restart the backend and
  wait for ID 0 before sending anything: the game restores the initial room and
  clears effects/history automatically. Then send a small gift; ID 1 works again.
- Enter an unavailable backend URL, then restore `http://127.0.0.1:8000` using
  the in-game address field and **Connect / resync**. The client recovers without
  restarting Godot.
- Resize the window. The 1280 × 720 composition scales with the viewport.

Limitations: a restarted backend that has already reached the previous event ID
between polls is indistinguishable from the previous session with the current
API. Use **Connect / resync** then. Walking/exploring positions and animation
phases are cosmetic, not shared world coordinates. Browser/Godot reloads may
restart those animations without changing world state. No autonomous stat decay,
resource generation, physics simulation, or additional backend runs in Godot.
