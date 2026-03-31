-- SpellDB.lua
-- 추적할 스킬 테이블
--
-- ⚠️  스펠 ID 검증 방법 (게임 내):
--     /run local i=C_Spell.GetSpellInfo(62618); print(i and i.spellID or "not found")
--
-- cd       = 기본 쿨타임(초)
-- spec     = "ANY" → 해당 클래스 전 특성에서 사용 가능
-- category = "RAID"     → 공생기 (공대 전체 영향)
--            "EXTERNAL" → 외부생존기 (단일 대상)
--
-- ⚠️ 쿨감 탤런트 주석 표기 방식:
--    [탤런트명(ID)] 기본CD → 탤런트 적용CD  (감소량)
--    파티원의 탤런트 보유 여부는 WoW API로 조회 불가
--    → 하드코딩 기본값 사용, 실제와 다를 수 있음

RMT_SPELLS = {

    -- ════════════════════════════════════════════════════════════
    -- 공생기 (RAID)
    -- ════════════════════════════════════════════════════════════

    -- ── 사제 ──────────────────────────────────────────────────────
    [62618] = {
        name     = "신의 권능: 방벽",
        name_en  = "Power Word: Barrier",
        cd       = 180,
        class    = "PRIEST",
        spec     = "DISCIPLINE",
        category = "RAID",
        icon     = 253400,
    },
    -- ⚠️ 쿨감 탤런트: 대천사의 점증(419110) 180→120 (-60s)
    [64843] = {
        name     = "천상의 찬가",
        name_en  = "Divine Hymn",
        cd       = 180,
        class    = "PRIEST",
        spec     = "HOLY",
        category = "RAID",
        icon     = 237540,
    },

    -- ── 죽음의 기사 ───────────────────────────────────────────────
    [51052] = {
        name     = "대마법 지대",
        name_en  = "Anti-Magic Zone",
        cd       = 240,
        class    = "DEATHKNIGHT",
        spec     = "ANY",
        category = "RAID",
        icon     = 237510,
    },

    -- ── 성기사 ────────────────────────────────────────────────────
    [31821] = {
        name     = "오라 숙련",
        name_en  = "Aura Mastery",
        cd       = 180,
        class    = "PALADIN",
        spec     = "HOLY",
        category = "RAID",
        icon     = 135872,
    },

    -- ── 주술사 ────────────────────────────────────────────────────
    [98008] = {
        name     = "정신의 고리 토템",
        name_en  = "Spirit Link Totem",
        cd       = 180,
        class    = "SHAMAN",
        spec     = "RESTORATION",
        category = "RAID",
        icon     = 237586,
    },
    -- ⚠️ 쿨감 탤런트: 최초의 승천자(462440) 180→120 (-60s)
    [108280] = {
        name     = "치유의 해일 토템",
        name_en  = "Healing Tide Totem",
        cd       = 180,
        class    = "SHAMAN",
        spec     = "RESTORATION",
        category = "RAID",
        icon     = 538569,
        isTalent = true,
    },
    -- ⚠️ 쿨감 탤런트: 최초의 승천자(462440) 180→120 (-60s)
    -- 치유의 해일 토템과 동일 탤런트로 쿨감 적용
    [114052] = {
        name     = "승천",
        name_en  = "Ascendance",
        cd       = 180,
        class    = "SHAMAN",
        spec     = "RESTORATION",
        category = "RAID",
        icon     = 571586,
        isTalent = true,
    },

    -- ── 기원사 ────────────────────────────────────────────────────
    -- ⚠️ 쿨감 탤런트: 시간의 기술자(381922) 240→180 (-60s)
    [363534] = {
        name     = "되돌리기",
        name_en  = "Rewind",
        cd       = 240,
        class    = "EVOKER",
        spec     = "PRESERVATION",
        category = "RAID",
        icon     = 4622474,
    },

    -- ── 드루이드 ──────────────────────────────────────────────────
    -- ⚠️ 쿨감 탤런트: 내면의 평화(197073) 180→150 (-30s)
    [740] = {
        name     = "평온",
        name_en  = "Tranquility",
        cd       = 180,
        class    = "DRUID",
        spec     = "RESTORATION",
        category = "RAID",
        icon     = 136107,
    },

    -- ── 수도사 ────────────────────────────────────────────────────
    -- 재활(115310) / 회복(388615): 특성으로 둘 중 하나만 선택 가능, 쿨타임 동일
    -- 297850은 WoW 기준 존재하지 않는 스펠 ID (GetSpellInfo 반응 없음) → 제거
    -- ⚠️ 쿨감 탤런트: 고양된 영혼(388551) 150→120 (-30s)
    [115310] = {
        name     = "재활",
        name_en  = "Revival",
        cd       = 150,
        class    = "MONK",
        spec     = "MISTWEAVER",
        category = "RAID",
        icon     = 1020466,
    },
    -- ⚠️ 쿨감 탤런트: 고양된 영혼(388551) 150→120 (-30s)
    [388615] = {
        name     = "회복",
        name_en  = "Restoral",
        cd       = 150,
        class    = "MONK",
        spec     = "MISTWEAVER",
        category = "RAID",
        icon     = 1020466,
    },

    -- ── 전사 ──────────────────────────────────────────────────────
    [97462] = {
        name     = "재집결의 함성",
        name_en  = "Rallying Cry",
        cd       = 180,
        class    = "WARRIOR",
        spec     = "ANY",
        category = "RAID",
        icon     = 132351,
    },


    -- ════════════════════════════════════════════════════════════
    -- 외부생존기 (EXTERNAL)
    -- ════════════════════════════════════════════════════════════

    -- ── 사제 ──────────────────────────────────────────────────────
    -- ⚠️ 조건부 쿨감: 수호 천사(200209)
    --    대상을 살리지 못하고 만료 시 남은 쿨이 60s로 감소 (런타임 조건부 → 추적 불가)
    [47788] = {
        name     = "수호 영혼",
        name_en  = "Guardian Spirit",
        cd       = 180,
        class    = "PRIEST",
        spec     = "HOLY",
        category = "EXTERNAL",
        icon     = 237542,
    },
    -- ⚠️ 복합 쿨감: 약자의 보호자(373035)
    --    1) 충전 횟수 1회 추가 (최대 2충전)
    --    2) 신의 권능: 보호막 사용 시마다 3s씩 쿨 감소
    --    충전 기반 + 동적 감소 → 정확한 추적 불가
    [33206] = {
        name     = "고통 억제",
        name_en  = "Pain Suppression",
        cd       = 180,
        class    = "PRIEST",
        spec     = "DISCIPLINE",
        category = "EXTERNAL",
        icon     = 135936,
    },

    -- ── 드루이드 ──────────────────────────────────────────────────
    -- ⚠️ 쿨감 탤런트: 무쇠껍질 연마(382552) 90→70 (-20s)
    [102342] = {
        name     = "무쇠 껍질",
        name_en  = "Ironbark",
        cd       = 90,
        class    = "DRUID",
        spec     = "RESTORATION",
        category = "EXTERNAL",
        icon     = 572025,
    },

    -- ── 성기사 ────────────────────────────────────────────────────
    [6940] = {
        name     = "희생의 축복",
        name_en  = "Blessing of Sacrifice",
        cd       = 120,
        class    = "PALADIN",
        spec     = "ANY",
        category = "EXTERNAL",
        icon     = 135966,
    },

    -- ── 기원사 ────────────────────────────────────────────────────
    [357170] = {
        name     = "시간 팽창",
        name_en  = "Time Dilation",
        cd       = 60,
        class    = "EVOKER",
        spec     = "PRESERVATION",
        category = "EXTERNAL",
        icon     = 4622478,
    },

    -- ── 수도사 ────────────────────────────────────────────────────
    -- ⚠️ 쿨감 탤런트: 번데기(202424) 120→75 (-45s)
    [116849] = {
        name     = "기의 고치",
        name_en  = "Life Cocoon",
        cd       = 120,
        class    = "MONK",
        spec     = "MISTWEAVER",
        category = "EXTERNAL",
        icon     = 627485,
    },
}

-- 스펠 ID → 스킬 정보 빠른 조회 (별칭)
RMT_SPELL_IDS = {}
for id, data in pairs(RMT_SPELLS) do
    RMT_SPELL_IDS[id] = data
end
