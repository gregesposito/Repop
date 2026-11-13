# Repop

Fixes **"invisible NPC"** problems when multi-boxing. Sometimes the server never sends a character the spawn packet for an important NPC (a Dimensional Portal, a `???`, a home point), so that character can't see or target it and a bot stalls. Repop remembers the NPC packets that *any* of your characters receive, shares them over IPC, and re-injects them on a character that's missing the NPC.

- **Author:** PBW (fork maintained by Kriz) · **Version:** 2.1.0
- **Command:** `//repop`
- **File:** `Repop.lua`

---

## Loading

1. Copy the folder to `Windower/addons/Repop/`.
2. Load it on **every** character: `mc send lua load repop` (or add it to each character's init script). It only helps when more than one character runs it, because they share NPC data over IPC.

---

## How it works

1. On each zone-in (outgoing 0x00C), it builds a list of the zone's NPCs whose names are on the **whitelist** (below).
2. Whenever a character receives an NPC update (incoming **0x00E**) for a whitelisted NPC that is visible and targetable, it stores the raw packet for that zone and broadcasts it to your other characters by IPC.
3. On every position update (outgoing 0x015, starting 12 s after zoning), it checks stored NPCs within **45 yalms**. If the client has no model for one, it **injects** the stored 0x00E packet so the NPC appears, and prints a warning naming it.
4. It does nothing inside a battlefield (while buff 254 is active).

### Whitelisted NPCs
```lua
mob_name_whitelist = S{'Dimensional Portal','Transcendental Radiance','Incantrix','Survival Guide',
                       'Home Point #2','Infernal Transposer','???','Peculiar Footprints','Swirling Vortex'}
```
Add names here if another NPC regularly fails to appear.

---

## Commands

| Command | What it does |
|---|---|
| `//repop showstorage` | Lists the stored NPCs for the current zone. |
| `//repop showstorage <zone id>` | Lists the stored NPCs for a specific zone. |
| `//repop showmoblist` | Shows the whitelisted NPCs found in the current zone's mob list. |

---

## Changes in this fork

| Date | Change |
|---|---|
| Oct 2023 | Added `???` to the whitelist (Provenance and other zones that use `???` entry points). |
| Jan 2025 | Added `Peculiar Footprints`. |
| May 2026 | Added `Swirling Vortex` (Apollyon entrance). |

Upstream: [PeachBlossomWine/Repop](https://github.com/PeachBlossomWine/Repop).

## Caveats
- Stored packets live in memory only and are cleared when the addon unloads.
- Injected packets are a snapshot. If an NPC really moved or despawned, the injected copy can be stale until a real update arrives.
