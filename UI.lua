-- UI.lua
-- 공대장/부공대장 전용 공생기 패널
-- 레이아웃: [플레이어명] [스킬아이콘] [직업색 쿨타임바 ───────] [남은초]

local PANEL_W   = 340
local ROW_H     = 28
local NAME_W    = 80
local ICON_SZ   = 22
local PAD       = 8
local BAR_H     = 16
local TITLE_H   = 22

-- 리사이즈 제한
-- 가로: 이름칸 + 아이콘 + 바 최소폭 + 여백
local MIN_W = NAME_W + ICON_SZ + 8 + PAD * 2 + 80   -- ~218px
local MIN_H = TITLE_H + PAD * 2                       -- 행 없을 때 최솟값, 동적 갱신됨

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

    -- 2순위: SpellDB의 class 필드로 직업 확정 (스킬은 직업 고정이므로 확실)
    if spellID then
        local spellData = RMT_SPELLS[spellID]
        if spellData and spellData.class then
            local cc = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[spellData.class])
                    or CLASS_COLORS[spellData.class]
            if cc then return cc.r, cc.g, cc.b end
        end
    end

    return 0.6, 0.6, 0.6   -- 최후 fallback (실질적으로 도달 불가)
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
    panel:SetBackdropColor(0.04, 0.04, 0.08, 0.96)
    panel:SetBackdropBorderColor(0.8, 0.5, 0.1, 1)
end

-- 이동: 타이틀 영역만 드래그
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if RMTdb then
        local pt, _, rpt, x, y = self:GetPoint()
        RMTdb.panelPos  = { pt = pt, rpt = rpt, x = x, y = y }
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
local HANDLE_THICK = 6   -- 핸들 두께 (px)

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

-- 오른쪽 테두리
local hRight = MakeEdgeHandle("RIGHT")
hRight:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",    0,           -TITLE_H)
hRight:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,            HANDLE_THICK)
hRight:SetWidth(HANDLE_THICK)

-- 아래쪽 테두리
local hBottom = MakeEdgeHandle("BOTTOM")
hBottom:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  HANDLE_THICK, 0)
hBottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -HANDLE_THICK, 0)
hBottom:SetHeight(HANDLE_THICK)

-- 오른쪽 아래 모서리 (대각선)
local hCorner = MakeEdgeHandle("BOTTOMRIGHT")
hCorner:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
hCorner:SetSize(HANDLE_THICK + 4, HANDLE_THICK + 4)

-- 모서리 핸들 시각적 아이콘 (WoW 기본 리사이즈 그립)
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
    local row = {}
    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetHeight(ROW_H)

    local nameBg = row.frame:CreateTexture(nil, "BACKGROUND")
    nameBg:SetColorTexture(0, 0, 0, 0.3)
    nameBg:SetPoint("TOPLEFT",    row.frame, "TOPLEFT",   0, 0)
    nameBg:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT",0, 0)
    nameBg:SetWidth(NAME_W)

    row.nameText = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
    row.nameText:SetWidth(NAME_W - 6)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.icon = row.frame:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SZ, ICON_SZ)
    row.icon:SetPoint("LEFT", row.frame, "LEFT", NAME_W + 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local barBg = row.frame:CreateTexture(nil, "BACKGROUND")
    barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    barBg:SetPoint("LEFT",  row.frame, "LEFT",  NAME_W + ICON_SZ + 8, -(ROW_H - BAR_H) / 2)
    barBg:SetPoint("RIGHT", row.frame, "RIGHT", 0,                    -(ROW_H - BAR_H) / 2)
    barBg:SetHeight(BAR_H)
    row.barBg = barBg

    local bar = CreateFrame("StatusBar", nil, row.frame)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetPoint("TOPLEFT",     barBg, "TOPLEFT",     1,  -1)
    bar:SetPoint("BOTTOMRIGHT", barBg, "BOTTOMRIGHT", -1,  1)
    row.bar = bar

    -- 타이머 텍스트 (우측 고정 — 숫자 카운트다운)
    row.cdText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cdText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    row.cdText:SetJustifyH("RIGHT")

    -- "사용가능" 텍스트 (바 중앙 고정)
    row.readyText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    -- 재사용 시 텍스트 상태 초기화
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
-- OnUpdate: 매 프레임 바 + 텍스트 갱신
-- ================================================================
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function()
    if #activeRows == 0 then return end
    local now = GetTime()
    for _, row in ipairs(activeRows) do
        if row.endTime and row.endTime > 0 then
            local remain = row.endTime - now
            if remain > 0 then
                -- 쿨타임 진행 중: 바 + 우측 숫자
                row.bar:SetValue(remain / (row.totalCD or 1))
                local m = math.floor(remain / 60)
                local s = math.floor(remain % 60)
                row.cdText:SetText(m > 0 and string.format("%d:%02d", m, s) or string.format("%ds", s))
                row.cdText:SetTextColor(1, 1, 1, 1)
                row.cdText:Show()
                row.readyText:Hide()
            else
                -- 쿨타임 종료: "사용가능" 중앙
                row.bar:SetValue(0)
                row.cdText:Hide()
                row.readyText:Show()
            end
        else
            -- endTime = 0: 한 번도 안 씀 = 사용가능
            row.bar:SetValue(0)
            row.cdText:Hide()
            row.readyText:Show()
        end
    end
end)

-- ================================================================
-- 패널 갱신
-- ================================================================
function RMT_UI_RefreshPanel(force)
    if not force and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        return
    end

    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}

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
    table.sort(entries, function(a, b)
        if a.player ~= b.player then return a.player < b.player end
        return a.spellID < b.spellID
    end)

    local yOff = -(TITLE_H + 4)

    for _, e in ipairs(entries) do
        local row       = GetRow(panel)
        local spellData = RMT_SPELLS[e.spellID]

        row.frame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD,  yOff)
        row.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, yOff)

        if spellData and spellData.icon then
            row.icon:SetTexture(spellData.icon)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local r, g, b = GetClassColor(e.player, e.spellID)
        row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, e.player))
        row.bar:SetStatusBarColor(r, g, b, 0.85)

        row.totalCD = e.totalCD
        row.endTime = e.endTime

        activeRows[#activeRows + 1] = row
        yOff = yOff - ROW_H - 3
    end

    -- 콘텐츠 전체 높이 계산 → 리사이즈 하한선으로 설정
    local contentH = TITLE_H + (#entries * (ROW_H + 3)) + PAD
    MIN_H = math.max(TITLE_H + PAD * 2, contentH)
    panel:SetResizeBounds(MIN_W, MIN_H)

    -- 현재 패널 높이가 콘텐츠보다 짧으면 자동 늘림
    if panel:GetHeight() < MIN_H then
        panel:SetHeight(MIN_H)
    end

    panel:Show()
end

-- ================================================================
-- 공개 함수
-- ================================================================
function RMT_UI_ShowPanel()
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        print("|cffff9900[RMT]|r " .. RMT_L.LEADER_ONLY)
        return
    end
    RMT_UI_RefreshPanel()
end

function RMT_UI_ForceShow()
    RMT_UI_RefreshPanel(true)
end

function RMT_UI_Init()
    if RMTdb then
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
    end
end
