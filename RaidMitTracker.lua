-- RaidMitTracker.lua
-- 공대 생존기(공생기) 쿨타임 추적 애드온
-- 공대원 전원 설치 필요 — 공대장/부공대장 화면에만 UI 표시
--
-- Author:  kimgod1142
-- Contact: kimgod1142@gmail.com
-- License: MIT

local ADDON_NAME = "RaidMitTracker"
local VERSION    = "1.1.0"
local PREFIX     = "MITTRACK"   -- SendAddonMessage 프리픽스 (최대 16자)

-- ================================================================
-- STATE
-- ================================================================
-- ⚠️ RMT는 global — UI.lua 등 다른 파일에서도 참조함
RMT = {
    -- [playerName] = { [spellID] = { cd = 180, usedAt = nil, endTime = nil } }
    roster   = {},
    db       = nil,
}

-- ================================================================
-- HELPERS
-- ================================================================
local function Log(msg)
    print("|cffff9900[RMT]|r " .. tostring(msg))
end

local function IsLeaderOrAssist()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function GetChannel()
    if IsInRaid()  then return "RAID"  end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- TWW 호환 쿨타임 조회
-- 구버전: GetSpellCooldown(id) → start, duration
-- TWW:    C_Spell.GetSpellCooldown(id) → { startTime, duration, ... }
local function GetCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        return (info and info.startTime or 0), (info and info.duration or 0)
    elseif type(GetSpellCooldown) == "function" then
        return GetSpellCooldown(spellID)
    end
    return 0, 0
end

