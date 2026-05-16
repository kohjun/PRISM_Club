# Architecture and Data Design

## 1. 설계 원칙

1. 주제 정보 허브를 1급 도메인으로 둔다: Category는 단순 게시판명이 아니라 Topic Hub를 가진다.
2. 주제 구조를 1급 도메인으로 둔다: Space, Category, TopicHub, Room, Post, Reply가 Club의 핵심이다.
3. 유저 생성 방을 기본 모델로 둔다: 운영자 기본 방과 사용자 생성 방은 같은 Room 모델을 쓰되 `origin`과 권한으로 구분한다.
4. 참가자/기획자 커뮤니티를 권한으로 분리한다: 기획자 전용 카테고리와 방은 서버 권한 검사로 보호한다.
5. 이벤트 연동은 카드화한다: Events/Contenido의 이벤트 원본은 Events가 소유하고, Club은 참조 카드와 토론 맥락을 가진다.
6. 레퍼런스는 별도 자산으로 관리한다: 외부 링크, 예능 프로그램, 영상, 룰 문서, 아이디어를 검색 가능한 Reference로 저장한다.
7. 방은 대표 자료를 가질 수 있다: 방 소유자는 대표 이벤트 카드와 대표 레퍼런스를 고정해 대화 맥락을 만든다.
8. 지식과 대화를 분리하되 연결한다: KnowledgeBlock은 정리된 정보, Post/Reply는 대화 원장이다.
9. 타임라인은 원장과 집계를 분리한다: 게시글/댓글 원장은 PostgreSQL, 인기순/홈피드는 Redis 캐시나 materialized view로 최적화한다.
10. 커뮤니티 안전을 기본 기능으로 둔다: 신고, 숨김, 차단, 금칙어, 운영자 감사 로그를 MVP부터 포함한다.
11. 향후 기록/배지/랭킹은 보조 모듈로 붙인다: Club의 중심은 지식 허브와 대화다.

## 2. 시스템 컨텍스트

```mermaid
flowchart LR
  Member["Member\n커뮤니티 사용자"]
  Participant["Verified Participant\n이벤트 참가 인증 사용자"]
  Host["Event Host\n기획자"]
  Planner["Verified Planner\n인증 기획자"]
  Moderator["Moderator\n커뮤니티 운영자"]

  Mobile["PRISM Mobile App\nClub"]
  AdminWeb["PRISM Admin Web"]
  Api["PRISM Backend API"]
  Events["PRISM Events / Contenido"]
  DB[("PostgreSQL\ncommunity data")]
  Redis[("Redis\nfeed cache / counters")]
  Storage[("Object Storage\nimages / media")]
  Search["Search Index\nPostgres FTS first"]
  Push["FCM / APNs"]

  Member --> Mobile
  Participant --> Mobile
  Host --> Mobile
  Planner --> Mobile
  Moderator --> AdminWeb
  Mobile --> Api
  AdminWeb --> Api
  Api --> Events
  Api --> DB
  Api --> Redis
  Api --> Storage
  Api --> Search
  Api --> Push
```

## 3. 컨테이너 구조

```mermaid
flowchart TB
  subgraph Client
    Flutter["Flutter App\nClub community screens"]
    NextAdmin["Next.js Admin\nrooms / moderation / reports"]
  end

  subgraph Backend["NestJS Modular Monolith"]
    Account["Account Module"]
    Profile["Profile Module"]
    Community["Community Module"]
    Access["Access Control Module"]
    Knowledge["Knowledge Module"]
    Feed["Feed Module"]
    EventLink["Event Link Module"]
    Reference["Reference Module"]
    Search["Search Module"]
    Moderation["Moderation Module"]
    Notification["Notification Module"]
    EventBus["Domain Event Bus"]
  end

  Flutter --> Account
  Flutter --> Profile
  Flutter --> Community
  Flutter --> Access
  Flutter --> Knowledge
  Flutter --> Feed
  Flutter --> Search
  NextAdmin --> Community
  NextAdmin --> Access
  NextAdmin --> Knowledge
  NextAdmin --> Moderation
  Community --> EventBus
  EventLink --> EventBus
  Reference --> EventBus
  Moderation --> EventBus
  EventBus --> Notification
```

## 4. Community 내부 컴포넌트

