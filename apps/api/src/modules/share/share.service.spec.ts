import { NotFoundException } from '@nestjs/common';
import { ShareService } from './share.service';
import { AccessControlService } from '../../shared/access-control.service';

type AnyFn = (...args: unknown[]) => unknown;

function mkPrisma(state: {
  post?: unknown;
  category?: unknown;
  event?: unknown;
  user?: unknown;
  media?: unknown;
}): {
  post: { findUnique: AnyFn };
  category: { findUnique: AnyFn };
  eventCard: { findUnique: AnyFn };
  user: { findUnique: AnyFn };
  mediaAsset: { findUnique: AnyFn };
} {
  return {
    post: { findUnique: jest.fn().mockResolvedValue(state.post ?? null) },
    category: {
      findUnique: jest.fn().mockResolvedValue(state.category ?? null),
    },
    eventCard: {
      findUnique: jest.fn().mockResolvedValue(state.event ?? null),
    },
    user: { findUnique: jest.fn().mockResolvedValue(state.user ?? null) },
    mediaAsset: {
      findUnique: jest.fn().mockResolvedValue(state.media ?? null),
    },
  };
}

function buildSvc(state: Parameters<typeof mkPrisma>[0]): ShareService {
  const prisma = mkPrisma(state) as unknown as ConstructorParameters<
    typeof ShareService
  >[0];
  // Real AccessControlService — its allowlist logic is small and pure.
  const access = new AccessControlService(prisma);
  return new ShareService(prisma, access);
}

const ANON = { roles: [] };
const PLANNER = { roles: ['VERIFIED_PLANNER'] };

describe('ShareService.getPreview', () => {
  const OLD_ENV = { ...process.env };
  beforeEach(() => {
    process.env = { ...OLD_ENV };
    process.env.SHARE_BASE_URL = 'https://share.test';
  });
  afterAll(() => {
    process.env = OLD_ENV;
  });

  test('POST preview hides PLANNER_ONLY content from anonymous viewer (404)', async () => {
    const svc = buildSvc({
      post: {
        id: 'p1',
        body: 'planner-only secret',
        status: 'VISIBLE',
        room: {
          category: {
            space: { accessPolicy: 'PLANNER_ONLY' },
          },
        },
        author: { profile: { nickname: '민서' } },
        attachments: [],
      },
    });
    await expect(svc.getPreview('POST', 'p1', ANON)).rejects.toThrow(
      NotFoundException,
    );
  });

  test('POST preview is visible to verified planner', async () => {
    const svc = buildSvc({
      post: {
        id: 'p1',
        body: 'planner content',
        status: 'VISIBLE',
        room: {
          category: {
            space: { accessPolicy: 'PLANNER_ONLY' },
          },
        },
        author: { profile: { nickname: '민서' } },
        attachments: [],
      },
    });
    const dto = await svc.getPreview('POST', 'p1', PLANNER);
    expect(dto.type).toBe('POST');
    expect(dto.title).toBe('민서님의 글');
    expect(dto.description).toBe('planner content');
    expect(dto.deep_link).toBe('https://share.test/share/post/p1');
  });

  test('POST preview returns 404 when status is HIDDEN/DELETED', async () => {
    const svc = buildSvc({
      post: {
        id: 'p2',
        body: 'hidden',
        status: 'HIDDEN',
        room: {
          category: { space: { accessPolicy: 'PUBLIC' } },
        },
        author: { profile: { nickname: '민서' } },
        attachments: [],
      },
    });
    await expect(svc.getPreview('POST', 'p2', ANON)).rejects.toThrow(
      NotFoundException,
    );
  });

  test('POST preview prefers variants.md when an IMAGE attachment exists', async () => {
    const svc = buildSvc({
      post: {
        id: 'p3',
        body: 'with image',
        status: 'VISIBLE',
        room: { category: { space: { accessPolicy: 'PUBLIC' } } },
        author: { profile: { nickname: '코랄' } },
        attachments: [
          { attachmentType: 'IMAGE', targetId: 'm-1' },
        ],
      },
      media: {
        variants: { md: '/uploads/m-1-md.webp', thumb: '/uploads/m-1-thumb.webp' },
        cdnUrl: '/uploads/m-1.jpg',
        path: '/uploads/m-1.jpg',
      },
    });
    const dto = await svc.getPreview('POST', 'p3', ANON);
    expect(dto.image_url).toBe('/uploads/m-1-md.webp');
  });

  test('TOPIC_HUB preview enforces space access policy', async () => {
    const svc = buildSvc({
      category: {
        slug: 'movies',
        space: { accessPolicy: 'PLANNER_ONLY' },
        topicHub: { title: '영화', summary: '요약' },
      },
    });
    await expect(svc.getPreview('TOPIC_HUB', 'movies', ANON)).rejects.toThrow(
      NotFoundException,
    );
    const dto = await svc.getPreview('TOPIC_HUB', 'movies', PLANNER);
    expect(dto.title).toBe('영화');
    expect(dto.web_url).toBe('https://share.test/share/topic_hub/movies');
  });

  test('EVENT preview returns title and thumbnail without access check', async () => {
    const svc = buildSvc({
      event: {
        id: 'e1',
        title: '제주 보드게임 모임',
        venueName: '한라 카페',
        region: '제주',
        thumbnailUrl: 'https://cdn.example.com/e1.jpg',
      },
    });
    const dto = await svc.getPreview('EVENT', 'e1', ANON);
    expect(dto.title).toBe('제주 보드게임 모임');
    expect(dto.description).toBe('한라 카페 · 제주');
    expect(dto.image_url).toBe('https://cdn.example.com/e1.jpg');
  });

  test('PROFILE preview returns nickname and bio truncated', async () => {
    const svc = buildSvc({
      user: {
        id: 'u1',
        status: 'ACTIVE',
        profile: {
          nickname: '민서',
          bio: 'x'.repeat(200),
          avatarUrl: '/avatars/u1.png',
        },
      },
    });
    const dto = await svc.getPreview('PROFILE', 'u1', ANON);
    expect(dto.title).toBe('민서');
    expect(dto.description.endsWith('…')).toBe(true);
    expect(dto.image_url).toBe('/avatars/u1.png');
  });
});
