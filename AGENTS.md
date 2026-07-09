# AGENTS.md

Flutter + `provider` 패키지 기반 MVVM. Riverpod 없음.

## 계층

```
screens/              → UI (ViewModel만 호출)
widgets/              → 재사용 UI
providers/view_model/ → 화면별 ViewModel
providers/            → 앱 전역 상태
repository/           → DB·로컬 저장
services/             → 네트워크·외부 API
core/                 → 순수 계산 (트랜잭션 빌드, UTXO 선택 등)
model/                → 데이터 클래스
```

## 6가지 경계

1. **Screen** → ViewModel만 본다 (전역 Provider는 ViewModel이 대신 읽음)
2. **ViewModel** → Provider / Repository / Service / `core` 호출 (`new Repository()` 금지)
3. **Repository** → 저장소만
4. **Service** → IO만
5. **core/** → 계산만 (폴더 추가·이름 변경 금지)
6. **새 레이어·새 접미사 금지**

## 계층별 가이드

| 수정 대상 | 문서 |
|-----------|------|
| `lib/screens/` | [lib/screens/AGENTS.md](lib/screens/AGENTS.md) |
| `lib/widgets/` | [lib/widgets/AGENTS.md](lib/widgets/AGENTS.md) |
| `lib/providers/view_model/` | [lib/providers/view_model/AGENTS.md](lib/providers/view_model/AGENTS.md) |
| `lib/providers/` (view_model 제외) | [lib/providers/AGENTS.md](lib/providers/AGENTS.md) |
| `lib/repository/` | [lib/repository/AGENTS.md](lib/repository/AGENTS.md) |
| `lib/services/` | [lib/services/AGENTS.md](lib/services/AGENTS.md) |
| `lib/core/` | [lib/core/AGENTS.md](lib/core/AGENTS.md) |

## PR 체크리스트 (신규·수정 공통)

- [ ] Screen이 Repository/Service를 직접 호출하지 않음
- [ ] ViewModel이 `new Repository()` 하지 않음
- [ ] 화면 상태는 ViewModel, 앱 상태는 Provider
- [ ] 신규 IO 코드는 `lib/services/`에만
- [ ] 800줄 넘는 Screen은 widget 분리 검토
