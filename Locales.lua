-- Locales.lua
-- English default, Korean (koKR) override

local L = {
    -- UI
    TITLE           = "Raid Mit Tracker",
    READY           = "Ready",
    LEADER_ONLY     = "Only raid leader or assistant can use this panel.",

    -- Chat messages
    NOT_IN_GROUP    = "You are not in a party or raid.",
    CHECK_SENT      = "Cooldown check request sent.",
    REPORTED        = "Your cooldowns have been reported to the raid.",
    RESET_DONE      = "Roster cleared.",
    HELP            = "Commands: /rmt (check) | /rmt reset | /rmt show | /rmt test | /rmt config",
    LOADED          = "loaded",
    TEST_MODE       = "|cffaaffaa[TEST MODE]|r Dummy data loaded — /rmt reset to clear",
    WIPE_RESET      = "|cffff4444[WIPE]|r Encounter failed — all cooldowns reset.",
    AUTO_SHOW       = "Auto-show panel on instance entry (leader/assist only)",
}

if GetLocale() == "koKR" then
    L.TITLE           = "공생기 트래커"
    L.READY           = "사용가능"
    L.LEADER_ONLY     = "공대장 또는 부공대장만 패널을 사용할 수 있습니다."

    L.NOT_IN_GROUP    = "공대/파티에 속해 있지 않습니다."
    L.CHECK_SENT      = "공생기 확인 요청을 보냈습니다."
    L.REPORTED        = "본인 보유 공생기를 공대에 보고했습니다."
    L.RESET_DONE      = "목록을 초기화했습니다."
    L.HELP            = "명령어: /rmt (확인 요청) | /rmt reset | /rmt show | /rmt test | /rmt config"
    L.LOADED          = "로드됨"
    L.TEST_MODE       = "|cffaaffaa[TEST MODE]|r 가짜 데이터 로드 완료 — /rmt reset 으로 초기화"
    L.WIPE_RESET      = "|cffff4444[전멸]|r 인카운터 실패 — 모든 쿨타임이 초기화되었습니다."
    L.AUTO_SHOW       = "인스턴스 진입 시 패널 자동 표시 (리더/부리더 전용)"
end

RMT_L = L
