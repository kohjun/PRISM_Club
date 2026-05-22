import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

const VALID_TIERS = new Set(['OFFICIAL', 'TRUSTED', 'COMMUNITY', 'UNKNOWN']);
const TIER_PRIORITY: Record<string, number> = {
  OFFICIAL: 0,
  TRUSTED: 1,
  COMMUNITY: 2,
  UNKNOWN: 3,
};

export interface SourceRuleDTO {
  id: string;
  domain_pattern: string;
  tier: string;
  note: string | null;
  created_by: string | null;
  created_at: string;
}

interface CreateRuleInput {
  domain_pattern: string;
  tier: string;
  note?: string | null;
}

interface PatchRuleInput {
  tier?: string;
  note?: string | null;
}

/**
 * P2.3 reference source-rule registry. Drives the trust tier shown on
 * every Reference card. New references run through `classifyUrl()`
 * during create; admins can re-tier individual rows via the ops
 * controller after changing a rule.
 *
 * Rules are evaluated by tier priority (OFFICIAL > TRUSTED > COMMUNITY)
 * so a domain matched by both an OFFICIAL pattern and a broader
 * COMMUNITY one resolves to OFFICIAL. Within a tier, the longest
 * pattern wins so `*.tving.com` doesn't shadow a more specific
 * `subdomain.tving.com` rule.
 */
@Injectable()
export class SourceRulesService {
  constructor(private readonly prisma: PrismaService) {}

  async classifyUrl(url: string): Promise<string> {
    const host = this.extractHost(url);
    if (!host) return 'UNKNOWN';
    const rules = await this.prisma.referenceSourceRule.findMany();
    if (rules.length === 0) return 'UNKNOWN';

    const matched = rules.filter((r) => this.matchDomain(host, r.domainPattern));
    if (matched.length === 0) return 'UNKNOWN';

    matched.sort((a, b) => {
      const pa = TIER_PRIORITY[a.tier] ?? 99;
      const pb = TIER_PRIORITY[b.tier] ?? 99;
      if (pa !== pb) return pa - pb;
      // Within the same tier, prefer more specific (longer) patterns.
      return b.domainPattern.length - a.domainPattern.length;
    });
    return matched[0].tier;
  }

  async listRules(): Promise<SourceRuleDTO[]> {
    const rows = await this.prisma.referenceSourceRule.findMany({
      orderBy: [{ tier: 'asc' }, { domainPattern: 'asc' }],
    });
    return rows.map(this.toDTO);
  }

  async createRule(
    input: CreateRuleInput,
    actorId: string,
  ): Promise<SourceRuleDTO> {
    this.assertTier(input.tier);
    const pattern = input.domain_pattern.trim().toLowerCase();
    if (!pattern || pattern.length > 255) {
      throw new BadRequestException('Invalid domain_pattern');
    }
    const row = await this.prisma.referenceSourceRule.create({
      data: {
        domainPattern: pattern,
        tier: input.tier,
        note: input.note ?? null,
        createdBy: actorId,
      },
    });
    return this.toDTO(row);
  }

  async patchRule(
    id: string,
    input: PatchRuleInput,
  ): Promise<SourceRuleDTO> {
    const data: { tier?: string; note?: string | null } = {};
    if (input.tier !== undefined) {
      this.assertTier(input.tier);
      data.tier = input.tier;
    }
    if (input.note !== undefined) data.note = input.note ?? null;

    try {
      const row = await this.prisma.referenceSourceRule.update({
        where: { id },
        data,
      });
      return this.toDTO(row);
    } catch {
      throw new NotFoundException(`Rule not found: ${id}`);
    }
  }

  async deleteRule(id: string): Promise<{ ok: boolean }> {
    try {
      await this.prisma.referenceSourceRule.delete({ where: { id } });
      return { ok: true };
    } catch {
      throw new NotFoundException(`Rule not found: ${id}`);
    }
  }

  /** Retier a single reference row by re-running classifyUrl. */
  async retierReference(
    referenceId: string,
  ): Promise<{ id: string; source_tier: string }> {
    const ref = await this.prisma.reference.findUnique({
      where: { id: referenceId },
    });
    if (!ref) throw new NotFoundException(`Reference not found: ${referenceId}`);
    const tier = await this.classifyUrl(ref.url);
    await this.prisma.reference.update({
      where: { id: referenceId },
      data: { sourceTier: tier },
    });
    return { id: referenceId, source_tier: tier };
  }

  /** Retier every reference row. Bounded by the size of the table. */
  async retierAll(): Promise<{ scanned: number; updated: number }> {
    const rows = await this.prisma.reference.findMany({
      select: { id: true, url: true, sourceTier: true },
    });
    let updated = 0;
    for (const r of rows) {
      const tier = await this.classifyUrl(r.url);
      if (tier !== r.sourceTier) {
        await this.prisma.reference.update({
          where: { id: r.id },
          data: { sourceTier: tier },
        });
        updated += 1;
      }
    }
    return { scanned: rows.length, updated };
  }

  private extractHost(url: string): string | null {
    try {
      const u = new URL(url);
      return u.hostname.toLowerCase();
    } catch {
      return null;
    }
  }

  private matchDomain(host: string, pattern: string): boolean {
    const p = pattern.toLowerCase();
    if (p.startsWith('*.')) {
      const suffix = p.slice(1); // ".youtube.com"
      return host.endsWith(suffix);
    }
    return host === p;
  }

  private assertTier(tier: string): void {
    if (!VALID_TIERS.has(tier)) {
      throw new BadRequestException(
        `tier must be one of ${[...VALID_TIERS].join(', ')}`,
      );
    }
  }

  private toDTO = (row: {
    id: string;
    domainPattern: string;
    tier: string;
    note: string | null;
    createdBy: string | null;
    createdAt: Date;
  }): SourceRuleDTO => ({
    id: row.id,
    domain_pattern: row.domainPattern,
    tier: row.tier,
    note: row.note,
    created_by: row.createdBy,
    created_at: row.createdAt.toISOString(),
  });
}
