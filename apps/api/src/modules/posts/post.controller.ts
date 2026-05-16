import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { PostService } from './post.service';

const attachmentSchema = z.object({
  attachment_type: z.enum(['EVENT_CARD', 'REFERENCE']),
  target_id: z.string().uuid(),
});

const createPostSchema = z.object({
  body: z.string().min(1).max(8000),
  attachments: z.array(attachmentSchema).max(10).optional(),
});

const updatePostSchema = z.object({
  body: z.string().min(1).max(8000),
});

type CreatePostBody = z.infer<typeof createPostSchema>;
type UpdatePostBody = z.infer<typeof updatePostSchema>;

@Controller()
export class PostController {
  constructor(private readonly posts: PostService) {}

  @Post('rooms/:slug/posts')
  @HttpCode(201)
  async create(
    @Param('slug') slug: string,
    @Body(new ZodValidationPipe(createPostSchema)) body: CreatePostBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.posts.create(slug, body, user.id);
  }

  @Get('rooms/:slug/timeline')
  async timeline(
    @Param('slug') slug: string,
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? Number(limit) : undefined;
    return this.posts.listByRoomSlug(slug, user.id, cursor, parsedLimit);
  }

  @Get('posts/:id')
  async get(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.posts.getById(id, user.id);
  }

  @Patch('posts/:id')
  async update(
    @Param('id') id: string,
    @Body(new ZodValidationPipe(updatePostSchema)) body: UpdatePostBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.posts.update(id, body.body, user.id);
  }

  @Delete('posts/:id')
  @HttpCode(204)
  async delete(@Param('id') id: string, @CurrentUser() user: RequestUser): Promise<void> {
    await this.posts.softDelete(id, user.id);
  }
}
