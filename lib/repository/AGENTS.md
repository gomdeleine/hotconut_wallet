# repository/ AGENTS.md

디스크·Realm·SecureStorage·SharedPrefs. 상위: [AGENTS.md](../../AGENTS.md)

## Do

- `BaseRepository` 상속, `handleRealm` / `Result<T>` 패턴
- [app.dart](../app.dart)에서 `Provider<Repo>`로 DI

```dart
Provider<AddressRepository>(
  create: (ctx) => AddressRepository(ctx.read<RealmManager>()),
),
```

## Don't

- 네트워크·소켓 호출 금지 → `services/`
- `ChangeNotifier` 사용 금지

## 호출 관계

ViewModel / Provider → Repository (Screen에서 직접 호출 금지)
