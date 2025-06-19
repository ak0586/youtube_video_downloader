// src/youtube/youtube.controller.ts
import { Controller, Get, Post, Query, Body, Sse, MessageEvent, Res, Headers } from '@nestjs/common';
import { YoutubeService } from './youtube.service';
import { Observable } from 'rxjs';
import { Response } from 'express';

@Controller('youtube')
export class YoutubeController {
  constructor(private readonly ytService: YoutubeService) {}

  @Get('resolutions')
  getResolutions(@Query('url') url: string) {
    return this.ytService.getAvailableResolutions(url);
  }

  @Post('download')
  async downloadVideo(@Body() body: { url: string; resolution: number }) {
    return await this.ytService.downloadVideo(body.url, body.resolution);
  }

  @Sse('progress')
  downloadProgress(@Res() res: Response): Observable<MessageEvent> {
    // Set proper SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Cache-Control');

    return this.ytService.getProgressStream();
  }
}
