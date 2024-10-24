import 'dart:html' as html;
import 'dart:typed_data';

import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';
import 'package:ffmpeg_wasm_demo/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPickerAndCompressor extends StatefulWidget {
  @override
  _VideoPickerAndCompressorState createState() => _VideoPickerAndCompressorState();
}

class _VideoPickerAndCompressorState extends State<VideoPickerAndCompressor> {
  VideoPlayerController? _originalVideoController;
  VideoPlayerController? _compressedVideoController;
  Uint8List? _compressedVideoData;
  double _compressionProgress = 0.0; // Progress state

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      // Creating a blob URL
      final blobUrl = html.Url.createObjectUrl(html.Blob([file.bytes!]));
      setState(() {
        _originalVideoController = VideoPlayerController.network(blobUrl);
        _originalVideoController!.initialize().then((_) {
          setState(() {});
        });
      });

      // After picking the video, compress it
      await _compressVideo(file.bytes!);
    }
  }

  Future<void> _compressVideo(Uint8List videoBytes) async {
    if (_originalVideoController != null && _originalVideoController!.value.isInitialized) {
      try {
        // Reset progress before starting compression
        setState(() {
          _compressionProgress = 0.0;
        });

        // Call exportVideo to compress the video
        _compressedVideoData = await exportVideo(videoBytes);

        if (_compressedVideoData != null) {
          // Create a blob URL for the compressed video
          final compressedBlob = html.Blob([_compressedVideoData!]);
          final compressedBlobUrl = html.Url.createObjectUrl(compressedBlob);

          setState(() {
            _compressedVideoController = VideoPlayerController.network(compressedBlobUrl);
            _compressedVideoController!.initialize().then((_) {
              setState(() {});
            });
          });
        }
      } catch (e) {
        print('Error during compression: $e');
      }
    }
  }

  @override
  void dispose() {
    _originalVideoController?.dispose();
    _compressedVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Picker and Compressor')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _pickVideo,
                    child: Text('Pick Video'),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('Original Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  _originalVideoController != null && _originalVideoController!.value.isInitialized
                      ? Container(
                    width: 400, // Set a fixed width
                    height: 400 * 0.5625, // Maintain aspect ratio
                    child: AspectRatio(
                      aspectRatio: _originalVideoController!.value.aspectRatio,
                      child: VideoPlayerWidget(videoUrl: _originalVideoController!.dataSource),
                    ),
                  )
                      : Container(
                    height: 200,
                    color: Colors.black12,
                    child: Center(child: Text('No video selected')),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('Compressed Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  _compressedVideoController != null && _compressedVideoController!.value.isInitialized
                      ? VideoPlayerWidget(videoUrl: _compressedVideoController!.dataSource)
                      : Container(
                    height: 200,
                    color: Colors.black12,
                    child: Center(child: Text('No video compressed')),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          // Show progress indicator during compression
          _compressionProgress > 0.0 && _compressionProgress < 1.0
              ? Column(
            children: [
              Text('Compression Progress: ${(_compressionProgress * 100).toStringAsFixed(2)}%'),
              LinearProgressIndicator(value: _compressionProgress),
            ],
          )
              : Container(),
        ],
      ),
    );
  }

  Future<Uint8List> exportVideo(Uint8List input) async {
    FFmpeg? ffmpeg;
    try {
      ffmpeg = createFFmpeg(CreateFFmpegParam(log: true));
      ffmpeg.setLogger(_onLogHandler);
      ffmpeg.setProgress(_onProgressHandler);

      if (!ffmpeg.isLoaded()) {
        await ffmpeg.load();
      }

      const inputFile = 'input.mp4';
      const outputFile = 'output.mp4';

      ffmpeg.writeFile(inputFile, input);

      // Compress the video and scale to 1080p
      await ffmpeg.runCommand('-i $inputFile -s 1920x1080 $outputFile');

      final data = ffmpeg.readFile(outputFile);
      return data;
    } finally {
      ffmpeg?.exit();
    }
  }

  void _onProgressHandler(ProgressParam progress) {
    setState(() {
      _compressionProgress = progress.ratio; // Update progress state
    });
    print('Progress: ${progress.ratio * 100}%');
  }

  void _onLogHandler(LoggerParam logger) {
    print('FFmpeg log: ${logger.message}');
  }
}
