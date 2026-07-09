# providers/view_model/ AGENTS.md

화면별 ViewModel. 화면 수명과 같다. 상위: [AGENTS.md](../../../AGENTS.md)

## Do

- `extends ChangeNotifier`, `private _field` + public getter
- 의존성은 생성자 주입 (`WalletProvider`, `UtxoRepository` 등)
- `dispose()`에서 `addListener` 등록분 `removeListener` + Stream cancel
- 로딩/에러 (신규 표준): `bool _isLoading`, `String? _errorMessage`
- `core/` 호출 OK, 로직 복사 금지

## Don't

- `new Repository()` / `SharedPrefsRepository()` 직접 생성 금지
- `TextEditingController` 등 UI 객체 소유 금지 (레거시 `SendViewModel` 콜백 패턴은 신규 금지)
- enum/모델을 ViewModel 파일에 정의 금지 → `lib/model/` 또는 `*_models.dart`

## 파일 규칙

- 경로: `lib/providers/view_model/<feature>/<name>_view_model.dart`
- 클래스: `{Feature}ViewModel` (파일명과 일치)

## ViewModel에 넣을 것 / 넣지 말 것

| 넣어도 됨 | 넣지 말 것 (`core/`에 있음) |
|-----------|---------------------------|
| Provider 조합·파생 값 | 트랜잭션 조립, UTXO 선택 알고리즘 |
| 로딩/에러/버튼 활성화 | fee 계산 로직 |
| 액션 → Provider/Service 호출 | |

## 레거시 예외 (신규 금지)

- `SignedPsbtScannerViewModel` — ChangeNotifier 미사용
- `SettingsViewModel` — 상태 없는 delegate
