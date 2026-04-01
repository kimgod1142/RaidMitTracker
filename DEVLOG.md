# RaidMitTracker — Dev Log

---

## v1.1.0 — Session 4 (2026-04-01)

### 개요
구역 이동 시 로스터 재동기화 문제 해결, 리더 자동 CHECK, `GetCooldown` pcall 강화, autoShow 옵션 추가.
원격(Session 3)에서 작업된 커밋들을 rebase 병합.

---

### 기능 추가

#### `PLAYER_ENTERING_WORLD` — 구역 이동 시 자동 재동기화
- **문제**: 던전 진입·퇴장 시 로스터가 초기화되지 않고 이전 데이터가 잔류. 늦게 합류한 파티원의 스킬 미등록
- **수정**: `zoneFrame`으로 `PLAYER_ENTERING_WORLD` 이벤트 감지
  - 구역 이동 시 `RMT.roster = {}` 초기화
  - 리더/부리더: 3초 후 `RMT_SendCheck()` 자동 전송
  - 일반 파티원: 3초 후 `RMT_SendHave()` 자동 전송

```lua
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
    -- 로그인/리로드는 ADDON_LOADED에서 이미 처리됨 → 구역 이동만 처리
    if isInitialLogin or isReloadingUi then return end
    RMT.roster = {}
    C_Timer.After(3, function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            RMT_SendCheck()
        else
            RMT_SendHave()
        end
    end)
end)
```

---

#### `GROUP_ROSTER_UPDATE` — 리더/부리더 자동 CHECK 전송
- **문제**: 기존에는 GROUP_ROSTER_UPDATE 시 항상 `RMT_SendHave()`만 전송 → 리더가 구성원 변경을 감지해도 CHECK를 보내지 않아 새 파티원 정보 미수집
- **수정**: 리더/부리더 여부에 따라 분기

```lua
-- Before: 모두 HAVE 전송
C_Timer.After(2, RMT_SendHave)

-- After: 리더면 CHECK, 일반 파티원이면 HAVE
C_Timer.After(2, function()
    if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
        RMT_SendCheck()
    else
        RMT_SendHave()
    end
end)
```

---

#### `autoShow` 옵션 — 인스턴스 진입 시 패널 자동 표시
- 신규 SavedVariables 키: `autoShow = false` (기본 비활성)
- `PLAYER_ENTERING_WORLD` 이벤트에서 `IsInInstance()` 체크 → 인스턴스 진입 + 리더/부리더 + `autoShow == true` 조건 충족 시 패널 자동 표시
- `Options.lua` 기능 섹션에 체크박스 추가
- `Locales.lua` `AUTO_SHOW` 키 추가 (EN/KR)

```lua
-- PLAYER_ENTERING_WORLD 핸들러 내
local inInstance = IsInInstance()
if inInstance and RMTdb.autoShow
    and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
    RMT_UI_ShowPanel()
end
```

---

### 버그 수정 / 방어 코딩

#### `GetCooldown()` — pcall 강화 + GCD 오염값 필터
- **배경**: Session 3에서 pcall을 추가했으나 `C_Spell.GetSpellCooldown` 경로만 보호.
  `GetSpellCooldown` (구버전 fallback) 경로는 미보호 상태였음
- **추가 문제**: WoW 12.0에서 `C_Spell.GetSpellCooldown`이 GCD(~1.5s) 상태를 가끔 반환하는 버그 존재 → `duration < 5s`를 유효 쿨타임으로 오해
- **수정**:
  1. 양쪽 API 경로 모두 pcall 보호
  2. `duration < 5` 조건 시 `duration = 0` (GCD 오염값 폐기)

```lua
local function GetCooldown(spellID)
    local start, duration = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and info then
            start    = info.startTime or 0
            duration = info.duration  or 0
        end
    elseif type(GetSpellCooldown) == "function" then
        local ok
        ok, start, duration = pcall(GetSpellCooldown, spellID)
        if not ok then start, duration = 0, 0 end
    end
    if (duration or 0) < 5 then duration = 0 end
    return start, duration
end
```

---

