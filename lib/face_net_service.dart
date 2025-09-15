import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Lớp dịch vụ xử lý nhận diện khuôn mặt sử dụng FaceNet
class FaceNetService {
  Interpreter? _interpreter; // Trình thông dịch TensorFlow Lite

  /// Tải model FaceNet từ assets
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/facenet.tflite');

      // Hiển thị thông tin debug về model
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print("✅ Tải model thành công");
      print("📊 Thông tin Model:");
      for (int i = 0; i < inputTensors.length; i++) {
        print("  Đầu vào $i: ${inputTensors[i].shape} (${inputTensors[i].type})");
      }
      for (int i = 0; i < outputTensors.length; i++) {
        print("  Đầu ra $i: ${outputTensors[i].shape} (${outputTensors[i].type})");
      }
    } catch (e) {
      print("❌ Lỗi khi tải model: $e");
      rethrow;
    }
  }

  /// Tải ảnh từ thư mục assets
  Future<img.Image?> _taiAnhTuAssets(String duongDan) async {
    try {
      final data = await rootBundle.load(duongDan);
      final bytes = data.buffer.asUint8List();
      return img.decodeImage(bytes);
    } catch (e) {
      print("Lỗi khi tải ảnh từ assets: $e");
      return null;
    }
  }

  /// Tiền xử lý ảnh: thay đổi kích thước và chuẩn hóa
  Float32List _tienXuLyAnh(img.Image anh) {
    // Thay đổi kích thước về 160x160 pixels cho FaceNet
    final anhDaThayDoiKichThuoc = img.copyResize(anh, width: 160, height: 160);

    // Tạo buffer đầu vào [1 * 160 * 160 * 3]
    final dauVao = Float32List(1 * 160 * 160 * 3);
    int chiSo = 0;

    // Duyệt qua từng pixel của ảnh
    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = anhDaThayDoiKichThuoc.getPixel(x, y);

        // Sử dụng API mới của thư viện image để lấy giá trị RGB
        final r = (pixel.r * 255).round(); // Đỏ
        final g = (pixel.g * 255).round(); // Xanh lá
        final b = (pixel.b * 255).round(); // Xanh dương

        // Chuẩn hóa giá trị pixel về khoảng [-1, 1] cho FaceNet
        dauVao[chiSo++] = (r - 127.5) / 127.5;
        dauVao[chiSo++] = (g - 127.5) / 127.5;
        dauVao[chiSo++] = (b - 127.5) / 127.5;
      }
    }

    return dauVao;
  }

  /// Lấy embedding (vector đặc trưng) cho một ảnh
  Future<List<double>> layEmbedding(String duongDanAsset) async {
    if (_interpreter == null) {
      throw Exception("Model chưa được tải");
    }

    final anh = await _taiAnhTuAssets(duongDanAsset);
    if (anh == null) {
      throw Exception("Không thể tải ảnh từ: $duongDanAsset");
    }

    try {
      // Tiền xử lý ảnh thành Float32List
      final dauVao = _tienXuLyAnh(anh);

      // Tạo buffer đầu ra cho embedding 128 chiều
      final dauRa = Float32List(1 * 128);

      print("Đang chạy inference cho: $duongDanAsset");
      print("Kích thước đầu vào: ${dauVao.length}, Kích thước đầu ra: ${dauRa.length}");

      // Chạy suy luận trên model
      _interpreter!.run(dauVao, dauRa);

      // Trả về vector embedding
      return dauRa.cast<double>();
    } catch (e) {
      print("Lỗi khi lấy embedding cho $duongDanAsset: $e");

      // Thử phương pháp thay thế với cấu trúc List lồng nhau
      return await _layEmbeddingThayThe(anh);
    }
  }

  /// Phương pháp thay thế sử dụng cấu trúc List lồng nhau
  Future<List<double>> _layEmbeddingThayThe(img.Image anh) async {
    try {
      final anhDaThayDoiKichThuoc = img.copyResize(anh, width: 160, height: 160);

      // Tạo đầu vào với cấu trúc [batch][chiều cao][chiều rộng][kênh màu]
      final dauVao = <List<List<List<double>>>>[];
      final batch = <List<List<double>>>[];

      for (int y = 0; y < 160; y++) {
        final hang = <List<double>>[];
        for (int x = 0; x < 160; x++) {
          final pixel = anhDaThayDoiKichThuoc.getPixel(x, y);

          final r = (pixel.r * 255).round();
          final g = (pixel.g * 255).round();
          final b = (pixel.b * 255).round();

          // Các kênh RGB đã được chuẩn hóa
          final cacKenh = [
            (r - 127.5) / 127.5, // Đỏ
            (g - 127.5) / 127.5, // Xanh lá
            (b - 127.5) / 127.5, // Xanh dương
          ];

          hang.add(cacKenh);
        }
        batch.add(hang);
      }
      dauVao.add(batch);

      // Cấu trúc đầu ra [batch][embedding]
      final dauRa = <List<double>>[];
      dauRa.add(List.filled(128, 0.0));

      print(
        "Phương pháp thay thế - Hình dạng đầu vào: [${dauVao.length}, ${dauVao[0].length}, ${dauVao[0][0].length}, ${dauVao[0][0][0].length}]",
      );

      _interpreter!.run(dauVao, dauRa);

      return dauRa[0];
    } catch (e) {
      print("Phương pháp thay thế thất bại: $e");
      throw Exception("Không thể xử lý ảnh với model này: $e");
    }
  }

  /// Tính khoảng cách Euclidean giữa hai vector
  double khoangCachEuclidean(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) {
      throw Exception("Độ dài các vector phải bằng nhau");
    }

    double tong = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      tong += pow(vector1[i] - vector2[i], 2);
    }
    return sqrt(tong);
  }

  /// Tính độ tương đồng cosine giữa hai vector
  double doTuongDongCosine(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) {
      throw Exception("Độ dài các vector phải bằng nhau");
    }

    double tichVoHuong = 0.0, chuanVector1 = 0.0, chuanVector2 = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      tichVoHuong += vector1[i] * vector2[i];
      chuanVector1 += vector1[i] * vector1[i];
      chuanVector2 += vector2[i] * vector2[i];
    }

    final mauSo = sqrt(chuanVector1) * sqrt(chuanVector2);
    return mauSo == 0 ? 0 : tichVoHuong / mauSo;
  }

  /// Giải phóng tài nguyên
  void giaiPhong() {
    _interpreter?.close();
  }
}
