# widgets/ AGENTS.md

재사용 UI 컴포넌트. 상위: [AGENTS.md](../../AGENTS.md)

## Do

- props / callback으로 데이터·이벤트 수신
- Screen에서 분리한 조각은 `lib/widgets/` 또는 screen 옆 co-locate

## Don't

- Provider / Repository / Service 직접 접근 금지
- 비즈니스 로직 작성 금지

필요 시 callback으로 Screen / ViewModel에 위임한다.

## Screen 분리

800줄 넘는 Screen은 `_buildXxxSection()` → 별도 widget 파일로 분리 (아키텍처 변경 아님).