#### `GetChannel()` — INSTANCE_CHAT 크로스렐름 지원 (Session 3 누락분 반영)
- Session 3 DEVLOG에는 기술됐으나 코드에 미반영된 상태였음 → 이번 세션에서 확인 후 적용
- 인스턴스(M+, 공격대) 내에서 `PARTY`/`RAID` 채널이 크로스렐름 파티원에게 미도달하는 문제 수정

```lua
local function GetChannel()
    local inInstance = IsInInstance()
    if IsInRaid()  then return inInstance and "INSTANCE_CHAT" or "RAID"  end
    if IsInGroup() then return inInstance and "INSTANCE_CHAT" or "PARTY" end
    return nil
end
```

---

#### string-keyed 테이블 fallback — 비설치 파티원 추적 강화
- **문제**: WoW 12.0에서 파티원의 `UNIT_SPELLCAST_SUCCEEDED` spellID는 secret value → `RMT_SPELLS[spellID]` (numeric key) 접근 불가. 기존 pcall 방어만으로는 에러를 막지만 추적도 실패
- **해결**: `tostring(secretNumber)`은 허용됨을 이용
  - `RMT_SPELLS_STR[tostring(id)]` = string-keyed 병렬 테이블 (`ADDON_LOADED` 시 초기화)
  - `memberFrame`에서 numeric key pcall 실패 시 string-keyed fallback으로 재시도
  - **효과**: 애드온 미설치 파티원도 공생기 사용을 감지 가능

```lua
-- ADDON_LOADED 시
for id, data in pairs(RMT_SPELLS) do
    RMT_SPELLS_STR[tostring(id)] = data
end

-- memberFrame OnEvent
local ok, result = pcall(function() return RMT_SPELLS[spellID] end)
if ok then
    dbEntry = result
else
    -- secret number → tostring → string key로 조회
    local ok2, sid = pcall(tostring, spellID)
    if ok2 and sid then dbEntry = RMT_SPELLS_STR[sid] end
end
```

---

### Session 3 원격 커밋 rebase 병합

Session 4 작업 전 원격에 Session 3 커밋이 올라와 있어 `git pull --rebase origin main` 후 진행.
병합된 변경사항은 DEVLOG Session 3 섹션 참고.

---

### 변경된 파일
- `RaidMitTracker.lua` — PLAYER_ENTERING_WORLD 핸들러, GROUP_ROSTER_UPDATE CHECK 분기, GetCooldown pcall 전면 강화, GetChannel INSTANCE_CHAT 적용, string-keyed fallback, castFrame pcall 통일
- `Options.lua` — autoShow 체크박스 추가
- `Locales.lua` — AUTO_SHOW 키 추가 (EN/KR), HELP 업데이트
- `AGENTS.md` — Session 4 작업 내용 기록

---

## v1.1.0 — Session 3 (2026-04-01)

### 개요
M+ 실전 테스트에서 발생한 에러 3종 수정, 크로스렐름 지원, 탤런트 쿨감 정보 정리.
BugSack 에러 전부 해소 + 설정창에 사용자 안내 섹션 추가.

---

### 수정된 버그

#### 🔴 `attempt to compare local 'duration' (secret number value)`
- **에러 위치**: `SendUsed()` line 137 — `duration > 2` 비교 시
- **발생 조건**: M+ 전투 중 본인 스킬 사용
- **원인**: WoW 12.0 Secret Value 제약 — 전투 중 `C_Spell.GetSpellCooldown()` 반환값이 taint된 secret value로 마킹됨. 비교/연산 자체가 에러
- **수정**: `pcall`로 감싸 실패 시 DB 하드코딩 기본값으로 폴백

```lua
-- Before
local _, duration = GetCooldown(spellID)
actualCD = (duration and duration > 2) and math.floor(duration) or RMT_SPELLS[spellID].cd

-- After
local ok, cd = pcall(function()
    local _, duration = GetCooldown(spellID)
    return (duration and duration > 2) and math.floor(duration) or nil
end)
actualCD = (ok and cd) or RMT_SPELLS[spellID].cd
```

---

