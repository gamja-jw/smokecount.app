# SmokeCount

흡연 기록 및 통계 분석 앱. Flutter(Android 우선, iOS 빌드 가능), 서버 없이 기기 로컬(SQLite)에만 저장한다.

## 핵심 규칙

- 흡연 버튼을 누를 때마다 **1개비**가 기록된다. (기록 단위 = 개비)
- 직전 기록과 **10분 이내**(설정에서 1~60분 조절)면 통계상 **한 번의 흡연 세션**으로 묶어
  "1회 n개비"로 집계한다. 묶기는 통계 표현일 뿐, 저장은 항상 개비 단위다.
- 하루 기준 시각을 0~6시로 설정할 수 있다. 4시로 두면 새벽 3시 흡연은 전날로 집계된다.
- 진행 중인 주/달의 평균은 **오늘까지 지난 날 수**로만 계산하고, 전 주기 비교도 같은 일수로 자른다.

## 화면

- **홈** — 흡연 버튼, 마지막 흡연 이후 경과 시간 링(한 바퀴 = 최근 7일 평균 간격),
  오늘 개비/세션 수, 어제·어제 같은 시각·7일 평균 대비 변화, 최근 7일 막대, 오늘 타임라인
- **통계** — 일간/주간/월간 탭
  - 일간: 요약 타일, 전날·7일 평균 대비, 시간대별 분포, 세션 상세
  - 주간: 요일별 막대(평균선), 요약, 지난주 같은 기간 대비, 시간대별 분포
  - 월간: 일별 추세 라인, 달력 히트맵, 요약, 지난달 대비, 요일별 평균, 시간대별 분포
- **기록** — 날짜별 목록, 개별 기록 시간 수정/삭제, 과거 시각으로 기록 추가
- **설정** — 연속 흡연 묶기 간격, 하루 기준 시각, 하루 목표, 개비당 가격, CSV 복사, 전체 삭제

## 구조

```
lib/
  main.dart                  앱 진입점 + 하단 네비게이션
  models/smoke_log.dart      SmokeLog(1개비), SmokeSession(연속 묶음)
  data/smoke_database.dart   sqflite 저장소
  data/settings_store.dart   shared_preferences 설정
  state/app_state.dart       ChangeNotifier(기록 전체를 메모리에 두고 통계 계산)
  utils/analytics.dart       세션 묶기 · 기간 통계 · 오늘 요약
  utils/time_utils.dart      하루 기준 시각 계산 · 포맷터
  screens/                   home / stats / history / settings
  widgets/                   차트, 경과 링, 통계 타일, 기간 선택
```

## 개발

```bash
flutter pub get
flutter test          # 세션 묶기 · 통계 계산 단위 테스트
flutter analyze
flutter run -d <device>
```

APK 빌드:

```bash
flutter build apk --release --split-per-abi
```

기기 설치 (arm64 기준):

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 라이선스

GNU General Public License v3.0 — 전문은 [LICENSE](LICENSE) 참고.

Copyright (C) 2026 gamja-jw

이 코드를 가져다 수정·배포하려면 파생물도 GPL-3.0으로 소스를 공개해야 한다.
상업적 이용 자체를 막지는 않지만, 닫힌 소스로 만들어 배포하는 것은 허용되지 않는다.
