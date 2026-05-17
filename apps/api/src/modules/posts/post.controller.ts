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
  attachment_type: z.enum(['EVENT_CARD', 'REFERENCE', 'IMAGE']),
  target_id: z.string().uuid(),
});

const recruitmentFieldsSchema = z.object({
  role: z.string().min(1).max(100),
  schedule: z.string().min(1).max(200),
  location: z.string().min(1).max(200),
  compensation: z.string().min(1).max(200),
  capacity: z.number().int().positive().max(999),
  application_method: z.string().min(1).max(500),
  status: z.enum(['OPEN', 'CLOSED', 'FILLED']).optional(),
});

const createPostSchema = z
  .object({
    body: z.string().min(1).max(8000),
    post_type: z.enum(['GENERAL', 'RECRUITMENT']).optional(),
    recruitment_fields: recruitmentFieldsSchema.optional(),
    attachments: z.array(attachmentSchema).max(10).optional(),
  })
  .refine(
    (v) => v.post_type !== 'RECRUITMENT' || v.recruitment_fields !== undefined,
    { message: 'recruitment_fields required when post_type=RECRUITMENT' },
  );

const updatePostSchema = z.object({
  body: z.string().min(1).max(8000),
});

const setStatusSchema = z.object({
  status: z.enum(['OPEN', 'CLOSED', 'FILLED']),
});

type CreatePostBody = z.infer<typeof createPostSchema>;
type UpdatePostBody = z.infer<typeof updatePostSchema>;
type SetStatusBody = z.infer<typeof setStatusSchema>;

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
    return this.posts.create(slug, body, user);
  }

  @Get('rooms/:slug/timeline')
  async timeline(
    @Param('slug') slug: string,
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? Number(limit) : undefined;
    return this.posts.listByRoomSlug(slug, user, cursor, parsedLimit);
  }

  @Get('posts/:id')
  async get(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.posts.getById(id, user);
  }

  @Patch('posts/:id')
  async update(
    @Param('id') id: string,
    @Body(new ZodValidationPipe(updatePostSchema)) body: UpdatePostBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.posts.update(id, body.body, user);
  }

  @Delete('posts/:id')
  @HttpCode(204)
  async delete(@Param('id') id: string, @CurrentUser() user: RequestUser): Promise<void> {
    await this.posts.softDelete(id, user);
  }

  @Post('posts/:id/recruitment-status')
  async setRecruitmentStatus(
    @Param('id') id: string,
    @Body(new ZodValidationPipe(setStatusSchema)) body: SetStatusBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.posts.setRecruitmentStatus(id, body.status, user);
  }
}
