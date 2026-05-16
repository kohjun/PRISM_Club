import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { ReplyService } from './reply.service';

const createReplySchema = z.object({
  body: z.string().min(1).max(4000),
  parent_reply_id: z.string().uuid().optional(),
});

type CreateReplyBody = z.infer<typeof createReplySchema>;

@Controller()
export class ReplyController {
  constructor(private readonly replies: ReplyService) {}

  @Post('posts/:id/replies')
  @HttpCode(201)
  async create(
    @Param('id') postId: string,
    @Body(new ZodValidationPipe(createReplySchema)) body: CreateReplyBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.replies.create(postId, body, user);
  }

  @Get('posts/:id/replies')
  async list(@Param('id') postId: string, @CurrentUser() user: RequestUser) {
    return { items: await this.replies.listByPost(postId, user) };
  }
}