```mermaid
flowchart LR
  Controller["Community API Controllers"]
  SpaceSvc["SpaceService"]
  KnowledgeSvc["KnowledgeService"]
  CategorySvc["CategoryService"]
  RoomSvc["RoomService"]
  PostSvc["PostService"]
  ReplySvc["ReplyService"]
  ReactionSvc["ReactionService"]
  EventCardSvc["EventCardService"]
  ReferenceSvc["ReferenceService"]
  FeedSvc["FeedService"]
  SearchSvc["SearchService"]
  ModerationSvc["ModerationService"]
  Repo["Repositories"]
  Events["Domain Events"]

  Controller --> CategorySvc
  Controller --> SpaceSvc
  Controller --> KnowledgeSvc
  Controller --> RoomSvc
  Controller --> PostSvc
  Controller --> ReplySvc
  Controller --> FeedSvc
  Controller --> SearchSvc
  PostSvc --> EventCardSvc
  PostSvc --> ReferenceSvc
  PostSvc --> ModerationSvc
  ReplySvc --> ModerationSvc
  PostSvc --> ReactionSvc
  ReplySvc --> ReactionSvc
  PostSvc --> Events
  ReplySvc --> Events
  ReactionSvc --> Events
  SpaceSvc --> Repo
  KnowledgeSvc --> Repo
  CategorySvc --> Repo
  RoomSvc --> Repo
  PostSvc --> Repo
  ReplySvc --> Repo
  EventCardSvc --> Repo
  ReferenceSvc --> Repo
```

## 5. 데이터 모델 초안

```mermaid
erDiagram
  USERS ||--|| PROFILES : has
  USERS ||--o{ USER_ROLES : has
  USERS ||--o{ POSTS : writes
  USERS ||--o{ REPLIES : writes
  USERS ||--o{ REACTIONS : makes
  USERS ||--o{ BOOKMARKS : saves
  USERS ||--o{ REPORTS : reports
  USERS ||--o{ USER_BLOCKS : blocks

  SPACES ||--o{ CATEGORIES : contains
  CATEGORIES ||--|| TOPIC_HUBS : has
  TOPIC_HUBS ||--o{ KNOWLEDGE_BLOCKS : contains
  TOPIC_HUBS ||--o{ TOPIC_SIGNALS : summarizes
  TOPIC_HUBS ||--o{ KNOWLEDGE_CONTRIBUTIONS : receives
  CATEGORIES ||--o{ ROOMS : contains
  USERS ||--o{ ROOMS : owns
  ROOMS ||--o{ POSTS : contains
  ROOMS ||--o{ ROOM_PINS : pins
  POSTS ||--o{ REPLIES : has
  REPLIES ||--o{ REPLIES : has_children

  POSTS ||--o{ POST_ATTACHMENTS : includes
  POST_ATTACHMENTS }o--|| EVENT_CARDS : may_reference
  POST_ATTACHMENTS }o--|| REFERENCES : may_reference
  KNOWLEDGE_BLOCKS }o--o{ REFERENCES : cites
  KNOWLEDGE_BLOCKS }o--o{ EVENT_CARDS : cites
  KNOWLEDGE_BLOCKS }o--o{ POSTS : cites
  ROOM_PINS }o--|| EVENT_CARDS : may_pin
  ROOM_PINS }o--|| REFERENCES : may_pin
  POSTS ||--o{ MEDIA_ASSETS : attaches
  REPLIES ||--o{ MEDIA_ASSETS : attaches

  EVENTS ||--o{ EVENT_CARDS : mirrored_as
  USERS ||--o{ EVENT_PARTICIPATIONS : participates
  EVENTS ||--o{ EVENT_PARTICIPATIONS : has

  POSTS ||--o{ REPORTS : reported
  REPLIES ||--o{ REPORTS : reported
  ROOMS ||--o{ REPORTS : reported
  REPORTS ||--o{ MODERATION_ACTIONS : resolved_by

  EVENTS {
    uuid id PK
    string title
    string status
    datetime starts_at
  }

  EVENT_PARTICIPATIONS {
    uuid id PK
    uuid event_id FK
    uuid user_id FK
    string status
    datetime checked_in_at
  }

  USERS {
    uuid id PK
    string status
    datetime created_at
  }

  PROFILES {
    uuid user_id PK
    string nickname
    string avatar_url
    string region
    json interests
    datetime created_at
  }

  USER_ROLES {
    uuid id PK
    uuid user_id FK
    string role
    string source
    datetime granted_at
  }

  SPACES {
    uuid id PK
    string slug
    string name
    string audience
    string access_policy
    string status
  }

  CATEGORIES {
    uuid id PK
    uuid space_id FK
    string slug
    string name
    string description
    int sort_order
    string status
  }

  TOPIC_HUBS {
    uuid id PK
    uuid category_id FK
    string title
    string summary
    string status
    datetime updated_at
  }

  KNOWLEDGE_BLOCKS {
    uuid id PK
    uuid topic_hub_id FK
    string block_type
    string title
    string body
    int sort_order
    string status
    datetime updated_at
  }

  TOPIC_SIGNALS {
    uuid id PK
    uuid topic_hub_id FK
    string signal_type
    string title
    json payload
    datetime calculated_at
  }

  KNOWLEDGE_CONTRIBUTIONS {
    uuid id PK
    uuid topic_hub_id FK
    uuid contributor_id FK
    string target_type
    uuid target_id
    string proposed_body
    string status
    datetime created_at
  }

  ROOMS {
    uuid id PK
    uuid category_id FK
    uuid owner_id FK
    string slug
    string name
    string description
    string rules
    string origin
    string room_type
    string access_policy
    json tags
    string status
  }

  ROOM_PINS {
    uuid id PK
    uuid room_id FK
    string target_type
    uuid target_id
    int sort_order
    datetime created_at
  }

  POSTS {
    uuid id PK
    uuid room_id FK
    uuid author_id FK
    string post_type
    string body
    string visibility
    string status
    boolean spoiler
    int reply_count
    int like_count
    int bookmark_count
    json recruitment_fields
    datetime created_at
    datetime updated_at
  }

  REPLIES {
    uuid id PK
    uuid post_id FK
    uuid parent_reply_id FK
    uuid author_id FK
    string body
    string status
    int like_count
    datetime created_at
    datetime updated_at
  }

  EVENT_CARDS {
    uuid id PK
    uuid event_id
    string title
    string venue_name
    string region
    datetime starts_at
    string event_status
    string thumbnail_url
    datetime synced_at
  }

  REFERENCES {
    uuid id PK
    uuid created_by FK
    string type
    string url
    string title
    string source_name
    string thumbnail_url
    string summary
    string status
    datetime created_at
  }

  POST_ATTACHMENTS {
    uuid id PK
    uuid post_id FK
    string attachment_type
    uuid target_id
    int sort_order
  }

  REACTIONS {
    uuid id PK
    uuid user_id FK
    string target_type
    uuid target_id
    string reaction_type
    datetime created_at
  }

  BOOKMARKS {
    uuid id PK
    uuid user_id FK
    string target_type
    uuid target_id
    datetime created_at
  }

  REPORTS {
    uuid id PK
    uuid reporter_id FK
    string target_type
    uuid target_id
    string reason
    string status
    datetime created_at
  }

  MODERATION_ACTIONS {
    uuid id PK
    uuid report_id FK
    uuid actor_id FK
    string action
    string reason
    datetime created_at
  }
```

