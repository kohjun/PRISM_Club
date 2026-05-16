# PRISM Club Technical Stack

확인일: 2026-05-16  
목표: PRISM Club을 주제별 예능/이벤트 지식형 커뮤니티로 빠르게 만들되, PRISM Events/Contenido, Play, MC, Maker와 자연스럽게 연결되도록 설계한다.

## 1. 권장 스택 요약

| 영역 | 선택 | 이유 |
| --- | --- | --- |
| 모바일 앱 | Flutter | 커뮤니티 탐색, 글쓰기, 댓글, 알림 중심의 iOS/Android 앱을 한 코드베이스로 시작하기 좋다. |
| 관리자 웹 | Next.js + TypeScript | 카테고리/방 관리, 유저 생성 방 검수, 기획자 권한 관리, 신고 처리, 콘텐츠 검수, 이벤트 연동 확인 화면에 적합하다. |
| 백엔드 | NestJS + TypeScript | Knowledge, Community, Feed, Search, Moderation, EventLink 모듈을 명확히 나누기 좋다. |
| 데이터베이스 | PostgreSQL | Topic Hub, 지식 블록, 카테고리, 방, 게시글, 댓글, 이벤트 카드, 신고 등 관계형 데이터 정합성이 중요하다. |
| 검색 | PostgreSQL Full-Text Search first | MVP 검색에는 충분하다. 지식 블록과 커뮤니티 글이 늘어나면 OpenSearch/Meilisearch로 확장한다. |
| 캐시/카운터 | Redis | 타임라인 캐시, 좋아요/댓글 카운터, 인기순 계산, 알림 큐에 사용한다. |
| 파일 저장 | S3 호환 Object Storage | 게시글 이미지, 프로필 이미지, 레퍼런스 썸네일 캐시를 저장한다. |
| ORM/마이그레이션 | Prisma | 커뮤니티 CRUD와 migration 생산성이 좋다. 복잡한 검색/랭킹 쿼리는 raw SQL로 분리한다. |
| API 문서 | OpenAPI/Swagger | 모바일, 관리자, Events/Contenido 연동 계약을 명확히 한다. |
| 인증 | PRISM Account + OAuth/OIDC + JWT | 하나의 계정으로 Club과 다른 PRISM 앱을 연결한다. |
| 알림 | FCM/APNs | 댓글, 대댓글, 멘션, 저장한 이벤트 업데이트 알림을 보낸다. |
| 이벤트 연동 | Events API Adapter | Club은 Events 원본을 소유하지 않고 이벤트 카드로 참조한다. |
| AI 확장 | AI Provider Adapter | 향후 글 요약, 레퍼런스 분류, Topic Hub 초안 생성, 금칙어/스팸 보조 검수에 활용 가능하다. |
| 배포 | Docker Compose local, AWS Seoul or managed PaaS production | 로컬 재현성과 한국 사용자 지연 시간을 함께 고려한다. |

## 2. 공식 문서로 확인한 기준

| 기술 | 참고 |
| --- | --- |
| Flutter | 공식 문서는 모바일, 웹, 데스크톱, 임베디드까지 단일 코드베이스로 빌드할 수 있음을 설명한다. https://flutter.dev/multi-platform |
| NestJS WebSocket | NestJS는 `@WebSocketGateway()` 기반 Gateway 패턴을 제공한다. 실시간 채팅은 MVP 제외지만, 추후 라이브 토론/현장 피드에 대비 가능하다. https://docs.nestjs.com/websockets/gateways |
| Next.js App Router | Next.js App Router는 Server/Client Components와 파일 기반 라우팅을 제공한다. https://nextjs.org/docs/app |
| PostGIS | Play 위치 게임 확장 시 PostgreSQL에 `geometry`, `geography` 타입과 공간 연산을 추가할 수 있다. https://postgis.net/docs/using_postgis_dbmanagement.html |
| Redis Pub/Sub & Streams | Redis Pub/Sub은 at-most-once 전달이고, 더 강한 처리 보장이 필요하면 Streams를 고려하라고 공식 문서가 설명한다. https://redis.io/docs/latest/develop/pubsub/ |
| OpenAI Realtime | MC 음성 진행자와 향후 라이브 이벤트 보조 기능은 Realtime API 또는 TTS/Responses 조합으로 검증할 수 있다. https://platform.openai.com/docs/api-reference/realtime |

## 3. 왜 이 조합인가

PRISM Club은 일반 게시판보다 “Topic Hub + 주제별 타임라인 + 유저 생성 방 + 이벤트 카드 + 레퍼런스 아카이브 + 대댓글 토론”에 가깝다. 따라서 MVP부터 다음 여섯 가지를 만족해야 한다.

1. 주제 클릭 시 정리된 정보와 관련 대화가 함께 보여야 한다.
2. 모바일 글쓰기와 탐색 경험이 가벼워야 한다.
3. 댓글/대댓글/알림이 빠르게 반영되어야 한다.
4. 이벤트 원본 데이터와 커뮤니티 대화가 느슨하게 연결되어야 한다.
5. 참가자 커뮤니티와 기획자 전용 커뮤니티를 권한으로 분리해야 한다.
6. 신고, 숨김, 차단, 감사 로그가 처음부터 있어야 한다.

