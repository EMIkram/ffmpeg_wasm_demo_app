import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js' as js;

import 'package:ffmpeg_wasm/ffmpeg_wasm.dart';
import 'package:ffmpeg_wasm_demo/my_video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPickerAndCompressor extends StatefulWidget {
  const VideoPickerAndCompressor({super.key});

  @override
  _VideoPickerAndCompressorState createState() => _VideoPickerAndCompressorState();
}

class _VideoPickerAndCompressorState extends State<VideoPickerAndCompressor> {
  VideoPlayerController? _originalVideoController;
  VideoPlayerController? _compressedVideoController;
  Uint8List? _compressedVideoData;
  double _compressionProgress = 0.0; // Progress state
  FFmpeg? ffmpeg;
  bool _shouldCancelCompression = false; // Cancellation flag

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      // Create a blob URL for the video file
      final blobUrl = html.Url.createObjectUrl(html.Blob([file.bytes!]));

      // Create an HTML video element to extract metadata
      final videoElement = html.VideoElement()
        ..src = blobUrl
        ..autoplay = false
        ..muted = true;

      // Load video metadata to get width and height
      videoElement.onLoadedMetadata.listen((event) {
        final videoWidth = videoElement.videoWidth;
        final videoHeight = videoElement.videoHeight;
        setState(() {
          _originalVideoController = VideoPlayerController.network(blobUrl);
          _originalVideoController!.initialize().then((_) {
            _compressVideo(file.bytes!, width: videoWidth, height: videoHeight);
            setState(() {});
          });
        });

        // Clean up the video element
        videoElement.remove();
      });
    }
  }

  Future<void> _compressVideo(Uint8List videoBytes, {required int width, required int height}) async {
    print('entered _compressVideo width: $width and height: $height');
    print('video length is : ${videoBytes.length}');
    if (_originalVideoController != null && _originalVideoController!.value.isInitialized) {
      try {
        // Reset progress and cancellation flag before starting compression
        setState(() {
          _compressionProgress = 0.0;
          _shouldCancelCompression = false;
          ffmpeg = createFFmpeg(CreateFFmpegParam(log: true));
          ffmpeg!.setLogger(_onLogHandler);
          ffmpeg!.setProgress(_onProgressHandler);
        });

        // Ensure the ffmpeg instance is loaded
        if (!ffmpeg!.isLoaded()) {
          await ffmpeg!.load();
        }

        // Call exportVideo to compress the video
        _compressedVideoData = await exportVideo(videoBytes, width, height);

        if (_compressedVideoData != null) {
          print("compressed video data is not null");
          // Create a blob URL for the compressed video
          final compressedBlob = html.Blob([_compressedVideoData!]);
          final compressedBlobUrl = html.Url.createObjectUrl(compressedBlob);
          print('compressed video url: $compressedBlobUrl');
          setState(() {
            _compressedVideoController = VideoPlayerController.network(compressedBlobUrl);
            _compressedVideoController!.initialize().then((_) {
              print("compressed video controller is initialized");
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
    ffmpeg?.exit();
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
                  // ElevatedButton(
                  //   onPressed: () {
                  //     setState(() {
                  //       _shouldCancelCompression = true; // Set flag to cancel compression
                  //     });
                  //   },
                  //   child: Text('Cancel Compression'),
                  // ),
                ],
              ),
              Column(
                children: [
                  Text('Original Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  _originalVideoController != null && _originalVideoController!.value.isInitialized
                      ? MyVideoPlayer(videoURL: _originalVideoController!.dataSource, height: 550)
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
                      ? MyVideoPlayer(videoURL: _compressedVideoController!.dataSource, height: 550)
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

  Future<Uint8List> exportVideo(Uint8List input, int width, int height) async {
    print('entered exportVideo');
    const inputFile = 'input.mp4';
    const outputFile = 'output.mp4';

    try {
      ffmpeg!.writeFile(inputFile, input);

      await ffmpeg!.run([
        '-i',
        inputFile,                // Input file path
        '-vf',
        'scale=-2:1280',         // Set height to 1280, width will be auto-calculated
        '-c:v',
        'libx264',               // Video codec: H.264
        '-crf',
        '26',                    // Constant Rate Factor for quality
        '-preset',
        'medium',                // Compression speed/quality balance
        '-c:a',
        'aac',                   // Audio codec: AAC
        '-b:a',
        '128k',                  // Audio bitrate: 128 kbps
        outputFile               // Output file path
      ]);

      // Check if cancellation is requested
      if (_shouldCancelCompression) {
        print("Compression canceled.");
        throw Exception("Compression was canceled");
      }

      final data = ffmpeg!.readFile(outputFile);
      print('video successfully compressed to size ${data.length}');

      js.context.callMethod('webSaveAs', [
        html.Blob([data]),
        outputFile
      ]);

      return data;
    } finally {
      // Clean up after compression
      ffmpeg!.unlink(inputFile);
      ffmpeg!.unlink(outputFile);
    }
  }

  void _onProgressHandler(ProgressParam progress) {
    setState(() {
      _compressionProgress = progress.ratio; // Update progress state
    });
    print('Progress: ${progress.ratio * 100}%');
  }

  void _onLogHandler(LoggerParam logger) {
    print('\x1B[36mFFmpeg log: ${logger.message}\x1B[0m');
  }
}
