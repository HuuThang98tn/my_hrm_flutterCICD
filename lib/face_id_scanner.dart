import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;

enum FaceScanStatus { idle, success, fail }

class FaceIDScanningCircle extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Duration duration;
  final bool enableCamera;

  const FaceIDScanningCircle({
    super.key,
    this.size = 200.0,
    this.strokeWidth = 4.0,
    this.duration = const Duration(seconds: 2),
    this.enableCamera = false,
  });

  @override
  State<FaceIDScanningCircle> createState() => _FaceIDScanningCircleState();
}

class _FaceIDScanningCircleState extends State<FaceIDScanningCircle> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  CameraController? _cameraController;
  bool _isInitialized = false;

  FaceScanStatus _scanStatus = FaceScanStatus.idle;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    if (widget.enableCamera) {
      _initializeCamera();
      _simulateScan();
    }
  }

  void _setupAnimations() {
    _rotationController = AnimationController(duration: widget.duration, vsync: this);
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_rotationController);

    _rotationController.repeat();
  }

  void _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _scanStatus = FaceScanStatus.fail);
    }
  }

  /// Giả lập kết quả scan
  void _simulateScan() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _scanStatus = FaceScanStatus.fail);

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // ✅ Chụp ảnh trong nền, khi xong thì hiển thị
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      final image = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImage = image;
      });
    }
    // ✅ Chuyển ngay sang success và dừng animation
    setState(() {
      _scanStatus = FaceScanStatus.success;
      _rotationController.stop();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (_scanStatus) {
      case FaceScanStatus.idle:
        return Colors.grey;
      case FaceScanStatus.success:
        return Colors.green;
      case FaceScanStatus.fail:
        return Colors.red;
    }
  }

  String _getStatusText() {
    switch (_scanStatus) {
      case FaceScanStatus.idle:
        return "Position your face in the frame";
      case FaceScanStatus.success:
        return "Face ID successful!";
      case FaceScanStatus.fail:
        return "Face not recognized!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ Camera Preview hoặc ảnh chụp
          if (widget.enableCamera && _isInitialized && _cameraController != null)
            ClipOval(
              child: SizedBox(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                child: _capturedImage == null
                    ? CameraPreview(_cameraController!)
                    : Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
              ),
            ),

          // ✅ Vòng xoay (sọc kẻ)
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: FaceIDCirclePainter(
                  rotation: _rotationAnimation.value,
                  color: _getColor(),
                  strokeWidth: widget.strokeWidth,
                  isSuccess: _scanStatus == FaceScanStatus.success,
                ),
              );
            },
          ),

          // ✅ Status Text
          if (widget.enableCamera)
            Positioned(
              bottom: -40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FaceIDCirclePainter extends CustomPainter {
  final double rotation;
  final Color color;
  final double strokeWidth;
  final bool isSuccess;

  FaceIDCirclePainter({
    required this.rotation,
    required this.color,
    required this.strokeWidth,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - strokeWidth) / 2;
    final innerRadius = outerRadius - 25;

    // ✅ Nếu success thì không dùng gradient xoay nữa mà full xanh lá
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (!isSuccess) {
      final gradient = SweepGradient(
        colors: [color.withOpacity(0.0), color],
        stops: const [0.0, 1.0],
        transform: GradientRotation(rotation),
      );
      paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: outerRadius));
    }

    const dashCount = 100;
    final angleStep = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final angle = i * angleStep - math.pi / 2;

      final startX = center.dx + math.cos(angle) * innerRadius;
      final startY = center.dy + math.sin(angle) * innerRadius;
      final endX = center.dx + math.cos(angle) * outerRadius;
      final endY = center.dy + math.sin(angle) * outerRadius;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(FaceIDCirclePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color || oldDelegate.isSuccess != isSuccess;
  }
}
