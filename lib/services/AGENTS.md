# services/ AGENTS.md

네트워크·소켓·외부 API. 상위: [AGENTS.md](../../AGENTS.md)

## Do

- 신규 파일은 `lib/services/`에만 추가
- ViewModel / Provider에서 호출

## Don't

- Realm / SharedPrefs / SecureStorage 접근 금지 → `repository/`
- Screen에서 직접 호출 금지

## 기존 코드

`providers/node_provider/*_service` 파일은 건드릴 때만 `lib/services/`로 이동한다. 당장 일괄 이동하지 않는다.

## 호출 관계

ViewModel / Provider → Service → (필요 시) `core/`
