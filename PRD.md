# PRD — Drops Ecosystem

> "생각을 떠올리는 즉시 어디서든 기록하고, 하나의 Journal로 통합"

---

## 1. Product Overview

| 항목 | 내용 |
|------|------|
| 제품명 | Drops Ecosystem |
| 구성요소 | iOS App, Mac App, Supabase Backend |
| 핵심 가치 | 멀티 디바이스 Journal 통합 |
| 목표 사용자 | 빠른 기록 + 통합 관리가 필요한 사용자 |
| 제품 원칙 | 빠름 · 단순 · 실시간 동기화 · 단일 소스 |

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Supabase Cloud                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PostgreSQL Database                                     │   │
│  │  - journal_entries (개별 엔트리)                         │   │
│  │  - journal_metadata (전체 문서 동기화)                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                    Realtime Subscriptions                       │
└────────────────────────────┼────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────────────┐
│  Drops iOS    │   │  JournalMac   │   │  ~/Projects/bruce/    │
│               │   │               │   │  Journal.md           │
│  음성 → 텍스트 │   │  MD 에디터    │   │  (로컬 파일)          │
│  Journal 전송  │   │  실시간 동기화 │   │                       │
└───────────────┘   └───────┬───────┘   └───────────────────────┘
                            │                    ▲
                            │                    │
                            └────── 양방향 동기화 ─┘
```

---

## 3. Tech Stack

### 공통

| 영역 | 기술 |
|------|------|
| Backend | Supabase (PostgreSQL + Realtime) |
| Authentication | Anonymous (v1), Auth (v2) |
| Sync Strategy | Append-only + Timestamp-based |

### iOS App (Drops)

| 영역 | 기술 |
|------|------|
| UI Framework | SwiftUI |
| Architecture | MVVM + Clean Architecture |
| Data Layer | SwiftData |
| Audio | AVFoundation |
| STT | OpenAI Whisper API |
| Network | Supabase Swift SDK |
| Minimum iOS | 17.0+ |

### Mac App (JournalMac)

| 영역 | 기술 |
|------|------|
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Local File | FSEvents (파일 감시) |
| Network | Supabase Swift SDK |
| Minimum macOS | 14.0+ |

---

## 4. Data Model

### Supabase Schema

```sql
-- 개별 Journal 엔트리
CREATE TABLE journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source TEXT NOT NULL CHECK (source IN ('mac', 'ios', 'manual')),
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1
);

-- 전체 문서 메타데이터
CREATE TABLE journal_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_content TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1
);
```

### iOS Data Model (SwiftData)

```swift
@Model
class Memo {
    @Attribute(.unique) var id: UUID
    var text: String
    var audioFileName: String?
    var createdAt: Date
    var updatedAt: Date
    var sttStatus: STTStatus
    @Relationship(deleteRule: .cascade)
    var threads: [ThreadItem]
}

@Model
class ThreadItem {
    @Attribute(.unique) var id: UUID
    var type: ThreadItemType  // .text, .audio
    var content: String?
    var audioFileName: String?
    var createdAt: Date
    var sttStatus: STTStatus
}
```

---

## 5. Feature Spec

### 5.1 Drops iOS

#### 핵심 기능

| 기능 | 설명 |
|------|------|
| 음성 녹음 | 탭 → 녹음 → 탭 → 저장 |
| Whisper STT | 음성 → 텍스트 자동 변환 |
| 메모 스레드 | 하나의 메모에 추가 기록 |
| Journal 전송 | 메모를 Supabase로 전송 (↑ 버튼) |

#### User Flow

```
[Home: 메모 리스트]
        │
        ├─ [녹음 버튼] → 녹음 → Whisper STT → 새 메모 생성
        │
        └─ [메모 탭] → [상세 화면]
                            │
                            ├─ 스레드 추가 (텍스트/음성)
                            │
                            └─ [↑ 버튼] → Journal에 전송
```

#### Journal 전송 포맷

```markdown
메모 본문

- 스레드 1 내용
- 스레드 2 내용
```

---

### 5.2 JournalMac

#### 핵심 기능

| 기능 | 설명 |
|------|------|
| 마크다운 에디터 | Journal.md 편집 |
| 로컬 파일 동기화 | ~/Projects/bruce/Journal.md 양방향 |
| Supabase 동기화 | 실시간 업데이트 |
| 엔트리 목록 | 사이드바에 날짜별 그룹 |

#### User Flow

```
[앱 실행]
    │
    ├─ 로컬 Journal.md 로드
    │
    ├─ Supabase에서 최신 엔트리 fetch
    │
    ├─ 병합 (Append-only)
    │
    └─ Realtime 구독 시작
           │
           ├─ iOS에서 새 엔트리 → 자동 업데이트
           │
           └─ 에디터 수정 → 자동 저장 (debounce 1초)
```

#### Journal.md 포맷

```markdown
# Journal

---

## 2024-12-19 10:30:00

오늘의 첫 번째 기록입니다.

---

## 2024-12-19 09:15:00

