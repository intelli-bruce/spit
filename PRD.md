# PRD — Throw

> "생각을 떠올리는 즉시 어디서든 기록하고, 하나의 공간에서 관리"

---

## 1. Product Overview

| 항목 | 내용 |
|------|------|
| 제품명 | Throw |
| 구성요소 | iOS App, Mac App, Supabase Backend |
| 핵심 가치 | 블록 기반 노트 + 실시간 동기화 |
| 목표 사용자 | 빠른 기록 + 멀티 디바이스 사용자 |
| 제품 원칙 | 빠름 · 단순 · 오프라인 우선 · 단일 소스 |

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Supabase Cloud                               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  PostgreSQL                                              │    │
│  │  - notes (노트 메타데이터)                                │    │
│  │  - note_blocks (블록 컨텐츠)                             │    │
│  │  - note_block_history (변경 이력)                        │    │
│  │  - tags, note_tags (태그)                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Storage                                                 │    │
│  │  - 이미지, 오디오, 비디오 파일                            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                    Realtime Subscriptions                        │
└────────────────────────────┼─────────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
        ▼                                         ▼
┌───────────────────┐                   ┌───────────────────┐
│    Throw iOS      │                   │    Throw Mac      │
│                   │                   │                   │
│  SwiftData        │                   │  SwiftData        │
│  (로컬 캐시)       │◄─────────────────►│  (로컬 캐시)       │
│                   │    실시간 동기화    │                   │
│  음성/텍스트 입력  │                   │  텍스트 편집       │
│  미디어 첨부       │                   │  히스토리 조회     │
└───────────────────┘                   └───────────────────┘
```

---

## 3. Tech Stack

### 공통

| 영역 | 기술 |
|------|------|
| Backend | Supabase (PostgreSQL + Realtime + Storage) |
| Authentication | Anonymous (v1), Supabase Auth (v2) |
| Sync Strategy | Offline-first + Last-write-wins |

### iOS App

| 영역 | 기술 |
|------|------|
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Local Storage | SwiftData |
| Audio | AVFoundation |
| STT | OpenAI Whisper API |
| Network | Supabase Swift SDK |
| Minimum iOS | 17.0+ |

### Mac App

| 영역 | 기술 |
|------|------|
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Local Storage | SwiftData |
| Network | Supabase Swift SDK |
| Minimum macOS | 14.0+ |

---

## 4. Data Model

### 4.1 Supabase Schema

```sql
-- 노트 메타데이터
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source TEXT NOT NULL CHECK (source IN ('ios', 'mac')),
    device_id TEXT,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- 블록 기반 컨텐츠
CREATE TABLE note_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES note_blocks(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('text', 'image', 'audio', 'video')),
    content TEXT,
    storage_path TEXT,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

-- 블록 변경 이력 (무제한 보존)
CREATE TABLE note_block_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    block_id UUID NOT NULL REFERENCES note_blocks(id) ON DELETE CASCADE,
    content TEXT,
    storage_path TEXT,
    version INTEGER NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_type TEXT NOT NULL CHECK (change_type IN ('create', 'update', 'delete'))
);

-- 태그
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 노트-태그 연결
CREATE TABLE note_tags (
    note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, tag_id)
);

-- 인덱스
CREATE INDEX idx_notes_created_at ON notes(created_at DESC);
CREATE INDEX idx_notes_is_deleted ON notes(is_deleted);
CREATE INDEX idx_note_blocks_note_id ON note_blocks(note_id);
CREATE INDEX idx_note_blocks_parent_id ON note_blocks(parent_id);
CREATE INDEX idx_note_block_history_block_id ON note_block_history(block_id);
CREATE INDEX idx_note_tags_note_id ON note_tags(note_id);
CREATE INDEX idx_note_tags_tag_id ON note_tags(tag_id);
```

### 4.2 블록 구조 예시

```
Note (id: abc-123, created_at: 2024-12-20 10:30)
│
├── Block (type: text, position: 0, parent_id: NULL)
│   └── content: "오늘 회의 내용 정리"
│
├── Block (type: image, position: 1, parent_id: NULL)
│   └── storage_path: "notes/abc-123/screenshot.png"
│
├── Block (type: audio, position: 2, parent_id: NULL)
│   └── storage_path: "notes/abc-123/recording.m4a"
│
└── Thread (parent_id로 연결)
    │
    ├── Block (type: text, position: 0, parent_id: block-xyz)
    │   └── content: "추가 메모: 다음 주 팔로업 필요"
    │
    └── Block (type: image, position: 1, parent_id: block-xyz)
        └── storage_path: "notes/abc-123/photo.jpg"
