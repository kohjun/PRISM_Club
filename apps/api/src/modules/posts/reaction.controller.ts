import { Body, Controller, Post } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { ReactionService } from './reaction.service';

const toggleSchema = z.object({
  target_type: z.enum(['POST', 'REPLY']),
  target_id: z.string().uuid(),
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
    return this.reactions.toggleLike(user.id, body.target_type, body.target_id);
  }
}
