import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { join, isAbsolute } from 'path';
import { AppModule } from './app.module';

function resolveCorsOrigin(): boolean | string[] {
  const env = process.env.CORS_ORIGINS;
  if (!env || env.trim() === '' || env === '*') {
    // Dev default: allow any. Production deployments MUST set CORS_ORIGINS.
    return true;
  }
  return env.split(',').map((s) => s.trim()).filter(Boolean);
}

function resolveUploadsDir(): string {
  const env = process.env.UPLOADS_DIR;
  if (!env || env.trim() === '') {
    return join(process.cwd(), 'uploads');
  }
  return isAbsolute(env) ? env : join(process.cwd(), env);
}

/**
 * Fail fast on a production deploy missing critical security config,
 * rather than booting with insecure dev defaults: a public JWT secret
 * would let anyone forge an admin token, and an open CORS origin
 * reflects any site. No-op outside production.
 */
function assertProductionConfig(): void {
  if (process.env.NODE_ENV !== 'production') return;
  const problems: string[] = [];
  const secret = process.env.JWT_SECRET;
  if (
    !secret ||
    secret.length < 32 ||
    secret === 'prism-club-dev-secret-do-not-use-in-prod'
  ) {
    problems.push(
      'JWT_SECRET must be set to a strong (32+ char) value — not the dev fallback',
    );
  }
  const cors = (process.env.CORS_ORIGINS ?? '').trim();
  if (cors === '' || cors === '*') {
    problems.push(
      'CORS_ORIGINS must be an explicit allow-list (not empty or "*")',
    );
  }
  if (problems.length > 0) {
    throw new Error(
      `Refusing to boot in production with unsafe config:\n  - ${problems.join('\n  - ')}`,
    );
  }
}

async function bootstrap(): Promise<void> {
  assertProductionConfig();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.setGlobalPrefix('v1');

  // M10: serve uploaded media files. Local dev only; production should
  // proxy /uploads/* to an object store.
  app.useStaticAssets(resolveUploadsDir(), { prefix: '/uploads/' });

  app.enableCors({
    // Configurable via CORS_ORIGINS env (comma-separated). Defaults to
    // `*` in dev so the Flutter web dev server, Android emulator
    // (10.0.2.2), and curl all work locally.
    origin: resolveCorsOrigin(),
    credentials: false,
    allowedHeaders: [
      'Content-Type',
      'X-User-Id',
      'X-Request-Id',
      'Authorization',
    ],
    exposedHeaders: ['X-Request-Id'],
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  const swaggerConfig = new DocumentBuilder()
    .setTitle('PRISM Club API')
    .setDescription('PRISM Club — knowledge-based community API (M1–M13)')
    .setVersion('0.1.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'BearerAuth',
    )
    .addApiKey(
      { type: 'apiKey', name: 'X-User-Id', in: 'header' },
      'X-User-Id',
    )
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('v1/docs', app, document);

  const port = Number(process.env.API_PORT ?? 3000);
  await app.listen(port);

  new Logger('Bootstrap').log(
    `PRISM Club API listening on http://localhost:${port}/v1`,
  );
}

void bootstrap();