#### 🔴 `ADDON_ACTION_FORBIDDEN` — `Frame:RegisterEvent()` (M+ 재진입 시)
- **에러 위치**: `RegisterFrames()` — `combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")`
- **발생 조건**: M+ 키스톤 던전 진입 시 (로딩 중 다른 애드온이 먼저 taint)
- **원인 1**: `CHAT_MSG_ADDON`을 메인 청크에서 `RegisterEvent` 호출 → taint 유발
- **원인 2**: `RegisterFrames()` 호출이 `ADDON_LOADED` 핸들러 내에서 동기적으로 실행 → 다른 애드온 ADDON_LOADED 핸들러가 taint를 남기면 차단됨
- **수정 1**: `CHAT_MSG_ADDON` 등록을 메인 청크 → `ADDON_LOADED` 이후로 이동
- **수정 2**: `RegisterFrames()` 호출을 `C_Timer.After(0, RegisterFrames)`로 지연 → 모든 ADDON_LOADED 핸들러 완료 후 실행 보장

```lua
-- Before (메인 청크에서 등록 — taint 위험)
loader:RegisterEvent("CHAT_MSG_ADDON")

-- After (ADDON_LOADED 핸들러 안에서 등록)
self:RegisterEvent("CHAT_MSG_ADDON")

-- RegisterFrames 지연 실행
C_Timer.After(0, RegisterFrames)
```

---

#### 🔴 `table index is secret` — `UNIT_SPELLCAST_SUCCEEDED`
- **에러 위치**: `castFrame` OnEvent — `if RMT_SPELLS[spellID] then`
- **발생 조건**: 파티원(party4 등) 스킬 사용 시
- **원인**: WoW 12.0 Secret Value — 파티원의 `UNIT_SPELLCAST_SUCCEEDED` 이벤트에서 수신한 `spellID`가 secret value로 마킹됨. 테이블 인덱스로 사용 불가
- **수정**: `pcall` 보호 + `unitID ~= "player"` 필터 명시

```lua
-- Before
castFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    if RMT_SPELLS[spellID] then SendUsed(spellID) end
end)

-- After
castFrame:SetScript("OnEvent", function(_, _, unitID, _, spellID)
    if unitID ~= "player" then return end
    local ok, inDB = pcall(function() return RMT_SPELLS[spellID] end)
    if ok and inDB then SendUsed(spellID) end
end)
```

---

### 개선

#### 크로스렐름 그룹 지원 — `GetChannel()` INSTANCE_CHAT 분기
- **문제**: WoW 인스턴스 내에서 `PARTY` / `RAID` 채널 애드온 메시지가 크로스렐름 파티원에게 미도달
- **수정**: `IsInInstance()` 체크 추가 → 인스턴스 내에서는 `INSTANCE_CHAT` 사용

```lua
local function GetChannel()
    local inInstance = IsInInstance()
    if IsInRaid()  then return inInstance and "INSTANCE_CHAT" or "RAID"  end
    if IsInGroup() then return inInstance and "INSTANCE_CHAT" or "PARTY" end
    return nil
end
```

---

#### 파티원 감지 방식 교체 — COMBAT_LOG → UNIT_SPELLCAST_SUCCEEDED
- **문제**: `COMBAT_LOG_EVENT_UNFILTERED`가 WoW 12.0에서 restricted event로 변경 → RegisterEvent 시 `ADDON_ACTION_FORBIDDEN` 발생 가능
- **수정**: `memberFrame`에 `UNIT_SPELLCAST_SUCCEEDED`를 party1~4 + raid1~40에 직접 등록

```lua
local memberFrame = CreateFrame("Frame")
local memberUnits = { "party1", "party2", "party3", "party4" }
for i = 1, 40 do memberUnits[#memberUnits + 1] = "raid" .. i end
memberFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unpack(memberUnits))
```

---

#### HAVE 전송 시 실제 탤런트 적용 CD 반영
- **문제**: `CollectMySpells()`가 항상 DB 하드코딩값 전송 → 탤런트로 쿨이 줄어도 파티원 화면에 기본값 표시
- **수정**: 쿨 진행 중일 때 `GetCooldown()`으로 실제값 읽어 전송, 준비 상태면 DB 기본값 폴백

