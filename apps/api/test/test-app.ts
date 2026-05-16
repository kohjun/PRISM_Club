import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/shared/prisma.service';
import { runSeed, U } from '../../../prisma/seed';

export interface TestContext {
  app: INestApplication;
  prisma: PrismaService;
  uuids: typeof U;
}

/**
 * Build a NestJS test app pointed at the test database.
 *
 * Callers should:
 *   const ctx = await bootstrapTestApp();
 *   ...
 *   await teardownTestApp(ctx);
 */
export async function bootstrapTestApp(): Promise<TestContext> {
  const moduleRef: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleRef.createNestApplication({ logger: false });
  app.setGlobalPrefix('v1');
  await app.init();

  const prisma = app.get(PrismaService);
  await runSeed(prisma);

  return { app, prisma, uuids: U };
}

export async function teardownTestApp(ctx: TestContext): Promise<void> {
  await ctx.app.close();
}

/** Convenience: create a fresh PrismaClient for direct DB inspection in tests. */
export function newClient(): PrismaClient {
  return new PrismaClient({
    datasources: { db: { url: process.env.DATABASE_URL } },
  });
}
