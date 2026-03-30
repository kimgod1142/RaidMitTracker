-- Options.lua
-- 공생기 트래커 자체 설정창
-- /rmt config 또는 패널 우클릭으로 열기

local OPT_W   = 370
local PAD     = 14
local TITLE_H = 30

-- 바 텍스처 선택지 (WoW 기본 내장 텍스처)
local BAR_TEXTURES = {
    { name = "기본 (Default)",  path = "Interface\\TargetingFrame\\UI-StatusBar"              },
    { name = "레이드 HP",       path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"               },
    { name = "플랫 (Flat)",     path = "Interface\\Buttons\\WHITE8x8"                         },
    { name = "스킬바 (Skills)", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local function FindTexIndex()
    local cur = RMTdb and RMTdb.barTexture or BAR_TEXTURES[1].path
    for i, t in ipairs(BAR_TEXTURES) do
        if t.path == cur then return i end
    end
    return 1
end

-- ================================================================
-- 옵션 프레임
-- ================================================================
local opt = CreateFrame("Frame", "RMT_OptionsFrame", UIParent, "BackdropTemplate")
opt:SetSize(OPT_W, 100)   -- 높이는 항목 추가 후 자동 설정
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

local titleFs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleFs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, -9)
titleFs:SetText("|cffff9900공생기 트래커|r  설정")

local closeBtn = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", opt, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() opt:Hide() end)

-- ================================================================
-- 레이아웃 헬퍼 (y 누적으로 항목 배치)
-- ================================================================
local yPos = -(TITLE_H + 4)

local function ApplyAndRefresh()
    if RMT_UI_ApplySettings then RMT_UI_ApplySettings() end
end

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

-- 슬라이더: key = RMTdb의 키 이름
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

-- 체크박스
local checkRefs = {}
local function AddCheckbox(label, key, defaultVal)
    local cb = CreateFrame("CheckButton", "RMT_Opt_"..key, opt, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos + 3)
    cb.text:SetText(label)
    cb.text:SetFontObject(GameFontNormalSmall)
    cb:SetScript("OnClick", function(self)
        if RMTdb then RMTdb[key] = self:GetChecked() end
    end)
    checkRefs[key] = { widget = cb, default = defaultVal }
    yPos = yPos - 28
    return cb
end

-- ================================================================
-- 외관 섹션
-- ================================================================
AddHeader("외관")
AddSlider("배경 투명도", 0.1, 1.0, 0.05, "bgAlpha",    "%.2f")
AddSlider("행 높이",     20,  44,  1,    "rowHeight",  "%d px")
AddSlider("아이콘 크기", 14,  36,  1,    "iconSize",   "%d px")
AddSlider("폰트 크기",   8,   18,  1,    "fontSize",   "%d")
AddSlider("행 간격",     0,   12,  1,    "rowSpacing", "%d px")

-- 바 텍스처 (이전/다음 버튼)
yPos = yPos - 4
local texIdx = FindTexIndex()

local texLbl = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
texLbl:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
texLbl:SetText("바 텍스처")

local texValFs = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
texValFs:SetPoint("LEFT", texLbl, "RIGHT", 10, 0)
texValFs:SetText(BAR_TEXTURES[texIdx].name)

local function UpdateTex(dir)
    texIdx = texIdx + dir
    if texIdx < 1 then texIdx = #BAR_TEXTURES
    elseif texIdx > #BAR_TEXTURES then texIdx = 1 end
    texValFs:SetText(BAR_TEXTURES[texIdx].name)
    if RMTdb then RMTdb.barTexture = BAR_TEXTURES[texIdx].path end
    ApplyAndRefresh()
end

local prevBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
prevBtn:SetSize(26, 20)
prevBtn:SetText("<")
prevBtn:SetPoint("LEFT", texValFs, "RIGHT", 8, 0)
prevBtn:SetScript("OnClick", function() UpdateTex(-1) end)

local nextBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
nextBtn:SetSize(26, 20)
nextBtn:SetText(">")
nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
nextBtn:SetScript("OnClick", function() UpdateTex(1) end)

yPos = yPos - 32

-- ================================================================
-- 정렬 섹션
-- ================================================================
AddHeader("정렬")

-- 라디오 버튼 쌍 (UICheckButtonTemplate로 상호 배타 구현)
local rbName = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
rbName:SetSize(22, 22)
rbName:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos + 3)
rbName.text:SetText("이름순 (가나다 / ABC)")
rbName.text:SetFontObject(GameFontNormalSmall)
yPos = yPos - 28

local rbCd = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
rbCd:SetSize(22, 22)
rbCd:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos + 3)
rbCd.text:SetText("쿨타임 낮은 순")
rbCd.text:SetFontObject(GameFontNormalSmall)
yPos = yPos - 28

rbName:SetScript("OnClick", function()
    rbName:SetChecked(true)
    rbCd:SetChecked(false)
    if RMTdb then RMTdb.sortMode = "name" end
    ApplyAndRefresh()
end)
rbCd:SetScript("OnClick", function()
    rbCd:SetChecked(true)
    rbName:SetChecked(false)
    if RMTdb then RMTdb.sortMode = "cd" end
    ApplyAndRefresh()
end)

-- ================================================================
-- 기능 섹션
-- ================================================================
AddHeader("기능")
AddCheckbox("아이콘 마우스오버 툴팁", "tooltipOn", true)

-- ================================================================
-- 프레임 최종 높이 확정
-- ================================================================
opt:SetHeight(math.abs(yPos) + PAD + 10)

-- ================================================================
-- 공개 함수: 창 열기 (최신 RMTdb 값으로 동기화)
-- ================================================================
function RMT_Options_Open()
    if not RMTdb then opt:Show(); return end

    -- 슬라이더 동기화
    for key, ref in pairs(sliderRefs) do
        local val = RMTdb[key]
        if val then
            ref.widget:SetValue(val)
            ref.sync(val)
        end
    end

    -- 체크박스 동기화
    for key, ref in pairs(checkRefs) do
        local val = RMTdb[key]
        if val == nil then val = ref.default end
        ref.widget:SetChecked(val)
    end

    -- 정렬 라디오 동기화
    local mode = RMTdb.sortMode or "name"
    rbName:SetChecked(mode == "name")
    rbCd:SetChecked(mode == "cd")

    -- 텍스처 동기화
    texIdx = FindTexIndex()
    texValFs:SetText(BAR_TEXTURES[texIdx].name)

    opt:Show()
    opt:Raise()
end
