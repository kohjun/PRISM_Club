import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { SaveCollectionService } from './save-collection.service';

interface CreateBody {
  name?: string;
}

interface PatchBody {
  name?: string;
  sort_order?: number;
}

interface MoveBody {
  collection_id?: string | null;
}

@Controller()
export class SaveCollectionController {
  constructor(private readonly svc: SaveCollectionService) {}

  @Get('me/collections')
  list(@CurrentUser() user: RequestUser) {
    return this.svc.listForUser(user.id);
  }

  @Post('me/collections')
  @HttpCode(200)
  create(@Body() body: CreateBody, @CurrentUser() user: RequestUser) {
    return this.svc.create(user.id, body?.name ?? '');
  }

  @Patch('me/collections/:id')
  @HttpCode(200)
  patch(
    @Param('id') id: string,
    @Body() body: PatchBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.patch(user.id, id, {
      name: body?.name,
      sort_order: body?.sort_order,
    });
  }

  @Delete('me/collections/:id')
  @HttpCode(200)
  remove(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.svc.delete(user.id, id);
  }

  @Post('me/saves/:saveId/move')
  @HttpCode(200)
  move(
    @Param('saveId') saveId: string,
    @Body() body: MoveBody,
    @CurrentUser() user: RequestUser,
  ) {
    const collectionId =
      body?.collection_id === undefined ? null : body.collection_id;
    return this.svc.moveSave(user.id, saveId, collectionId);
  }
}
