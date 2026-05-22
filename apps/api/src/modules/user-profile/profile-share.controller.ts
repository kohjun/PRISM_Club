import {
  Controller,
  Get,
  Header,
  Param,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { Public } from '../../shared/decorators/public.decorator';
import { ProfileShareService } from './profile-share.service';

@Controller()
export class ProfileShareController {
  constructor(private readonly svc: ProfileShareService) {}

  /**
   * Metadata for the in-app "share my profile" bottom sheet. Public so
   * messaging clients fetching the web fallback can call it too — the
   * profile itself is public-by-design (no bio = synthetic subtitle).
   */
  @Public()
  @Get('profiles/:id/share-card')
  card(@Param('id') id: string) {
    return this.svc.getShareCard(id);
  }

  /**
   * Open-Graph rasterised PNG. We set a 10-minute browser TTL and a
   * 1-hour shared-cache TTL so Cloudflare can absorb the spike when a
   * share link is posted to a high-traffic KakaoTalk room.
   */
  @Public()
  @Get('og/profile/:id.png')
  @Header('Content-Type', 'image/png')
  @Header(
    'Cache-Control',
    'public, max-age=600, s-maxage=3600, stale-while-revalidate=86400',
  )
  async ogImage(@Param('id') id: string, @Res() res: Response): Promise<void> {
    const buf = await this.svc.getOgPng(id);
    res.send(buf);
  }
}
