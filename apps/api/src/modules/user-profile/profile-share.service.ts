import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import sharp from 'sharp';
import { PrismaService } from '../../shared/prisma.service';
import { TrustScoreService, TrustTier } from '../../shared/trust-score.service';
import { ContributionReputationService } from '../knowledge/contribution-reputation.service';
import { AnalyticsService } from '../analytics/analytics.service';

const SHARE_BASE_DEFAULT = 'https://club.prism.club';
const OG_TTL_MS = 60_000;
const OG_WIDTH = 1200;
const OG_HEIGHT = 630;

export interface ProfileBadgeDTO {
  kind: 'TIER' | 'APPROVED_CONTRIB' | 'PLANNER_ROLE';
  label: string;
}

export interface ProfileShareCardDTO {
  user_id: string;
  title: string;
  subtitle: string;
  deep_link: string;
  og_image_url: string;
  badges: ProfileBadgeDTO[];
}

interface CachedPng {
  buf: Buffer;
  expiresAt: number;
}

/**
 * P4.1 share card. Powers both:
 *  - GET /v1/profiles/:userId/share-card → JSON metadata for the in-app
 *    bottom sheet (badges, deep link, OG image URL).
 *  - GET /v1/og/profile/:userId.png → 1200×630 PNG used by KakaoTalk,
 *    Slack, iMessage, etc. The image is composed as SVG and rasterised
 *    by sharp (already a dep from P1.4 — no native `resvg-js` needed,
 *    which keeps Windows dev clean).
 *
 * Visibility: profile cards are public (Discoverable by design) but a
 * DELETED user or one without a profile row 404s. PII safety: only the
 * nickname + bio fragment are rendered; we never put email/phone on the
 * card.
 */
