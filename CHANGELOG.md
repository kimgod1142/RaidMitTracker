# Changelog

All notable changes to RaidMitTracker are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [1.1.0] - 2026-03-31

### Fixed
- **ADDON_ACTION_FORBIDDEN 오류 수정**: TWW 12.0에서 `COMBAT_LOG_EVENT_UNFILTERED`가 restricted event로 지정되어 `RegisterEvent()` 호출 시 오류 발생. `RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", ...)` 방식으로 교체.
- **본인 스킬 사용 미감지 수정**: `castFrame`이 `party1~4` / `raid1~40` 대상으로만 등록되어 솔로·파티 상태에서 본인 스킬이 추적되지 않던 문제 수정.
- **패널 미갱신 수정**: Config로 패널을 열어 둔 상태에서 스킬을 사용해도 패널이 갱신되지 않던 문제 수정 (리더 체크 로직 위치 문제).
- **bgAlpha 복원 누락 수정**: 세션 재접속 시 저장된 배경 투명도가 반영되지 않던 문제 수정.
- **bgAlpha 기본값 불일치 수정**: `ApplySettings`의 fallback 값(`0.96`)이 defaults 테이블(`0.55`)과 달랐던 문제 수정.
- **`CHAT_MSG_ADDON` 등록 위치 수정**: 메인 청크에서 등록 시 taint로 수신이 불가능하던 문제. `ADDON_LOADED` 핸들러 내부로 이동.
- **`C_Spell.GetSpellCharges` 반환 형식 처리**: TWW에서 테이블로 반환될 경우와 기존 다중반환 방식을 모두 처리하도록 수정.
- **Options.lua 타이틀 하드코딩 수정**: 한국어 고정 텍스트를 `RMT_L.TITLE` + 로케일 분기로 교체.

### Changed
- **UI 아키텍처 리팩토링**: 패널 표시 여부 결정과 내용 갱신 로직을 완전히 분리. `RebuildRows()` (내부) / `RMT_UI_RefreshPanel()` / `RMT_UI_ShowPanel()` / `RMT_UI_ForceShow()` / `RMT_UI_ApplySettings()` 역할 명확화.

### SpellDB
- 운무 수도사 재활(115310) / 회복(388615) 추가 — 특성 선택지, 쿨타임 2분 30초
- 유효하지 않은 스펠 ID 297850 제거 (TWW 기준 `GetSpellInfo` 반응 없음)

---

## [1.0.0] - 2026-03-28

### Added
- 공대 생존기(공생기) 쿨타임 추적 코어 기능
- 공대원 스킬 사용 감지 및 애드온 메시지 브로드캐스트 (`MITTRACK` prefix)
- 공대장·부공대장 전용 쿨타임 패널 (직업 색상 바, 이름, 아이콘, 남은 시간)
- 패널 드래그 이동 / 리사이즈 / 위치·크기 저장
- Options UI: 배경 투명도, 행 높이, 바 두께, 아이콘 크기, 폰트 크기, 행 간격, 바 텍스처, 정렬 기준, 아이콘 표시, 툴팁
- 솔로 테스트 모드 (`/rmt test`) — 랜덤 가짜 공대원 데이터로 UI 확인
- 전멸 감지 후 쿨타임 자동 초기화
- 미니맵 버튼 (LibDataBroker + LibDBIcon)
- 한국어·영어 로케일 지원
- SpellDB: 사제·죽음의기사·성기사·주술사·기원사·드루이드·수도사·전사 주요 공생기 수록