어제 회의 내용 정리...
```

---

### 5.3 동기화 전략

#### Append-only 원칙

- 새 엔트리는 항상 추가
- 기존 엔트리 수정 시 타임스탬프 기준 최신 우선
- 충돌 시 양쪽 모두 보존 (conflict marker)

#### Sync Flow

```
iOS (Drops)              Supabase              Mac (JournalMac)
    │                        │                        │
    │── insert entry ───────>│                        │
    │                        │── realtime notify ────>│
    │                        │                        │
    │                        │                        │── write Journal.md
    │                        │                        │
    │                        │<── update metadata ────│
    │                        │                        │
```

---

## 6. MonoRepo 구조

```
~/Projects/drops/                    # Root
├── ios/                             # iOS 앱
│   ├── Drops/
│   │   ├── App/
│   │   │   ├── DropsApp.swift
│   │   │   ├── Config.swift
│   │   │   └── Secrets.swift
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   │   ├── WhisperService.swift
│   │   │   ├── SupabaseService.swift
│   │   │   └── JournalSyncService.swift
│   │   └── Extensions/
│   ├── DropsWidget/
│   ├── Drops.xcodeproj
│   └── project.yml
│
├── mac/                             # Mac 앱
│   ├── JournalMac/
│   │   ├── App/
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   │   ├── SupabaseService.swift
│   │   │   ├── LocalFileService.swift
│   │   │   └── MarkdownParser.swift
│   │   └── Utilities/
│   ├── JournalMac.xcodeproj
│   └── project.yml
│
├── shared/                          # 공유 코드 (향후)
│
├── supabase/                        # DB 설정
│   └── migrations/
│       └── 001_initial_schema.sql
│
├── Makefile                         # 빌드 스크립트
├── PRD.md                           # 이 문서
└── .gitignore
```

---

## 7. Build Commands

```bash
# iOS
make ios-generate    # XcodeGen으로 프로젝트 생성
make ios-build       # 디바이스용 빌드
make ios-simulator   # 시뮬레이터용 빌드
make ios-device      # 빌드 + 설치 + 실행
make ios-open        # Xcode에서 열기

# Mac
make mac-generate    # XcodeGen으로 프로젝트 생성
make mac-build       # 빌드
make mac-run         # 빌드 + 실행
make mac-open        # Xcode에서 열기

# Clean
make clean           # 전체 클린
```

---

## 8. Configuration

### Supabase 설정

1. https://supabase.com 에서 프로젝트 생성
2. SQL Editor에서 `supabase/migrations/001_initial_schema.sql` 실행
3. Project Settings > API에서 URL과 anon key 복사
4. 아래 파일에 입력:
   - `ios/Drops/App/Config.swift`
   - `mac/JournalMac/App/Config.swift`

```swift
// Config.swift
static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
static let supabaseAnonKey = "YOUR_ANON_KEY"
```

### OpenAI API 설정 (iOS)

1. https://platform.openai.com 에서 API 키 생성
2. `ios/Drops/App/Secrets.swift` 생성:

```swift
enum Secrets {
    static let openAIAPIKey = "sk-..."
}
```

---

## 9. MVP Scope (v1.0)

### 포함

- [x] iOS 음성 녹음 + Whisper STT
- [x] iOS 메모 리스트 + 스레드
- [x] iOS → Supabase Journal 전송
- [x] Mac 마크다운 에디터
- [x] Mac ↔ 로컬 파일 동기화
- [x] Mac ↔ Supabase 실시간 동기화
- [x] Supabase 스키마 설계

### 제외 (v2)

- [ ] 사용자 인증
- [ ] 멀티 유저 지원
- [ ] 오프라인 큐 (iOS)
- [ ] Apple Watch 앱
- [ ] iPad 최적화
- [ ] AI 요약/태그

---

## 10. KPIs

| 목표 | 지표 |
|------|------|
| 빠른 기록 | iOS 첫 메모 생성 < 5초 |
| 정확한 STT | Whisper 성공률 95%+ |
| 실시간 동기화 | iOS 전송 → Mac 반영 < 3초 |
| 앱 안정성 | Crash-free rate 99%+ |

---

## 11. Roadmap

### v1.0 (Current)

- iOS 기본 기능 (녹음, STT, 메모)
- iOS → Journal 전송
- Mac 에디터 + 동기화
- Supabase 연동

### v1.1

- 오프라인 지원 (펜딩 큐)
- Mac 에디터 UX 개선
- 위젯 업데이트

### v2.0

- 사용자 인증 (Supabase Auth)
- 멀티 디바이스 동기화
- AI 기능 (요약, 태그)
- iPad/Apple Watch

---

## 12. Open Questions

1. **Conflict Resolution**: 동시 편집 시 어떻게 처리?
   - 현재: Append-only + Last-write-wins
   - 향후: OT/CRDT 검토

2. **오프라인 지원**: iOS에서 오프라인 시 전송 큐?
   - v1: 온라인 필수
   - v2: UserDefaults 기반 큐

3. **인증**: Anonymous → Auth 전환 시점?
   - v2에서 Supabase Auth 도입

---

*Last Updated: 2024-12-19*
