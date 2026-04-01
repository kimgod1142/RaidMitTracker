# RaidMitTracker — AGENTS.md
> **AI 에이전트 및 다중 환경 개발자용 공유 노트**
> 세션 시작 전 반드시 `git pull` 후 이 파일을 읽을 것.
> 세션 종료 전 반드시 이 파일을 업데이트하고 커밋할 것.

---

## 현재 상태

| 항목 | 내용 |
|---|---|
| **버전** | v1.1.0 (배포됨) |
| **마지막 작업** | 2026-04-01 (Session 4, Claude Code 회사계정) |
| **안정성** | M+ 실전 테스트 완료, BugSack 에러 해소 |
| **GitHub** | https://github.com/kimgod1142/RaidMitTracker |
| **CurseForge** | 프로젝트 ID: 1499477 (수동 업로드 필요) |

---

## 마지막 세션에서 한 것 (Session 4 — 2026-04-01)

- `PLAYER_ENTERING_WORLD` 핸들러 추가 — 구역 이동 시 로스터 초기화 + 자동 HAVE/CHECK
- `GROUP_ROSTER_UPDATE` 개선 — 리더/부리더는 CHECK 자동 전송 (이전: HAVE만 전송)
- `GetCooldown()` pcall 방어 + GCD 오염값 필터 (duration < 5s 무시)
- `autoShow` 옵션 추가 — 인스턴스 진입 시 패널 자동 표시 (리더 전용)
- 원격 Session 3 변경 rebase 병합:
  - Secret Value 버그 3종 수정 (M+ 실전에서 발견)
  - `INSTANCE_CHAT` 크로스렐름 지원
  - `CollectMySpells()` 실제 탤런트 CD 반영
  - 승천(114052) SpellDB 추가
  - Options.lua 추적 정확도 안내 섹션

---

## 다음 우선순위

1. **인게임 테스트** — PLAYER_ENTERING_WORLD/autoShow 실제 동작 확인
2. **SpellDB 검증** — 아래 "미확인 스펠 ID" 목록 인게임에서 확인 필요
3. **공격대 규모 테스트** — RegisterUnitEvent에 raid1-40 unpack 안정성 검증
4. **v1.2.0 계획** — 아래 로드맵 참고

---

## 알려진 이슈

| 이슈 | 심각도 | 상태 |
|---|---|---|
| RegisterUnitEvent에 raid1-40 unpack — WoW 제한 있을 수 있음 | 중 | 미검증 |
| 파티원 탤런트 쿨감 반영 불가 (WoW API 제약) | 낮음 | 설계상 한계, Options에 안내문 있음 |
| 고통 억제(33206) 충전 시스템 — 충전 복잡도로 부정확 가능 | 낮음 | 안내문 있음 |

---

## SpellDB 미확인 항목

인게임에서 검증이 필요한 스펠 ID:
```
-- 확인 방법: /run local i=C_Spell.GetSpellInfo(ID); print(i and i.spellID or "not found")
승천(114052)     — Session 3에서 추가됨, 인게임 검증 필요
```

---

## v1.2.0 로드맵 (아이디어)

- [ ] `PLAYER_ENTERING_WORLD` 동작 검증 후 안정화
- [ ] 공격대 규모(25/40인) RegisterUnitEvent 안정성 확인
- [ ] 자동 CHECK 타이밍 조정 (현재 2~3s, 상황에 따라 최적화 필요)
- [ ] Loxx에서 배운 패턴 추가 반영:
  - string-keyed 테이블 fallback (spellID taint 대비)
  - 주기적 STATE resync (USED 메시지 유실 대비)

---

## 중요 기술 메모 (WoW 12.0 API 제약)

### Secret Value 이슈
WoW Midnight 12.0+에서 전투 중 일부 API 반환값이 "secret"으로 마킹됨.
비교/테이블 인덱스 사용 시 에러 발생. 반드시 `pcall`로 보호.

```lua
-- ❌ 직접 사용 금지 (전투 중 에러 가능)
if RMT_SPELLS[spellID] then ...

-- ✅ pcall 보호
local ok, inDB = pcall(function() return RMT_SPELLS[spellID] end)
if ok and inDB then ...
```

### GetSpellCooldown taint
전투 중 `C_Spell.GetSpellCooldown()` 반환값도 secret value.
비교 연산 시 에러 → pcall + 폴백 패턴 사용.

### RegisterUnitEvent vs RegisterEvent
- `COMBAT_LOG_EVENT_UNFILTERED`: 12.0에서 restricted — **사용 금지**
- `UNIT_SPELLCAST_SUCCEEDED`: RegisterUnitEvent로 등록 — 안전

### INSTANCE_CHAT
인스턴스(M+, 공격대) 내에서는 `PARTY`/`RAID` 채널 애드온 메시지가
크로스렐름 파티원에게 전달 안 됨 → `INSTANCE_CHAT` 사용.

### RegisterFrames 지연
`ADDON_LOADED` 핸들러 내에서 `CreateFrame` + `RegisterEvent` 직접 호출 시
다른 애드온이 먼저 taint를 남기면 차단됨.
→ `C_Timer.After(0, RegisterFrames)` 로 지연 실행.

---

## 파일 구조

```
RaidMitTracker/
├── AGENTS.md               ← 이 파일 (공유 노트)
├── RaidMitTracker.toc
├── RaidMitTracker.lua      ← 코어 (통신, 이벤트, 슬래시 명령)
├── SpellDB.lua             ← 스킬 테이블
├── UI.lua                  ← 패널 UI
├── Options.lua             ← 설정창
├── Locales.lua             ← EN/KR
├── DEVLOG.md               ← 세션별 상세 변경 이력
├── CHANGELOG.md            ← 사용자용 릴리즈 노트
├── libs/
│   ├── LibStub/
│   ├── LibSharedMedia-3.0/
│   ├── LibDataBroker-1.1/
│   └── LibDBIcon-1.0/
└── .github/workflows/release.yml  ← tag push → GitHub Release 자동화
```

---

## 워크플로우

```bash
# 세션 시작
git pull
# → AGENTS.md 읽기 (지금 이 파일)

# 작업 후
# → AGENTS.md "마지막 세션에서 한 것" 업데이트
# → "다음 우선순위" 업데이트
git add -A
git commit -m "..."
git push
```
