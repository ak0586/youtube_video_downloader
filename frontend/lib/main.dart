import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const YoutubeDownloaderApp());
}

class YoutubeDownloaderApp extends StatelessWidget {
  const YoutubeDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Downloader',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const DownloaderHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DownloaderHomePage extends StatefulWidget {
  const DownloaderHomePage({super.key});

  @override
  State<DownloaderHomePage> createState() => _DownloaderHomePageState();
}

class _DownloaderHomePageState extends State<DownloaderHomePage> {
  final TextEditingController _urlController = TextEditingController();
  List<Map<String, dynamic>> resolutions = [];
  Map<String, dynamic>? selectedFormat;
  bool isDownloading = false;
  double progress = 0.0;
  bool isLoadingResolutions = false;
  StreamSubscription? _progressSubscription;
  http.Client? _sseClient;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _sseClient?.close();
    super.dispose();
  }

  Future<void> fetchResolutions() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showError('Please enter a YouTube URL');
      return;
    }

    setState(() => isLoadingResolutions = true);

    try {
      final response = await http.get(Uri.parse(
          'http://127.0.0.1:3000/youtube/resolutions?url=${Uri.encodeComponent(url)}'));

      setState(() => isLoadingResolutions = false);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final Map<int, Map<String, dynamic>> highest = {};
        for (var format in data) {
          final int res = format['resolution'];
          if (!highest.containsKey(res) ||
              format['ext'] == 'mp4' && highest[res]!['ext'] != 'mp4') {
            highest[res] = format;
          }
        }

        setState(() {
          resolutions = highest.values.toList()
            ..sort((a, b) =>
                (b['resolution'] as int).compareTo(a['resolution'] as int));
          selectedFormat = null;
        });
      } else {
        showError('Failed to fetch resolutions: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoadingResolutions = false);
      showError('Error fetching resolutions: $e');
    }
  }

  Future<void> downloadVideo() async {
    if (selectedFormat == null) {
      showError('Please select a format first');
      return;
    }

    setState(() {
      isDownloading = true;
      progress = 0.0;
    });

    try {
      // Start progress monitoring first
      await _startProgressListener();

      // Small delay to ensure SSE connection is established
      await Future.delayed(const Duration(milliseconds: 1000));

      // Send the download request
      final downloadResponse = await http.post(
        Uri.parse('http://127.0.0.1:3000/youtube/download'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'url': _urlController.text.trim(),
          'resolution': selectedFormat!['resolution'],
        }),
      );

      debugPrint('Download response status: ${downloadResponse.statusCode}');

      if (downloadResponse.statusCode == 200 ||
          downloadResponse.statusCode == 201) {
        // Don't show success immediately, let the progress stream handle completion
        showSuccess('Download completed successfully!');
        debugPrint('Download request successful');
      } else {
        showError('Download failed: ${downloadResponse.statusCode}');
        setState(() => isDownloading = false);
      }
    } catch (e) {
      showError('Download error: $e');
      setState(() => isDownloading = false);
    }
  }

  Future<void> _startProgressListener() async {
    // Cancel any existing subscription
    _progressSubscription?.cancel();
    _sseClient?.close();

    try {
      _sseClient = http.Client();
      final request = http.Request(
          'GET', Uri.parse('http://127.0.0.1:3000/youtube/progress'));

      // Add SSE headers
      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });

      debugPrint('Starting SSE connection...');
      final response = await _sseClient!.send(request);
      debugPrint('SSE Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _progressSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            debugPrint('SSE Raw Line: "$line"');

            if (line.trim().isEmpty) return;

            // Handle SSE format
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6); // Remove 'data: ' prefix
              debugPrint('SSE JSON Data: "$jsonStr"');

              try {
                final data = json.decode(jsonStr);
                debugPrint('Parsed SSE Data: $data');

                if (data['progress'] != null) {
                  final progressValue = (data['progress'] as num).toDouble();
                  debugPrint('Progress value: $progressValue');

                  setState(() {
                    progress = (progressValue / 100.0).clamp(0.0, 1.0);
                  });

                  debugPrint('UI Progress updated: ${progress * 100}%');
                }

                if (data['status'] == 'completed' ||
                    data['status'] == 'finished') {
                  debugPrint('Download completed via SSE');
                  setState(() {
                    progress = 1.0;
                    isDownloading = false;
                  });
                  showSuccess('Download completed successfully!');
                }

                if (data['error'] != null) {
                  debugPrint('Error received via SSE: ${data['error']}');
                  showError('Download error: ${data['error']}');
                  setState(() => isDownloading = false);
                }
              } catch (e) {
                debugPrint('JSON parse error: $e, Raw data: "$jsonStr"');
              }
            }
          },
          onError: (error) {
            debugPrint('SSE Stream error: $error');
            setState(() => isDownloading = false);
            showError('Progress monitoring error: $error');
          },
          onDone: () {
            debugPrint('SSE Stream completed');
            setState(() {
              if (progress < 1.0) {
                isDownloading = false;
              }
            });
          },
        );
      } else {
        debugPrint('SSE connection failed with status: ${response.statusCode}');
        showError('Failed to connect to progress stream');
        setState(() => isDownloading = false);
      }
    } catch (e) {
      debugPrint('Failed to start SSE connection: $e');
      showError('Failed to start progress monitoring: $e');
      setState(() => isDownloading = false);
    }
  }

  void showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  void showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Video Downloader'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoadingResolutions ? null : fetchResolutions,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: isLoadingResolutions
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Loading...'),
                      ],
                    )
                  : const Text('Get Available Resolutions'),
            ),
            const SizedBox(height: 20),
            if (resolutions.isNotEmpty) ...[
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedFormat,
                items: resolutions.map((res) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: res,
                    child: Text('${res['resolution']}p (${res['ext']})'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedFormat = value),
                decoration: const InputDecoration(
                  labelText: 'Select Format',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Downloading...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Progress: ${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (!isDownloading && selectedFormat != null)
              ElevatedButton.icon(
                onPressed: downloadVideo,
                icon: const Icon(Icons.download),
                label: const Text('Download Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