@Injectable()
export class ProfileShareService {
  private readonly log = new Logger(ProfileShareService.name);
  private readonly cache = new Map<string, CachedPng>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly trust: TrustScoreService,
    private readonly reputation: ContributionReputationService,
    private readonly analytics: AnalyticsService,
  ) {}

  async getShareCard(userId: string): Promise<ProfileShareCardDTO> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE' || !user.profile) {
      throw new NotFoundException('Profile not found');
    }

    const viewerLike = { id: user.id, roles: user.roles.map((r) => r.role) };
    const [tier, rep] = await Promise.all([
      this.trust.tierFor(viewerLike),
      this.reputation.getForUser(user.id),
    ]);

    const badges = this.buildBadges(tier.tier, rep.approved_count, viewerLike.roles);
    const base = (process.env.SHARE_BASE_URL ?? SHARE_BASE_DEFAULT).replace(
      /\/+$/,
      '',
    );
    const deepLink = `${base}/share/profile/${encodeURIComponent(user.id)}`;
    const apiBase = (process.env.PUBLIC_API_BASE_URL ?? base).replace(/\/+$/, '');
    const ogUrl = `${apiBase}/v1/og/profile/${encodeURIComponent(user.id)}.png`;

    this.analytics.record({
      actorId: null,
      eventType: 'PROFILE_SHARED',
      payload: {
        target_user_id: user.id,
        tier: tier.tier,
        approved_count: rep.approved_count,
      },
    });

    return {
      user_id: user.id,
      title: user.profile.nickname,
      subtitle: user.profile.bio
        ? truncate(user.profile.bio, 80)
        : 'PRISM Club 프로필',
      deep_link: deepLink,
      og_image_url: ogUrl,
      badges,
    };
  }

  async getOgPng(userId: string): Promise<Buffer> {
    const cached = this.cache.get(userId);
    const now = Date.now();
    if (cached && cached.expiresAt > now) return cached.buf;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE' || !user.profile) {
      throw new NotFoundException('Profile not found');
    }

    const viewerLike = { id: user.id, roles: user.roles.map((r) => r.role) };
    const [tier, rep] = await Promise.all([
      this.trust.tierFor(viewerLike),
      this.reputation.getForUser(user.id),
    ]);

    const svg = this.renderSvg({
      nickname: user.profile.nickname,
      bio: user.profile.bio,
      tier: tier.tier,
      approvedCount: rep.approved_count,
    });

    let png: Buffer;
    try {
      png = await sharp(Buffer.from(svg, 'utf-8')).png().toBuffer();
    } catch (e) {
      this.log.warn(
        `OG rasterise failed for user=${userId}: ${e instanceof Error ? e.message : String(e)}`,
      );
      png = await this.fallbackPng();
    }

    this.cache.set(userId, { buf: png, expiresAt: now + OG_TTL_MS });
    if (this.cache.size > 256) this.evictOldest();
    return png;
  }

  private evictOldest(): void {
    // Bound the cache; nothing here is hot-path so a linear scan is fine.
    const now = Date.now();
    for (const [k, v] of this.cache) {
      if (v.expiresAt <= now) this.cache.delete(k);
    }
    if (this.cache.size > 256) {
      const firstKey = this.cache.keys().next().value;
      if (firstKey) this.cache.delete(firstKey);
    }
  }

  private buildBadges(
    tier: TrustTier,
    approvedCount: number,
    roles: string[],
  ): ProfileBadgeDTO[] {
    const out: ProfileBadgeDTO[] = [];
    out.push({ kind: 'TIER', label: tierLabel(tier) });
    if (approvedCount > 0) {
      out.push({
        kind: 'APPROVED_CONTRIB',
        label: `검수 통과 ${approvedCount}건`,
      });
    }
    if (roles.includes('VERIFIED_PLANNER')) {
      out.push({ kind: 'PLANNER_ROLE', label: '인증 플래너' });
    }
    return out;
  }

  private renderSvg(input: {
    nickname: string;
    bio: string | null;
    tier: TrustTier;
    approvedCount: number;
  }): string {
    const nick = escapeXml(input.nickname);
    const bio = escapeXml(truncate(input.bio ?? 'PRISM Club 멤버', 70));
    const tierText = escapeXml(tierLabel(input.tier));
    const contribText = escapeXml(
      input.approvedCount > 0 ? `검수 통과 ${input.approvedCount}건` : 'PRISM Club',
    );
    return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${OG_WIDTH}" height="${OG_HEIGHT}" viewBox="0 0 ${OG_WIDTH} ${OG_HEIGHT}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1f1d3a"/>
      <stop offset="1" stop-color="#3a1f64"/>
    </linearGradient>
  </defs>
  <rect width="${OG_WIDTH}" height="${OG_HEIGHT}" fill="url(#bg)"/>
  <text x="80" y="160" font-family="Pretendard, sans-serif" font-size="48" fill="#c4b5fd" font-weight="600">PRISM Club</text>
  <text x="80" y="290" font-family="Pretendard, sans-serif" font-size="92" fill="#ffffff" font-weight="700">${nick}</text>
  <text x="80" y="370" font-family="Pretendard, sans-serif" font-size="36" fill="#e0e7ff">${bio}</text>
  <rect x="80" y="450" width="280" height="64" rx="32" fill="#ffffff" opacity="0.12"/>
  <text x="220" y="492" font-family="Pretendard, sans-serif" font-size="28" fill="#ffffff" text-anchor="middle" font-weight="600">${tierText}</text>
  <text x="80" y="572" font-family="Pretendard, sans-serif" font-size="28" fill="#a5b4fc">${contribText}</text>
</svg>`;
  }

  private async fallbackPng(): Promise<Buffer> {
    return sharp({
      create: {
        width: OG_WIDTH,
        height: OG_HEIGHT,
        channels: 3,
        background: { r: 31, g: 29, b: 58 },
      },
    })
      .png()
      .toBuffer();
  }
}

function tierLabel(t: TrustTier): string {
  switch (t) {
    case 'PLANNER':
      return 'Planner';
    case 'TRUSTED':
      return 'Trusted';
    case 'MEMBER':
      return 'Member';
    case 'NEW':
      return 'New';
  }
}

function truncate(s: string, max: number): string {
  if (!s) return '';
  return s.length > max ? `${s.slice(0, max).trimEnd()}…` : s;
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