```lua
local ok, cd = pcall(function()
    local _, duration = GetCooldown(spellID)
    return (duration and duration > 2) and math.floor(duration) or nil
end)
local actualCD = (ok and cd) or data.cd
```

---

### SpellDB 업데이트

#### 승천 (114052) 신규 추가
- 주술사 회복 특성 스킬, 기본 CD 180s
- 치유의 해일 토템과 동일하게 최초의 승천자 탤런트 적용 대상

#### 쿨감 탤런트 주석 전면 추가
실전에서 파악된 탤런트 쿨감 목록을 DB 주석으로 정리.
파티원 탤런트는 API로 조회 불가 → 하드코딩 기본값 사용, 주석으로 명시.

| 스킬 | 탤런트 | 기본CD → 적용CD |
|------|--------|----------------|
| 평온 | 내면의 평화 (197073) | 180 → 150 |
| 무쇠 껍질 | 무쇠껍질 연마 (382552) | 90 → 70 |
| 천상의 찬가 | 대천사의 점증 (419110) | 180 → 120 |
| 수호 영혼 | 수호 천사 (200209) | 조건부 — 만료 시 남은 쿨 60s |
| 고통 억제 | 약자의 보호자 (373035) | 충전 +1회 + 보호막 사용 시 3s씩 감소 |
| 재활 / 회복 | 고양된 영혼 (388551) | 150 → 120 |
| 기의 고치 | 번데기 (202424) | 120 → 75 |
| 되돌리기 | 시간의 기술자 (381922) | 240 → 180 |
| 치유의 해일 토템 / 승천 | 최초의 승천자 (462440) | 180 → 120 |

> 수호 영혼 / 고통 억제는 런타임 조건부 또는 동적 감소 → 추적 구조상 정확한 반영 불가

---

### Options.lua — 추적 정확도 안내 섹션 추가
- 설정창 하단에 접기/펼치기 가능한 안내 섹션 추가
- 대상: 공대장/레이더가 쿨타임 수치를 맹신하지 않도록 안내
- 내용:
  - WoW API 제약 (전투 중 타인 쿨타임 조회 불가) 설명
  - 탤런트 쿨감으로 부정확할 수 있는 스킬 전체 목록
  - 정확하게 추적되는 케이스 안내

---

### 변경된 파일
- `RaidMitTracker.lua` — Secret value pcall, INSTANCE_CHAT, CHAT_MSG_ADDON taint 수정, UNIT_SPELLCAST_SUCCEEDED 파티원 감지, C_Timer 지연, HAVE CD 실제값
- `SpellDB.lua` — 승천(114052) 추가, 쿨감 탤런트 주석 9개 스킬
- `Options.lua` — 추적 정확도 안내 섹션 (접기/펼치기)

---

## v1.0.0 — Session 2 (2026-03-31)

### 개요
WoW API 비호환 버그 3종 수정, 자기 자신 스킬 추적 구조 개선, UI 기본값 및 슬라이더 범위 조정.
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
- **원인**: WoW에서 `GetSpellCharges` 전역 함수가 `C_Spell.GetSpellCharges`로 이동됨. 전역 호출 시 nil
- **수정**: 양쪽 호환 처리

```lua
local getCharges = (C_Spell and C_Spell.GetSpellCharges)
               or (type(GetSpellCharges) == "function" and GetSpellCharges)
```

---

#### 🔴 `GetSpellCooldown` nil
- **에러 위치**: `RunTestMode()` — 내 캐릭터 실제 스킬 추가 로직
- **원인**: `GetSpellCharges`와 동일하게 WoW에서 `C_Spell.GetSpellCooldown`으로 이동됨. 추가로 반환값도 변경됨
  - 구버전: `start, duration, enabled, modRate` (다중 반환)
  - WoW: `{ startTime, duration, isEnabled, modRate }` (테이블 반환)
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

