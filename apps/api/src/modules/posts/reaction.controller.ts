import { Body, Controller, Post } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { REACTION_TYPES, ReactionService } from './reaction.service';

const toggleSchema = z.object({
  target_type: z.enum(['POST', 'REPLY']),
  target_id: z.string().uuid(),
  // P6.4: clients send the emoji they want. Defaults to HEART so the
  // legacy "tap heart" flow keeps working when the mobile rollout is
  // staged behind a feature flag.
  reaction_type: z.enum(REACTION_TYPES).optional().default('HEART'),
});

type ToggleBody = z.infer<typeof toggleSchema>;

@Controller('reactions')
export class ReactionController {
  constructor(private readonly reactions: ReactionService) {}

  @Post('toggle')
  async toggle(
    @Body(new ZodValidationPipe(toggleSchema)) body: ToggleBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.reactions.toggle(
      user,
      body.target_type,
      body.target_id,
      body.reaction_type,
    );
  }
}