## 6. 주요 API 초안

| Method | Path | 설명 |
| --- | --- | --- |
| `GET` | `/v1/categories` | 카테고리 목록 |
| `GET` | `/v1/spaces` | 참가자/기획자 커뮤니티 목록 |
| `GET` | `/v1/categories/{categorySlug}/hub` | Topic Hub 조회 |
| `POST` | `/v1/categories/{categorySlug}/knowledge-contributions` | Topic Hub 정보 개선 제안 |
| `POST` | `/v1/admin/knowledge-contributions/{id}/resolve` | 지식 기여 승인/거절 |
| `GET` | `/v1/categories/{categorySlug}/rooms` | 카테고리별 방 목록 |
| `POST` | `/v1/categories/{categorySlug}/rooms` | 유저 생성 방 만들기 |
| `GET` | `/v1/rooms/{roomSlug}` | 방 상세와 규칙 |
| `PATCH` | `/v1/rooms/{roomSlug}` | 방 소유자/운영자 방 정보 수정 |
| `POST` | `/v1/rooms/{roomSlug}/pins` | 방 대표 이벤트/레퍼런스 고정 |
| `GET` | `/v1/rooms/{roomSlug}/timeline` | 방 타임라인 |
| `POST` | `/v1/rooms/{roomSlug}/posts` | 게시글 작성 |
| `GET` | `/v1/posts/{postId}` | 게시글 상세와 댓글 |
| `PATCH` | `/v1/posts/{postId}` | 게시글 수정 |
| `DELETE` | `/v1/posts/{postId}` | 게시글 삭제 |
| `POST` | `/v1/posts/{postId}/replies` | 댓글 작성 |
| `POST` | `/v1/replies/{replyId}/replies` | 대댓글 작성 |
| `POST` | `/v1/reactions` | 좋아요 등 반응 |
| `POST` | `/v1/bookmarks` | 저장 |
| `GET` | `/v1/events/search` | Events/Contenido 이벤트 검색 proxy |
| `POST` | `/v1/event-cards` | 이벤트 카드 생성/동기화 |
| `POST` | `/v1/references` | 레퍼런스 카드 생성 |
| `GET` | `/v1/search` | 통합 검색 |
| `POST` | `/v1/reports` | 신고 |
| `GET` | `/v1/admin/moderation/reports` | 신고 큐 |
| `POST` | `/v1/admin/moderation/actions` | 운영자 처리 |
| `POST` | `/v1/admin/users/{userId}/roles` | 기획자/운영자 권한 부여 |

