# PRD Artifact — Spit (iOS)

> "생각을 떠올리는 즉시 뱉어내는 음성 메모 앱"

---

## 1. Product Overview

| 항목 | 내용 |
|------|------|
| 제품명 | Spit |
| 플랫폼 | iOS 17.0+ |
| 핵심 가치 | 가장 빠른 음성 기반 메모 생성 |
| 핵심 기술 | OpenAI Whisper STT (Speech API) |
| 목표 사용자 | 빠르게 기록하는 습관이 필요한 모든 유저 |
| 제품 원칙 | 빠름 · 단순 · 즉시 · 확장성 |

---

## 2. Tech Stack

| 영역 | 기술 |
|------|------|
| UI Framework | SwiftUI |
| Architecture | MVVM + Clean Architecture |
| Data Layer | SwiftData (iOS 17+) |
| Audio | AVFoundation |
| Network | URLSession + async/await |
| Widgets | WidgetKit + App Intents |
| Live Activity | ActivityKit |
| Dependency Injection | Swift Package (자체 구현 또는 경량 DI) |
| Minimum iOS | 17.0 |

---

## 3. Product Goals

- 앱 실행 후 1초 이내 메모 가능 상태
- 음성 → 텍스트 변환 1.5초 이하
- UI/UX는 가능한 한 단 하나의 흐름으로 유지
- 불필요한 모든 기능 제거
- 확장 가능한 메모 구조(Threading) 기본 탑재

---

## 4. User Flow Diagram

```
[Lock Screen Widget]      [Home Screen Widget]     [Action Button]     [Control Center]
          │                         │                     │                   │
          └─────────────────────────┴─────────────────────┴───────────────────┘
                                          │
                                          ▼
                                     [App Launch]
                                          │
                                          ▼
                                 [Home: Memo List]
                                          │
                          ┌───────────────┴────────────────┐
                          ▼                                 ▼
                  [Bottom Record Button]             [Tap Memo Cell]
                          │                                 │
                          ▼                                 ▼
                  [Recording → Stop]                 [Memo Detail(Thread)]
                          │                                 │
                          ▼                                 ▼
                  [OpenAI Whisper STT]          [Add Text / Add Voice]
                          │                                 │
                          ▼                                 ▼
                  [New Memo Cell Created]      [Thread Item Added]
```

---

## 5. Screens & IA (Information Architecture)

```
Spit App
 ├─ Home (Memo List)
 │    ├─ Memo Cells
 │    └─ Bottom Record Button
 │
 ├─ Memo Detail (Thread View)
 │    ├─ Main Memo
 │    ├─ Thread Items
 │    └─ Text/Voice Add Bar
 │
 ├─ Onboarding (First Launch Only)
 │    ├─ Welcome Screen
 │    ├─ Microphone Permission Request
 │    └─ Quick Tutorial (Optional Skip)
 │
 └─ Widgets & Extensions
      ├─ Lock Screen Quick Launch
      ├─ Home Screen Quick Launch
      ├─ Control Center Widget (iOS 18+)
      ├─ StandBy Mode Widget
      └─ Dynamic Island / Live Activity
```

---

## 6. Feature Spec (Functional Requirements)

### 6.1 Home / Memo List

**기능 목표:**
앱 실행 → 즉시 기록 가능한 상태 제공.

**요구사항:**

- 홈 = 메모 리스트 (최상단 최신)
- 메모 셀 구성:
  - 첫 줄 텍스트 (최대 2줄)
  - 생성 시간 (상대 시간: "방금 전", "5분 전", "어제")
  - 오디오 여부 아이콘
  - 스레드 개수 표시 (있을 경우)
- 스와이프로 삭제 가능 (확인 없이 즉시 삭제 + Undo 토스트)
- 상단에는 검색/필터 등 없음 (v1 제거)
- Empty State: 첫 메모 유도 메시지

---

### 6.2 Bottom Record Button

**기능 목표:**
항상 하단에 고정되어 사용자가 0초 만에 녹음을 시작할 수 있도록.

**요구사항:**