Flutter는 참가자 앱에, Next.js는 운영자/관리자 웹에, NestJS는 커뮤니티 API와 연동 처리에 배치하면 각 영역의 책임이 자연스럽다.

## 4. 초기 아키텍처 선택

초기에는 마이크로서비스가 아니라 Modular Monolith를 권장한다.

| 선택지 | 판단 |
| --- | --- |
| Modular Monolith | MVP 권장. 커뮤니티, 피드, 검색, 신고, 이벤트 연동을 한 배포 단위에서 빠르게 검증한다. |
| Microservices | 트래픽, 조직, 도메인 변경 속도가 커진 뒤 Feed/Search/Moderation부터 분리한다. |
| Firebase/Supabase only | 빠른 프로토타입에는 좋지만, 이벤트 연동/신고 정책/검색/운영자 감사 로그가 커지면 커스텀 서버가 필요하다. |
| Serverless only | 일반 CRUD는 가능하지만, 피드 카운터와 커뮤니티 운영 로직은 장기적으로 서버 모듈이 낫다. |

## 5. 백엔드 모듈 구조

```text
apps/api
  account        # 계정, OAuth, 토큰, 권한
  profile        # 공개 프로필, 관심 카테고리
  access-control # 참가자/기획자 커뮤니티 권한, role grants
  knowledge      # Topic Hub, 지식 블록, 정보 기여, 데이터 신호
  community      # space, 카테고리, 유저 생성 방, 게시글, 댓글, 대댓글
  feed           # 방 타임라인, 홈 피드, 인기순
  event-link     # Events/Contenido 이벤트 검색과 이벤트 카드
  reference      # 외부 링크/예능 레퍼런스 카드
  search         # 통합 검색, indexing
  moderation     # 신고, 숨김, 차단, 금칙어, audit log
  notification   # 댓글, 멘션, 업데이트 알림
  admin          # 운영자 백오피스 API
  shared         # 공통 예외, 로깅, config, auth guards
```

Club MVP에서는 `account`, `profile`, `community`, `feed`, `event-link`, `reference`, `search`, `moderation`, `notification`, `admin`을 우선 구현한다.

## 6. 데이터 저장 전략

| 데이터 | 저장소 | 설명 |
| --- | --- | --- |
| 계정/프로필 | PostgreSQL | 사용자 식별, 공개 프로필, 관심 카테고리 |
| Topic Hub/지식 블록 | PostgreSQL | 주제 개요, FAQ, 기획 팁, 체크리스트, 변경 이력 |
| 권한/인증 | PostgreSQL | 기획자 인증, 스튜디오 소속, 운영자 권한 |
| 카테고리/방 | PostgreSQL | 운영자 기본 방과 유저 생성 방을 함께 관리 |
| 게시글/댓글 | PostgreSQL | 원장 데이터와 정합성이 중요하다. |
| 좋아요/저장 카운터 | PostgreSQL + Redis | 원장은 DB, 빠른 피드 계산은 Redis |
| 타임라인 캐시 | Redis | 방별 최신/인기 피드 캐시 |
| 검색 인덱스 | PostgreSQL FTS | MVP 검색. 이후 전용 검색 엔진 검토 |
| 데이터 신호 | PostgreSQL + Redis | 인기 레퍼런스, 많이 언급된 이벤트, 뜨거운 쟁점 |
| 이벤트 카드 | PostgreSQL | Events 원본을 복제하지 않고 스냅샷/참조 저장 |
| 레퍼런스 카드 | PostgreSQL + Object Storage | 링크 메타데이터와 썸네일 |
| 이미지/미디어 | S3 compatible storage | DB에는 메타데이터와 접근 권한만 저장 |
| 신고/audit log | PostgreSQL | 운영 조치 추적과 복구 가능성 |

## 7. 보안과 커뮤니티 안전 기본값

1. 쓰기 API는 인증을 요구한다.
2. 닉네임 프로필과 계정 식별 정보를 분리한다.
3. Topic Hub의 지식 블록은 출처, 관련 글, 관련 이벤트 중 하나 이상의 근거를 추적할 수 있게 한다.
4. 신고된 콘텐츠는 정책에 따라 임시 숨김될 수 있다.
5. 운영자 조치와 지식 블록 변경은 audit log에 남긴다.
6. 이벤트 참가 인증 후기는 Events/Contenido 참가 기록으로 검증한다.
7. 기획자 전용 카테고리는 클라이언트 숨김뿐 아니라 서버 권한 검사로 보호한다.
8. 차단한 사용자의 글/댓글/멘션 알림은 숨긴다.
9. 레퍼런스 공유는 URL, 출처, 썸네일, 저작권 정책을 별도로 관리한다.
10. 스태프 모집 글은 역할, 시간, 장소, 보상, 연락 방식 같은 필수 정보를 요구한다.

## 8. 버전 정책

실제 구현 시작 시점에 다음 명령으로 버전을 확정하고 이 문서에 기록한다.

```powershell
flutter --version
node --version
npm --version
docker --version
```

라이브러리는 “최신”보다 “현 시점 안정 버전 + 보안 패치 가능성”을 우선한다. MVP 구현 중에는 major upgrade를 피하고, 릴리스 단위로 upgrade window를 둔다.
