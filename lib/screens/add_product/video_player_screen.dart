import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hoorain_pos/widgets/backbutton.dart';

import '../../constants.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final File? localVideoFile;
  final String? productImageUrl;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    this.localVideoFile,
    this.productImageUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _showThumbnail = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Create controller based on source
      if (widget.localVideoFile != null) {
        _controller = VideoPlayerController.file(widget.localVideoFile!);
      } else if (widget.videoUrl.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        throw Exception('No video source provided');
      }

      // Add error listener
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          setState(() {
            _isError = true;
            _errorMessage = _controller!.value.errorDescription ?? 'Unknown error';
          });
        }
      });

      // Add listener to hide thumbnail when video starts
      _controller!.addListener(() {
        if (_controller!.value.isPlaying && _showThumbnail && _isInitialized) {
          setState(() {
            _showThumbnail = false;
          });
        }
      });

      // Initialize controller
      await _controller!.initialize();
      
      // Set looping
      await _controller!.setLooping(true);
      
      // Start playing
      await _controller!.play();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
        if (_showThumbnail) {
          _showThumbnail = false;
        }
      }
    });
  }

  void _seekTo(Duration position) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller!.seekTo(position);
    if (_showThumbnail) {
      setState(() {
        _showThumbnail = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackNavigatingButton(color: Colors.white),
        title: Text(
          'Product Video',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              _controller?.pause();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: _isError
            ? _buildErrorWidget()
            : (!_isInitialized || _controller == null)
                ? _buildLoadingWidget()
                : _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        SizedBox(height: 20.h),
        Text(
          'Loading video...',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 60.sp,
        ),
        SizedBox(height: 20.h),
        Text(
          'Failed to load video',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Text(
            _errorMessage,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20.h),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isError = false;
              _initializeVideo();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
          ),
          child: Text(
            'Retry',
            style: GoogleFonts.inter(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final videoRatio = _controller!.value.aspectRatio;
              
              // Calculate appropriate size to fit screen
              double width = constraints.maxWidth;
              double height = constraints.maxWidth / videoRatio;
              
              if (height > constraints.maxHeight) {
                height = constraints.maxHeight;
                width = constraints.maxHeight * videoRatio;
              }
              
              return SizedBox(
                width: width,
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video Player
                    VideoPlayer(_controller!),
                    
                    // Product Image Thumbnail
                    if (_showThumbnail && widget.productImageUrl != null && widget.productImageUrl!.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: widget.productImageUrl!,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[900],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[900],
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                              ),
                              // Dark overlay
                              Container(
                                color: Colors.black.withOpacity(0.4),
                              ),
                              // Play button on thumbnail
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.black,
                                    size: 80.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Play/Pause Overlay Button
                    if (!_isPlaying && !_showThumbnail)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 60.sp,
                        ),
                      ),
                    
                    // Loading indicator while buffering
                    if (_controller!.value.isBuffering)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 50.w,
                          height: 50.h,
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget buildBottomNavigationBar(BuildContext context) {
    if (!_isInitialized || _controller == null || _isError) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      color: Colors.black.withOpacity(0.8),
      child: Row(
        children: [
          // Play/Pause Button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _togglePlayPause,
          ),
          
          // Current Position
          Text(
            _formatDuration(_controller!.value.position),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12.sp,
            ),
          ),
          
          // Progress Slider
          Expanded(
            child: Slider(
              value: _controller!.value.position.inMilliseconds.toDouble(),
              min: 0,
              max: _controller!.value.duration.inMilliseconds.toDouble(),
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
              onChanged: (value) {
                _seekTo(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          
          // Total Duration
          Text(
            _formatDuration(_controller!.value.duration),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12.sp,
            ),
          ),
          
          SizedBox(width: 8.w),
          
          // Close Button
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              _controller?.pause();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == null) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}