- 하단 중앙에 Floating 형태 (Safe Area 고려)
- 탭 → 녹음 시작
- 탭 → 녹음 종료
- 녹음 중 waveform 표시 + 경과 시간
- 녹음 파일은 .m4a (AAC) 로 저장
- 녹음 UI는 최소 요소만 포함
- Haptic Feedback: 녹음 시작/종료 시 진동

---

### 6.3 Speech-to-Text (OpenAI Whisper API)

```
POST /v1/audio/transcriptions
model: whisper-1
file: audio.m4a
response_format: json
language: ko (optional, auto-detect 가능)
```

**요구사항:**

- Whisper 기반 다국어 STT (한국어 우선)
- 10초 음성 → 1~1.5초 내 결과
- 문장부호 자동 삽입
- STT 실패 시:
  - 음성메모만 저장 + "텍스트 변환 실패" 표시
  - "다시 시도" 버튼 제공
- 오프라인 시 큐에 저장 → 온라인 복귀 시 자동 처리

---

### 6.4 Memo Detail (Threaded Notes)

**기능 목표:**
하나의 메모 안에서 생각을 이어서 기록할 수 있도록.

**요구사항:**

- 메모 본문 표시 (편집 가능)
- 오디오 플레이 가능 (재생 속도 조절: 1x, 1.5x, 2x)
- Thread UI 형태:
  - Text Bubble
  - Voice Bubble (파형 + 재생 버튼)
- 하단 입력 바:
  - 텍스트 입력
  - 음성 추가 버튼
- Long Press → 개별 스레드 삭제
- 스레드는 iMessage 스타일로 아래로 누적됨

---

### 6.5 Widgets & Quick Access

**Lock Screen Widget**

- 단일 아이콘형 (accessoryCircular)
- 탭 → Spit 실행 → 홈 화면

**Home Screen Widget**

- Small (2x2): 즉시 녹음 시작 버튼
- 탭 → 앱 실행 + 자동 녹음 시작 (App Intent)

**Control Center Widget (iOS 18+)**

- 단일 버튼형
- 탭 → 앱 실행 또는 즉시 녹음

**StandBy Mode (iOS 17+)**

- 시계 옆 위젯 슬롯 지원
- 최근 메모 미리보기 또는 녹음 버튼

**Dynamic Island / Live Activity**

- 녹음 시 Compact/Minimal 형태 표시
- 경과 시간 + waveform 아이콘
- 탭 → 녹음 종료

**Action Button (iPhone 15 Pro+)**

- Shortcuts 연동을 통한 즉시 녹음 시작 지원

---

### 6.6 App Intents & Siri Shortcuts

**제공 Intent:**

- `StartRecordingIntent`: 녹음 시작
- `CreateMemoIntent`: 텍스트 메모 생성

**Siri 지원 문구 (예시):**

- "Spit으로 메모해"
- "Spit 녹음 시작"

---

## 7. Onboarding & First Launch

**목표:** 첫 실행 시 마이크 권한 확보 + 핵심 가치 전달

**플로우:**

1. Welcome Screen: "생각을 뱉어내세요" + 앱 소개 (1문장)
2. Microphone Permission: 권한 요청 + 왜 필요한지 설명
3. Quick Demo (Optional): 3초 녹음 테스트
4. 완료 → 홈 화면 진입

**권한 거부 시:**

- 홈 화면에 배너 표시: "마이크 권한이 필요합니다"
- 설정 앱으로 이동 버튼 제공

---

## 8. Non-Functional Requirements (NFR)

### 8.1 성능

| 항목 | 목표 |
|------|------|
| 앱 실행 → 리스트 렌더링 | < 0.2초 |
| 녹음 시작 지연 | < 0.1초 |
| 녹음 종료 → STT 요청 시작 | < 0.15초 |
| STT 결과 완성 | < 1.5초 (10초 음성 기준) |
| 앱 메모리 사용량 | < 50MB (Idle) |

### 8.2 시스템

- 오프라인 녹음 가능 (STT는 온라인 시 처리)
- SwiftData로 로컬 저장
- 음성 파일은 App Documents 디렉토리 저장
- DB 스키마는 확장 가능한 Thread 구조 허용

### 8.3 제거된 항목 (v1 명시적 제외)

