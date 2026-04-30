import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Yapay zekanın bulduğu vücut koordinatlarını (landmark) alıp
/// ekrana iskelet olarak çizmemizi sağlayan özel çizici (CustomPainter) sınıfı.
class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  final List<Pose> poses;                // Algılanan kişilerin vücut noktaları
  final Size absoluteImageSize;          // Kameradan gelen ham görüntünün boyutu
  final InputImageRotation rotation;     // Görüntünün ne kadar döndürüldüğü (Portre/Manzara)

  @override
  void paint(Canvas canvas, Size size) {
    // Çizgi ve nokta stillerini (Paint nesneleri) belirliyoruz. Neon oyun temasına uygun renkler:
    
    // Gövde (Orta kısım) için kullanılacak fırça (Turkuaz/Neon Mavi)
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.cyanAccent;

    // Vücudun SOL tarafı için kullanılacak fırça (Sarı)
    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellowAccent;

    // Vücudun SAĞ tarafı için kullanılacak fırça (Pembe)
    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.pinkAccent;

    // Kamerada algılanan her bir kişi (pose) için dön
    for (final pose in poses) {
      
      // 1. ADIM: Tüm eklem noktalarını (omuz, dirsek, vb.) küçük yuvarlaklar (circle) olarak çiz
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
            Offset(
              // ML Kit'ten gelen ham (raw) koordinatları, telefon ekranının boyutuna (size) oranlayarak çeviriyoruz.
              translateX(landmark.x, rotation, size, absoluteImageSize),
              translateY(landmark.y, rotation, size, absoluteImageSize),
            ),
            1, // Noktanın yarıçapı
            paint);
      });

      // İki eklem noktası arasına çizgi çekmek için yardımcı bir fonksiyon
      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        canvas.drawLine(
            Offset(translateX(joint1.x, rotation, size, absoluteImageSize),
                translateY(joint1.y, rotation, size, absoluteImageSize)),
            Offset(translateX(joint2.x, rotation, size, absoluteImageSize),
                translateY(joint2.y, rotation, size, absoluteImageSize)),
            paintType);
      }

      // 2. ADIM: İskeleti Oluştur (Kolları Çiz)
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Gövdeyi (Omuzlar ve Kalçayı) Çiz
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, paint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint);

      // Bacakları Çiz
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  /// Eğer kameradan gelen görüntü (frame) veya telefonun boyutu değiştiyse, 
  /// Flutter'a "ekranı tekrar çiz" demek için `true` döndürürüz.
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }

  /// ML Kit'in verdiği X koordinatını telefon ekranının piksel aralığına çevirir. (Ölçekleme - Scaling)
  double translateX(double x, InputImageRotation rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * size.width / absoluteImageSize.height;
      case InputImageRotation.rotation270deg:
        // Cihaz yan tutuluyorsa veya ön kameradaysa ayna etkisini kırmak için ekran genişliğinden çıkarıyoruz.
        return size.width - x * size.width / absoluteImageSize.height;
      default:
        return x * size.width / absoluteImageSize.width;
    }
  }

  /// ML Kit'in verdiği Y koordinatını telefon ekranının piksel aralığına çevirir. (Ölçekleme - Scaling)
  double translateY(double y, InputImageRotation rotation, Size size, Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * size.height / absoluteImageSize.width;
      default:
        return y * size.height / absoluteImageSize.height;
    }
  }
}
