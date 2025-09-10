import 'package:flutter/material.dart';
import 'package:my_face/face_id_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> requestPermissions() async {
    // Xin nhiều quyền cùng lúc
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();

    // Kiểm tra kết quả
    if (statuses[Permission.camera]!.isGranted) {
      print("✅ Camera permission granted");
    } else {
      print("❌ Camera permission denied");
    }

    if (statuses[Permission.microphone]!.isGranted) {
      print("✅ Microphone permission granted");
    }

    if (statuses[Permission.location]!.isGranted) {
      print("✅ Location permission granted");
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    requestPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: FaceIDScanningCircle(
        size: 350,
        strokeWidth: 3,
        duration: Duration(seconds: 5),
        enableCamera: true,
      ), // ✅ Đã gọi đúng
    );
  }
}
