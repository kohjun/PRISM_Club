import { Module } from '@nestjs/common';
import { SpaceService } from './space.service';
import { CategoryService } from './category.service';
import { RoomService } from './room.service';
import { SpaceController } from './space.controller';
import { RoomController } from './room.controller';

@Module({
  providers: [SpaceService, CategoryService, RoomService],
  controllers: [SpaceController, RoomController],
  exports: [SpaceService, CategoryService, RoomService],
})
export class CommunityModule {}
