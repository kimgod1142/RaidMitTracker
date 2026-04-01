-- UI.lua
-- 공대장/부공대장 전용 공생기 패널
-- 레이아웃: [플레이어명] [스킬아이콘] [직업색 쿨타임바 ───────] [남은초]
--
-- ── 공개 API 요약 ──────────────────────────────────────────────────────
--  RMT_UI_Init()            로그인 시 저장된 위치·크기·배경 복원 (ADDON_LOADED 후)
--  RMT_UI_RefreshPanel()    이벤트 핸들러용: 패널이 열려 있을 때만 내용 갱신
--  RMT_UI_ShowPanel()       /rmt show: 리더·부리더만 패널 열기
--  RMT_UI_ForceShow()       테스트·설정 미리보기: 리더 체크 없이 패널 열기
--  RMT_UI_HidePanel()       패널 닫기
--  RMT_UI_ApplySettings()   설정 변경 후 행 풀 초기화 + 재구성 (Options.lua 전용)
-- ────────────────────────────────────────────────────────────────────────

local PANEL_W   = 340
local ROW_H     = 28
local NAME_W    = 80
local ICON_SZ   = 22
local PAD       = 8
local BAR_H     = 16
local TITLE_H   = 22

-- 리사이즈 제한
local MIN_W = NAME_W + ICON_SZ + 8 + PAD * 2 + 80   -- ~218px
local MIN_H = TITLE_H + PAD * 2                       -- 동적 갱신됨

-- 직업별 색상 (RAID_CLASS_COLORS 없을 때 대비 fallback)
local CLASS_COLORS = {
    WARRIOR      = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN      = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER       = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE        = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST       = { r = 1.00, g = 1.00, b = 1.00 },
    DEATHKNIGHT  = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN       = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE         = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK      = { r = 0.58, g = 0.51, b = 0.79 },
    MONK         = { r = 0.00, g = 1.00, b = 0.60 },
    DRUID        = { r = 1.00, g = 0.49, b = 0.04 },
    DEMONHUNTER  = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER       = { r = 0.20, g = 0.58, b = 0.50 },
}

local function GetClassColor(playerName, spellID)
    -- 1순위: UnitClass로 실제 직업 확인
    local _, classFile = UnitClass(playerName)
    if classFile then
        local cc = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
                or CLASS_COLORS[classFile]
        if cc then return cc.r, cc.g, cc.b end
    end

    -- 2순위: SpellDB의 class 필드 (스킬은 직업 고정이므로 확실)
    if spellID then
        local spellData = RMT_SPELLS[spellID]
        if spellData and spellData.class then
            local cc = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[spellData.class])
                    or CLASS_COLORS[spellData.class]
            if cc then return cc.r, cc.g, cc.b end
        end
    end

    return 0.6, 0.6, 0.6
end

-- ================================================================
-- 패널 프레임
-- ================================================================
local panel = CreateFrame("Frame", "RMT_Panel", UIParent, "BackdropTemplate")
panel:SetWidth(PANEL_W)
panel:SetHeight(TITLE_H + PAD)
panel:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
panel:SetFrameStrata("MEDIUM")
panel:SetMovable(true)
panel:SetResizable(true)
panel:SetResizeBounds(MIN_W, MIN_H)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()

if panel.SetBackdrop then
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.08, RMTdb and RMTdb.bgAlpha or 0.55)
    panel:SetBackdropBorderColor(0.8, 0.5, 0.1, 1)
end

-- 타이틀 영역만 드래그
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if RMTdb then
        local pt, _, rpt, x, y = self:GetPoint()
        RMTdb.panelPos = { pt = pt, rpt = rpt, x = x, y = y }
    end
end)

-- 크기 변경 시 저장
panel:SetScript("OnSizeChanged", function(self, w, h)
    if RMTdb then
        RMTdb.panelSize = { w = w, h = h }
    end
end)

-- ================================================================
-- 리사이즈 핸들
-- ================================================================
local HANDLE_THICK = 6

