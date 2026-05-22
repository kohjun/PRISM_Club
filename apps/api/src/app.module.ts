import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';

import { PrismaModule } from './shared/prisma.module';
import { AccessControlModule } from './shared/access-control.module';
import { AuthGuard } from './shared/guards/auth.guard';
import { RolesGuard } from './shared/guards/roles.guard';
import { AllExceptionsFilter } from './shared/filters/http-exception.filter';
import { RequestIdMiddleware } from './shared/middleware/request-id.middleware';

import { AuthModule } from './modules/auth/auth.module';
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
import { HomeModule } from './modules/home/home.module';
import { UserProfileModule } from './modules/user-profile/user-profile.module';
import { ModerationModule } from './modules/moderation/moderation.module';
import { MediaModule } from './modules/media/media.module';
import { OpsModule } from './modules/ops/ops.module';
import { SignalsModule } from './modules/signals/signals.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { ShareModule } from './modules/share/share.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // P3.2: in-process cron host. Production deployments must either
    // pin scheduling to a single API instance OR rely on the
    // advisory-lock guard inside each @Cron handler to prevent
    // duplicate fan-out across replicas.
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
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
    HomeModule,
    UserProfileModule,
    ModerationModule,
    MediaModule,
    OpsModule,
    SignalsModule,
    AnalyticsModule,
    ShareModule,
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
