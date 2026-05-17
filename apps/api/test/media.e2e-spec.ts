import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

// 1×1 transparent PNG
const PNG_1x1 = Buffer.from(
  '89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C4890000000D49444154789C63000100000005000196FE2C460000000049454E44AE426082',
  'hex',
);

describe('Milestone 10 — media upload (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('POST /v1/media/upload accepts image and returns asset', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/media/upload')
      .set(HEAD(ctx.uuids.user.minseo))
      .attach('file', PNG_1x1, { filename: 'tiny.png', contentType: 'image/png' });
    expect(res.status).toBe(201);
    expect(res.body.kind).toBe('IMAGE');
    expect(res.body.url).toMatch(/^\/uploads\/.+\.png$/);
    expect(res.body.size_bytes).toBeGreaterThan(0);
  });

  test('Upload rejects non-image MIME types', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/media/upload')
      .set(HEAD(ctx.uuids.user.minseo))
      .attach('file', Buffer.from('hello'), {
        filename: 'note.txt',
        contentType: 'text/plain',
      });
    expect(res.status).toBe(400);
  });

  test('Upload requires a file', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/media/upload')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(400);
  });

  test('Post create with IMAGE attachment succeeds and exposes URL', async () => {
    // 1. Upload
    const upload = await request(ctx.app.getHttpServer())
      .post('/v1/media/upload')
      .set(HEAD(ctx.uuids.user.minseo))
      .attach('file', PNG_1x1, { filename: 'tiny.png', contentType: 'image/png' });
    expect(upload.status).toBe(201);
    const mediaId = upload.body.id;

    // 2. Create a post in a room minseo can write to (dating-event-reviews)
    const post = await request(ctx.app.getHttpServer())
      .post('/v1/rooms/dating-event-reviews/posts')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({
        body: 'test post with image',
        attachments: [
          { attachment_type: 'IMAGE', target_id: mediaId },
        ],
      });
    expect(post.status).toBe(201);
    const imgAtt = post.body.attachments.find(
      (a: { attachment_type: string }) => a.attachment_type === 'IMAGE',
    );
    expect(imgAtt).toBeTruthy();
    expect(imgAtt.target.url).toMatch(/^\/uploads\//);
  });
});