#### 🔴 SetCursor — 리사이즈 핸들에서 검은 정사각형 커서 표시
- **에러 위치**: `UI.lua` — `MakeEdgeHandle()` OnEnter/OnLeave
- **원인**: `SetCursor("SIZE_RIGHT")` 등 커서 변경 API가 WoW에서 제거됨. 호출 시 검은 정사각형이 마우스 커서 위치에 나타남
- **수정**: `SetCursor` 호출 전체 제거. 리사이즈 핸들 함수 시그니처도 단순화 (`cursor` 파라미터 제거)

---

### 기능 추가

#### 전멸 감지 — DoWipeReset()
- `PLAYER_REGEN_DISABLED` / `BOSS_KILL` / `PLAYER_REGEN_ENABLED` 3개 이벤트 조합으로 전멸/소프트리셋 감지
- 전투 진입 시 `wasInEncounter = true`, 보스 킬 시 `bossKilled = true`
- 전투 종료 (`PLAYER_REGEN_ENABLED`) 시 `wasInEncounter == true && bossKilled == false` → 전멸로 판정
- `DoWipeReset()`: 전 공대원의 모든 스킬 `endTime = 0` 초기화 후 패널 갱신
- `Locales.lua`에 `WIPE_RESET` 키 추가 (EN / KR)

> 참고: `ENCOUNTER_END` (보호된 이벤트, 애드온 차단)와 `PLAYER_DEAD` (솔로 죽음도 감지되는 오탐 위험)을 거쳐 최종 BOSS_KILL 기반으로 확정

---

#### Options.lua — 설정창 신규 추가 (469줄)
초기 배포 시 없던 설정창이 통째로 추가됨. (기존 "슬라이더 범위 수정"은 이 파일의 수정이 아닌 신규 생성)

**시각 설정 (Visual)**
| 슬라이더 | 범위 | 기본값 |
|---|---|---|
| 배경 투명도 (bgAlpha) | 0.1 ~ 1.0 | 0.55 |
| 행 높이 (rowHeight) | 20 ~ 68 px | 44 px |
| 바 두께 (barHeight) | 4 ~ 68 px | 36 px |
| 아이콘 크기 (iconSize) | 14 ~ 58 px | 36 px |
| 폰트 크기 (fontSize) | 8 ~ 28 pt | 18 |
| 행 간격 (rowSpacing) | 0 ~ 24 px | 0 px |

**텍스처 드롭다운**: LibSharedMedia-3.0 통합 → 게임 내 상태바 텍스처 목록, 스크롤 지원, 선택 시 미리보기 표시

**정렬 모드 드롭다운**: `이름순 (name)` / `쿨타임 남은순 (cd)` 선택

**토글 옵션**
- `showIcon`: 스킬 아이콘 표시/숨기기 (숨기면 바가 왼쪽으로 확장)
- `tooltipOn`: 아이콘 호버 시 스펠 툴팁 표시/숨기기

**UX**
- ESC 키로 닫기 (`UISpecialFrames` 등록)
- 옵션 변경 시 80ms 디바운싱 후 패널 즉시 갱신
- 설정창 열릴 때 자동 test mode 진입 (미리보기용)

---

#### 미니맵 버튼 (LibDBIcon)
- 미니맵 버튼 추가 — 좌클릭: `/rmt show`, 우클릭: 설정창 열기
- 버튼 위치 `RMTdb.minimap`에 저장 (드래그 이동 가능)
- 라이브러리 3개 추가:
  - `libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua` — 텍스처/폰트 레지스트리
  - `libs/LibDataBroker-1.1/LibDataBroker-1.1.lua` — 미니맵 데이터 소스 표준
  - `libs/LibDBIcon-1.0/LibDBIcon-1.0.lua` — 미니맵 버튼 생성/관리

---

#### 스펠 툴팁 (UI.lua)
- 아이콘 위에 투명 히트박스 프레임 (`iconHover`) 추가
- 마우스 호버 시 `GameTooltip:SetSpellByID(spellID)` — 게임 내 공식 스펠 정보 표시
- `tooltipOn == false`이면 비활성화 (Options에서 제어)

---

#### USED 메시지 포맷 변경
- 기존: `USED:spellID:timestamp`
- 변경: `USED:spellID:timestamp:actualCD`
- 탤런트로 감소된 실제 쿨타임 포함 → 수신 공대원도 정확한 쿨타임으로 계산 가능

