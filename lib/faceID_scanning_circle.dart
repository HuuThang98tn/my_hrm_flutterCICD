import 'package:flutter/material.dart';
import 'dart:math' as math;

class FaceIDScanningCircle extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  const FaceIDScanningCircle({
    super.key,
    this.size = 200.0,
    this.color = Colors.blue,
    this.strokeWidth = 4.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<FaceIDScanningCircle> createState() => _FaceIDScanningCircleState();
}

class _FaceIDScanningCircleState extends State<FaceIDScanningCircle> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: widget.duration, vsync: this);

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.linear));

    // Bắt đầu animation và lặp lại
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: FaceIDCirclePainter(
            rotation: _rotationAnimation.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class FaceIDCirclePainter extends CustomPainter {
  final double rotation;
  final Color color;
  final double strokeWidth;

  FaceIDCirclePainter({required this.rotation, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - strokeWidth) / 2;
    final innerRadius = outerRadius - 25; // Độ dài cố định của mỗi gạch
    final innerCircleRadius = innerRadius - 15; // Bán kính vòng tròn giữa

    // Vẽ vòng tròn ở giữa (background)
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, innerCircleRadius, circlePaint);

    // Vẽ viền vòng tròn giữa
    final circleBorderPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, innerCircleRadius, circleBorderPaint);

    final gradient = SweepGradient(
      colors: [color.withOpacity(0.0), color],
      stops: const [0.0, 1.0], // chỉ 2 mốc
      transform: GradientRotation(rotation),
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Số lượng gạch đứt (các nét có độ dài bằng nhau)
    const dashCount = 100;
    final angleStep = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final angle = i * angleStep - math.pi / 2;

      // Tính toán vị trí bắt đầu và kết thúc của mỗi gạch (độ dài bằng nhau)
      final startX = center.dx + math.cos(angle) * innerRadius;
      final startY = center.dy + math.sin(angle) * innerRadius;
      final endX = center.dx + math.cos(angle) * outerRadius;
      final endY = center.dy + math.sin(angle) * outerRadius;

      // Vẽ từng gạch như một đường thẳng
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    // Vẽ icon Face ID ở giữa (tùy chọn)
    final iconPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Vẽ khung face đơn giản
    final faceRect = Rect.fromCenter(center: center, width: innerCircleRadius * 0.8, height: innerCircleRadius * 1.0);

    canvas.drawRRect(RRect.fromRectAndRadius(faceRect, Radius.circular(8)), iconPaint);

    // Vẽ mắt
    final eyeSize = 4.0;
    canvas.drawCircle(Offset(center.dx - 8, center.dy - 8), eyeSize / 2, iconPaint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(center.dx + 8, center.dy - 8), eyeSize / 2, iconPaint);

    // Vẽ miệng
    final mouthPath = Path();
    mouthPath.moveTo(center.dx - 6, center.dy + 8);
    mouthPath.quadraticBezierTo(center.dx, center.dy + 14, center.dx + 6, center.dy + 8);

    canvas.drawPath(mouthPath, iconPaint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(FaceIDCirclePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

// // Widget để demo sử dụng
// class FaceIDDemo extends StatelessWidget {
//   const FaceIDDemo({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text('Face ID Scanning Demo'),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Vòng tròn Face ID cơ bản
//             FaceIDScanningCircle(size: 200, color: Colors.blue, strokeWidth: 3, duration: Duration(seconds: 2)),
//             SizedBox(height: 50),

//             // Vòng tròn với màu xanh lá
//             FaceIDScanningCircle(
//               size: 150,
//               color: Colors.green,
//               strokeWidth: 4,
//               duration: Duration(milliseconds: 1500),
//             ),
//             SizedBox(height: 50),

//             // Vòng tròn nhỏ với màu cam
//             FaceIDScanningCircle(size: 100, color: Colors.orange, strokeWidth: 2, duration: Duration(seconds: 1)),

//             SizedBox(height: 30),
//             Text(
//               'Scanning...',
//               style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
