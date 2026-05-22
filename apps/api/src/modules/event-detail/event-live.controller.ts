import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
} from '@nestjs/common';
import { z } from 'zod';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { EventLiveService } from './event-live.service';

const createLiveSchema = z.object({
  body: z.string().min(1).max(500),
  image_media_id: z.string().uuid().optional().nullable(),
});

type CreateLiveBody = z.infer<typeof createLiveSchema>;

@Controller()
export class EventLiveController {
  constructor(private readonly live: EventLiveService) {}

  @Post('event-cards/:cardId/live')
  @HttpCode(201)
  async create(
    @Param('cardId') cardId: string,
    @Body(new ZodValidationPipe(createLiveSchema)) body: CreateLiveBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.live.createLivePost(
      cardId,
      body.body,
      user.id,
      body.image_media_id ?? null,
    );
  }

  @Get('event-cards/:cardId/live')
  async list(
    @Param('cardId') cardId: string,
    @CurrentUser() user: RequestUser,
  ) {
    const items = await this.live.listLivePosts(cardId, user.id);
    return { items };
  }
}
