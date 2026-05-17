/**
 * NotificationDelivery abstraction (M17).
 *
 * The in-app `notifications` table is the source of truth. This interface
 * lets the API additionally fan out to external channels (email, push) on
 * a best-effort basis. Delivery failures must NEVER prevent notification
 * row creation — callers should `.catch()` any rejection and log it.
 *
 * In Alpha:
 *   - LocalNoopDelivery is the default (logs only, no I/O).
 *   - EmailDelivery + PushDelivery exist as configurable boundaries; the
 *     bundled implementations are inert stubs that document the
 *     integration contract for a future M-? to fill in.
 */

export type DeliveryChannel = 'IN_APP' | 'EMAIL' | 'PUSH';

export type DeliveryStatus = 'SENT' | 'SKIPPED' | 'FAILED';

export interface DeliveryRequest {
  notificationId: string;
  userId: string;
  type: string; // e.g. REPLY_ON_POST, CONTRIBUTION_RESOLVED
  payload: Record<string, unknown>;
}

export interface DeliveryAttempt {
  channel: DeliveryChannel;
  status: DeliveryStatus;
  /** Provider-specific identifier or error code for diagnostics. */
  ref?: string | null;
  error?: string | null;
}

export interface INotificationDeliverer {
  /// Deliver via every channel this provider supports. Implementations
  /// MUST NOT throw — return one DeliveryAttempt per channel attempted
  /// (status SKIPPED when nothing to do; FAILED with `error` set when
  /// the external call errored).
  deliver(req: DeliveryRequest): Promise<DeliveryAttempt[]>;
  /// Human-readable mode label for logs / diagnostics / ops endpoint.
  mode(): string;
}

export const NOTIFICATION_DELIVERY = Symbol('INotificationDeliverer');
