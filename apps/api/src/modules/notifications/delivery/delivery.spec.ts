import { LocalNoopDelivery } from './local-noop-delivery';
import { EmailDelivery } from './email-delivery';
import { PushDelivery } from './push-delivery';
import { NotificationPreferencesService } from '../notification-preferences.service';
import { DeviceTokenService } from '../device-token.service';

const baseReq = {
  notificationId: 'n-1',
  userId: 'u-1',
  type: 'REPLY_ON_POST',
  payload: { roomSlug: 'r' },
};

function buildPushDelivery(opts: {
  pushAllowed?: { allow: boolean; reason?: string };
  tokens?: Array<{ id: string; provider: string; token: string }>;
} = {}) {
  const prefs = {
    pushAllowedFor: jest
      .fn()
      .mockResolvedValue(opts.pushAllowed ?? { allow: true }),
  } as unknown as NotificationPreferencesService;
  const deviceTokens = {
    activeTokensForUser: jest
      .fn()
      .mockResolvedValue(
        opts.tokens ?? [{ id: 't-1', provider: 'FCM', token: 'tok-xxxxxxxx' }],
      ),
  } as unknown as DeviceTokenService;
  return new PushDelivery(prefs, deviceTokens);
}

describe('NotificationDelivery providers', () => {
  let envSnapshot: NodeJS.ProcessEnv;

  beforeEach(() => {
    envSnapshot = { ...process.env };
    for (const k of Object.keys(process.env)) {
      if (k.startsWith('EMAIL_') || k.startsWith('PUSH_')) {
        delete process.env[k];
      }
    }
  });

  afterEach(() => {
    process.env = envSnapshot;
  });

  test('LocalNoopDelivery returns IN_APP=SENT, EMAIL/PUSH=SKIPPED', async () => {
    const d = new LocalNoopDelivery();
    const attempts = await d.deliver(baseReq);
    expect(attempts).toEqual(
      expect.arrayContaining([
        { channel: 'IN_APP', status: 'SENT', ref: 'n-1' },
        { channel: 'EMAIL', status: 'SKIPPED' },
        { channel: 'PUSH', status: 'SKIPPED' },
      ]),
    );
  });

  test('EmailDelivery stub returns SKIPPED with helpful ref when no provider configured', async () => {
    const d = new EmailDelivery();
    expect(d.mode()).toBe('email(stub — no provider configured)');
    const attempts = await d.deliver(baseReq);
    const email = attempts.find((a) => a.channel === 'EMAIL');
    expect(email?.status).toBe('SKIPPED');
    expect(email?.ref).toBe('no-provider-configured');
  });

  test('EmailDelivery with provider env reports a configured mode label', async () => {
    process.env.EMAIL_PROVIDER = 'resend';
    process.env.EMAIL_FROM_ADDRESS = 'PRISM <no-reply@x.com>';
    const d = new EmailDelivery();
    expect(d.mode()).toBe('email(resend)');
    const attempts = await d.deliver(baseReq);
    const email = attempts.find((a) => a.channel === 'EMAIL');
    expect(email?.status).toBe('SKIPPED'); // implementation deferred
    expect(email?.ref).toBe('not-implemented');
  });

  test('PushDelivery stub returns SKIPPED with helpful ref when no provider configured', async () => {
    const d = buildPushDelivery();
    expect(d.mode()).toBe('push(stub — no provider configured)');
    const attempts = await d.deliver(baseReq);
    const push = attempts.find((a) => a.channel === 'PUSH');
    expect(push?.status).toBe('SKIPPED');
    expect(push?.ref).toBe('no-provider-configured');
  });

  test('PushDelivery skips when user disabled push at the master switch', async () => {
    const d = buildPushDelivery({
      pushAllowed: { allow: false, reason: 'user-pref-push-off' },
    });
    const attempts = await d.deliver(baseReq);
    const push = attempts.find((a) => a.channel === 'PUSH');
    expect(push?.status).toBe('SKIPPED');
    expect(push?.ref).toBe('user-pref-push-off');
  });

  test('PushDelivery skips when user disabled this notification type', async () => {
    const d = buildPushDelivery({
      pushAllowed: { allow: false, reason: 'user-pref-type-off' },
    });
    const attempts = await d.deliver(baseReq);
    const push = attempts.find((a) => a.channel === 'PUSH');
    expect(push?.status).toBe('SKIPPED');
    expect(push?.ref).toBe('user-pref-type-off');
  });

  test('PushDelivery skips when the user has no active device tokens', async () => {
    const d = buildPushDelivery({ tokens: [] });
    const attempts = await d.deliver(baseReq);
    const push = attempts.find((a) => a.channel === 'PUSH');
    expect(push?.status).toBe('SKIPPED');
    expect(push?.ref).toBe('no-active-device-tokens');
  });

  test('Delivery providers MUST NOT throw — they return FAILED attempts instead', async () => {
    process.env.EMAIL_PROVIDER = 'resend';
    process.env.EMAIL_FROM_ADDRESS = 'x@x';
    const d = new EmailDelivery();
    // Even if the deliver implementation grows real I/O later, callers
    // should always get a list of attempts back instead of a thrown error.
    const attempts = await d.deliver(baseReq);
    expect(Array.isArray(attempts)).toBe(true);
  });
});
