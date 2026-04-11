# Raider Ranks

`Raider Ranks` is a retail WoW addon for **Midnight / 12.0.x** that adds a native-feeling Mythic+ ranking view for your **guild members** and **friends**.

It uses the **RaiderIO addon** as its Mythic+ data source, can optionally read **AstralKeys** for shared keystones, and embeds itself into the **Group Finder / Mythic+ UI**.

## Why Use Raider Ranks?

Raider Ranks is meant for the moment when you want a fast answer to questions like:

- Who in my guild has actually done this key level?
- Which healer friends are ahead this season?
- Who has already timed my current key dungeon?
- Which tanks are the strongest Mythic+ candidates right now?

It keeps that answer inside WoW, inside the PvE UI, and based on the RaiderIO data you already use.

## Required Dependency

**RaiderIO is required.**

This addon does not ship its own Mythic+ database. It reads RaiderIO's public addon API and depends on RaiderIO being installed and enabled.

## Optional Dependency

**AstralKeys is optional.**

If installed, Raider Ranks will show AstralKeys detection in Settings and surface a selected player's reported key in the detail pane.

## What It Does

- Adds a **Raider Ranks** tab to the Group Finder / Mythic+ frame
- Ranks guild members and friends by **current-season Mythic+ score**
- Shows role-grouped rankings for **Tank**, **Healer**, and **Damage**
- Uses a **class filter** and native-style controls above the table
- Adds a current-key column that quickly shows who has:
  - completed your current key
  - timed it
  - timed it with a **+2**
  - timed it with a **+3**
- Displays timed run buckets for:
  - `20+`
  - `15+`
  - `11+`
  - `9-10`
  - `4-8`
  - `2-3`
- Shows a detail pane for the selected character with:
  - RaiderIO score
  - best run
  - AstralKeys key when available
  - current-key readiness summary
  - dungeon experience matrix by bucket
  - role, spec, and item level when available

## Best-Effort Enrichment

In addition to RaiderIO score data, Raider Ranks can show:

- **spec**
- **equipped item level**

These values are best-effort and come from live/self data or inspect data when available.

Inspect-derived spec and item level are cached, and older cached values are shown in a **greyed out stale state** after 24 hours.

## Ranking Rules

The main ranking is based on Mythic+ progression first.

Primary sort:

1. RaiderIO score
2. Best key level
3. Timed `20+`
4. Timed `15+`
5. Item level as a final tie-breaker when all other M+ values are tied
6. Name

## Opening the Addon

- Open **Group Finder / Mythic+**
- Click the **Raider Ranks** tab

You can also use:

- `/rranks`
- `/raideranks`
