import 'package:flutter/material.dart';

class ThreeDPage extends StatelessWidget {
  const ThreeDPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D展示'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: CustomPaint(
              painter: HumanBodyPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

// 人体3D绘制
class HumanBodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    // 绘制人体轮廓和节点
    const nodeRadius = 4.0;

    // 头部
    final headCenter = Offset(size.width / 2, size.height * 0.15);
    canvas.drawCircle(headCenter, size.width * 0.1, paint);
    canvas.drawCircle(headCenter, nodeRadius, dotPaint);

    // 颈部
    final neckCenter = Offset(size.width / 2, size.height * 0.22);
    canvas.drawCircle(neckCenter, nodeRadius, dotPaint);
    canvas.drawLine(headCenter, neckCenter, paint);

    // 肩部
    final leftShoulder = Offset(size.width * 0.3, size.height * 0.28);
    final rightShoulder = Offset(size.width * 0.7, size.height * 0.28);
    canvas.drawCircle(leftShoulder, nodeRadius, dotPaint);
    canvas.drawCircle(rightShoulder, nodeRadius, dotPaint);
    canvas.drawLine(neckCenter, leftShoulder, paint);
    canvas.drawLine(neckCenter, rightShoulder, paint);
    canvas.drawLine(leftShoulder, rightShoulder, paint);

    // 胸部
    final chestCenter = Offset(size.width / 2, size.height * 0.35);
    canvas.drawCircle(chestCenter, nodeRadius, dotPaint);
    canvas.drawLine(neckCenter, chestCenter, paint);
    canvas.drawLine(leftShoulder, chestCenter, paint);
    canvas.drawLine(rightShoulder, chestCenter, paint);

    // 腰部
    final waistCenter = Offset(size.width / 2, size.height * 0.45);
    canvas.drawCircle(waistCenter, nodeRadius, dotPaint);
    canvas.drawLine(chestCenter, waistCenter, paint);

    // 髋部
    final leftHip = Offset(size.width * 0.4, size.height * 0.55);
    final rightHip = Offset(size.width * 0.6, size.height * 0.55);
    canvas.drawCircle(leftHip, nodeRadius, dotPaint);
    canvas.drawCircle(rightHip, nodeRadius, dotPaint);
    canvas.drawLine(waistCenter, leftHip, paint);
    canvas.drawLine(waistCenter, rightHip, paint);
    canvas.drawLine(leftHip, rightHip, paint);

    // 左臂
    final leftElbow = Offset(size.width * 0.2, size.height * 0.35);
    final leftWrist = Offset(size.width * 0.15, size.height * 0.45);
    canvas.drawCircle(leftElbow, nodeRadius, dotPaint);
    canvas.drawCircle(leftWrist, nodeRadius, dotPaint);
    canvas.drawLine(leftShoulder, leftElbow, paint);
    canvas.drawLine(leftElbow, leftWrist, paint);

    // 右臂
    final rightElbow = Offset(size.width * 0.8, size.height * 0.35);
    final rightWrist = Offset(size.width * 0.85, size.height * 0.45);
    canvas.drawCircle(rightElbow, nodeRadius, dotPaint);
    canvas.drawCircle(rightWrist, nodeRadius, dotPaint);
    canvas.drawLine(rightShoulder, rightElbow, paint);
    canvas.drawLine(rightElbow, rightWrist, paint);

    // 左腿
    final leftKnee = Offset(size.width * 0.35, size.height * 0.7);
    final leftAnkle = Offset(size.width * 0.4, size.height * 0.85);
    canvas.drawCircle(leftKnee, nodeRadius, dotPaint);
    canvas.drawCircle(leftAnkle, nodeRadius, dotPaint);
    canvas.drawLine(leftHip, leftKnee, paint);
    canvas.drawLine(leftKnee, leftAnkle, paint);

    // 右腿
    final rightKnee = Offset(size.width * 0.65, size.height * 0.7);
    final rightAnkle = Offset(size.width * 0.6, size.height * 0.85);
    canvas.drawCircle(rightKnee, nodeRadius, dotPaint);
    canvas.drawCircle(rightAnkle, nodeRadius, dotPaint);
    canvas.drawLine(rightHip, rightKnee, paint);
    canvas.drawLine(rightKnee, rightAnkle, paint);

    // 连接线
    canvas.drawLine(chestCenter, leftShoulder, paint);
    canvas.drawLine(chestCenter, rightShoulder, paint);
    canvas.drawLine(waistCenter, leftHip, paint);
    canvas.drawLine(waistCenter, rightHip, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}