-- 본인이 보유한 공생기 스펠 ID 목록 수집
local function CollectMySpells()
    local result = {}
    for spellID, data in pairs(RMT_SPELLS) do
        if IsPlayerSpell(spellID) then
            result[#result + 1] = spellID .. ":" .. data.cd
        end
    end
    return result
end

-- ================================================================
-- COMMUNICATION
-- ================================================================

-- CHECK 전송 (공대장이 사용)
function RMT_SendCheck()
    local ch = GetChannel()
    if not ch then
        Log(RMT_L.NOT_IN_GROUP)
        return
    end
    C_ChatInfo.SendAddonMessage(PREFIX, "CHECK", ch)
    Log(RMT_L.CHECK_SENT)

    -- 본인도 응답
    RMT_SendHave()
end

-- HAVE 전송 (본인 보유 스킬 보고)
function RMT_SendHave()
    local ch = GetChannel()
    if not ch then return end

    local spells = CollectMySpells()
    if #spells == 0 then return end

    -- 254자 제한 대비: 한 메시지에 최대 10개씩
    local CHUNK = 10
    for i = 1, #spells, CHUNK do
        local slice = {}
        for j = i, math.min(i + CHUNK - 1, #spells) do
            slice[#slice + 1] = spells[j]
        end
        C_ChatInfo.SendAddonMessage(PREFIX, "HAVE:" .. table.concat(slice, ","), ch)
    end
end

-- 스킬 사용 로컬 반영 (메시지 수신 및 자기 자신 모두 이 함수로 처리)
local function ProcessUsed(name, spellID, castTime, actualCD)
    if not RMT.roster[name] then RMT.roster[name] = {} end
    if not RMT.roster[name][spellID] then
        local dbEntry = RMT_SPELLS[spellID]
        RMT.roster[name][spellID] = { cd = dbEntry and dbEntry.cd or 180, endTime = 0 }
    end
    local entry   = RMT.roster[name][spellID]
    local cd      = actualCD or entry.cd
    entry.endTime = castTime + cd
    RMT_UI_RefreshPanel()
end

-- USED 처리: 로컬 즉시 반영 + 그룹이면 공대원에게도 브로드캐스트
-- 솔로/공대장 본인 사용 모두 정상 작동
local function SendUsed(spellID)
    local now  = GetTime()
    local name = UnitName("player")

    -- TWW: GetSpellCharges → C_Spell.GetSpellCharges 로 이동됨 (하위 호환 처리)
    -- ⚠️ C_Spell.GetSpellCharges는 테이블 반환 가능성 있음 (C_Spell.GetSpellCooldown과 동일 패턴)
    --    테이블/다중반환 양쪽 모두 처리
    local actualCD
    do
        local currentCharges, maxCharges, chargeDuration
        if C_Spell and C_Spell.GetSpellCharges then
            local r1, r2, r3, r4 = C_Spell.GetSpellCharges(spellID)
            if type(r1) == "table" then
                -- TWW 테이블 반환 형식: { currentCharges, maxCharges, chargeStartTime, chargeDuration }
                currentCharges = r1.currentCharges
                maxCharges     = r1.maxCharges
                chargeDuration = r1.chargeDuration
            else
                -- 구버전 다중 반환 형식
                currentCharges, maxCharges, _, chargeDuration = r1, r2, r3, r4
            end
        elseif type(GetSpellCharges) == "function" then
            currentCharges, maxCharges, _, chargeDuration = GetSpellCharges(spellID)
        end

        -- 충전 스킬: 충전이 남아있으면 아직 사용 가능 → 무시
        if maxCharges and maxCharges > 1 then
            if currentCharges and currentCharges > 0 then return end
            actualCD = chargeDuration and math.floor(chargeDuration) or RMT_SPELLS[spellID].cd
        end
    end

    -- 일반 스킬: 탤런트 적용된 실제 쿨타임
    if not actualCD then
        local _, duration = GetCooldown(spellID)
        actualCD = (duration and duration > 2) and math.floor(duration) or RMT_SPELLS[spellID].cd
    end

    -- ① 로컬 즉시 반영 (솔로 / 공대장 포함 항상 동작)
    ProcessUsed(name, spellID, now, actualCD)

    -- ② 그룹 내 다른 공대원에게 브로드캐스트
    local ch = GetChannel()
    if ch then
        C_ChatInfo.SendAddonMessage(PREFIX, "USED:" .. spellID .. ":" .. string.format("%.3f", now) .. ":" .. actualCD, ch)
    end
end

-- ================================================================
-- MESSAGE HANDLER
-- ================================================================
local function OnAddonMessage(_, event, prefix, message, _, sender)
    if prefix ~= PREFIX then return end

    -- sender 정규화 (서버명 제거)
    local name = sender:match("^([^%-]+)") or sender

    -- 본인이 보낸 USED는 SendUsed()에서 이미 로컬 처리 완료 → 중복 방지
    local myName = UnitName("player")

    -- CHECK
    if message == "CHECK" then
        RMT_SendHave()
        return
    end

    -- HAVE:spellID:cd,spellID:cd,...
    local payload = message:match("^HAVE:(.+)")
    if payload then
        if not RMT.roster[name] then RMT.roster[name] = {} end
        for entry in payload:gmatch("[^,]+") do
            local idStr, cdStr = entry:match("^(%d+):(%d+)$")
            if idStr then
                local spellID = tonumber(idStr)
                local cd      = tonumber(cdStr)
                RMT.roster[name][spellID] = { cd = cd, endTime = 0 }
            end
        end
        RMT_UI_RefreshPanel()
        return
    end

    -- USED:spellID:timestamp:actualCD
    local usedID, usedTime, usedCD = message:match("^USED:(%d+):([%d%.]+):?(%d*)$")
    if usedID then
        -- 본인 메시지는 SendUsed()에서 이미 반영했으므로 스킵
        if name == myName then return end
        ProcessUsed(name, tonumber(usedID), tonumber(usedTime), tonumber(usedCD))
        return
    end
end

-- ================================================================
-- RESET DETECTION  —  RegisterFrames() 보다 먼저 선언해야 upvalue로 참조 가능
-- ================================================================
local function DoWipeReset()
    for _, spells in pairs(RMT.roster) do
        for _, entry in pairs(spells) do
            entry.endTime = 0
        end
    end
    RMT_UI_RefreshPanel()
    Log(RMT_L.WIPE_RESET)
end

local wasInEncounter = false
local bossKilled     = false

-- ================================================================
-- SELF CAST DETECTION  /  COMBAT LOG BACKUP
-- ⚠️  프레임 생성은 ADDON_LOADED 이후 RegisterFrames()에서 처리
--     (main chunk 에서 RegisterEvent 하면 taint → ADDON_ACTION_FORBIDDEN)
-- ================================================================
local function RegisterFrames()
    -- 본인 공생기 사용 감지
    local castFrame = CreateFrame("Frame")
    castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    castFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
        if RMT_SPELLS[spellID] then
            SendUsed(spellID)
        end
    end)

    -- 공대원 스킬 사용 감지 — UNIT_SPELLCAST_SUCCEEDED 기반
    -- COMBAT_LOG_EVENT_UNFILTERED는 TWW 12.0에서 restricted event가 되어
    -- RegisterEvent 호출 시 ADDON_ACTION_FORBIDDEN 발생 → unit event 방식으로 교체
    local memberFrame = CreateFrame("Frame")
    local memberUnits = { "party1", "party2", "party3", "party4" }
    for i = 1, 40 do memberUnits[#memberUnits + 1] = "raid" .. i end
    memberFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unpack(memberUnits))
    memberFrame:SetScript("OnEvent", function(_, _, unitID, _, spellID)
        if not RMT_SPELLS[spellID] then return end
        if UnitIsUnit(unitID, "player") then return end  -- 본인은 castFrame에서 처리

        local unitName = UnitName(unitID)
        if not unitName then return end
        local name = unitName:match("^([^%-]+)") or unitName

        local dbEntry = RMT_SPELLS[spellID]
        ProcessUsed(name, spellID, GetTime(), dbEntry and dbEntry.cd or 180)
    end)

    -- 전멸/소프트리셋 감지
    local wipeFrame = CreateFrame("Frame")
    wipeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    wipeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    wipeFrame:RegisterEvent("BOSS_KILL")
    wipeFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if IsEncounterInProgress() then wasInEncounter = true end
            bossKilled = false
        elseif event == "BOSS_KILL" then
            bossKilled = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if wasInEncounter and not bossKilled then DoWipeReset() end
            wasInEncounter = false
            bossKilled     = false
        end
    end)

    -- 공대 구성 변경 시 자동 보고
    local rosterFrame = CreateFrame("Frame")
    rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    rosterFrame:SetScript("OnEvent", function()
        C_Timer.After(2, function()
            if GetChannel() then RMT_SendHave() end
        end)
    end)
end

-- ================================================================
-- TEST MODE
-- /rmt test → 가짜 공대원 데이터로 UI 테스트 (솔로 테스트용)
-- 이름은 "형용사+직업명" 조합으로 매 실행마다 랜덤 생성
-- ================================================================

-- 랜덤 이름 생성용 테이블
local TEST_ADJ_KR = { "배고픈", "심심한", "졸린", "게으른", "신나는", "무서운", "귀여운", "빠른", "느린", "강한" }
local TEST_ADJ_EN = { "angry", "lazy", "sleepy", "hungry", "silly", "brave", "grumpy", "jolly", "tiny", "sneaky" }
local TEST_CLASS_KR = {
    PRIEST      = "사제",
    DEATHKNIGHT = "죽기",
    PALADIN     = "성기사",
    SHAMAN      = "주술사",
    EVOKER      = "기원사",
    DRUID       = "드루이드",
    MONK        = "수도사",
    WARRIOR     = "전사",
}
local TEST_CLASS_EN = {
    PRIEST      = "Priest",
    DEATHKNIGHT = "DK",
    PALADIN     = "Paladin",
    SHAMAN      = "Shaman",
    EVOKER      = "Evoker",
    DRUID       = "Druid",
    MONK        = "Monk",
    WARRIOR     = "Warrior",
}

local function MakeTestName(classKey)
    if math.random(2) == 1 then
        local adj = TEST_ADJ_KR[math.random(#TEST_ADJ_KR)]
        local cls = TEST_CLASS_KR[classKey] or classKey
        return adj .. cls
    else
        local adj = TEST_ADJ_EN[math.random(#TEST_ADJ_EN)]
        local cls = TEST_CLASS_EN[classKey] or classKey
        return adj .. cls
    end
end

-- { spellID, 쿨타임 남은 초 (0 = 준비됨) }
local TEST_SPELLS = {
    { 62618,  95  },   -- 수양 신의 권능: 방벽 — 쿨 중
    { 47788,  0   },   -- 신성 수호 영혼 — 준비
    { 116849, 48  },   -- 운무 기의 고치 — 쿨 중
    { 31821,  180 },   -- 신성 오라 숙련 — 방금 씀
    { 97462,  0   },   -- 전사 재집결 — 준비
    { 740,    130 },   -- 회복 평온 — 쿨 중
    { 6940,   30  },   -- 성기사 희생의 축복 — 거의 됨
    { 363534, 240 },   -- 보존 되돌리기 — 방금 씀
}

local function RunTestMode()
    RMT.roster = {}
    local now = GetTime()

    -- 샘플 캐릭터 (기존 유지)
    for _, entry in ipairs(TEST_SPELLS) do
        local spellID, remain = entry[1], entry[2]
        local data = RMT_SPELLS[spellID]
        if data then
            local name = MakeTestName(data.class)
            -- 같은 이름이 중복될 경우 숫자 접미사 추가
            local baseName = name
            local suffix   = 2
            while RMT.roster[name] do
                name = baseName .. suffix
                suffix = suffix + 1
            end
            RMT.roster[name] = {}
            RMT.roster[name][spellID] = {
                cd      = data.cd,
                endTime = remain > 0 and (now + remain) or 0,
            }
        end
    end

    -- 내 캐릭터 실제 스킬 추가
    local myName = UnitName("player")
    if myName then
        -- 이름 충돌 방지 (샘플 이름과 겹칠 경우 대비)
        local displayName = myName
        if RMT.roster[displayName] then
            displayName = myName .. "*"
        end
        RMT.roster[displayName] = {}
        for spellID, data in pairs(RMT_SPELLS) do
            if IsPlayerSpell(spellID) then
                -- 실제 쿨타임 잔여 시간 반영
                local start, duration = GetCooldown(spellID)
                local endTime = 0
                if start and start > 0 and duration and duration > 1.5 then
                    endTime = start + duration
                end
                RMT.roster[displayName][spellID] = {
                    cd      = data.cd,
                    endTime = endTime,
                }
            end
        end
        -- 보유 스킬 없으면 항목 자체 제거
        if not next(RMT.roster[displayName]) then
            RMT.roster[displayName] = nil
        end
    end

    RMT_UI_ForceShow()   -- 리더 체크 없이 패널 강제 표시
    Log(RMT_L.TEST_MODE)
end

-- ================================================================
-- COMMANDS
-- /rmt         → CHECK 전송 (공대장/부공대장)
-- /rmt reset   → 목록 초기화
-- /rmt show    → 패널 강제 표시
-- /rmt test    → 테스트 데이터로 UI 확인 (솔로)
-- ================================================================
SLASH_RMT1 = "/rmt"
SlashCmdList["RMT"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(%S*)") or ""
    if arg == "reset" then
        RMT.roster = {}
        RMT_UI_RefreshPanel()
        Log(RMT_L.RESET_DONE)
    elseif arg == "show" then
        RMT_UI_ShowPanel()
    elseif arg == "test" then
        RunTestMode()
    elseif arg == "config" then
        if RMT_Options_Open then RMT_Options_Open() end
    elseif arg == "" then
        if IsLeaderOrAssist() then
            RMT_SendCheck()
        else
            RMT_SendHave()
            Log(RMT_L.REPORTED)
        end
    else
        Log(RMT_L.HELP)
    end
end

-- ================================================================
-- INIT
-- ================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
-- ⚠️ CHAT_MSG_ADDON은 ADDON_LOADED 핸들러 안에서 등록
--    메인 청크에서 RegisterEvent하면 다른 애드온에 의해 taint → 수신 불가
loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")

        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        self:RegisterEvent("CHAT_MSG_ADDON")   -- ← ADDON_LOADED 이후 안전하게 등록

        RMTdb  = RMTdb or {}
        RMT.db = RMTdb

        -- 기본값 설정 (저장된 값 없을 때만) — 슬라이더 범위의 중간값
        local defaults = {
            bgAlpha    = 0.55,   -- 0.1 ~ 1.0  중간
            barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
            rowHeight  = 44,     -- 20 ~ 68    중간
            barHeight  = 36,     -- 4  ~ 68    중간
            iconSize   = 36,     -- 14 ~ 58    중간
            showIcon   = true,
            fontSize   = 18,     -- 8  ~ 28    중간
            rowSpacing = 0,      -- 0  ~ 24    (0이 최솟값)
            sortMode   = "name",
            tooltipOn  = true,
        }
        for k, v in pairs(defaults) do
            if RMTdb[k] == nil then RMTdb[k] = v end
        end

        RMT_UI_Init()
        SetupMinimapButton()
        -- RegisterFrames()를 다음 프레임으로 지연
        -- ADDON_LOADED 체인에서 다른 애드온이 taint를 남기면
        -- 같은 핸들러 안에서도 RegisterEvent가 ADDON_ACTION_FORBIDDEN으로 차단됨
        -- C_Timer.After(0, ...) 은 모든 ADDON_LOADED 핸들러가 완료된 후 실행 → taint 해소
        C_Timer.After(0, RegisterFrames)

        Log("v" .. VERSION .. " " .. RMT_L.LOADED .. "  |cff888888/rmt|r")
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(nil, event, ...)
    end
end)

-- ================================================================
-- MINIMAP BUTTON
-- ================================================================
function SetupMinimapButton()
    local LDB    = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0",     true)
    if not LDB or not DBIcon then return end

    local launcher = LDB:NewDataObject("RaidMitTracker", {
        type = "launcher",
        text = "Raid Mit Tracker",
        icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit",

        OnClick = function(self, btn)
            if btn == "LeftButton" then
                if RMT_Options_Open then RMT_Options_Open() end
            elseif btn == "RightButton" then
                RMT_UI_ShowPanel()
            end
        end,

        OnTooltipShow = function(tip)
            tip:AddLine("|cffff9900Raid Mit Tracker|r")
            tip:AddLine(" ")
            tip:AddLine("|cffffffff좌클릭|r  설정 열기")
            tip:AddLine("|cffffffff우클릭|r  공생기 패널 열기")
        end,
    })

    RMTdb.minimapIcon = RMTdb.minimapIcon or {}
    DBIcon:Register("RaidMitTracker", launcher, RMTdb.minimapIcon)
end

