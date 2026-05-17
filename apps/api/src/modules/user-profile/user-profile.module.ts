import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { PostsModule } from '../posts/posts.module';
import { UserProfileService } from './user-profile.service';
import { UserFollowService } from './user-follow.service';
import { UserProfileController } from './user-profile.controller';
import { UserFollowController } from './user-follow.controller';

@Module({
  imports: [PrismaModule, AccessControlModule, PostsModule],
  controllers: [UserProfileController, UserFollowController],
  providers: [UserProfileService, UserFollowService],
})
export class UserProfileModule {}
