// src/youtube/youtube.service.ts
import { Injectable } from '@nestjs/common';
import { spawn } from 'child_process';
import { Subject, Observable } from 'rxjs';
import { MessageEvent } from '@nestjs/common';

@Injectable()
export class YoutubeService {
  private progressSubject = new Subject<MessageEvent>();

  getAvailableResolutions(url: string): Promise<any> {
    return new Promise((resolve, reject) => {
      const py = spawn('python', ['src/youtube/yt_downloader.py', 'list', url]);

      let output = '';
      let errorOutput = '';

      py.stdout.on('data', (data) => output += data);
      py.stderr.on('data', (err) => errorOutput += err.toString());

      py.on('close', (code) => {
        if (errorOutput) console.error('PY STDERR:', errorOutput);
        if (code !== 0) {
          reject(new Error(`Python script failed with code ${code}: ${errorOutput}`));
          return;
        }
        try {
          const parsed = JSON.parse(output);
          resolve(parsed);
        } catch (err) {
          console.error('JSON parse error:', err);
          console.error('Raw output:', output);
          reject(new Error('Failed to parse Python output'));
        }
      });

      py.on('error', (error) => {
        console.error('Failed to start Python process:', error);
        reject(error);
      });
    });
  }

  downloadVideo(url: string, resolution: number): Promise<any> {
    return new Promise((resolve, reject) => {
      console.log(`Starting download for ${url} at ${resolution}p`);
      
      // Create a new progress subject for each download
      this.progressSubject = new Subject<MessageEvent>();
      
      const py = spawn('python', ['-u', 'src/youtube/yt_downloader.py', 'download', url, resolution.toString()]);

      let errorOutput = '';
      let hasCompleted = false;

      py.stdout.on('data', (data) => {
        const output = data.toString();
        console.log('[PY OUTPUT]', output.trim()); 
        
        // Split by lines and process each line
        const lines = output.split('\n');
        for (const line of lines) {
          const trimmedLine = line.trim();
          if (!trimmedLine) continue;
          
          try {
            const parsed = JSON.parse(trimmedLine);
            console.log('[Parsed Progress]', parsed);
            
            if (parsed.progress !== undefined) {
              const event: MessageEvent = {
                data: JSON.stringify(parsed),
              } as MessageEvent;
              this.progressSubject.next(event);
              console.log('[Progress Event Sent]', parsed.progress);
            }
            
            if (parsed.status === 'completed' || parsed.status === 'finished') {
              hasCompleted = true;
            }
          } catch (e) {
            // Not JSON, might be regular log output
            console.log('[Non-JSON Output]', trimmedLine);
          }
        }
      });

      py.stderr.on('data', (err) => {
        errorOutput += err.toString();
        console.error('[PY STDERR]', err.toString());
      });

      py.on('close', (code) => {
        console.log('Python script exited with code:', code);
        
        if (!hasCompleted) {
          // Send final completion event if not already sent
          const finalEvent: MessageEvent = {
            data: JSON.stringify({ progress: 100, status: 'completed' }),
          } as MessageEvent;
          this.progressSubject.next(finalEvent);
          console.log('[Final Progress Event Sent]');
        }
        
        // Complete the subject after a small delay
        setTimeout(() => {
          this.progressSubject.complete();
          console.log('[Progress Subject Completed]');
        }, 500);
        
        if (code === 0) {
          resolve({ message: 'Download complete' });
        } else {
          const errorMsg = `Download failed with code ${code}: ${errorOutput}`;
          console.error(errorMsg);
          
          // Send error event
          const errorEvent: MessageEvent = {
            data: JSON.stringify({ error: errorMsg, progress: -1 }),
          } as MessageEvent;
          this.progressSubject.next(errorEvent);
          
          reject(new Error(errorMsg));
        }
      });

      py.on('error', (error) => {
        console.error('Failed to start Python process:', error);
        
        // Send error event
        const errorEvent: MessageEvent = {
          data: JSON.stringify({ error: error.message, progress: -1 }),
        } as MessageEvent;
        this.progressSubject.next(errorEvent);
        
        reject(error);
      });
    });
  }

  getProgressStream(): Observable<MessageEvent> {
    console.log('[SSE] New client connected to progress stream');
    return this.progressSubject.asObservable();
  }
}