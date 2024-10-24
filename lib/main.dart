
import 'package:ffmpeg_wasm_demo/video_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Picker App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoPickerAndCompressor(), // The page with your video picker UI
    );
  }
}
