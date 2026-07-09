# core/ AGENTS.md

순수 계산 모듈 (트랜잭션 빌드, UTXO 선택, BIP 정규화). 상위: [AGENTS.md](../../AGENTS.md)

Clean Architecture의 Domain Layer가 아니다. Flutter/DB/소켓 없이 테스트 가능한 코드만 둔다.

## Do

- Flutter / DB / 소켓 import 없음
- ViewModel이 **호출**만 (`TransactionBuilder`, `UtxoSelector` 등)
- 단위 테스트 가능하게 유지

## Don't

- 폴더 추가·이름 변경 금지
- Provider / Repository / Service 의존 금지
- ViewModel 안에 계산 로직 복사 금지

## 참고

`SendViewModel` + `core/transaction/` 조합이 올바른 방향이다.
