# screens/ AGENTS.md

화면 UI. ViewModel만 호출한다. 상위: [AGENTS.md](../../AGENTS.md)

## Do

- ViewModel만 호출: `context.read<XxxViewModel>()`, `Selector`, `Consumer`
- 전역 Provider는 ViewModel `create:` 시 `context.read`로 주입만 (Screen이 직접 구독하지 않음)
- 800줄 초과 시 private widget 파일로 분리 (예: `send_amount_section.dart`)

## Don't

- `Repository`, `Service` 직접 호출·생성 금지
- 비즈니스 로직·조건 분기를 Screen에 작성 금지

## ViewModel 제공 패턴 (신규 화면 선택 기준)

| 상황 | 패턴 | 참고 |
|------|------|------|
| 다중 Provider 동기화 | `ChangeNotifierProxyProviderN` + `Selector` | `home/wallet_home_screen.dart` |
| 단순 화면 스코프 | `ChangeNotifierProvider` + `Consumer`/`Selector` | `settings/electrum_server_screen.dart` |
| 바텀시트·짧은 수명 | `initState` 생성 → `ChangeNotifierProvider.value` | `common/tag_apply_bottom_sheet.dart` |

## 혼재 정리 (신규 코드)

- `context.read<T>()` 사용 (`Provider.of` 신규 작성 금지)
- Provider 트리 없이 필드만 보유 (`onboarding/start_screen.dart`) — 신규 금지
- `ProxyProvider` `update`에서 ViewModel 재생성 금지 — `previous` 재사용 + 갱신 메서드 호출

## 네이밍

- 파일: `*_screen.dart`, `*_bottom_sheet.dart`
- ViewModel: `lib/providers/view_model/<동일 feature>/`
