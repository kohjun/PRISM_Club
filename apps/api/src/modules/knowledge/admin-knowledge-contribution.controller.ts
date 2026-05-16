import { Body, Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { Roles } from '../../shared/decorators/roles.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { ContributionStatus } from './dto/contribution.dto';

const resolveSchema = z.object({
  decision: z.enum(['APPROVE', 'REJECT', 'REQUEST_CHANGES']),
  note: z.string().max(2000).optional(),
});

type ResolveBody = z.infer<typeof resolveSchema>;

const VALID_STATUSES: ContributionStatus[] = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'NEEDS_CHANGES',
  'WITHDRAWN',
];

@Controller('admin/knowledge-contributions')
@Roles('CURATOR', 'ADMIN')
export class AdminKnowledgeContributionController {
  constructor(private readonly contributions: KnowledgeContributionService) {}

  @Get()
  async list(
    @Query('status') status?: string,
    @Query('categorySlug') categorySlug?: string,
  ) {
    const filter = status && VALID_STATUSES.includes(status as ContributionStatus)
      ? (status as ContributionStatus)
      : 'PENDING'; // default for the curator queue
    return { items: await this.contributions.listForAdmin(filter, categorySlug) };
  }

  @Get(':id')
  async getDetail(@Param('id') id: string) {
    return this.contributions.getDetail(id);
  }

  @Post(':id/resolve')
  @HttpCode(201)
  async resolve(
    @Param('id') id: string,
    @Body(new ZodValidationPipe(resolveSchema)) body: ResolveBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.contributions.resolve(id, body, user.id);
  }
}
