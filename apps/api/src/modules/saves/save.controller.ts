import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { SaveService, ToggleSaveInput } from './save.service';

@Controller()
export class SaveController {
  constructor(private readonly svc: SaveService) {}

  @Post('me/saves')
  @HttpCode(200)
  toggle(@Body() body: ToggleSaveInput, @CurrentUser() user: RequestUser) {
    return this.svc.toggle(body, user);
  }

  @Get('me/saves')
  list(@CurrentUser() user: RequestUser, @Query('type') type?: string) {
    return this.svc.listForUser(user, type);
  }
}