local function MakeEdgeHandle(sizeDir)
    local h = CreateFrame("Frame", nil, panel)
    h:SetFrameLevel(panel:GetFrameLevel() + 5)
    h:EnableMouse(true)
    h:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then panel:StartSizing(sizeDir) end
    end)
    h:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        if RMTdb then
            RMTdb.panelSize = { w = panel:GetWidth(), h = panel:GetHeight() }
        end
    end)
    return h
end

local hRight = MakeEdgeHandle("RIGHT")
hRight:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",    0,            -TITLE_H)
hRight:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,             HANDLE_THICK)
hRight:SetWidth(HANDLE_THICK)

local hBottom = MakeEdgeHandle("BOTTOM")
hBottom:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",   HANDLE_THICK, 0)
hBottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -HANDLE_THICK, 0)
hBottom:SetHeight(HANDLE_THICK)

local hCorner = MakeEdgeHandle("BOTTOMRIGHT")
hCorner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
hCorner:SetSize(HANDLE_THICK + 4, HANDLE_THICK + 4)

local gripTex = hCorner:CreateTexture(nil, "OVERLAY")
gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
gripTex:SetSize(16, 16)
gripTex:SetPoint("BOTTOMRIGHT", hCorner, "BOTTOMRIGHT", 0, 0)
hCorner:SetScript("OnEnter", function()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
end)
hCorner:SetScript("OnLeave", function()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
end)

-- ================================================================
-- 타이틀
-- ================================================================
local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -5)
titleText:SetText("|cffff9900" .. RMT_L.TITLE .. "|r  |cff888888/rmt|r")

local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetSize(16, 16)
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() panel:Hide() end)

-- ================================================================
-- 행 풀
-- ================================================================
local rowPool    = {}
local activeRows = {}