## 7. 도메인 이벤트

| 이벤트 | 발행 주체 | 소비 주체 |
| --- | --- | --- |
| `PostCreated` | PostService | FeedService, SearchService, Notification |
| `RoomCreated` | RoomService | FeedService, SearchService, ModerationService |
| `RoomPinned` | RoomService | FeedService, SearchService |
| `KnowledgeContributionSubmitted` | KnowledgeService | Admin Queue |
| `KnowledgeBlockUpdated` | KnowledgeService | SearchService, FeedService |
| `TopicSignalUpdated` | KnowledgeService | FeedService |
| `ReplyCreated` | ReplyService | Notification, FeedService |
| `ReactionCreated` | ReactionService | CounterService, Notification |
| `ReferenceCreated` | ReferenceService | SearchService, ModerationService |
| `EventCardAttached` | EventCardService | Event Analytics, FeedService |
| `ContentReported` | ModerationService | Admin Queue |
| `ModerationActionApplied` | ModerationService | FeedService, SearchService, Notification |

## 8. 데이터 흐름: Topic Hub 조회

```mermaid
sequenceDiagram
  participant User as Member
  participant App as Flutter App
  participant API as Backend API
  participant Knowledge as KnowledgeService
  participant Feed as FeedService
  participant DB as PostgreSQL

  User->>App: 연애 콘텐츠 선택
  App->>API: GET /categories/love-content/hub
  API->>Knowledge: getTopicHub()
  Knowledge->>DB: load topic_hub, knowledge_blocks, topic_signals
  Knowledge->>Feed: load related rooms and hot posts
  Feed->>DB: query rooms, posts, event cards, references
  API-->>App: topic hub detail
```

## 9. 데이터 흐름: Topic Hub 정보 기여

```mermaid
sequenceDiagram
  participant User as Knowledge Contributor
  participant API as Backend API
  participant Knowledge as KnowledgeService
  participant Admin as Admin Web
  participant Search as SearchService
  participant DB as PostgreSQL

  User->>API: POST /categories/{slug}/knowledge-contributions
  API->>Knowledge: submitContribution()
  Knowledge->>DB: insert knowledge_contribution
  Admin->>API: resolve contribution
  API->>Knowledge: applyContribution()
  Knowledge->>DB: update knowledge_block, insert audit log
  Knowledge-->>Search: KnowledgeBlockUpdated
```

## 10. 데이터 흐름: 유저 생성 방 개설

```mermaid
sequenceDiagram
  participant User as Member
  participant App as Flutter App
  participant API as Backend API
  participant Room as RoomService
  participant Mod as ModerationService
  participant Search as SearchService
  participant DB as PostgreSQL

  User->>App: 카테고리에서 방 만들기
  App->>API: POST /categories/{slug}/rooms
  API->>Room: createUserRoom()
  Room->>DB: insert room, room owner, tags
  Room-->>Mod: RoomCreated
  Mod->>DB: visible or review_required
  Room-->>Search: RoomCreated
  Search->>DB: update search vector
  API-->>App: room detail
```

## 11. 데이터 흐름: 이벤트 카드를 첨부한 글 작성

```mermaid
sequenceDiagram
  participant User as Member
  participant App as Flutter App
  participant API as Backend API
  participant Events as Events/Contenido
  participant Post as PostService
  participant Feed as FeedService
  participant Search as SearchService
  participant DB as PostgreSQL

  User->>App: 글쓰기에서 이벤트 검색
  App->>API: GET /events/search?q=소개팅
  API->>Events: search events
  Events-->>API: event candidates
  API-->>App: event list
  User->>App: 이벤트 카드 선택 후 게시
  App->>API: POST /rooms/{roomSlug}/posts
  API->>Post: createPostWithEventCard()
  Post->>DB: upsert event_card, insert post, insert attachment
  Post-->>Feed: PostCreated
  Post-->>Search: PostCreated
  Feed->>DB: update counters/materialized feed
  Search->>DB: update search vector
  API-->>App: post detail
```

