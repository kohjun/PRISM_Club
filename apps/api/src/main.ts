import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.setGlobalPrefix('v1');
  // M10: serve uploaded media files (dev/local storage). NOT a production CDN.
  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads/' });
  app.enableCors({
    // Loose during milestone 1 — Flutter web dev server, Android emulator
    // (10.0.2.2), and curl all need to reach us locally. Tighten in phase 2.
    origin: true,
    credentials: false,
    allowedHeaders: ['Content-Type', 'X-User-Id', 'X-Request-Id', 'Authorization'],
    exposedHeaders: ['X-Request-Id'],
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  const swaggerConfig = new DocumentBuilder()
    .setTitle('PRISM Club API')
    .setDescription('Milestone 1 — knowledge-based community vertical slice')
    .setVersion('0.1.0')
    .addApiKey({ type: 'apiKey', name: 'X-User-Id', in: 'header' }, 'X-User-Id')
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('v1/docs', app, document);

  const port = Number(process.env.API_PORT ?? 3000);
  await app.listen(port);

  // eslint-disable-next-line no-console
  console.log(`PRISM Club API listening on http://localhost:${port}/v1`);
}

void bootstrap();