```

### 4.3 SwiftData Model (iOS/Mac 공통)

```swift
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var source: String  // "ios" | "mac"
    var deviceId: String?
    var isDeleted: Bool
    var syncStatus: SyncStatus  // .pending | .synced | .conflict

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.note)
    var blocks: [NoteBlock]

    @Relationship(inverse: \Tag.notes)
    var tags: [Tag]
}

@Model
final class NoteBlock {
    @Attribute(.unique) var id: UUID
    var note: Note?
    var parentBlock: NoteBlock?  // nil = 본문, 있음 = thread
    var type: BlockType  // .text | .image | .audio | .video
    var content: String?
    var storagePath: String?
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var syncStatus: SyncStatus

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.parentBlock)
    var childBlocks: [NoteBlock]
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var notes: [Note]
}

enum BlockType: String, Codable {
    case text, image, audio, video
}

enum SyncStatus: String, Codable {
    case pending, synced, conflict
}
```

---

## 5. Feature Spec

### 5.1 Throw iOS

#### 핵심 기능

| 기능 | 설명 |
|------|------|
| 텍스트 노트 | 텍스트 입력으로 노트 생성 |
| 음성 노트 | 녹음 → Whisper STT → 텍스트 변환 |
| 미디어 첨부 | 이미지, 비디오 첨부 |
| Thread | 노트에 추가 블록 연결 |
| 태그 | 노트에 태그 추가/관리 |
| 오프라인 | 오프라인에서 작성 → 온라인 시 동기화 |

#### User Flow

```
[Home: 노트 리스트]
        │
        ├─ [+ 버튼] → 새 노트 생성
        │       │
        │       ├─ 텍스트 입력
        │       ├─ 음성 녹음 → STT
        │       └─ 미디어 첨부
        │
        └─ [노트 탭] → [상세 화면]
                            │
                            ├─ 블록 편집/삭제
                            ├─ Thread 추가
                            ├─ 태그 관리
                            └─ 히스토리 조회
```

### 5.2 Throw Mac

#### 핵심 기능

| 기능 | 설명 |
|------|------|
| 노트 목록 | 날짜별/태그별 그룹핑 |
| 노트 편집 | 텍스트 블록 편집, 미디어 첨부 |
| 태그 필터 | 태그로 노트 필터링 |
| 히스토리 | 블록 변경 이력 조회/복원 |
| 검색 | 전체 노트 검색 |

#### User Flow

```
[앱 실행]
    │
    ├─ 로컬 SwiftData 로드
    │
    ├─ Supabase 동기화 (pending 항목 push)
    │
    └─ Realtime 구독 시작
           │
           └─ 변경 감지 → 자동 업데이트
```

---

## 6. Sync Strategy

### 6.1 Offline-First 원칙

```
[사용자 액션]
      │
      ▼
[SwiftData 저장]
      │
      ├─ syncStatus = .pending
      │
      ▼
[온라인 확인]
      │
      ├─ YES → Supabase Push → syncStatus = .synced
      │
      └─ NO → 대기 (앱 재시작/네트워크 복구 시 재시도)
```

### 6.2 충돌 해결: Last-Write-Wins

```
[로컬]                    [서버]
updated_at: 10:30        updated_at: 10:35
      │                        │
      └───── 충돌 감지 ────────┘
                  │
                  ▼
         서버 버전 채택 (10:35 > 10:30)
         로컬 버전 → history 저장
```

### 6.3 Realtime Subscription

```swift
// 구독 대상 테이블
supabase.channel("notes")
    .on("INSERT", table: "notes") { ... }
    .on("UPDATE", table: "notes") { ... }
    .on("DELETE", table: "notes") { ... }

