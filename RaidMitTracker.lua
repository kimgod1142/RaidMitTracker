-- RaidMitTracker.lua
-- 공대 생존기(공생기) 쿨타임 추적 애드온
-- 공대원 전원 설치 필요 — 공대장/부공대장 화면에만 UI 표시
--
-- Author:  kimgod1142
-- Contact: kimgod1142@gmail.com
-- License: MIT

local ADDON_NAME = "RaidMitTracker"
local VERSION    = "1.0.0"
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

-- USED 전송 (스킬 사용 시 자동 발송)
local function SendUsed(spellID)
    local ch = GetChannel()
    if not ch then return end

    -- 충전 스킬: 충전이 남아있으면 전송 안 함 (아직 사용 가능)
    local currentCharges, maxCharges, _, chargeDuration = GetSpellCharges(spellID)
    if maxCharges and maxCharges > 1 then
        if currentCharges and currentCharges > 0 then return end
        -- 모든 충전 소모 → 충전 쿨타임으로 보고
        local actualCD = math.floor(chargeDuration or RMT_SPELLS[spellID].cd)
        C_ChatInfo.SendAddonMessage(PREFIX, "USED:" .. spellID .. ":" .. string.format("%.3f", GetTime()) .. ":" .. actualCD, ch)
        return
    end

    -- 일반 스킬: GetSpellCooldown으로 탤런트 적용된 실제 쿨타임 사용
    local _, duration = GetSpellCooldown(spellID)
    local actualCD = (duration and duration > 2) and math.floor(duration) or RMT_SPELLS[spellID].cd
    C_ChatInfo.SendAddonMessage(PREFIX, "USED:" .. spellID .. ":" .. string.format("%.3f", GetTime()) .. ":" .. actualCD, ch)
end

-- ================================================================
-- MESSAGE HANDLER
-- ================================================================
local function OnAddonMessage(_, event, prefix, message, _, sender)
    if prefix ~= PREFIX then return end

    -- sender 정규화 (서버명 제거)
    local name = sender:match("^([^%-]+)") or sender

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
        local spellID  = tonumber(usedID)
        local castTime = tonumber(usedTime)
        local actualCD = tonumber(usedCD)   -- 탤런트 적용된 실제 쿨타임 (없으면 nil)
        if not RMT.roster[name] then RMT.roster[name] = {} end
        if not RMT.roster[name][spellID] then
            local dbEntry = RMT_SPELLS[spellID]
            RMT.roster[name][spellID] = { cd = dbEntry and dbEntry.cd or 180, endTime = 0 }
        end
        local entry   = RMT.roster[name][spellID]
        local cd      = actualCD or entry.cd
        entry.endTime = castTime + cd
        RMT_UI_RefreshPanel()
        return
    end
end

-- ================================================================
-- SELF CAST DETECTION
-- 본인이 공생기 사용 시 → USED 메시지 발송
-- ================================================================
local castFrame = CreateFrame("Frame")
castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castFrame:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if RMT_SPELLS[spellID] then
        SendUsed(spellID)
    end
end)

-- ================================================================
-- COMBAT LOG BACKUP
-- 애드온 미설치 공대원 스킬 사용도 감지
-- ================================================================
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatFrame:SetScript("OnEvent", function()
    local _, subEvent, _, sourceGUID, sourceName = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SPELL_CAST_SUCCESS" then return end

    local _, _, _, _, _, spellID = select(9, CombatLogGetCurrentEventInfo())
    if not spellID or not RMT_SPELLS[spellID] then return end

    -- 본인 캐릭터는 UNIT_SPELLCAST_SUCCEEDED로 이미 처리됨
    local myGUID = UnitGUID("player")
    if sourceGUID == myGUID then return end

    -- 공대원 이름 정규화
    local name = sourceName and (sourceName:match("^([^%-]+)") or sourceName) or "Unknown"

    if not RMT.roster[name] then RMT.roster[name] = {} end
    if not RMT.roster[name][spellID] then
        local dbEntry = RMT_SPELLS[spellID]
        RMT.roster[name][spellID] = { cd = dbEntry and dbEntry.cd or 180, endTime = 0 }
    end
    local entry   = RMT.roster[name][spellID]
    entry.endTime = GetTime() + entry.cd
    RMT_UI_RefreshPanel()
end)

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
loader:RegisterEvent("CHAT_MSG_ADDON")
loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")

        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

        RMTdb          = RMTdb or {}
        RMT.db         = RMTdb

        RMT_UI_Init()

        Log("v" .. VERSION .. " " .. RMT_L.LOADED .. "  |cff888888/rmt|r")
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(nil, event, ...)
    end
end)

-- 공대 구성 변경 시 자동 보고 (선택적)
local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterFrame:SetScript("OnEvent", function()
    -- 공대 합류 직후 자동으로 본인 스킬 보고
    C_Timer.After(2, function()
        if GetChannel() then
            RMT_SendHave()
        end
    end)
end)
