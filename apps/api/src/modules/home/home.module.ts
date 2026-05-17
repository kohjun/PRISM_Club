import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PostsModule } from '../posts/posts.module';
import { HomeService } from './home.service';
import { HomeController } from './home.controller';

@Module({
  imports: [PrismaModule, AccessControlModule, NotificationsModule, PostsModule],
  controllers: [HomeController],
  providers: [HomeService],
})
export class HomeModule {}