supabase.channel("note_blocks")
    .on("INSERT", table: "note_blocks") { ... }
    .on("UPDATE", table: "note_blocks") { ... }
    .on("DELETE", table: "note_blocks") { ... }
```

---

## 7. Storage

### 7.1 Supabase Storage 구조

```
throw-media/
├── notes/
│   ├── {note_id}/
│   │   ├── {block_id}_image.jpg
│   │   ├── {block_id}_audio.m4a
│   │   └── {block_id}_video.mp4
```

### 7.2 업로드 Flow

```
[미디어 선택]
      │
      ▼
[로컬 임시 저장]
      │
      ▼
[SwiftData 저장] (storagePath = local://temp/{uuid})
      │
      ▼
[백그라운드 업로드] → Supabase Storage
      │
      ▼
[storagePath 업데이트] (notes/{note_id}/{block_id}_xxx)
```

---

## 8. History Management

### 8.1 변경 이력 저장

| 시점 | 액션 |
|------|------|
| 블록 생성 | history에 `change_type: create` 기록 |
| 블록 수정 | 수정 전 상태를 history에 저장, version++ |
| 블록 삭제 | history에 `change_type: delete` 기록 |

### 8.2 복원 기능

```
[히스토리 조회] → 특정 버전 선택 → [복원]
                                      │
                                      ▼
                            현재 상태 → history 저장
                            선택 버전 → 현재 상태로 복원
                            version++
```

---

## 9. MonoRepo Structure

```
throw/
├── ios/                          # iOS 앱
│   ├── Throw/
│   │   ├── App/
│   │   │   ├── ThrowApp.swift
│   │   │   └── Config.swift
│   │   ├── Models/
│   │   │   ├── Note.swift
│   │   │   ├── NoteBlock.swift
│   │   │   └── Tag.swift
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   └── Services/
│   │       ├── SupabaseService.swift
│   │       ├── SyncService.swift
│   │       ├── StorageService.swift
│   │       └── WhisperService.swift
│   └── project.yml
│
├── mac/                          # Mac 앱
│   ├── ThrowMac/
│   │   ├── App/
│   │   ├── Models/               # iOS와 동일 구조
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   └── Services/
│   └── project.yml
│
├── shared/                       # 공유 코드 (향후)
│   ├── Models/
│   └── DTOs/
│
├── supabase/
│   └── migrations/
│       ├── 001_initial_schema.sql
│       └── 002_block_based_schema.sql
│
├── Makefile
└── PRD.md
```

---

## 10. Build Commands

```bash
# iOS
make ios-generate    # XcodeGen으로 프로젝트 생성
make ios-build       # 빌드
make ios-run         # 시뮬레이터 실행

# Mac
make mac-generate    # XcodeGen으로 프로젝트 생성
make mac-build       # 빌드
make mac-run         # 실행

# Supabase
make supabase-migrate  # 마이그레이션 실행
```

---

## 11. MVP Scope (v1.0)

### 포함

- [ ] 새 스키마 마이그레이션
- [ ] iOS 블록 기반 노트 생성/편집
- [ ] iOS 음성 녹음 + STT
- [ ] iOS 이미지 첨부
- [ ] iOS ↔ Supabase 동기화
- [ ] Mac 노트 목록/편집
- [ ] Mac ↔ Supabase 동기화
- [ ] 태그 시스템

### 제외 (v2)

- [ ] 사용자 인증
- [ ] 비디오 첨부
- [ ] 히스토리 복원 UI
- [ ] Apple Watch
- [ ] AI 요약/태그 자동 추출

---

## 12. KPIs

| 목표 | 지표 |
|------|------|
| 빠른 기록 | 노트 생성 < 3초 |
| 정확한 STT | Whisper 성공률 95%+ |
| 실시간 동기화 | 변경 → 다른 디바이스 반영 < 3초 |
| 오프라인 | 오프라인 작업 → 온라인 복구 시 100% 동기화 |
| 앱 안정성 | Crash-free rate 99%+ |

---

*Last Updated: 2024-12-20*
