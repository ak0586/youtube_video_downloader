// src/app.module.ts
import { Module } from '@nestjs/common';
import { YoutubeController } from './youtube/youtube.controller';
import { YoutubeService } from './youtube/youtube.service';

@Module({
  imports: [],
  controllers: [YoutubeController],
  providers: [YoutubeService],
})
export class AppModule {}