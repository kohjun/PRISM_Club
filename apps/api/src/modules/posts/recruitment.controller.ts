import {
  BadRequestException,
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
import { RecruitmentService } from './recruitment.service';

interface ApplyBody {
  message?: string | null;
}

interface DecideBody {
  decision?: string;
}

@Controller()
export class RecruitmentController {
  constructor(private readonly svc: RecruitmentService) {}

  @Post('posts/:id/apply')
  @HttpCode(200)
  apply(
    @Param('id') postId: string,
    @Body() body: ApplyBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.apply(postId, user, body?.message ?? null);
  }

  @Delete('posts/:id/apply')
  @HttpCode(200)
  withdraw(
    @Param('id') postId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.withdraw(postId, user);
  }

  @Get('posts/:id/applications')
  listApplications(
    @Param('id') postId: string,
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listApplications(postId, user, {
      status,
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Patch('applications/:id')
  @HttpCode(200)
  decide(
    @Param('id') applicationId: string,
    @Body() body: DecideBody,
    @CurrentUser() user: RequestUser,
  ) {
    const decisionRaw = (body?.decision ?? '').toUpperCase();
    if (decisionRaw !== 'ACCEPT' && decisionRaw !== 'REJECT') {
      throw new BadRequestException("decision must be 'ACCEPT' or 'REJECT'");
    }
    return this.svc.decide(applicationId, decisionRaw as 'ACCEPT' | 'REJECT', user);
  }

  @Get('me/applications')
  listMine(
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listMine(user.id, {
      status,
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }
}
