# Product Spec — AI Live World MVP

## Core product idea

A persistent AI world that viewers can influence through comments and gifts. The monetization mechanic is not passive viewing; it is **paying to cause visible consequences in the world**.

## MVP user loop

1. Viewer sees a persistent character/world.
2. Viewer sends a comment or gift.
3. The system maps the event to a guaranteed or AI-mediated consequence.
4. The consequence appears on screen quickly.
5. Other viewers react and may intervene with their own actions.

## Design rule

Low-value / simple interactions should be deterministic. High-value / free-form requests may be handled by the AI Director.

### Example tiers

- Free comment: suggestion only, e.g. `go left`, `sleep`, `work`.
- Small gift: guaranteed resource change, e.g. +food, +money, +mood.
- Medium gift: guaranteed world event, e.g. rain, NPC spawn, monster, power outage.
- Large gift: high-impact event, e.g. disaster, rescue, boss, teleport.
- Premium free-form request: AI Director translates a natural-language wish into a bounded sequence of game actions.

## MVP world

Theme: one cat living in a small apartment / tiny town.

Visible stats:
- HP
- Hunger
- Mood
- Money

Initial actions:
- walk
- eat
- sleep
- work
- explore
- idle

Initial world events:
- food drop
- rain
- power outage
- NPC visit
- lottery win
- monster spawn
- illness
- fire
- portal
- meteor strike

## MVP success criteria

The local demo is considered successful when:

- the character can run autonomously for 10 minutes;
- world state persists through the session;
- simulated audience events cause visible changes within ~2 seconds for deterministic events;
- the AI Director can transform one free-form request into valid bounded game actions;
- the entire experience is capturable in OBS;
- the system does not require real Douyin APIs to test the loop.

## What we are NOT building yet

- real Douyin integration
- 24/7 production hosting
- generative video
- custom-trained models
- complex multiplayer
- final art direction
- production economy balancing

## Product risk to test first

The key unknown is not whether the technology works. It is whether people find it compelling to spend attention or money to alter the world.

Therefore, speed of iteration matters more than polish.
