-- Options.lua
-- 공생기 트래커 자체 설정창  (/rmt config)

local OPT_W       = 370
local PAD         = 14
local TITLE_H     = 30
local POPUP_ROW_H = 30

-- 바 텍스처 선택지
local BAR_TEXTURES = {
    { name = "기본 (Default)",  path = "Interface\\TargetingFrame\\UI-StatusBar"               },
    { name = "레이드 HP",       path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"                },
    { name = "플랫 (Flat)",     path = "Interface\\Buttons\\WHITE8x8"                          },
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

local titleFs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleFs:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, -9)
titleFs:SetText("|cffff9900공생기 트래커|r  설정")

local closeBtn = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", opt, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() opt:Hide() end)

-- ================================================================
-- 텍스처 드롭다운 팝업 (UIParent 자식 — 옵션창에 클리핑 안 됨)
-- ================================================================
local texPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
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

-- 팝업 외부 클릭 감지 (FULLSCREEN < TOOLTIP 이므로 팝업 버튼은 여전히 클릭 가능)
local texCatch = CreateFrame("Frame", nil, UIParent)
texCatch:SetAllPoints(UIParent)
texCatch:SetFrameStrata("FULLSCREEN")
texCatch:EnableMouse(true)
texCatch:Hide()
texCatch:SetScript("OnMouseDown", function()
    texPopup:Hide()
    texCatch:Hide()
end)

opt:SetScript("OnHide", function()
    texPopup:Hide()
    texCatch:Hide()
end)

-- 팝업 내 선택 하이라이트 참조 (선택 시 갱신용)
local selHighlights = {}
local texBtn        -- 드롭다운 버튼 (아래에서 정의, 팝업 OnClick에서 참조)

local function SelectTexture(i)
    texIdx = i
    if texBtn then texBtn:SetText(BAR_TEXTURES[i].name .. "  ▼") end
    if RMTdb  then RMTdb.barTexture = BAR_TEXTURES[i].path end
    for j, hl in ipairs(selHighlights) do hl:SetShown(j == i) end
    texPopup:Hide()
    texCatch:Hide()
    if RMT_UI_ApplySettings then RMT_UI_ApplySettings() end
end

-- 팝업 항목 생성
local texIdx = FindTexIndex()
for i, tex in ipairs(BAR_TEXTURES) do
    local row = CreateFrame("Button", nil, texPopup)
    row:SetHeight(POPUP_ROW_H)
    row:SetPoint("TOPLEFT",  texPopup, "TOPLEFT",  4, -(4 + (i - 1) * POPUP_ROW_H))
    row:SetPoint("TOPRIGHT", texPopup, "TOPRIGHT", -4, 0)

    -- 현재 선택 배경
    local selBg = row:CreateTexture(nil, "BACKGROUND")
    selBg:SetAllPoints()
    selBg:SetColorTexture(0.8, 0.5, 0.1, 0.18)
    selBg:SetShown(i == texIdx)
    selHighlights[i] = selBg

    -- 호버 하이라이트
    local hlTex = row:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints()
    hlTex:SetColorTexture(1, 1, 1, 0.08)

    -- 텍스처 미리보기 바
    local preview = CreateFrame("StatusBar", nil, row)
    preview:SetSize(90, 14)
    preview:SetPoint("LEFT", row, "LEFT", 4, 0)
    preview:SetStatusBarTexture(tex.path)
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0.65)
    preview:SetStatusBarColor(0.3, 0.65, 1, 1)

    -- 텍스처 이름
    local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    nameFs:SetText(tex.name)

    row:SetScript("OnClick", function() SelectTexture(i) end)
end

texPopup:SetHeight(4 + #BAR_TEXTURES * POPUP_ROW_H + 4)

-- ================================================================
-- 레이아웃 헬퍼
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

-- 바 텍스처 드롭다운
yPos = yPos - 4
local texLbl = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
texLbl:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
texLbl:SetText("바 텍스처")
yPos = yPos - 18

texBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
texBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", PAD, yPos)
texBtn:SetWidth(OPT_W - PAD * 2 - 4)
texBtn:SetHeight(22)
texBtn:SetText(BAR_TEXTURES[texIdx].name .. "  ▼")
texBtn:SetScript("OnClick", function()
    if texPopup:IsShown() then
        texPopup:Hide()
        texCatch:Hide()
    else
        texPopup:ClearAllPoints()
        texPopup:SetPoint("TOPLEFT", texBtn, "BOTTOMLEFT", 0, -2)
        texPopup:SetWidth(texBtn:GetWidth())
        texPopup:Show()
        texPopup:Raise()
        texCatch:SetFrameLevel(texPopup:GetFrameLevel() - 1)
        texCatch:Show()
    end
end)

yPos = yPos - 28

-- ================================================================
-- 정렬 섹션
-- ================================================================
AddHeader("정렬")

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
-- 공개 함수: 창 열기
-- ================================================================
function RMT_Options_Open()
    if not RMTdb then opt:Show(); return end

    -- 그룹 밖이면 테스트 모드 자동 실행 (미리보기용)
    if not IsInGroup() then
        SlashCmdList["RMT"]("test")
    end

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

    -- 텍스처 드롭다운 동기화
    texIdx = FindTexIndex()
    texBtn:SetText(BAR_TEXTURES[texIdx].name .. "  ▼")
    for j, hl in ipairs(selHighlights) do hl:SetShown(j == texIdx) end

    opt:Show()
    opt:Raise()
end