- 서버 싱크
- 사용자 계정
- 보안(잠금/FaceID)
- 폴더/태그/정렬
- 공유 기능
- 검색 (v1.1 예정)
- AI 요약/자동 태그

---

## 9. Error Handling & Edge Cases

| 상황 | 처리 방법 |
|------|-----------|
| 네트워크 없음 (녹음 시) | 녹음 저장 → "오프라인 - 나중에 변환" 표시 |
| 네트워크 복구 시 | 백그라운드에서 자동 STT 처리 |
| OpenAI API 오류 (5xx) | 자동 재시도 (최대 3회, exponential backoff) |
| API Rate Limit | 큐에 저장, 1분 후 재시도 |
| 저장 공간 부족 | 녹음 전 체크 → 경고 표시 |
| STT 빈 결과 | "내용 없음" 텍스트로 저장 |
| 마이크 권한 없음 | 녹음 버튼 탭 시 설정 안내 |
| 앱 강제 종료 (녹음 중) | 녹음 파일은 저장, 앱 재실행 시 복구 처리 |

---

## 10. Accessibility (접근성)

- VoiceOver 완전 지원
  - 모든 버튼/셀에 적절한 label 제공
  - 녹음 상태 음성 안내
- Dynamic Type 지원 (텍스트 크기 조절)
- 고대비 모드 대응
- Reduce Motion 설정 존중
- 최소 탭 영역 44x44pt 준수

---

## 11. Privacy & Permissions

### 11.1 필요 권한

| 권한 | 용도 | 요청 시점 |
|------|------|-----------|
| Microphone | 음성 녹음 | 첫 실행 또는 첫 녹음 시도 시 |

### 11.2 데이터 처리

- 음성 데이터는 OpenAI API로만 전송 (STT 목적)
- 로컬 저장 데이터는 기기 외부로 전송되지 않음
- API 키는 앱 내 하드코딩 금지 → 환경변수 또는 서버 프록시 고려

### 11.3 App Privacy Manifest (iOS 17+)

```
Privacy Nutrition Labels:
- Data Not Collected (v1 기준)
- Audio data sent to third party for STT only
```

---

## 12. Data Model (SwiftData Schema)

```swift
@Model
class Memo {
    @Attribute(.unique) var id: UUID
    var text: String
    var audioFileName: String?  // Documents 디렉토리 내 파일명
    var createdAt: Date
    var updatedAt: Date
    var sttStatus: STTStatus    // .pending, .completed, .failed

    @Relationship(deleteRule: .cascade)
    var threads: [ThreadItem]
}

@Model
class ThreadItem {
    @Attribute(.unique) var id: UUID
    var type: ThreadItemType    // .text, .audio
    var content: String?
    var audioFileName: String?
    var createdAt: Date
    var sttStatus: STTStatus
}

enum STTStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

enum ThreadItemType: String, Codable {
    case text
    case audio
}
```

---

## 13. Analytics & Monitoring

### 13.1 Crash Reporting

- Firebase Crashlytics 또는 Sentry

### 13.2 핵심 이벤트 (v1)

| 이벤트 | 설명 |
|--------|------|
| `app_launched` | 앱 실행 |
| `recording_started` | 녹음 시작 |
| `recording_completed` | 녹음 완료 (duration 포함) |
| `stt_requested` | STT API 호출 |
| `stt_completed` | STT 성공 (latency 포함) |
| `stt_failed` | STT 실패 (error type 포함) |
| `memo_created` | 메모 생성 |
| `memo_deleted` | 메모 삭제 |
| `thread_added` | 스레드 추가 |
| `widget_tapped` | 위젯에서 앱 실행 |

### 13.3 성능 모니터링

- 앱 실행 시간
- STT 응답 시간
- 메모리 사용량

---

## 14. Testing Strategy

### 14.1 Unit Tests

- ViewModel 비즈니스 로직
- Data Model 변환/저장
- Audio 파일 관리 로직

### 14.2 Integration Tests

- SwiftData 저장/조회
- OpenAI API 통신 (Mock 사용)

### 14.3 UI Tests

- 메모 생성 플로우
- 스레드 추가 플로우
- 삭제 플로우

