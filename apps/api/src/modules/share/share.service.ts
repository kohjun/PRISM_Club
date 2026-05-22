import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import { SharePreviewDTO, ShareTargetType } from './dto/share-preview.dto';

const DEFAULT_SHARE_BASE_URL = 'https://club.prism.club';
const SUMMARY_MAX_LEN = 140;

/**
 * Server-side share-preview composer (P1.5).
 *
 * `getPreview` joins the read-only side of the relevant module (Post / Topic
 * Hub / EventCard / Profile) and returns a flat shape the web fallback page
 * uses to emit Open Graph meta. The access-control rule is the same one the
 * full-detail endpoint enforces: anonymous viewers see only PUBLIC content;
 * Verified Planner / Admin viewers can additionally preview PLANNER_ONLY
 * material so they can share inside their own community.
 */
@Injectable()
export class ShareService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async getPreview(
    type: ShareTargetType,
    id: string,
    viewer: Viewer,
  ): Promise<SharePreviewDTO> {
    if (!id) {
      throw new BadRequestException('id is required');
    }
    switch (type) {
      case 'POST':
        return this.postPreview(id, viewer);
      case 'TOPIC_HUB':
        return this.topicHubPreview(id, viewer);
      case 'EVENT':
        return this.eventPreview(id);
      case 'PROFILE':
        return this.profilePreview(id);
      default:
        throw new BadRequestException(`Unknown share type: ${type}`);
    }
  }

  resolveWebUrl(type: ShareTargetType, id: string): string {
    return this.buildShareUrl(type, id);
  }

  private async postPreview(
    id: string,
    viewer: Viewer,
  ): Promise<SharePreviewDTO> {
    const post = await this.prisma.post.findUnique({
      where: { id },
      include: {
        room: { include: { category: { include: { space: true } } } },
        author: { include: { profile: true } },
        attachments: true,
      },
    });
    if (!post || post.status !== 'VISIBLE') {
      throw new NotFoundException('Post not found');
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(post.room.category.space.accessPolicy)
    ) {
      // Hide existence from non-PLANNER viewers — 404, not 403.
      throw new NotFoundException('Post not found');
    }

    const imageAttachment = post.attachments.find(
      (a) => a.attachmentType === 'IMAGE',
    );
    let imageUrl: string | null = null;
    if (imageAttachment) {
      const media = await this.prisma.mediaAsset.findUnique({
        where: { id: imageAttachment.targetId },
      });
      if (media) {
        const variants = (media.variants as { md?: string } | null) ?? null;
        imageUrl = variants?.md ?? media.cdnUrl ?? media.path;
      }
    }

    const nickname = post.author.profile?.nickname ?? '익명';
    return {
      type: 'POST',
      id: post.id,
      title: `${nickname}님의 글`,
      description: truncate(post.body, SUMMARY_MAX_LEN),
      image_url: imageUrl,
      deep_link: this.buildShareUrl('POST', post.id),
      web_url: this.buildShareUrl('POST', post.id),
    };
  }

  private async topicHubPreview(
    slug: string,
    viewer: Viewer,
  ): Promise<SharePreviewDTO> {
    const category = await this.prisma.category.findUnique({
      where: { slug },
      include: { space: true, topicHub: true },
    });
    if (!category || !category.topicHub) {
      throw new NotFoundException('Topic hub not found');
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(category.space.accessPolicy)
    ) {
      throw new NotFoundException('Topic hub not found');
    }
    return {
      type: 'TOPIC_HUB',
      id: slug,
      title: category.topicHub.title,
      description: truncate(category.topicHub.summary, SUMMARY_MAX_LEN),
      image_url: null,
      deep_link: this.buildShareUrl('TOPIC_HUB', slug),
      web_url: this.buildShareUrl('TOPIC_HUB', slug),
    };
  }

  private async eventPreview(id: string): Promise<SharePreviewDTO> {
    // EventCard is global today — no space access policy.
    const event = await this.prisma.eventCard.findUnique({ where: { id } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    return {
      type: 'EVENT',
      id: event.id,
      title: event.title,
      description: `${event.venueName} · ${event.region}`,
      image_url: event.thumbnailUrl,
      deep_link: this.buildShareUrl('EVENT', event.id),
      web_url: this.buildShareUrl('EVENT', event.id),
    };
  }

  private async profilePreview(userId: string): Promise<SharePreviewDTO> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user || user.status !== 'ACTIVE' || !user.profile) {
      throw new NotFoundException('Profile not found');
    }
    return {
      type: 'PROFILE',
      id: user.id,
      title: user.profile.nickname,
      description: user.profile.bio
        ? truncate(user.profile.bio, SUMMARY_MAX_LEN)
        : 'PRISM Club 프로필',
      image_url: user.profile.avatarUrl,
      deep_link: this.buildShareUrl('PROFILE', user.id),
      web_url: this.buildShareUrl('PROFILE', user.id),
    };
  }

  private buildShareUrl(type: ShareTargetType, id: string): string {
    const base = (
      process.env.SHARE_BASE_URL ?? DEFAULT_SHARE_BASE_URL
    ).replace(/\/+$/, '');
    return `${base}/share/${type.toLowerCase()}/${encodeURIComponent(id)}`;
  }
}

function truncate(s: string, max: number): string {
  if (!s) return '';
  return s.length > max ? `${s.slice(0, max).trimEnd()}…` : s;
}
