# 📥 YouTube Video Downloader

A full-stack YouTube video downloader built with **Flutter** (frontend), **NestJS** (backend), and **Python** (downloader engine). Supports format selection, real-time download progress updates via **Server-Sent Events (SSE)**, and seamless integration between UI and backend logic.

---

## 🚀 Features

- 🔍 Fetch available video resolutions and formats using `yt-dlp`
- 📲 Clean and responsive Flutter UI
- 🎯 Select desired resolution before downloading
- 📡 Real-time download progress streaming using **SSE**
- 🧠 Backend orchestrated in **NestJS**, integrated with Python scripts
- 🛠️ Cross-platform support (Android/Web/Desktop with Flutter)

---

## 🧱 Tech Stack

| Layer        | Technology                         |
|--------------|-------------------------------------|
| Frontend     | Flutter, Dart                      |
| Backend API  | NestJS (TypeScript), Express       |
| Video Engine | Python with `yt-dlp`, `ffmpeg`     |
| Streaming    | SSE (Server-Sent Events)           |
| UI Toolkit   | Material Components for Flutter    |

---

## 🖥️ Architecture

Flutter UI ─────> NestJS Backend ─────> Python yt-dlp Script
▲ │ │
└───── SSE <──────┴──── Emit Real-time Progress

yaml
Copy code

---

## 🧪 Local Setup

### 1. Clone the repo
```bash
git clone https://github.com/your-username/youtube-downloader.git
cd youtube-downloader
```

### 2. Backend Setup (NestJS)
```
bash
Copy code
cd backend
npm install
npm run start
```
Ensure Python 3 is installed with yt-dlp and ffmpeg available in your system PATH.

### 3. Frontend Setup (Flutter)
```bash
Copy code
cd ../frontend
flutter pub get
flutter run
```
Modify the base URL in Flutter if needed (http://127.0.0.1:3000) to match your backend.

### 🧠 How It Works
User enters a YouTube URL.

App fetches available video resolutions via the NestJS API (/youtube/resolutions).

After selecting a format, the frontend:

Connects to /youtube/progress SSE endpoint

Triggers a POST request to /youtube/download

Python script handles download via yt-dlp, emits JSON progress, and NestJS pushes updates through SSE.

Frontend displays progress bar in real time.

### 📌 Future Improvements
✅ Playlist support

📁 File save location picker in Flutter

🔐 Auth & rate limiting for API

☁️ Cloud deployment with persistent file storage


👨‍💻 Author
Ankit
🔗 www.linkedin.com/in/ankit59
💼 [Portfolio coming soon]


"A seamless fusion of UI, real-time communication, and video processing."
— Built with love for devs who like speed, control, and clean code.