### 14.4 Manual Test Checklist

- [ ] 오프라인 상태에서 녹음 → 온라인 복귀 시 STT 처리
- [ ] 녹음 중 앱 백그라운드 → 포그라운드 복귀
- [ ] 녹음 중 전화 수신
- [ ] 긴 녹음 (5분+) 처리
- [ ] 빠른 연속 녹음 (spam tap)
- [ ] 저장 공간 부족 상태
- [ ] VoiceOver로 전체 플로우 수행

---

## 15. Internationalization (i18n)

### v1.0

- 한국어 (ko) - 기본
- 영어 (en) - 기본

**Whisper API:**

- `language` 파라미터 생략 시 자동 감지
- 사용자가 언어 선택 가능하게 할지는 v1.1에서 결정

---

## 16. Risk & Mitigation

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| OpenAI API 비용 증가 | 수익성 | 녹음 시간 제한 (v1: 3분), 추후 구독 모델 |
| API 장애 | 핵심 기능 불가 | 오프라인 큐 + 로컬 STT 대안 검토 (v2) |
| App Store 리젝 | 출시 지연 | 가이드라인 사전 검토, 권한 설명 명확히 |
| 배터리 소모 | 사용자 이탈 | 녹음 시만 고성능 모드, 효율적 오디오 인코딩 |

---

## 17. MVP Scope (v1.0)

### 포함

- 음성녹음 (AVFoundation)
- Whisper STT
- 메모 리스트
- 메모 스레드
- 홈/잠금화면 위젯
- Dynamic Island / Live Activity
- 온보딩 플로우
- 오프라인 녹음 지원
- 기본 에러 핸들링
- 접근성 기본 지원
- 한/영 지원

### 제외

- 검색 (v1.1)
- 정렬/필터
- 태그
- 공유
- Mac/iPad 버전
- 클라우드 동기화
- AI 보조 기능
- Control Center Widget (iOS 18, v1.1)
- Action Button 지원 (v1.1)

---

## 18. KPIs

| 목표 | 지표 |
|------|------|
| 빠른 초기 경험 | 첫 메모 생성까지 < 5초 |
| 정확한 STT | Whisper 성공률 95%+ |
| 반복 사용성 | 사용자당 일 평균 ≥ 3 메모 |
| 퍼포먼스 | Cold Start < 0.5초 |
| 리텐션 | D1 40%+, D7 20%+ |
| 크래시 | Crash-free rate 99.5%+ |

---

## 19. Roadmap

### v1.0 (MVP)

- 음성 → 텍스트
- 메모 리스트
- Thread View
- 위젯 (Lock Screen, Home Screen)
- Dynamic Island
- 온보딩
- 한/영 지원

### v1.1

- 검색
- Control Center Widget (iOS 18)
- Action Button 지원
- 재생 속도 조절
- 메모 편집 기능 강화

### v1.2

- 다크모드 커스터마이징
- 추가 언어 지원
- Apple Watch 앱 (기본)

### v2.0

- 클라우드 동기화 (iCloud)
- 태그/폴더
- AI 요약
- Mac/iPad 버전

---

## 20. Open Questions

1. **API Key 관리**: 앱 내 직접 포함 vs 서버 프록시?
   - 서버 프록시 권장 (보안, 비용 관리)

2. **녹음 시간 제한**: v1에서 제한 둘 것인가?
   - 권장: 3분 (API 비용 + UX)

3. **무료/유료 모델**: v1은 무료?
   - 권장: v1 무료, 사용량 제한 후 v2에서 구독 도입

4. **로컬 STT 대안**: Apple Speech Framework 사용?
   - v1에서는 Whisper만, v2에서 오프라인 대안 검토

---

## Appendix: API Cost Estimation

| 항목 | 값 |
|------|-----|
| Whisper API 가격 | $0.006 / minute |
| 평균 녹음 시간 (예상) | 15초 |
| 일 평균 메모 수 (예상) | 5개 |
| 사용자당 일 비용 | ~$0.0075 |
| 1,000 DAU 월 비용 | ~$225 |

---

*Last Updated: 2025-12-07*
