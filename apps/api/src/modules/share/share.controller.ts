import {
  BadRequestException,
  Controller,
  Get,
  Query,
  Redirect,
  Req,
} from '@nestjs/common';
import { Public } from '../../shared/decorators/public.decorator';
import { Viewer } from '../../shared/access-control.service';
import { AuthService } from '../auth/auth.service';
import { ShareService } from './share.service';
import { ShareTargetType } from './dto/share-preview.dto';

const VALID_TYPES = new Set<ShareTargetType>([
  'POST',
  'TOPIC_HUB',
  'EVENT',
  'PROFILE',
]);

const DEFAULT_PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.prism.club';

@Controller()
export class ShareController {
  constructor(
    private readonly svc: ShareService,
    private readonly auth: AuthService,
  ) {}

  /**
   * Preview metadata for the web fallback host (Open Graph render) AND for
   * the mobile app's deep-link resolver. Public so messaging apps (KakaoTalk,
   * Slack, iMessage) can fetch it without auth — visibility is enforced per
   * target inside ShareService against the caller's viewer (anonymous when
   * no Bearer header is present).
   */
  @Public()
  @Get('share/preview')
  preview(
    @Query('type') type: string,
    @Query('id') id: string,
    @Req() req: { headers: Record<string, string | undefined> },
  ) {
    const viewer = this.viewerFromHeaders(req?.headers);
    return this.svc.getPreview(this.normalizeType(type), id, viewer);
  }

  /**
   * Fallback redirect — used when an Android App Link is verified but the
   * app isn't installed, the OS hits this endpoint and we bounce to the
   * Play Store. Operator can override with PLAY_STORE_URL env.
   */
  @Public()
  @Get('share/resolve')
  @Redirect()
  resolve(): { url: string; statusCode: number } {
    const url = process.env.PLAY_STORE_URL ?? DEFAULT_PLAY_STORE_URL;
    return { url, statusCode: 302 };
  }

  private normalizeType(raw: string): ShareTargetType {
    const norm = (raw ?? '').toUpperCase().replace(/-/g, '_');
    if (!VALID_TYPES.has(norm as ShareTargetType)) {
      throw new BadRequestException(
        `type must be one of POST | TOPIC_HUB | EVENT | PROFILE`,
      );
    }
    return norm as ShareTargetType;
  }

  /**
   * Anonymous when no/invalid token; verified-planner / admin when the
   * caller IS authenticated. Token failures are swallowed silently — this
   * endpoint is intentionally tolerant so a broken access JWT does not
   * break public previews.
   */
  private viewerFromHeaders(
    headers: Record<string, string | undefined> | undefined,
  ): Viewer {
    const authHeader = headers?.['authorization'];
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      try {
        const payload = this.auth.verify(authHeader.slice(7).trim());
        return { roles: payload.roles ?? [] };
      } catch {
        // fall through to anonymous
      }
    }
    return { roles: [] };
  }
}
