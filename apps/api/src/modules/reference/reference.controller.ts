import { Body, Controller, Get, HttpCode, Post, Query, BadRequestException } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { ReferenceService } from './reference.service';

const createSchema = z.object({
  url: z.string().url().max(2048),
  title: z.string().min(1).max(200),
  type: z.string().min(1),
  source_name: z.string().max(200).optional(),
  thumbnail_url: z.string().url().max(2048).optional(),
  summary: z.string().max(2000).optional(),
});

type CreateBody = z.infer<typeof createSchema>;

@Controller('references')
export class ReferenceController {
  constructor(private readonly references: ReferenceService) {}

  @Post()
  @HttpCode(201)
  async create(
    @Body(new ZodValidationPipe(createSchema)) body: CreateBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.references.create(body, user.id);
  }

  @Get()
  async listByIds(@Query('ids') ids?: string) {
    if (!ids) {
      throw new BadRequestException('ids query param is required');
    }
    const parts = ids
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    return { items: await this.references.findByIds(parts) };
  }
}
