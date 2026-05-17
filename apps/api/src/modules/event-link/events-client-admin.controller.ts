import { Controller, ForbiddenException, Get } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { MockEventsClient } from './clients/mock-events.client';
import { PrismEventsClient } from './clients/prism-events.client';

/**
 * Admin diagnostic surface for the upstream PRISM EVENT client (M20).
 *
 * Returns the active client mode, base URL configuration state, timeout,
 * and cumulative parse / HTTP error counters. Useful for noticing
 * contract drift (`parse_failed > 0`) or upstream incidents
 * (`http_errors / timeouts > 0`) without grepping logs.
 *
 * Role gate: CURATOR / MODERATOR / ADMIN.
 */
@Controller('admin/events-client')
export class EventsClientAdminController {
  constructor(
    private readonly mock: MockEventsClient,
    private readonly prism: PrismEventsClient,
  ) {}

  @Get('status')
  status(@CurrentUser() user: RequestUser): Record<string, unknown> {
    if (
      !user.roles.includes('ADMIN') &&
      !user.roles.includes('MODERATOR') &&
      !user.roles.includes('CURATOR')
    ) {
      throw new ForbiddenException('Events client diagnostic requires ops role');
    }
    const mode = (process.env.EVENTS_CLIENT_MODE ?? 'mock').toLowerCase();
    if (mode === 'prism' && process.env.PRISM_EVENTS_API_BASE_URL) {
      return this.prism.diagnostic();
    }
    return {
      mode: 'mock',
      base_url_configured: false,
      timeout_ms: 0,
      stats: {
        parsed_ok: 0,
        parse_failed: 0,
        http_errors: 0,
        timeouts: 0,
        last_error: null,
        last_error_at: null,
      },
      note:
        mode === 'prism'
          ? 'EVENTS_CLIENT_MODE=prism but PRISM_EVENTS_API_BASE_URL not set; client fell back to mock'
          : 'Mock client active (default for dev/test)',
    };
  }
}
