import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Face ID Demo',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      home: const FaceRecognitionPage(),
    );
  }
}

class FaceRecognitionPage extends StatefulWidget {
  const FaceRecognitionPage({super.key});

  @override
  _FaceRecognitionPageState createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  static const platform = MethodChannel('com.example.my_face/facerecognition');

  Map<dynamic, dynamic>? _recognitionResult;
  bool _isProcessing = false;
  String _initialMessage = 'Nhấn nút để so sánh khuôn mặt.';

  Future<Uint8List> loadAssetBytes(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  Future<void> _compareFaces() async {
    setState(() {
      _isProcessing = true;
      _recognitionResult = null;
      _initialMessage = 'Đang xử lý...';
    });

    try {
      final bytes1 = await loadAssetBytes('assets/thinh2.jpg');
      final bytes2 = await loadAssetBytes('assets/thang.jpg');

      final result = await platform.invokeMethod('compareFaces', {'bytes1': bytes1, 'bytes2': bytes2});

      setState(() {
        _isProcessing = false;
        _recognitionResult = result;
      });
    } on PlatformException catch (e) {
      setState(() {
        _isProcessing = false;
        _initialMessage = "Lỗi khi so sánh: '${e.message}'.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Nhận Dạng Khuôn Mặt'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'So sánh khuôn mặt từ tệp assets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: Image.asset('assets/thinh2.jpg', height: 150)),
                const SizedBox(width: 16),
                Expanded(child: Image.asset('assets/thang.jpg', height: 150)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing ? null : _compareFaces,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('So Sánh', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),
            // Hiển thị kết quả
            if (_recognitionResult != null) ResultCard(result: _recognitionResult!),
            if (_recognitionResult == null && !_isProcessing)
              Center(
                child: Text(
                  _initialMessage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  final Map<dynamic, dynamic> result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isMatch = result['isMatch'] as bool;
    final String matchType = result['matchType'] as String;
    final String confidence = result['confidence'] as String;
    final double cosineSimilarity = result['cosineSimilarity'] as double;
    final double euclideanDistance = result['euclideanDistance'] as double;
    final double compositeSimilarity = result['compositeSimilarity'] as double;

    final String finalResultText = isMatch ? 'CÙNG MỘT NGƯỜI' : 'KHÔNG PHẢI MỘT NGƯỜI';
    final Color resultColor = isMatch ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KẾT LUẬN:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: resultColor),
            ),
            const SizedBox(height: 8),
            Text(
              finalResultText,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: resultColor),
            ),
            const SizedBox(height: 16),
            const Divider(),
            _buildInfoRow('Loại kết quả', matchType.replaceAll('_', ' ').toLowerCase()),
            _buildInfoRow('Độ tin cậy', confidence.replaceAll('_', ' ').toLowerCase()),
            _buildInfoRow('Cosine Similarity', '${(cosineSimilarity * 100).toStringAsFixed(2)}%'),
            _buildInfoRow('Euclidean Distance', euclideanDistance.toStringAsFixed(3)),
            _buildInfoRow('Điểm Tổng Hợp', compositeSimilarity.toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
