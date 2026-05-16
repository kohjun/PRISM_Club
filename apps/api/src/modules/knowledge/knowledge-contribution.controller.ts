import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { ContributionStatus } from './dto/contribution.dto';

const submitSchema = z.object({
  target_block_id: z.string().uuid().optional().nullable(),
  proposed_block_type: z.string().min(1),
  proposed_title: z.string().min(1).max(200),
  proposed_body: z.string().min(1).max(8000),
  evidence_type: z.enum(['EVENT_CARD', 'REFERENCE']).optional().nullable(),
  evidence_target_id: z.string().uuid().optional().nullable(),
});

const VALID_STATUSES: ContributionStatus[] = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'NEEDS_CHANGES',
  'WITHDRAWN',
];

type SubmitBody = z.infer<typeof submitSchema>;

@Controller()
export class KnowledgeContributionController {
  constructor(private readonly contributions: KnowledgeContributionService) {}

  @Post('categories/:slug/knowledge-contributions')
  @HttpCode(201)
  async submit(
    @Param('slug') slug: string,
    @Body(new ZodValidationPipe(submitSchema)) body: SubmitBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.contributions.submit(slug, body, user);
  }

  @Get('me/contributions')
  async listMine(
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
  ) {
    const filter = status && VALID_STATUSES.includes(status as ContributionStatus)
      ? (status as ContributionStatus)
      : undefined;
    return { items: await this.contributions.listMine(user.id, filter) };
  }

  @Delete('knowledge-contributions/:id')
  @HttpCode(204)
  async withdraw(@Param('id') id: string, @CurrentUser() user: RequestUser): Promise<void> {
    await this.contributions.withdraw(id, user.id);
  }
}
