import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MyVideoPlayer extends StatefulWidget {
  final String? videoURL;
  final bool showUploadIcon;
  final double? height;
  final VoidCallback? onFilePick;

  const MyVideoPlayer({
    this.onFilePick,
    this.videoURL,
    this.showUploadIcon = false,
    this.height,
  });

  @override
  _MyVideoPlayerState createState() => _MyVideoPlayerState();
}

class _MyVideoPlayerState extends State<MyVideoPlayer> {
  VideoPlayerController? videoPlayerController;
  bool isPlay = false;
  bool showControls = true;
  bool isMuted = false;
  late Timer _hideControlsTimer;
  bool firstTimer = true;

  @override
  void initState() {
    super.initState();

    if(videoPlayerController != null){
      videoPlayerController!.dispose();
    }
    if (widget.videoURL != null) {
      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoURL!))
        ..initialize().then((_) {
          // videoPlayerController!.play();
          setState(() {
            // isPlay = true;
          });
        });

      videoPlayerController!.addListener(() {
        setState(() {});
      });

      _startHideControlsTimer();
    }
  }

  @override
  void didUpdateWidget(covariant MyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the video URL has changed
    if (oldWidget.videoURL != widget.videoURL) {
      if (videoPlayerController != null) {
        videoPlayerController!.dispose();
      }

      if (widget.videoURL != null) {
        videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoURL!))
          ..initialize().then((_) {
            setState(() {
              // isPlay = true;
            });
          });

        videoPlayerController!.addListener(() {
          setState(() {});
        });

        _startHideControlsTimer();
      }
    }
  }


  void _startHideControlsTimer() {
    _hideControlsTimer = Timer(Duration(milliseconds: firstTimer ? 3500 :500), () {
      setState(() {
        showControls = false;
        firstTimer = false;
      });
    });
  }

  @override
  void dispose() {
    videoPlayerController?.dispose();
    _hideControlsTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.sizeOf(context).width;
    double screenHeight = MediaQuery.sizeOf(context).height;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          showControls = true;
          _hideControlsTimer.cancel();
        });
      },
      onExit: (_) {
        _startHideControlsTimer();
      },
      child: Container(
        height: widget.height,
        width: videoPlayerController!.value.aspectRatio == 1
            ? 295
            : widget.height! * videoPlayerController!.value.aspectRatio,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            if (videoPlayerController != null && videoPlayerController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(videoPlayerController!),
                ),
              ),
            if (videoPlayerController == null || !videoPlayerController!.value.isInitialized)
             const  Center(
                child: CircularProgressIndicator(
                  color: Colors.yellow,
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: VideoProgressIndicator(
                  padding:const EdgeInsets.symmetric(horizontal: 5.5),
                  videoPlayerController!,
                  colors:const  VideoProgressColors(playedColor: Colors.yellow),
                  allowScrubbing: true,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  if (isPlay) {
                    videoPlayerController!.pause();
                  } else {
                    videoPlayerController!.play();
                  }

                  setState(() {
                    isPlay = !isPlay;
                    showControls = true;
                  });

                  _hideControlsTimer.cancel();
                  _startHideControlsTimer();
                },
                child: AnimatedOpacity(
                  opacity: showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Center(
                      child: Icon(
                        isPlay ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.yellow,
                  ),
                  onPressed: () {
                    setState(() {
                      isMuted = !isMuted;
                      videoPlayerController!.setVolume(isMuted ? 0.0 : 1.0);
                    });
                  },
                ),
              ),
            ),
            if (widget.showUploadIcon)
              Align(
                alignment: Alignment.topRight,
                child: AnimatedOpacity(
                  opacity: showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IconButton(
                    tooltip: "Pick video",
                    icon:const Icon(
                      Icons.video_file_outlined,
                      color: Colors.yellow,
                    ),
                    onPressed: widget.onFilePick,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
