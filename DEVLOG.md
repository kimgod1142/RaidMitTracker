# RaidMitTracker — Dev Log

---

## v1.0.0 — Session 2 (2026-03-31)

### 개요
TWW API 비호환 버그 3종 수정, 자기 자신 스킬 추적 구조 개선, UI 기본값 및 슬라이더 범위 조정.
다른 사람에게 배포 시 BugSack 에러 7~6회 발생하던 문제 전부 해결.

---

### 수정된 버그

#### 🔴 `ADDON_ACTION_FORBIDDEN` (6~7회 반복)
- **에러 위치**: `RaidMitTracker.lua` main chunk — `combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")`
- **원인**: `castFrame`, `combatFrame`, `wipeFrame`, `rosterFrame` 4개 프레임이 파일 최상단(main chunk)에서 `CreateFrame` + `RegisterEvent` 호출. 다른 애드온이 먼저 로드되면서 Lua 상태가 taint되면 이후 `RegisterEvent` 호출이 `ADDON_ACTION_FORBIDDEN`으로 차단됨
- **수정**: 4개 프레임 생성 전체를 `RegisterFrames()` 함수로 묶고, `ADDON_LOADED` 핸들러 안에서 호출 — taint 이전에 실행 보장

```lua
-- Before: 파일 최상단에서 직접 생성 (위험)
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")  -- ← ADDON_ACTION_FORBIDDEN

-- After: ADDON_LOADED 이후에만 실행
local function RegisterFrames()
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")  -- ← 안전
    ...
end
-- ADDON_LOADED 핸들러 안에서: RegisterFrames()
```

---

#### 🔴 `GetSpellCharges` nil (3회)
- **에러 위치**: `SendUsed()` — spellID=6940 (희생의 축복) 처리 시
- **원인**: TWW(The War Within)에서 `GetSpellCharges` 전역 함수가 `C_Spell.GetSpellCharges`로 이동됨. 전역 호출 시 nil
- **수정**: 양쪽 호환 처리

```lua
local getCharges = (C_Spell and C_Spell.GetSpellCharges)
               or (type(GetSpellCharges) == "function" and GetSpellCharges)
```

---

#### 🔴 `GetSpellCooldown` nil
- **에러 위치**: `RunTestMode()` — 내 캐릭터 실제 스킬 추가 로직
- **원인**: `GetSpellCharges`와 동일하게 TWW에서 `C_Spell.GetSpellCooldown`으로 이동됨. 추가로 반환값도 변경됨
  - 구버전: `start, duration, enabled, modRate` (다중 반환)
  - TWW: `{ startTime, duration, isEnabled, modRate }` (테이블 반환)
- **수정**: `GetCooldown()` 헬퍼 함수 추가 — 양쪽 API 모두 처리, 통일된 인터페이스 제공

```lua
local function GetCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        return (info and info.startTime or 0), (info and info.duration or 0)
    elseif type(GetSpellCooldown) == "function" then
        return GetSpellCooldown(spellID)
    end
    return 0, 0
end
```

---

#### 🔴 전투 로그 spellID 오독 (추적 무반응 원인)
- **에러 위치**: `combatFrame` OnEvent — `COMBAT_LOG_EVENT_UNFILTERED` 핸들러
- **원인**: `CombatLogGetCurrentEventInfo()` 반환값 순서 오해. `SPELL_CAST_SUCCESS` 기준으로:
  - position 12 = spellID ✅
  - position 14 = spellSchool ❌ (기존 코드가 이걸 읽고 있었음)
- **수정**: `select(12, CombatLogGetCurrentEventInfo())`

```lua
-- Before (잘못됨 — spellSchool을 spellID로 읽음)
local _, _, _, _, _, spellID = select(9, CombatLogGetCurrentEventInfo())
-- select(9,...) 에서 6번째 = position 14 = spellSchool

-- After (올바름)
local spellID = select(12, CombatLogGetCurrentEventInfo())
```

---

