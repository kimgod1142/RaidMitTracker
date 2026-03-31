# RaidMitTracker

**Track raid mitigation and external cooldowns in real time — without chat spam.**

> 공대 생존기(공생기) 및 외부생존기 쿨타임 실시간 추적 애드온

---

## Features

- **Silent communication** — cooldown data is shared via `SendAddonMessage`. Nothing appears in raid chat.
- **Auto-detect on join** — members automatically report their available spells when entering a group.
- **Real-time bar tracking** — smooth, class-colored status bars count down each cooldown every frame.
- **Group cast detection** — spell casts by all group members are detected via `UNIT_SPELLCAST_SUCCEEDED`.
- **Talent-aware cooldowns** — actual cooldown duration is read from the game API at cast time, not hardcoded.
- **Cross-realm support** — uses `INSTANCE_CHAT` automatically when inside a dungeon or raid instance.
- **Resizable, draggable panel** — position and size are saved between sessions.
- **Settings panel** — `/rmt config` opens a full options UI with bar texture, font size, row height, sort mode, and more.
- **Accuracy notice** — the settings panel includes a collapsible section explaining which spells may be inaccurate and why.
- **Minimap button** — left-click opens settings, right-click opens the tracker panel.
- **Solo test mode** — `/rmt test` loads dummy data with random player names so you can preview the UI without a group.
- **English / Korean UI** — automatically switches based on your client locale.

---

## Tracked Spells

### Raid Cooldowns (공생기)

| Spell | Class / Spec | Base CD | Known Talent Reduction |
|---|---|---|---|
| Power Word: Barrier | Discipline Priest | 3 min | — |
| Divine Hymn | Holy Priest | 3 min | Arcane Tome of Light: −60s |
| Anti-Magic Zone | Death Knight (any) | 4 min | — |
| Aura Mastery | Holy Paladin | 3 min | — |
| Spirit Link Totem | Restoration Shaman | 3 min | — |
| Healing Tide Totem *(talent)* | Restoration Shaman | 3 min | Primal Tide Core: −60s |
| Ascendance *(talent)* | Restoration Shaman | 3 min | Primal Tide Core: −60s |
| Rewind | Preservation Evoker | 4 min | Master of Time: −60s |
| Tranquility | Restoration Druid | 3 min | Inner Peace: −30s |
| Revival *(talent)* | Mistweaver Monk | 2.5 min | Uplifted Spirits: −30s |
| Restoral *(talent)* | Mistweaver Monk | 2.5 min | Uplifted Spirits: −30s |
| Rallying Cry | Warrior (any) | 3 min | — |

### External Cooldowns (외부생존기)

| Spell | Class / Spec | Base CD | Known Talent Reduction |
|---|---|---|---|
| Guardian Spirit | Holy Priest | 3 min | ⚠️ Guardian Angel: conditional (see below) |
| Pain Suppression | Discipline Priest | 3 min | ⚠️ Protector of the Frail: +1 charge + dynamic (see below) |
| Ironbark | Restoration Druid | 1.5 min | Ironbark Toughening: −20s |
| Blessing of Sacrifice | Paladin (any) | 2 min | — |
| Time Dilation | Preservation Evoker | 1 min | — |
| Life Cocoon | Mistweaver Monk | 2 min | Chrysalis: −45s |

---

## Cooldown Accuracy

Cooldowns shown in the panel are **estimates, not guaranteed values.**

> The WoW API (12.0+) does not allow addons to query other players' cooldown timers during combat. This addon works around that limitation using self-reporting and cast event detection.

**For your own character:** actual talent-reduced cooldowns are read from the API and used automatically.

**For other players:** cooldowns are calculated as `cast time + base CD`. Talent reductions are reflected only after the first cast is observed in a session.

### Spells with known inaccuracies

| Spell | Issue |
|---|---|
| Guardian Spirit | Guardian Angel talent: if the spell expires *without* saving the target, remaining CD drops to 60s. Cannot be tracked remotely. |
| Pain Suppression | Protector of the Frail talent: adds 1 extra charge + reduces CD by 3s per Power Word: Shield cast. Dynamic reduction — cannot be tracked remotely. |
| All talent-reduced spells | Talent ownership of other players cannot be queried via the API. Base CD is used until the first cast is seen. |

The settings panel (`/rmt config`) includes a full collapsible breakdown of these limitations for raid leaders.

---

## Requirements

- **All raid/party members should install this addon** for full coverage.
  Members without the addon won't appear in the panel until they cast a tracked spell (detected via combat log).
- Works in **5-man parties, M+ keystones, and raids** (including cross-realm groups).

---

## Installation

1. Download `RaidMitTracker-vX.X.X.zip` from the [Releases](../../releases) page.
2. Extract and place the `RaidMitTracker` folder into: `World of Warcraft/_retail_/Interface/AddOns/`
3. Reload WoW or log in.

---

## Usage

### Commands

| Command | Description |
|---|---|
| `/rmt` | (Leader / assistant) Broadcast a CHECK — all members report their available spells. |
| `/rmt show` | Open the tracker panel (leader / assistant only). |
| `/rmt config` | Open the settings panel. |
| `/rmt test` | Load dummy data for solo UI testing. |
| `/rmt reset` | Clear all tracked data. |

### Workflow

1. **All members** install the addon before the raid or M+ key.
2. **Raid leader or assist** types `/rmt` to request a cooldown check.
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
  └─ /rmt  →  SendAddonMessage("MITTRACK", "CHECK", "RAID" | "INSTANCE_CHAT")

Each member's addon
  └─ IsPlayerSpell(spellID) check
  └─ Reads actual CD via C_Spell.GetSpellCooldown() (talent reductions included)
  └─ SendAddonMessage("MITTRACK", "HAVE:spellID:cd,...", channel)

Raid leader's addon
  └─ Builds roster table
  └─ Shows panel with live cooldown bars

On spell cast (UNIT_SPELLCAST_SUCCEEDED — self + all party/raid members)
  └─ Reads actual cooldown via C_Spell.GetSpellCooldown()
  └─ SendAddonMessage("MITTRACK", "USED:spellID:timestamp:actualCD", channel)
  └─ endTime = castTime + actualCD  →  bar fills and counts down
```

**Channel selection** is automatic:
- Inside a dungeon/raid instance → `INSTANCE_CHAT` (cross-realm safe)
- Open world party → `PARTY`
- Open world raid → `RAID`

---

## License

MIT — free to use, modify, and distribute.

**Author:** kimgod1142 · kimgod1142@gmail.com
