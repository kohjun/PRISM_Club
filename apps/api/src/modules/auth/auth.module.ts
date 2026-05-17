import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';

@Global()
@Module({
  imports: [PrismaModule],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService],
})
export class AuthModule {}
