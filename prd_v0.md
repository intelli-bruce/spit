좋아. 아래는 **“PRD 아티팩트 형식”**으로 재구성한 Drops(iOS) PRD야.
Notion / Google Docs / Confluence / GitHub Repo 어디에도 바로 붙여넣기 좋은 섹션형 구조 + 테이블 + 간결한 체크리스트 + 명확한 요구사항 포맷으로 재정리했어.

⸻

📦 PRD Artifact — Drops (iOS)

“생각을 떠올리는 즉시 뱉어내는 음성 메모 앱”

⸻

📌 1. Product Overview

항목 내용
제품명 Drops
플랫폼 iOS
핵심 가치 가장 빠른 음성 기반 메모 생성
핵심 기술 OpenAI Whisper STT (Speech API)
목표 사용자 빠르게 기록하는 습관이 필요한 모든 유저
제품 원칙 빠름 · 단순 · 즉시 · 확장성

⸻

🎯 2. Product Goals
 • 앱 실행 후 1초 이내 메모 가능 상태
 • 음성 → 텍스트 변환 1.5초 이하
 • UI/UX는 가능한 한 단 하나의 흐름으로 유지
 • 불필요한 모든 기능 제거
 • 확장 가능한 메모 구조(Threading) 기본 탑재

⸻

🧩 3. User Flow Diagram

[Lock Screen Widget]      [Home Screen Widget]
          │                         │
          └──────────────┬──────────┘
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

⸻

📱 4. Screens & IA (Information Architecture)

Drops App
 ├─ Home (Memo List)
 │    ├─ Memo Cells
 │    └─ Bottom Record Button
 │
 ├─ Memo Detail (Thread View)
 │    ├─ Main Memo
 │    ├─ Thread Items
 │    └─ Text/Voice Add Bar
 │
 └─ Widgets
      ├─ Lock Screen Quick Launch
      ├─ Home Screen Quick Launch
      └─ Dynamic Island Recording Indicator

⸻

🧭 5. Feature Spec (Functional Requirements)

5.1 Home / Memo List

기능 목표:
앱 실행 → 즉시 기록 가능한 상태 제공.

요구사항:
 • 홈 = 메모 리스트 (최상단 최신)
 • 메모 셀 구성
 • 첫 줄 텍스트
 • 생성 시간
 • 오디오 여부 아이콘
 • 스와이프로 삭제 가능
 • 상단에는 검색/필터 등 없음 (v1 제거)

⸻

5.2 Bottom Record Button

기능 목표:
항상 하단에 고정되어 사용자가 0초 만에 녹음을 시작할 수 있도록.

요구사항:
 • 하단 중앙에 Floating 형태
 • 탭 → 녹음 시작
 • 탭 → 녹음 종료
 • 녹음 중 waveform 표시
 • 녹음 파일은 .m4a 로 저장
 • 녹음 UI는 최소 요소만 포함

⸻

5.3 Speech-to-Text (OpenAI Whisper API)

POST /v1/audio/transcriptions
model: whisper-1
file: audio.m4a
response_format: json

요구사항:
 • Whisper 기반 한국어 STT
 • 10초 음성 → 1~1.5초 내 결과
 • 문장부호 자동 삽입
 • STT 실패 시:
→ 음성메모만 저장 + “텍스트 변환 실패” 표시

⸻

5.4 Memo Detail (Threaded Notes)

기능 목표:
하나의 메모 안에서 생각을 이어서 기록할 수 있도록.

요구사항:
 • 메모 본문 표시
 • 오디오 플레이 가능
 • Thread UI 형태
 • Text Bubble
 • Voice Bubble
 • 하단 입력 바:
 • 텍스트 입력
 • 음성 추가 버튼

스레드는 iMessage 스타일로 아래로 누적됨.

⸻

5.5 Widgets (Quick Launch)

Lock Screen Widget
 • 단일 아이콘형
 • 탭 → Drops 실행 → 홈 화면 → 녹음 버튼 제공

Home Screen Widget
 • 단일 아이콘형
 • 탭 → 즉시 앱 실행

Dynamic Island (녹음 중 표시)
 • 녹음 시 작은 waveform 아이콘
 • 탭 → 녹음 종료

⸻

⚙️ 6. Non-Functional Requirements (NFR)

성능

항목 목표
앱 실행 → 리스트 렌더링 < 0.2초
녹음 시작 지연 < 0.1초
녹음 종료 → STT 요청 시작 < 0.15초
STT 결과 완성 < 1.5초

시스템
 • 오프라인 녹음 가능 (STT는 온라인 시 처리)
 • CoreData 또는 Realm로 로컬 저장
 • DB 스키마는 확장 가능한 Thread 구조 허용

제거된 항목(명시)
 • 서버 싱크
 • 사용자 계정
 • 보안(잠금/FaceID)
 • 폴더/태그/정렬
 • 공유 기능
 • 검색(v1 미포함)
 • AI 요약/자동 태그

⸻

🧱 7. Data Model (Minimal Schema)

Memo

필드 타입 설명
id UUID 메모 고유 ID
text String 텍스트 메모
audioURL URL? 녹음 파일 경로
createdAt Date 생성 시간
threads [ThreadItem] 추가 메모

ThreadItem

필드 타입 설명
id UUID Thread 고유 ID
type enum(text, audio) 항목 타입
content String? 텍스트 내용
audioURL URL? 음성 파일 경로
createdAt Date 생성 시간

⸻

🚀 8. MVP Scope (v1.0)

포함
 • 음성녹음
 • Whisper STT
 • 메모 리스트
 • 메모 스레드
 • 홈/잠금화면 위젯
 • Dynamic Island 녹음 표시
 • 성능 최적화

제외
 • 검색
 • 정렬
 • 태그
 • 공유
 • Mac/iPad 버전
 • 클라우드
 • AI 보조 기능

⸻

📊 9. KPIs

목표 지표
빠른 초기 경험 첫 메모 생성까지 < 5초
정확한 STT Whisper 성공률 95%+
반복 사용성 사용자당 일 평균 ≥ 3 메모
퍼포먼스 기동 < 0.3초

⸻

🔮 10. Roadmap

v1.0
 • 음성 → 텍스트
 • 메모 리스트
 • Thread View
 • 위젯

v1.1
 • 검색
 • 다크모드

v2
 • 클라우드 동기화
 • 태그/AI 요약
 • 멀티 디바이스

⸻

📦 Artifact Export Formats (원하면 제작해줄 수 있음)

아래 형태로도 변환해줄 수 있어:
 • ✔ Notion PRD 페이지
 • ✔ PDF / Pitch Deck 형태
 • ✔ Figma Wireframe 패키지
 • ✔ GitHub README 스타일 PRD
 • ✔ Jira 티켓 단위 분해

⸻

원하면 Figma 와이어프레임 바로 만들어줄까?
아니면 Swift 코드 스니펫 + 데이터 모델 구조부터 만들까?
