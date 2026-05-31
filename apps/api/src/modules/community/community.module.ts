import { Module } from '@nestjs/common';
import { SpaceService } from './space.service';
import { CategoryService } from './category.service';
import { RoomService } from './room.service';
import { RoomRoleService } from './room-role.service';
import { SpaceController } from './space.controller';
import { RoomController } from './room.controller';
import { RoomRoleController } from './room-role.controller';

@Module({
  providers: [SpaceService, CategoryService, RoomService, RoomRoleService],
  controllers: [SpaceController, RoomController, RoomRoleController],
  exports: [SpaceService, CategoryService, RoomService, RoomRoleService],
})
export class CommunityModule {}