local function MakeRow(parent)
    local rowH     = (RMTdb and RMTdb.rowHeight) or ROW_H
    local iconSz   = (RMTdb and RMTdb.iconSize)  or ICON_SZ
    local fSize    = (RMTdb and RMTdb.fontSize)  or 11
    local barH     = (RMTdb and RMTdb.barHeight) or BAR_H
    local showIcon = (RMTdb == nil) or (RMTdb.showIcon ~= false)
    local texPath  = (RMTdb and RMTdb.barTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
    local fontPath = GameFontNormalSmall:GetFont()
    local barLeft  = showIcon and (NAME_W + iconSz + 8) or (NAME_W + 4)

    local row = {}
    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetHeight(rowH)

    local nameBg = row.frame:CreateTexture(nil, "BACKGROUND")
    nameBg:SetColorTexture(0, 0, 0, 0.3)
    nameBg:SetPoint("TOPLEFT",    row.frame, "TOPLEFT",    0, 0)
    nameBg:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
    nameBg:SetWidth(NAME_W)

    row.nameText = row.frame:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont(fontPath, fSize)
    row.nameText:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.nameText:SetWidth(NAME_W - 6)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.icon = row.frame:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(iconSz, iconSz)
    row.icon:SetPoint("LEFT", row.frame, "LEFT", NAME_W + 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetShown(showIcon)

    -- 아이콘 위 투명 프레임 (마우스 이벤트 수신용)
    local iconHover = CreateFrame("Frame", nil, row.frame)
    iconHover:SetAllPoints(row.icon)
    iconHover:EnableMouse(showIcon)
    iconHover:SetScript("OnEnter", function(self)
        if not row.spellID then return end
        if RMTdb and RMTdb.tooltipOn == false then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(row.spellID)
        GameTooltip:Show()
    end)
    iconHover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.iconHover = iconHover

    local barBg = row.frame:CreateTexture(nil, "BACKGROUND")
    barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    barBg:SetPoint("LEFT",  row.frame, "LEFT",  barLeft, -(rowH - barH) / 2)
    barBg:SetPoint("RIGHT", row.frame, "RIGHT", 0,       -(rowH - barH) / 2)
    barBg:SetHeight(barH)
    row.barBg = barBg

    local bar = CreateFrame("StatusBar", nil, row.frame)
    bar:SetStatusBarTexture(texPath)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetPoint("TOPLEFT",     barBg, "TOPLEFT",     1, -1)
    bar:SetPoint("BOTTOMRIGHT", barBg, "BOTTOMRIGHT", -1, 1)
    row.bar = bar

    row.cdText = bar:CreateFontString(nil, "OVERLAY")
    row.cdText:SetFont(fontPath, fSize)
    row.cdText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    row.cdText:SetJustifyH("RIGHT")

    row.readyText = bar:CreateFontString(nil, "OVERLAY")
    row.readyText:SetFont(fontPath, fSize)
    row.readyText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    row.readyText:SetJustifyH("CENTER")
    row.readyText:SetText("|cff00ff00" .. RMT_L.READY .. "|r")
    row.readyText:Hide()

    return row
end

local function GetRow(parent)
    local row = table.remove(rowPool)
    if not row then row = MakeRow(parent) end
    row.frame:SetParent(parent)
    row.frame:Show()
    row.cdText:SetText("")
    row.cdText:Show()
    row.readyText:Hide()
    return row
end

local function ReleaseRow(row)
    row.frame:Hide()
    table.insert(rowPool, row)
end

-- ================================================================
-- OnUpdate: 바 + 텍스트 갱신
-- ⚠️ 성능 최적화:
--   1. 0.2s 간격 throttle — 60fps 대신 5fps로 갱신 (쿨타임 초 단위, 차이 없음)
--   2. panel OnShow/OnHide에서 등록/해제 — 패널이 닫히면 OnUpdate 자체를 중단
-- ================================================================
local updateFrame   = CreateFrame("Frame")
local UPDATE_TICK   = 0.2   -- seconds
local tickAccum     = 0

local function DoUpdate(_, elapsed)
    tickAccum = tickAccum + elapsed
    if tickAccum < UPDATE_TICK then return end
    tickAccum = 0

    local now = GetTime()
    for _, row in ipairs(activeRows) do
        if row.endTime and row.endTime > 0 then
            local remain = row.endTime - now
            if remain > 0 then
                row.bar:SetValue(remain / (row.totalCD or 1))
                local m = math.floor(remain / 60)
                local s = math.floor(remain % 60)
                row.cdText:SetText(m > 0 and string.format("%d:%02d", m, s) or string.format("%ds", s))
                row.cdText:SetTextColor(1, 1, 1, 1)
                row.cdText:Show()
                row.readyText:Hide()
            else
                row.bar:SetValue(0)
                row.cdText:Hide()
                row.readyText:Show()
            end
        else
            -- endTime = 0: 한 번도 사용 안 함 = 사용 가능
            row.bar:SetValue(0)
            row.cdText:Hide()
            row.readyText:Show()
        end
    end
end

-- 패널 표시 시 OnUpdate 시작, 숨김 시 완전 중단 + 행 해제
panel:SetScript("OnShow", function()
    tickAccum = 0
    updateFrame:SetScript("OnUpdate", DoUpdate)
end)
panel:SetScript("OnHide", function()
    updateFrame:SetScript("OnUpdate", nil)
    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}
end)

-- ================================================================
-- 내부: 행 재구성 (표시 여부·리더 체크와 완전히 분리)
-- 호출 전에 패널이 열려 있어야 하는지는 호출자가 판단한다.
-- ================================================================
local function RebuildRows()
    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}

    -- RMT.roster → 정렬된 항목 목록
    local entries = {}
    for playerName, spells in pairs(RMT.roster) do
        for spellID, data in pairs(spells) do
            entries[#entries + 1] = {
                player  = playerName,
                spellID = spellID,
                totalCD = data.cd,
                endTime = data.endTime or 0,
            }
        end
    end

    local sortMode = RMTdb and RMTdb.sortMode or "name"
    table.sort(entries, function(a, b)
        if sortMode == "cd" then
            local now = GetTime()
            local ra  = a.endTime > 0 and math.max(0, a.endTime - now) or 0
            local rb  = b.endTime > 0 and math.max(0, b.endTime - now) or 0
            return ra < rb
        end
        if a.player ~= b.player then return a.player < b.player end
        return a.spellID < b.spellID
    end)

    -- 행 배치
    local rowH = (RMTdb and RMTdb.rowHeight)  or ROW_H
    local gap  = (RMTdb and RMTdb.rowSpacing) or 3
    local yOff = -(TITLE_H + 4)

    for _, e in ipairs(entries) do
        local row       = GetRow(panel)
        local spellData = RMT_SPELLS[e.spellID]

        row.frame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD,  yOff)
        row.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, yOff)

        row.icon:SetTexture(
            (spellData and spellData.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
        )

        local r, g, b = GetClassColor(e.player, e.spellID)
        row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, e.player))
        row.bar:SetStatusBarColor(r, g, b, 0.85)

        row.spellID = e.spellID
        row.totalCD = e.totalCD
        row.endTime = e.endTime

        activeRows[#activeRows + 1] = row
        yOff = yOff - rowH - gap
    end

    -- 패널 높이: 콘텐츠에 맞게 조정
    local contentH = TITLE_H + (#entries * (rowH + gap)) + PAD
    MIN_H = math.max(TITLE_H + PAD * 2, contentH)
    panel:SetResizeBounds(MIN_W, MIN_H)
    if panel:GetHeight() < MIN_H then
        panel:SetHeight(MIN_H)
    end
end

-- ================================================================
-- 공개 API
-- ================================================================

-- 이벤트 핸들러용 갱신.
-- ProcessUsed / OnAddonMessage(HAVE·USED) / DoWipeReset 에서 호출.
-- 패널이 닫혀 있으면 아무것도 하지 않는다.
function RMT_UI_RefreshPanel()
    if panel:IsShown() then
        RebuildRows()
    end
end

-- /rmt show 명령어.
-- 리더·부리더만 패널을 열 수 있다.
function RMT_UI_ShowPanel()
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        print("|cffff9900[RMT]|r " .. RMT_L.LEADER_ONLY)
        return
    end
    panel:Show()
    RebuildRows()
end

-- 테스트 모드 (/rmt test) · 설정창 미리보기 전용.
-- 리더 여부와 무관하게 패널을 강제로 열고 내용을 갱신한다.
function RMT_UI_ForceShow()
    panel:Show()
    RebuildRows()
end

-- 패널 닫기 (OnHide 스크립트가 OnUpdate 중단 + 행 해제를 처리함)
function RMT_UI_HidePanel()
    panel:Hide()
end

-- 설정 변경 후 Options.lua에서 호출.
-- 행 풀을 초기화하고 배경 색상을 재적용한 뒤 내용을 다시 그린다.
-- open=true 이면 패널이 닫혀 있어도 강제로 열어서 미리보기를 보여준다.
function RMT_UI_ApplySettings(open)
    -- 행 풀 초기화 (폰트·크기 등이 바뀌었으므로 기존 행 재사용 불가)
    -- OnHide가 아직 안 불린 경우를 대비해 수동으로 정리
    for _, row in ipairs(activeRows) do row.frame:Hide() end
    activeRows = {}
    wipe(rowPool)

    -- 배경 투명도 재적용
    if panel.SetBackdrop then
        panel:SetBackdropColor(0.04, 0.04, 0.08, RMTdb and RMTdb.bgAlpha or 0.55)
    end

    if open then
        panel:Show()
    end

    if panel:IsShown() then
        RebuildRows()
    end
end

-- 로그인 시 저장된 위치·크기·배경 복원.
-- ADDON_LOADED 이후 RMTdb가 준비된 시점에 RaidMitTracker.lua에서 호출.
function RMT_UI_Init()
    if not RMTdb then return end

    if RMTdb.panelPos then
        local p = RMTdb.panelPos
        panel:ClearAllPoints()
        panel:SetPoint(p.pt, UIParent, p.rpt, p.x, p.y)
    end

    if RMTdb.panelSize then
        panel:SetSize(
            math.max(MIN_W, RMTdb.panelSize.w),
            math.max(MIN_H, RMTdb.panelSize.h)
        )
    end

    if panel.SetBackdrop and RMTdb.bgAlpha then
        panel:SetBackdropColor(0.04, 0.04, 0.08, RMTdb.bgAlpha)
    end
end
