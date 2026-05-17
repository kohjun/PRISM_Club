import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';

import { PrismaModule } from './shared/prisma.module';
import { AccessControlModule } from './shared/access-control.module';
import { AuthGuard } from './shared/guards/auth.guard';
import { RolesGuard } from './shared/guards/roles.guard';
import { AllExceptionsFilter } from './shared/filters/http-exception.filter';
import { RequestIdMiddleware } from './shared/middleware/request-id.middleware';

import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';
import { CommunityModule } from './modules/community/community.module';
import { KnowledgeModule } from './modules/knowledge/knowledge.module';
import { EventLinkModule } from './modules/event-link/event-link.module';
import { ReferenceModule } from './modules/reference/reference.module';
import { PostsModule } from './modules/posts/posts.module';
import { SearchModule } from './modules/search/search.module';
import { EventDetailModule } from './modules/event-detail/event-detail.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { FollowsModule } from './modules/follows/follows.module';
import { SavesModule } from './modules/saves/saves.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AccessControlModule,
    HealthModule,
    UsersModule,
    CommunityModule,
    KnowledgeModule,
    EventLinkModule,
    ReferenceModule,
    PostsModule,
    SearchModule,
    EventDetailModule,
    NotificationsModule,
    FollowsModule,
    SavesModule,
  ],
  providers: [
    // Order matters: AuthGuard runs first to populate req.user, RolesGuard
    // then enforces any @Roles() metadata.
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