## 12. 데이터 흐름: 레퍼런스 공유

```mermaid
sequenceDiagram
  participant User as Member
  participant App as Flutter App
  participant API as Backend API
  participant Ref as ReferenceService
  participant Mod as ModerationService
  participant DB as PostgreSQL

  User->>App: 예능 레퍼런스 URL 입력
  App->>API: POST /references
  API->>Ref: fetchMetadata(url)
  Ref->>DB: insert reference
  Ref-->>Mod: ReferenceCreated
  Mod->>DB: mark as visible or review_required
  API-->>App: reference card
  User->>App: 카드 첨부 후 글 게시
```

## 13. 데이터 흐름: 댓글/대댓글 알림

```mermaid
sequenceDiagram
  participant User as Member
  participant API as Backend API
  participant Reply as ReplyService
  participant Noti as Notification
  participant DB as PostgreSQL

  User->>API: POST /posts/{postId}/replies
  API->>Reply: createReply()
  Reply->>DB: insert reply, increment reply_count
  Reply-->>Noti: ReplyCreated
  Noti->>DB: create notification for post author and mentions
  API-->>User: reply detail
```

## 14. 검색 전략

MVP는 PostgreSQL full-text search로 시작한다.

검색 대상:

1. 카테고리 이름과 설명
2. Topic Hub 제목, 요약, 지식 블록
3. 방 이름, 설명, 규칙
4. 게시글 본문
5. 댓글 본문
6. 이벤트 카드 제목, 장소, 지역
7. 레퍼런스 제목, 출처, 요약
8. 모집 글의 역할, 지역, 일정

확장 기준:

| 상황 | 확장 |
| --- | --- |
| 검색 대상 100만 건 이상 | OpenSearch/Meilisearch 검토 |
| 형태소/한글 검색 품질 필요 | 한국어 tokenizer 도입 |
| 추천 피드 필요 | 별도 ranking pipeline |

## 15. 인기순 계산 초안

```text
hot_score =
  like_count * 3
  + reply_count * 5
  + bookmark_count * 4
  + event_card_bonus
  + reference_bonus
  - report_penalty
  - time_decay
```

주의:

1. 신고가 일정 수 이상이면 인기 피드에서 즉시 제외한다.
2. 이벤트 카드가 붙은 글은 이벤트 상세/관련 방에서 더 잘 노출한다.
3. 레퍼런스 글은 오래 지나도 검색 가치가 있으므로 time decay를 낮게 둘 수 있다.
4. 최종 점수는 서버에서 계산하고 클라이언트는 정렬 기준만 요청한다.

## 16. Topic Hub 데이터 신호

```text
topic_signal =
  saved_reference_count
  + event_card_mentions
  + verified_review_count
  + high_reply_threads
  + curator_selected_items
```

초기 Topic Hub 데이터 신호:

| 신호 | 설명 |
| --- | --- |
| 인기 레퍼런스 | 저장/첨부가 많은 레퍼런스 |
| 많이 언급된 이벤트 | 게시글과 댓글에서 자주 연결된 이벤트 |
| 뜨거운 쟁점 | 댓글과 대댓글이 많이 달린 주제 |
| 인증 후기 요약 | 참가 인증 후기에서 자주 등장하는 키워드 |
| 기획 팁 후보 | 기획자 커뮤니티에서 저장이 많은 정보 글 |

## 17. 장애 대응

| 상황 | 대응 |
| --- | --- |
| 이벤트 검색 실패 | 사용자가 직접 링크/제목으로 일반 글 작성 가능 |
| 이벤트 카드 동기화 실패 | 마지막으로 저장된 카드 정보를 보여주고 재동기화 job 실행 |
| 레퍼런스 메타데이터 수집 실패 | 제목/설명 수동 입력 허용 |
| 지식 기여 품질 저하 | Curator 승인 전까지 Topic Hub에 미반영 |
| Topic Hub 데이터 신호 계산 실패 | 마지막 계산 결과를 보여주고 배치 재실행 |
| 유저 생성 방 스팸 증가 | rate limit, 중복 제목 감지, 임시 검수 상태 |
| 기획자 권한 오부여 | role audit log, 운영자 재검수, 권한 회수 |
| 게시글 작성 후 피드 반영 지연 | 작성자는 즉시 optimistic UI, 서버 재조회로 보정 |
| 신고 폭주 | 자동 임시 숨김과 운영자 우선순위 큐 |
| 검색 인덱스 누락 | PostgreSQL 원장 기준 재색인 가능 |