#### 🔴 공대장/솔로 환경에서 본인 스킬 사용이 패널에 미반영
- **원인**: `SendUsed()` 내부에서 `GetChannel()` == nil (그룹 없음)이면 즉시 return. 패널 업데이트가 전혀 없었음. 그룹에 있어도 자신이 보낸 USED 메시지가 돌아와야만 업데이트 → 구조적으로 불안정
- **수정**: `ProcessUsed()` 함수 도입. 로컬 즉시 반영 후 그룹 브로드캐스트 분리

```lua
-- 로컬 즉시 처리 (항상 실행)
local function ProcessUsed(name, spellID, castTime, actualCD)
    -- RMT.roster 업데이트 + RMT_UI_RefreshPanel()
end

local function SendUsed(spellID)
    -- ① 항상: 로컬 즉시 반영
    ProcessUsed(UnitName("player"), spellID, GetTime(), actualCD)
    -- ② 그룹 있을 때만: 공대원에게 브로드캐스트
    local ch = GetChannel()
    if ch then C_ChatInfo.SendAddonMessage(...) end
end

-- OnAddonMessage에서 본인 USED는 중복 방지로 스킵
if name == UnitName("player") then return end
ProcessUsed(name, ...)
```

---

### 기능 추가

#### `/rmt test` — 내 캐릭터 실제 스킬 추가
- 기존 랜덤 샘플 캐릭터 유지 + 현재 캐릭터의 실제 보유 공생기 스킬 추가 표시
- `IsPlayerSpell(spellID)`로 보유 여부 확인
- `GetCooldown(spellID)`로 실제 쿨타임 잔여시간 반영
- 해당 직업에 공생기 없으면 행 자체 생략

---

### UI 기본값 및 슬라이더 범위 조정

**배경**: "UI가 너무 작다"는 피드백 → 실제로 사용하기 좋은 크기를 슬라이더 중간값으로 설정

| 항목 | 이전 기본값 | 새 기본값 | 이전 범위 | 새 범위 |
|------|-----------|---------|---------|---------|
| 배경 투명도 | 0.96 | 0.55 | 0.1~1.0 | 0.1~1.0 (변동 없음) |
| 행 높이 | 28 px | 44 px | 20~44 | **20~68** |
| 바 두께 | 16 px | 36 px | 4~36 | **4~68** |
| 아이콘 크기 | 22 px | 36 px | 14~36 | **14~58** |
| 폰트 크기 | 11 | 18 | 8~18 | **8~28** |
| 행 간격 | 3 px | 0 px | 0~12 | **0~24** |

> ⚠️ 기존 설치자는 `WTF/.../SavedVariables/RaidMitTracker.lua` 삭제 시 새 기본값 적용

---

### 변경된 파일
- `RaidMitTracker.lua` — GetCooldown 헬퍼, ProcessUsed 구조, RegisterFrames, 기본값, test mode
- `Options.lua` — 슬라이더 범위 수정

---

## v1.0.0 (2026-03-30) — Initial Release

### 개요
공대 생존기(공생기) 및 외부생존기 쿨타임 실시간 추적 애드온 첫 배포.

---

### 구현된 기능

#### 통신 (RaidMitTracker.lua)
- `SendAddonMessage` 기반 조용한 통신 — 채팅창에 아무것도 안 뜸
- `CHECK` → `HAVE` → `USED` 3단계 프로토콜
- `UNIT_SPELLCAST_SUCCEEDED` — 본인 스킬 사용 감지
- `COMBAT_LOG_EVENT_UNFILTERED` — 애드온 미설치 공대원 백업 감지
- `GROUP_ROSTER_UPDATE` — 공대 합류 2초 후 자동 보고

#### 스킬 DB (SpellDB.lua)
- 공생기 10종 + 외부생존기 6종
- 필드: `name` (한국어), `name_en` (영어), `cd`, `class`, `spec`, `category`, `icon`, `isTalent`

