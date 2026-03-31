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
- **Resizable, draggable panel** — position and size are saved between sessions.
- **Settings panel** — `/rmt config` opens a full options UI with bar texture, font size, row height, sort mode, and more.
- **Minimap button** — left-click opens settings, right-click opens the tracker panel.
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
| Revival *(talent)* | Mistweaver Monk | 2.5 min |
| Restoral *(talent)* | Mistweaver Monk | 2.5 min |
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
  Members without the addon won't appear in the panel until they cast a tracked spell.

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

On spell cast (UNIT_SPELLCAST_SUCCEEDED — all group members)
  └─ Reads actual cooldown via C_Spell.GetSpellCooldown()
  └─ SendAddonMessage("MITTRACK", "USED:spellID:timestamp:actualCD", "RAID")
  └─ endTime = castTime + actualCD  →  bar fills and counts down
```

Cooldown durations are read from the game API at cast time (`C_Spell.GetSpellCooldown`), so talent reductions are reflected automatically.
Direct cooldown queries on other players are not possible in the WoW API — this addon works around that via self-reporting and group cast event detection.

---

## Limitations

- **Requires addon on all members** for pre-combat roster building. Members without the addon won't appear until they cast.
- **Cooldown tracking accuracy** depends on members being present when `/rmt` is sent, or online during a `GROUP_ROSTER_UPDATE` event.

---

## License

MIT — free to use, modify, and distribute.

**Author:** kimgod1142 · kimgod1142@gmail.com
