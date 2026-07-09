# providers/ AGENTS.md

앱 전역 상태. `view_model/`은 [별도 가이드](view_model/AGENTS.md). 상위: [AGENTS.md](../../AGENTS.md)

## 역할

앱 수명 주기 상태: `WalletProvider`, `NodeProvider`, `AuthProvider`, `PreferenceProvider` 등

| | ViewModel | Provider |
|--|-----------|----------|
| 수명 | 화면 진입~퇴장 | 앱 전체 |
| 담는 것 | 로딩, 폼, UI 플래그 | 지갑 목록, 동기화, 설정 |

## Do

- `extends ChangeNotifier` + `notifyListeners()`
- [app.dart](../app.dart) `MultiProvider`에만 등록 (순서: Repository → Provider)
- `main` 진입 후에만 무거운 Provider 등록 (`WalletProvider`, `NodeProvider`)

## Don't

- 화면 전용 UI 상태 저장 금지 → ViewModel로
- UseCase/레이어 추가로 Provider 쪼개기 금지

## 예외: SendInfoProvider

- ChangeNotifier 아닌 송금 플로우 세션 버킷
- 송금 관련 ViewModel만 접근 (Screen 직접 접근 금지)
- 향후 `SendFlowState`로 이름 변경 예정

## 등록

`app.dart`에서 Repository를 Provider보다 먼저 등록한다.

```dart
Provider<AddressRepository>(create: (ctx) => AddressRepository(ctx.read<RealmManager>())),
ChangeNotifierProvider(create: (ctx) => WalletProvider(...)),
```
