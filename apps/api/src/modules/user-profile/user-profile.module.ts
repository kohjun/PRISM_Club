import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { PostsModule } from '../posts/posts.module';
import { KnowledgeModule } from '../knowledge/knowledge.module';
import { UserProfileService } from './user-profile.service';
import { UserFollowService } from './user-follow.service';
import { UserProfileController } from './user-profile.controller';
import { UserFollowController } from './user-follow.controller';
import { ProfileShareService } from './profile-share.service';
import { ProfileShareController } from './profile-share.controller';

@Module({
  imports: [PrismaModule, AccessControlModule, PostsModule, KnowledgeModule],
  controllers: [
    UserProfileController,
    UserFollowController,
    ProfileShareController,
  ],
  providers: [UserProfileService, UserFollowService, ProfileShareService],
})
export class UserProfileModule {}
