# RaidMitTracker

**Track raid mitigation and external cooldowns in real time — without chat spam.**

> 공대 생존기(공생기) 및 외부생존기 쿨타임 실시간 추적 애드온

---

## Features

- **Addon message communication** — cooldown data is shared silently via `SendAddonMessage`. Nothing appears in raid chat.
- **Auto-detect on join** — members automatically report their available spells when entering a group.
- **Real-time bar tracking** — a smooth, class-colored status bar counts down each cooldown every frame.
- **Combat log backup** — spell casts by members without the addon are still detected via the combat log.
- **Resizable, draggable panel** — position and size are saved between sessions.
- **Solo test mode** — `/rmt test` loads dummy data with random player names so you can preview the UI without a group.
- **English / Korean UI** — automatically switches based on your client locale.

---

## Tracked Spells

### Raid Cooldowns (공생기)

| Spell | Class / Spec | CD |
|---|---|---|
| Power Word: Barrier | Discipline Priest | 3 min |
| Divine Hymn | Holy Priest | 3 min |
| Anti-Magic Zone | Death Knight (any) | 4 min |
| Aura Mastery | Holy Paladin | 3 min |
| Spirit Link Totem | Restoration Shaman | 3 min |
| Healing Tide Totem | Restoration Shaman | 3 min |
| Rewind | Preservation Evoker | 4 min |
| Tranquility | Restoration Druid | 3 min |
| Revival | Mistweaver Monk | 3 min |
| Rallying Cry | Warrior (any) | 3 min |

### External Cooldowns (외부생존기)

| Spell | Class / Spec | CD |
|---|---|---|
| Guardian Spirit | Holy Priest | 3 min |
| Pain Suppression | Discipline Priest | 3 min |
| Ironbark | Restoration Druid | 1.5 min |
| Blessing of Sacrifice | Paladin (any) | 2 min |
| Time Dilation | Preservation Evoker | 1 min |
| Life Cocoon | Mistweaver Monk | 2 min |

---

## Requirements

- **All raid members must install this addon** for full coverage.
  Members without the addon can still be partially tracked via combat log detection, but their spell roster won't be known in advance.

---

## Installation

1. Download and extract the `RaidMitTracker` folder.
2. Place it in: `World of Warcraft/_retail_/Interface/AddOns/`
3. Reload WoW or log in. The addon loads automatically.

---

## Usage

### Commands

| Command | Description |
|---|---|
| `/rmt` | (Raid leader / assistant) Broadcast a CHECK request — all members report their available spells. |
| `/rmt show` | Open the tracker panel (leader / assistant only). |
| `/rmt reset` | Clear all tracked data. |
| `/rmt test` | Load dummy data for solo UI testing. |

### Workflow

1. **All members** install the addon before the raid.
2. **Raid leader** types `/rmt` to request a cooldown check.
3. Each member's addon replies automatically with their available spells.
4. The **panel appears for the leader / assistants** showing every cooldown with a live bar.
5. When a player uses a tracked spell, the bar fills and counts down — no manual input needed.

### Panel

- **Drag** the title bar to reposition.
- **Resize** by dragging the right edge, bottom edge, or corner grip.
- **Close** with the × button (data is preserved until `/rmt reset`).

---

## How It Works

```
Raid leader
  └─ /rmt  →  SendAddonMessage("MITTRACK", "CHECK", "RAID")

Each member's addon
  └─ IsPlayerSpell(spellID) check
  └─ SendAddonMessage("MITTRACK", "HAVE:spellID:cd,...", "RAID")

Raid leader's addon
  └─ Builds roster table
  └─ Shows panel with live cooldown bars

On spell cast (UNIT_SPELLCAST_SUCCEEDED / COMBAT_LOG_EVENT_UNFILTERED)
  └─ SendAddonMessage("MITTRACK", "USED:spellID:timestamp", "RAID")
  └─ endTime = castTime + hardcoded CD  →  bar fills and counts down
```

Cooldown durations are hardcoded in `SpellDB.lua`. Direct API queries to other players' cooldowns are not possible in WoW, so the addon relies on self-reporting and cast event detection.

---

## Limitations

- **Requires addon on all members** for pre-combat roster building. Combat log fallback covers cast events only.
- **Talent-reduced cooldowns** are not currently detected — base cooldown values are used.
- **Cooldown tracking accuracy** depends on members being online when `/rmt` is sent, or being present during a GROUP_ROSTER_UPDATE event.

---

## License

MIT — free to use, modify, and distribute.

**Author:** kimgod1142 · kimgod1142@gmail.com