| 스펠 ID | 스킬명 | 영문명 | 쿨타임 |
|---|---|---|---|
| 62618 | 신의 권능: 방벽 | Power Word: Barrier | 3분 |
| 64843 | 천상의 찬가 | Divine Hymn | 3분 |
| 51052 | 대마법 지대 | Anti-Magic Zone | 4분 |
| 31821 | 오라 숙련 | Aura Mastery | 3분 |
| 98008 | 정신의 고리 토템 | Spirit Link Totem | 3분 |
| 108280 | 치유의 해일 토템 | Healing Tide Totem | 3분 |
| 363534 | 되돌리기 | Rewind | 4분 |
| 740 | 평온 | Tranquility | 3분 |
| 297850 | 재활 | Revival | 3분 |
| 97462 | 재집결의 함성 | Rallying Cry | 3분 |
| 47788 | 수호 영혼 | Guardian Spirit | 3분 |
| 33206 | 고통 억제 | Pain Suppression | 3분 |
| 102342 | 무쇠 껍질 | Ironbark | 1.5분 |
| 6940 | 희생의 축복 | Blessing of Sacrifice | 2분 |
| 357170 | 시간 팽창 | Time Dilation | 1분 |
| 116849 | 기의 고치 | Life Cocoon | 2분 |

#### UI (UI.lua)
- 공대장/부공대장 전용 패널 (UnitIsGroupLeader / UnitIsGroupAssistant)
- 레이아웃: `[플레이어명 80px][스킬아이콘 22px][직업색 쿨타임바 ────][남은초]`
- `OnUpdate` 매 프레임 갱신 (부드러운 바 애니메이션)
- 직업 색상: UnitClass → SpellDB.class 2단계 fallback
- 쿨타임 종료 / 미사용 시 바 중앙에 "Ready" / "사용가능" 표시
- 드래그 이동 + 오른쪽/하단/모서리 리사이즈, 위치·크기 `RMTdb`에 저장

#### 로케일 (Locales.lua)
- EN 기본 + koKR 오버라이드 (`RMT_L` 글로벌)
- 키: TITLE / READY / LEADER_ONLY / NOT_IN_GROUP / CHECK_SENT / REPORTED / RESET_DONE / HELP / LOADED / TEST_MODE

#### 테스트 모드
- `/rmt test` — 솔로 UI 테스트용 더미 데이터 로드
- 이름: 랜덤 형용사+직업명 (KR: `배고픈드루이드` / EN: `angryWarrior`)
  - 한국어 형용사 10개 + 영어 형용사 10개 조합
  - 실행마다 다른 이름, 중복 시 숫자 접미사 처리

---

### 수정된 버그

| 버그 | 원인 | 수정 |
|---|---|---|
| `/rmt show` 후 엔터 불가 (채팅 잠김) | `local RMT`로 선언 → UI.lua에서 nil 참조 → Lua 에러 | `RMT` 글로벌로 변경 |
| USED 메시지 파싱 실패 | Lua 패턴에 `\d` 사용 (Lua는 `%d`) | `[%d%.]+` 로 수정 |
| 준비 상태 플레이어 표시 없음 | `endTime=0` 분기에서 near-black 색상 텍스트 | readyText FontString으로 교체 |
| 재활 스펠 ID 오류 | 115310 (MoP Classic 버전) | 297850 (TWW 정식 ID) 로 수정 |

---

### 파일 구조

```
RaidMitTracker/
├── RaidMitTracker.toc
├── RaidMitTracker.lua        ← 통신 + 이벤트 + 슬래시 커맨드
├── SpellDB.lua               ← 스킬 테이블 (name_en 포함)
├── UI.lua                    ← 패널 UI
├── Locales.lua               ← EN/KR 로케일
├── libs/LibStub/LibStub.lua
├── README.md                 ← GitHub 배포용
├── DEVLOG.md                 ← 이 파일
└── curseforge-description.html ← CurseForge 업로드용
```

### SavedVariables (`RMTdb`)
```lua
RMTdb = {
    panelPos  = { pt, rpt, x, y },   -- 패널 위치
    panelSize = { w, h },            -- 패널 크기
}
```

---

### 배포 현황
- GitHub: https://github.com/kimgod1142/RaidMitTracker
- CurseForge: 심사 요청 중
- 배포 파일: `RaidMitTracker-1.0.0.zip`
