# RaidMitTracker — Dev Log

---

## v1.0.0 (2026-03-30) — Initial Release

### 개요
공대 생존기(공생기) 및 외부생존기 쿨타임 실시간 추적 애드온 첫 배포.

---

### 구현된 기능

#### 통신 (RaidMitTracker.lua)
- `SendAddonMessage` 기반 조용한 통신 — 채팅창에 아무것도 안 뜸
- `CHECK` → `HAVE` → `USED` 3단계 프로토콜
- `UNIT_SPELLCAST_SUCCEEDED` — 본인 스킬 사용 감지
- `COMBAT_LOG_EVENT_UNFILTERED` — 애드온 미설치 공대원 백업 감지
- `GROUP_ROSTER_UPDATE` — 공대 합류 2초 후 자동 보고

#### 스킬 DB (SpellDB.lua)
- 공생기 10종 + 외부생존기 6종
- 필드: `name` (한국어), `name_en` (영어), `cd`, `class`, `spec`, `category`, `icon`, `isTalent`

| 스펠 ID | 스킬명 | 영문명 | 쿨타임 |
|---|---|---|---|
| 62618 | 신의 권능: 방벽 | Power Word: Barrier | 3분 |
| 64843 | 천상의 찬가 | Divine Hymn | 3분 |
| 51052 | 대마법 지대 | Anti-Magic Zone | 4분 |
| 31821 | 오라 숙련 | Aura Mastery | 3분 |
| 98008 | 정신의 고리 토템 | Spirit Link Totem | 3분 |
| 108280 | 치유의 해일 토템 | Healing Tide Totem | 3분 |
| 363534 | 되돌리기 | Rewind | 4분 |
| 740 | 평온 | Tranquility | 3분 |
| 297850 | 재활 | Revival | 3분 |
| 97462 | 재집결의 함성 | Rallying Cry | 3분 |
| 47788 | 수호 영혼 | Guardian Spirit | 3분 |
| 33206 | 고통 억제 | Pain Suppression | 3분 |
| 102342 | 무쇠 껍질 | Ironbark | 1.5분 |
| 6940 | 희생의 축복 | Blessing of Sacrifice | 2분 |
| 357170 | 시간 팽창 | Time Dilation | 1분 |
| 116849 | 기의 고치 | Life Cocoon | 2분 |

#### UI (UI.lua)
- 공대장/부공대장 전용 패널 (UnitIsGroupLeader / UnitIsGroupAssistant)
- 레이아웃: `[플레이어명 80px][스킬아이콘 22px][직업색 쿨타임바 ────][남은초]`
- `OnUpdate` 매 프레임 갱신 (부드러운 바 애니메이션)
- 직업 색상: UnitClass → SpellDB.class 2단계 fallback
- 쿨타임 종료 / 미사용 시 바 중앙에 "Ready" / "사용가능" 표시
- 드래그 이동 + 오른쪽/하단/모서리 리사이즈, 위치·크기 `RMTdb`에 저장

#### 로케일 (Locales.lua)
- EN 기본 + koKR 오버라이드 (`RMT_L` 글로벌)
- 키: TITLE / READY / LEADER_ONLY / NOT_IN_GROUP / CHECK_SENT / REPORTED / RESET_DONE / HELP / LOADED / TEST_MODE

#### 테스트 모드
- `/rmt test` — 솔로 UI 테스트용 더미 데이터 로드
- 이름: 랜덤 형용사+직업명 (KR: `배고픈드루이드` / EN: `angryWarrior`)
  - 한국어 형용사 10개 + 영어 형용사 10개 조합
  - 실행마다 다른 이름, 중복 시 숫자 접미사 처리

---

### 수정된 버그

| 버그 | 원인 | 수정 |
|---|---|---|
| `/rmt show` 후 엔터 불가 (채팅 잠김) | `local RMT`로 선언 → UI.lua에서 nil 참조 → Lua 에러 | `RMT` 글로벌로 변경 |
| USED 메시지 파싱 실패 | Lua 패턴에 `\d` 사용 (Lua는 `%d`) | `[%d%.]+` 로 수정 |
| 준비 상태 플레이어 표시 없음 | `endTime=0` 분기에서 near-black 색상 텍스트 | readyText FontString으로 교체 |
| 재활 스펠 ID 오류 | 115310 (MoP Classic 버전) | 297850 (TWW 정식 ID) 로 수정 |

---

### 파일 구조

```
RaidMitTracker/
├── RaidMitTracker.toc
├── RaidMitTracker.lua        ← 통신 + 이벤트 + 슬래시 커맨드
├── SpellDB.lua               ← 스킬 테이블 (name_en 포함)
├── UI.lua                    ← 패널 UI
├── Locales.lua               ← EN/KR 로케일
├── libs/LibStub/LibStub.lua
├── README.md                 ← GitHub 배포용
├── DEVLOG.md                 ← 이 파일
└── curseforge-description.html ← CurseForge 업로드용
```

### SavedVariables (`RMTdb`)
```lua
RMTdb = {
    panelPos  = { pt, rpt, x, y },   -- 패널 위치
    panelSize = { w, h },            -- 패널 크기
}
```

---

### 배포 현황
- GitHub: https://github.com/kimgod1142/RaidMitTracker
- CurseForge: 심사 요청 중
- 배포 파일: `RaidMitTracker-1.0.0.zip`
