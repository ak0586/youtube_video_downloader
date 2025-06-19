// src/main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Enable CORS with full access (for dev)
  app.enableCors({
    origin: '*',
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Accept', 'Cache-Control'],
  });

  await app.listen(3000);
  console.log('YouTube Downloader API running on http://localhost:3000');
}
bootstrap();