---

#### 충전 스킬 처리 (희생의 축복 등)
- 충전이 남아있으면 스킬 사용 이벤트 무시 (아직 준비됨)
- 마지막 충전 소모 시에만 쿨타임 시작
- `chargeDuration` 기반 실제 충전 복구 시간 사용

---

#### `/rmt test` — 내 캐릭터 실제 스킬 추가
- 기존 랜덤 샘플 캐릭터 유지 + 현재 캐릭터의 실제 보유 공생기 스킬 추가 표시
- `IsPlayerSpell(spellID)`로 보유 여부 확인
- `GetCooldown(spellID)`로 실제 쿨타임 잔여시간 반영
- 해당 직업에 공생기 없으면 행 자체 생략

---

### SpellDB 아이콘 ID 수정

WoW 패치에서 스프라이트시트 재구성으로 리소스 ID 변경된 스킬 8개 수정:

| 스펠 ID | 스킬명 | 이전 아이콘 | 새 아이콘 |
|---|---|---|---|
| 62618 | Power Word: Barrier | 135926 | 253400 |
| 363534 | Rewind | 4622465 | 4622474 |
| 297850 | Revival | 574586 | 1020466 |
| 33206 | Pain Suppression | 135960 | 135936 |
| 357170 | Time Dilation | 4622427 | 4622478 |
| 116849 | Life Cocoon | 627487 | 627485 |

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
- `RaidMitTracker.lua` — GetCooldown 헬퍼, ProcessUsed 구조, RegisterFrames, 충전 스킬, USED 포맷, 전멸 감지, test mode
- `UI.lua` — SetCursor 제거, MakeRow 동적화(rowHeight/iconSize/barHeight/barTexture), 스펠 툴팁, 정렬 모드, 아이콘 토글, 행 간격
- `SpellDB.lua` — 아이콘 ID 6개 수정
- `Locales.lua` — WIPE_RESET 키 추가
- `Options.lua` — **신규 생성** (469줄, 설정창 전체)
- `RaidMitTracker.toc` — 라이브러리 3개 + Options.lua 로드 순서 추가
- `libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua` — **신규**
- `libs/LibDataBroker-1.1/LibDataBroker-1.1.lua` — **신규**
- `libs/LibDBIcon-1.0/LibDBIcon-1.0.lua` — **신규**

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
| 재활 스펠 ID 오류 | 115310 (MoP Classic 버전) | 297850 (WoW 정식 ID) 로 수정 |

---

### 파일 구조

```
RaidMitTracker/
├── RaidMitTracker.toc
├── RaidMitTracker.lua        ← 통신 + 이벤트 + 슬래시 커맨드
├── SpellDB.lua               ← 스킬 테이블 (name_en 포함)
├── UI.lua                    ← 패널 UI
├── Options.lua               ← 설정창 (Session 2 추가)
├── Locales.lua               ← EN/KR 로케일
├── libs/LibStub/LibStub.lua
├── libs/LibSharedMedia-3.0/  ← Session 2 추가
├── libs/LibDataBroker-1.1/   ← Session 2 추가
├── libs/LibDBIcon-1.0/       ← Session 2 추가 (미니맵 버튼)
├── README.md                 ← GitHub 배포용
├── DEVLOG.md                 ← 이 파일
└── curseforge-description.html ← CurseForge 업로드용
```

### SavedVariables (`RMTdb`)
```lua
RMTdb = {
    panelPos  = { pt, rpt, x, y },   -- 패널 위치
    panelSize = { w, h },            -- 패널 크기
    -- Session 2 추가
    bgAlpha     = 0.55,
    rowHeight   = 44,
    barHeight   = 36,
    iconSize    = 36,
    fontSize    = 18,
    rowSpacing  = 0,
    barTexture  = "...",
    sortMode    = "name",
    showIcon    = true,
    tooltipOn   = true,
    minimap     = { minimapPos = 200 },
}
```

---

### 배포 현황
- GitHub: https://github.com/kimgod1142/RaidMitTracker
- CurseForge: 심사 요청 중
- 배포 파일: `RaidMitTracker-1.0.0.zip`
