-- Options.lua
-- 공생기 트래커 자체 설정창  (/rmt config)

local OPT_W       = 370
local PAD         = 14
local TITLE_H     = 30
local POPUP_ROW_H = 28
local MAX_POPUP_H = 280

-- LibSharedMedia 로 텍스처 목록 빌드
local function GetTextureList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local list = {}
        for name, path in pairs(LSM:HashTable("statusbar")) do
            list[#list + 1] = { name = name, path = path }
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end
    return {
        { name = "기본 (Default)",  path = "Interface\\TargetingFrame\\UI-StatusBar"               },
        { name = "레이드 HP",       path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"                },
        { name = "플랫 (Flat)",     path = "Interface\\Buttons\\WHITE8x8"                          },
        { name = "스킬바 (Skills)", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    }
end

-- ================================================================
-- 옵션 프레임
-- ================================================================
local opt = CreateFrame("Frame", "RMT_OptionsFrame", UIParent, "BackdropTemplate")
opt:SetSize(OPT_W, 100)
opt:SetPoint("CENTER")
opt:SetFrameStrata("DIALOG")
opt:SetMovable(true)
opt:EnableMouse(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop",  opt.StopMovingOrSizing)
opt:Hide()

if opt.SetBackdrop then
    opt:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    opt:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    opt:SetBackdropBorderColor(0.8, 0.5, 0.1, 1)
end

-- ESC 키로 창 닫기
tinsert(UISpecialFrames, "RMT_OptionsFrame")

local titleFs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleFs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, -9)
titleFs:SetText("|cffff9900공생기 트래커|r  설정")

local closeBtn = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", opt, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() opt:Hide() end)

opt:SetScript("OnHide", function()
    -- 팝업 닫기 (다음에 선언되는 변수 참조 방지 위해 pcall)
    if _G["RMT_TexPopup"]  then _G["RMT_TexPopup"]:Hide()  end
    if _G["RMT_SortPopup"] then _G["RMT_SortPopup"]:Hide() end
    if _G["RMT_TexCatch"]  then _G["RMT_TexCatch"]:Hide()  end
    -- 그룹 밖이면 테스트 패널 닫기
    if not IsInGroup() then
        RMT.roster = {}
        if RMT_UI_HidePanel then RMT_UI_HidePanel() end
    end
end)

-- ================================================================
-- Refresh 제어: syncing 플래그 + 80ms throttle
-- ================================================================
local syncing      = false
local refreshTimer = nil

local function ApplyAndRefresh()
    if syncing then return end
    if refreshTimer then refreshTimer:Cancel() end
    refreshTimer = C_Timer.NewTimer(0.08, function()
        refreshTimer = nil
        if RMT_UI_ApplySettings then RMT_UI_ApplySettings(true) end
    end)
end

-- ================================================================
-- 텍스처 드롭다운 팝업
-- ================================================================
local texPopup = CreateFrame("Frame", "RMT_TexPopup", UIParent, "BackdropTemplate")
texPopup:SetFrameStrata("TOOLTIP")
texPopup:Hide()
if texPopup.SetBackdrop then
    texPopup:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    texPopup:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    texPopup:SetBackdropBorderColor(0.8, 0.5, 0.1, 1)
end

local texScroll = CreateFrame("ScrollFrame", nil, texPopup)
texScroll:SetPoint("TOPLEFT",     texPopup, "TOPLEFT",     4, -4)
texScroll:SetPoint("BOTTOMRIGHT", texPopup, "BOTTOMRIGHT", -4,  4)
texScroll:EnableMouseWheel(true)
texScroll:SetScript("OnMouseWheel", function(self, delta)
    local max    = self:GetVerticalScrollRange()
    local scroll = math.max(0, math.min(max, self:GetVerticalScroll() - delta * POPUP_ROW_H))
    self:SetVerticalScroll(scroll)
end)

local texContent = CreateFrame("Frame", nil, texScroll)
texScroll:SetScrollChild(texContent)

local texCatch = CreateFrame("Frame", "RMT_TexCatch", UIParent)
texCatch:SetAllPoints(UIParent)
texCatch:SetFrameStrata("FULLSCREEN")
texCatch:EnableMouse(true)
texCatch:Hide()
texCatch:SetScript("OnMouseDown", function()
    texPopup:Hide()
    texCatch:Hide()
end)

local texList       = {}
local selHighlights = {}
local texIdx        = 1
local texBtn        -- 아래에서 선언

local function RebuildTexPopup()
    for _, child in pairs({ texContent:GetChildren() }) do child:Hide() end
    texList       = GetTextureList()
    selHighlights = {}

    local cur = RMTdb and RMTdb.barTexture or ""
    texIdx = 1
    for i, t in ipairs(texList) do
        if t.path == cur then texIdx = i; break end
    end

    local w = texPopup:GetWidth() - 8
    texContent:SetSize(w, #texList * POPUP_ROW_H)

    for i, tex in ipairs(texList) do
        local row = CreateFrame("Button", nil, texContent)
        row:SetHeight(POPUP_ROW_H)
        row:SetPoint("TOPLEFT",  texContent, "TOPLEFT",  0, -(i - 1) * POPUP_ROW_H)
        row:SetPoint("TOPRIGHT", texContent, "TOPRIGHT",  0, 0)

        local selBg = row:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetColorTexture(0.8, 0.5, 0.1, 0.2)
        selBg:SetShown(i == texIdx)
        selHighlights[i] = selBg

        local hlTex = row:CreateTexture(nil, "HIGHLIGHT")
        hlTex:SetAllPoints()
        hlTex:SetColorTexture(1, 1, 1, 0.08)

        local preview = CreateFrame("StatusBar", nil, row)
        preview:SetSize(80, 14)
        preview:SetPoint("LEFT", row, "LEFT", 4, 0)
        preview:SetStatusBarTexture(tex.path)
        preview:SetMinMaxValues(0, 1)
        preview:SetValue(0.65)
        preview:SetStatusBarColor(0.3, 0.65, 1, 1)

        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetPoint("LEFT", preview, "RIGHT", 8, 0)
        nameFs:SetText(tex.name)

        row:SetScript("OnClick", function()
            texIdx = i
            if texBtn then texBtn:SetText(tex.name .. "  ▼") end
            if RMTdb  then RMTdb.barTexture = tex.path end
            for j, hl in ipairs(selHighlights) do hl:SetShown(j == i) end
            texPopup:Hide()
            texCatch:Hide()
            ApplyAndRefresh()
        end)
    end

    local popupH = math.min(#texList * POPUP_ROW_H + 8, MAX_POPUP_H)
    texPopup:SetHeight(popupH)

    -- 현재 선택 항목이 보이도록 스크롤
    local scrollTo = math.max(0, (texIdx - 1) * POPUP_ROW_H - math.floor(MAX_POPUP_H / 2))
    texScroll:SetVerticalScroll(scrollTo)
end

-- ================================================================
-- 정렬 드롭다운 팝업
-- ================================================================
local SORT_OPTIONS = {
    { key = "name", label = "이름순 (가나다 / ABC)" },
    { key = "cd",   label = "쿨타임 낮은 순"       },
}

local sortPopup = CreateFrame("Frame", "RMT_SortPopup", UIParent, "BackdropTemplate")
sortPopup:SetFrameStrata("TOOLTIP")
sortPopup:Hide()
if sortPopup.SetBackdrop then
    sortPopup:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    sortPopup:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    sortPopup:SetBackdropBorderColor(0.8, 0.5, 0.1, 1)
end
sortPopup:SetSize(200, #SORT_OPTIONS * POPUP_ROW_H + 8)

local sortCatch = CreateFrame("Frame", nil, UIParent)
sortCatch:SetAllPoints(UIParent)
sortCatch:SetFrameStrata("FULLSCREEN")
sortCatch:EnableMouse(true)
sortCatch:Hide()
sortCatch:SetScript("OnMouseDown", function()
    sortPopup:Hide()
    sortCatch:Hide()
end)

local sortSelHls = {}
local sortBtn   -- 아래에서 선언

local function GetSortIdx()
    local mode = RMTdb and RMTdb.sortMode or "name"
    for i, s in ipairs(SORT_OPTIONS) do
        if s.key == mode then return i end
    end
    return 1
end

for i, opt_sort in ipairs(SORT_OPTIONS) do
    local row = CreateFrame("Button", nil, sortPopup)
    row:SetHeight(POPUP_ROW_H)
    row:SetPoint("TOPLEFT",  sortPopup, "TOPLEFT",  4, -(4 + (i - 1) * POPUP_ROW_H))
    row:SetPoint("TOPRIGHT", sortPopup, "TOPRIGHT", -4, 0)

    local selBg = row:CreateTexture(nil, "BACKGROUND")
    selBg:SetAllPoints()
    selBg:SetColorTexture(0.8, 0.5, 0.1, 0.2)
    selBg:SetShown(i == GetSortIdx())
    sortSelHls[i] = selBg

    local hlTex = row:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints()
    hlTex:SetColorTexture(1, 1, 1, 0.08)

    local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", row, "LEFT", 8, 0)
    nameFs:SetText(opt_sort.label)

    row:SetScript("OnClick", function()
        if RMTdb then RMTdb.sortMode = opt_sort.key end
        for j, hl in ipairs(sortSelHls) do hl:SetShown(j == i) end
        if sortBtn then sortBtn:SetText(opt_sort.label .. "  ▼") end
        sortPopup:Hide()
        sortCatch:Hide()
        ApplyAndRefresh()
    end)
end

-- ================================================================
-- 레이아웃 헬퍼
-- ================================================================
local yPos = -(TITLE_H + 4)

local function AddHeader(text)
    yPos = yPos - 8
    local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    fs:SetText("|cffff9900" .. text .. "|r")
    yPos = yPos - 16
    local line = opt:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.8, 0.5, 0.1, 0.4)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  opt, "TOPLEFT",  PAD,  yPos)
    line:SetPoint("TOPRIGHT", opt, "TOPRIGHT", -PAD, yPos)
    yPos = yPos - 10
end

local sliderRefs = {}
local function AddSlider(label, minVal, maxVal, step, key, fmt)
    local slider = CreateFrame("Slider", "RMT_Opt_"..key, opt, "OptionsSliderTemplate")
    slider:SetWidth(OPT_W - PAD * 2 - 16)
    slider:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD + 8, yPos)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local function Sync(val)
        slider.Text:SetText(label .. ": " .. string.format(fmt, val))
    end

    slider:SetScript("OnValueChanged", function(self, val)
        Sync(val)
        if RMTdb then RMTdb[key] = val end
        ApplyAndRefresh()
    end)

    sliderRefs[key] = { widget = slider, sync = Sync }
    yPos = yPos - 46
    return slider
end

local checkRefs = {}
local function AddCheckbox(label, key, defaultVal)
    local cb = CreateFrame("CheckButton", "RMT_Opt_"..key, opt, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos + 3)
    cb.text:SetText(label)
    cb.text:SetFontObject(GameFontNormalSmall)
    cb:SetScript("OnClick", function(self)
        if RMTdb then RMTdb[key] = self:GetChecked() end
        ApplyAndRefresh()
    end)
    checkRefs[key] = { widget = cb, default = defaultVal }
    yPos = yPos - 28
    return cb
end

local function AddDropdownBtn(label, getTextFn, onClickFn)
    local lbl = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    lbl:SetText(label)
    yPos = yPos - 18

    local btn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
    btn:SetWidth(OPT_W - PAD * 2 - 4)
    btn:SetHeight(22)
    btn:SetText(getTextFn() .. "  ▼")
    btn:SetScript("OnClick", onClickFn)
    yPos = yPos - 28
    return btn
end

-- ================================================================
-- 외관 섹션
-- ================================================================
AddHeader("외관")
AddSlider("배경 투명도", 0.1, 1.0, 0.05, "bgAlpha",    "%.2f")
AddSlider("행 높이",     20,  44,  1,    "rowHeight",  "%d px")
AddSlider("바 두께",     4,   36,  1,    "barHeight",  "%d px")
AddSlider("아이콘 크기", 14,  36,  1,    "iconSize",   "%d px")
AddSlider("폰트 크기",   8,   18,  1,    "fontSize",   "%d")
AddSlider("행 간격",     0,   12,  1,    "rowSpacing", "%d px")

-- 바 텍스처 드롭다운
texBtn = AddDropdownBtn("바 텍스처",
    function()
        local cur = RMTdb and RMTdb.barTexture or ""
        local list = GetTextureList()
        for _, t in ipairs(list) do
            if t.path == cur then return t.name end
        end
        return "선택..."
    end,
    function(self)
        if texPopup:IsShown() then
            texPopup:Hide(); texCatch:Hide()
        else
            RebuildTexPopup()
            texPopup:ClearAllPoints()
            texPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            texPopup:SetWidth(self:GetWidth())
            texContent:SetWidth(self:GetWidth() - 8)
            texPopup:Show(); texPopup:Raise()
            texCatch:SetFrameLevel(texPopup:GetFrameLevel() - 1)
            texCatch:Show()
        end
    end
)

-- ================================================================
-- 정렬 섹션
-- ================================================================
AddHeader("정렬")

sortBtn = AddDropdownBtn("정렬 기준",
    function()
        local idx = GetSortIdx()
        return SORT_OPTIONS[idx].label
    end,
    function(self)
        if sortPopup:IsShown() then
            sortPopup:Hide(); sortCatch:Hide()
        else
            -- 현재 선택 하이라이트 갱신
            local cur = GetSortIdx()
            for j, hl in ipairs(sortSelHls) do hl:SetShown(j == cur) end
            sortPopup:ClearAllPoints()
            sortPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            sortPopup:SetWidth(self:GetWidth())
            sortPopup:Show(); sortPopup:Raise()
            sortCatch:SetFrameLevel(sortPopup:GetFrameLevel() - 1)
            sortCatch:Show()
        end
    end
)

-- ================================================================
-- 기능 섹션
-- ================================================================
AddHeader("기능")
AddCheckbox("아이콘 표시",             "showIcon",  true)
AddCheckbox("아이콘 마우스오버 툴팁",  "tooltipOn", true)

-- ================================================================
-- 프레임 최종 높이 확정
-- ================================================================
opt:SetHeight(math.abs(yPos) + PAD + 10)

-- ================================================================
-- 공개 함수: 창 열기
-- ================================================================
function RMT_Options_Open()
    if not RMTdb then opt:Show(); return end

    -- syncing=true → slider SetValue가 ApplyAndRefresh 트리거하지 않도록
    syncing = true

    for key, ref in pairs(sliderRefs) do
        local val = RMTdb[key]
        if val ~= nil then
            ref.widget:SetValue(val)
            ref.sync(val)
        end
    end
    for key, ref in pairs(checkRefs) do
        local val = RMTdb[key]
        if val == nil then val = ref.default end
        ref.widget:SetChecked(val)
    end

    syncing = false

    -- 드롭다운 버튼 텍스트 동기화
    local curTex = RMTdb.barTexture or ""
    local texName = "선택..."
    local list = GetTextureList()
    for _, t in ipairs(list) do
        if t.path == curTex then texName = t.name; break end
    end
    texBtn:SetText(texName .. "  ▼")
    sortBtn:SetText(SORT_OPTIONS[GetSortIdx()].label .. "  ▼")

    opt:Show()
    opt:Raise()

    -- sync 완료 후 테스트 모드 실행 (그룹 밖일 때만)
    if not IsInGroup() then
        C_Timer.After(0.05, function()
            SlashCmdList["RMT"]("test")
        end)
    end
end
