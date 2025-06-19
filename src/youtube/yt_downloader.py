# yt_downloader.py (Clean Version)
import yt_dlp
import os
import sys
import json
import time
from pathlib import Path

def get_video_info(url):
    ydl_opts = {
        'quiet': True,
        'skip_download': True,
        'forcejson': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        return ydl.extract_info(url, download=False)

def list_resolutions(url):
    try:
        info = get_video_info(url)
        formats = info.get('formats', [])
        resolutions = []
        for f in formats:
            if f['vcodec'] != 'none' and f.get('height'):
                resolutions.append({
                    'itag': f['format_id'],
                    'resolution': f['height'],
                    'ext': f['ext']
                })
        print(json.dumps(resolutions), flush=True)
    except Exception as e:
        print(json.dumps({'error': str(e)}), flush=True)

def download_video(url, resolution):
    home_path = str(Path.home())
    output_path = os.path.join(home_path, 'Downloads')
    
    # Create Downloads directory if it doesn't exist
    try:
        os.makedirs(output_path, exist_ok=True)
    except Exception as e:
        print(json.dumps({'error': f'Failed to create directory: {str(e)}'}), flush=True)
        return
    
    # Get list of existing files before download
    existing_files = set(os.listdir(output_path)) if os.path.exists(output_path) else set()
    
    # More robust format selector - try multiple fallback options
    format_selector = f'bestvideo[height<={resolution}][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<={resolution}]+bestaudio/best[height<={resolution}][ext=mp4]/best[height<={resolution}]/best'
    
    ydl_opts = {
        'format': format_selector,
        'outtmpl': os.path.join(output_path, '%(title)s.%(ext)s'),
        'merge_output_format': 'mp4',
        'quiet': True,
        'no_warnings': False,  # Show warnings to help debug
        'progress_hooks': [progress_hook],
        'writeinfojson': False,
        'writethumbnail': False,
        'writesubtitles': False,
        'writeautomaticsub': False,
        'prefer_ffmpeg': True,  # Prefer ffmpeg for merging
        'keepvideo': False,  # Don't keep separate video/audio files after merging
        'nopostoverwrites': False,
        'postprocessors': [],
        'no_mtime': True,  # Don't preserve original file modification time
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        
        # Get list of files after download and find newly downloaded files
        current_files = set(os.listdir(output_path))
        new_files = current_files - existing_files
        
        # Manually set current timestamp only for newly downloaded files
        current_time = time.time()
        for filename in new_files:
            if filename.endswith(('.mp4', '.mkv', '.webm', '.avi')):
                file_path = os.path.join(output_path, filename)
                # Set both access time and modification time to current time
                os.utime(file_path, (current_time, current_time))
        
        print(json.dumps({'progress': 100, 'status': 'completed'}), flush=True)
        
    except Exception as e:
        print(json.dumps({'error': str(e), 'progress': -1}), flush=True)
        sys.exit(1)

def progress_hook(d):
    try:
        if d['status'] == 'downloading':
            # Handle different percentage formats
            percent_str = d.get('_percent_str', '0%').replace('%', '').strip()
            if percent_str and percent_str != 'N/A':
                try:
                    percent = float(percent_str)
                    print(json.dumps({'progress': percent}), flush=True)
                except ValueError:
                    # Calculate from downloaded/total if percentage parsing fails
                    downloaded = d.get('downloaded_bytes', 0)
                    total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
                    if total > 0:
                        percent = (downloaded / total) * 100
                        print(json.dumps({'progress': percent}), flush=True)
                        
        elif d['status'] == 'finished':
            filename = d.get('filename', 'Unknown file')
            print(json.dumps({
                'progress': 100, 
                'status': 'finished',
                'filename': filename
            }), flush=True)
            
    except Exception as e:
        print(json.dumps({'error': f'Progress hook error: {str(e)}'}), flush=True)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'Insufficient arguments'}), flush=True)
        sys.exit(1)

    command = sys.argv[1]
    url = sys.argv[2]

    if command == 'list':
        list_resolutions(url)
    elif command == 'download':
        if len(sys.argv) < 4:
            print(json.dumps({'error': 'Missing resolution for download'}), flush=True)
            sys.exit(1)
        resolution = sys.argv[3]
        download_video(url, resolution)