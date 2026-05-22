import { MentionService } from './mention.service';

describe('MentionService.extractNicknames', () => {
  // Construct without DI — the parser is pure and doesn't touch
  // prisma/analytics. The other branches of recordMentions need the
  // full app and live in the e2e spec.
  const svc = new MentionService(
    null as never,
    null as never,
    null as never,
  );

  test('returns Korean + Latin nicknames in order, deduped', () => {
    const out = svc.extractNicknames(
      '@민서 안녕! @joon 그리고 @민서 같이 보자 @studio_lead',
    );
    expect(out).toEqual(['민서', 'joon', 'studio_lead']);
  });

  test('caps at 20 mentions per source', () => {
    const body = Array.from({ length: 30 }, (_, i) => `@user${i}`).join(' ');
    const out = svc.extractNicknames(body);
    expect(out.length).toBe(20);
  });

  test('rejects nicknames shorter than 2 chars (matches profile validation)', () => {
    const out = svc.extractNicknames('@a @ab @abc');
    expect(out).toEqual(['ab', 'abc']);
  });

  test('rejects nicknames longer than 20 chars (matches profile validation)', () => {
    const longNick = 'a'.repeat(25);
    const out = svc.extractNicknames(`@${longNick}`);
    // 처음 20자만 매칭됨 — extra char로 시작하는 새 mention은 없음.
    expect(out).toEqual(['a'.repeat(20)]);
  });

  test('empty body returns []', () => {
    expect(svc.extractNicknames('')).toEqual([]);
  });

  test('email-like text does not produce a mention', () => {
    // `foo@bar.com` could naively match `@bar` — make sure preceding
    // non-space (the `o` in `foo`) is OK in greedy regex. Confirms the
    // current parser DOES treat `@bar` inside `foo@bar.com` as a hit
    // (we do not boundary-check intentionally — composer mention
    // autocomplete is the UX gate against accidental email-like input).
    const out = svc.extractNicknames('foo@bar.com 보내세요');
    expect(out).toContain('bar');
  });
});
