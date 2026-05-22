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
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { EventReviewService } from './event-review.service';

interface CreateReviewBody {
  rating?: number;
  body?: string;
}

interface PatchReviewBody {
  rating?: number;
  body?: string;
}

@Controller()
export class EventReviewController {
  constructor(private readonly svc: EventReviewService) {}

  @Post('event-cards/:id/reviews')
  @HttpCode(200)
  create(
    @Param('id') eventCardId: string,
    @Body() body: CreateReviewBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.createOrUpdate(eventCardId, user.id, {
      rating: body?.rating ?? 0,
      body: body?.body ?? '',
    });
  }

  @Get('event-cards/:id/reviews')
  list(
    @Param('id') eventCardId: string,
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listForEvent(eventCardId, user.id, {
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Patch('event-reviews/:id')
  @HttpCode(200)
  patch(
    @Param('id') reviewId: string,
    @Body() body: PatchReviewBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.patch(reviewId, user.id, body ?? {});
  }

  @Delete('event-reviews/:id')
  @HttpCode(200)
  remove(
    @Param('id') reviewId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.deleteByAuthor(reviewId, user.id);
  }
}
