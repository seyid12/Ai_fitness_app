import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'camera_view.dart';
import 'pose_painter.dart';

/// Bu sayfa, kameradan gelen görüntüleri yapay zeka modeline (PoseDetector)
/// gönderir ve dönen iskelet verilerine (landmark) göre açı hesaplamaları yapar.
class PoseDetectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  // ML Kit PoseDetector nesnesi oluşturuluyor. 
  // 'stream' modu, kameradan sürekli akan video görüntüsünü kesintisiz işlemek için kullanılır.
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  
  bool _canProcess = true; // Sayfa kapatıldığında işlemi durdurmak için bayrak
  bool _isBusy = false;    // Model aynı anda birden fazla kareyi (frame) işlemeye çalışmasın diye kilit mekanizması
  CustomPaint? _customPaint; // Ekrana iskelet çizgilerini çizeceğimiz bileşen
  
  // Oyunlaştırma ve Durum (State) Değişkenleri
  int _score = 0;                  // Toplam başarılı tekrar sayısı
  bool _isSquatDown = false;       // Kullanıcı o an çömelme pozisyonunda mı? (Yukarı/Aşağı durumu)
  String _feedbackText = "Hazır!"; // Kullanıcıya verilecek metinsel geri bildirim
  Color _feedbackColor = Colors.cyanAccent; // Geri bildirim kutusunun ve yazının rengi

  @override
  void dispose() async {
    _canProcess = false;
    _poseDetector.close(); // Hafıza sızıntısını (memory leak) önlemek için modeli kapat
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Kameradan canlı görüntüyü alan ve her bir kareyi bize ileten özel bileşenimiz
          CameraView(
            customPaint: _customPaint,
            onImage: _processImage, // Kameradan gelen her kare bu fonksiyona düşer
            initialDirection: CameraLensDirection.front, // Ön kamerayı kullan
          ),
          
          // Ekrana skoru ve mesajları yazdıran Arayüz (UI) Katmanı
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skor Göstergesi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                    ),
                    child: Text(
                      'SKOR: $_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Geri Bildirim Göstergesi (Örn: "Daha Eğil", "Harika")
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _feedbackColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _feedbackColor.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                      child: Text(
                        _feedbackText,
                        style: TextStyle(
                          color: _feedbackColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kameradan gelen 'InputImage' (Resim karesi) nesnesini işleyen ana fonksiyon.
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return; // Zaten bir önceki kare işleniyorsa, bu kareyi atla (FPS düşmemesi için)
    _isBusy = true;

    // ML Kit'e görüntüyü veriyoruz ve o bize vücut noktalarını (Pose dizisi) döndürüyor.
    final poses = await _poseDetector.processImage(inputImage);
    
    // Eğer karede bir insan bulunduysa
    if (poses.isNotEmpty) {
      final pose = poses.first; // Genelde ilk bulunan kişiyi (ana kullanıcı) alıyoruz
      _analyzeSquat(pose);      // Noktaları matematiksel analize gönder
    }

    // Ekrana İskelet (Skeleton) çizimi için PosePainter nesnesini hazırlıyoruz.
    // Kameranın rotasyonu ve çözünürlüğü gibi metadatalar, noktaların doğru yere çizilmesi için şart.
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
      );
      _customPaint = CustomPaint(painter: painter); // İskelet UI üzerinde güncellenir
    } else {
      _customPaint = null;
    }
    
    _isBusy = false; // Kilit açıldı, sıradaki resim işlenebilir
    if (mounted) {
      setState(() {}); // Skoru ve iskeleti ekranda yenile
    }
  }

  /// Squat hareketinin formunu, derinliğini ve sırt açısını kontrol eden algoritma
  void _analyzeSquat(Pose pose) {
    // Sol vücut eklem noktalarını al
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    // Sağ vücut eklem noktalarını al
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Eğer kamerada tam olarak görünmeyen temel bir nokta varsa hesaplamayı durdur
    if (leftShoulder == null || leftHip == null || leftKnee == null || leftAnkle == null ||
        rightShoulder == null || rightHip == null || rightKnee == null || rightAnkle == null) {
      return;
    }

    // Likelihood: Yapay zekanın o noktayı doğru tespit ettiğine dair güven skoru (0.0 ile 1.0 arası).
    // Sağ ve sol tarafın ortalama güven skorunu hesaplıyoruz.
    double leftLikelihood = (leftShoulder.likelihood + leftHip.likelihood + leftKnee.likelihood + leftAnkle.likelihood) / 4;
    double rightLikelihood = (rightShoulder.likelihood + rightHip.likelihood + rightKnee.likelihood + rightAnkle.likelihood) / 4;

    // Eğer iki tarafın da güven skoru %50'nin altındaysa (örneğin kameranın yarısından çıkmışsanız)
    // yanlış (saçma) açılar üretmemek için işlemi durduruyoruz.
    if (leftLikelihood < 0.5 && rightLikelihood < 0.5) return;

    // Profil açısından (yandan) çekim yapıldığını varsayıyoruz.
    // Kameraya daha net görünen (likelihood'u yüksek olan) taraf hangisiyse, açıları o taraftan hesaplayacağız.
    final shoulder = leftLikelihood > rightLikelihood ? leftShoulder : rightShoulder;
    final hip = leftLikelihood > rightLikelihood ? leftHip : rightHip;
    final knee = leftLikelihood > rightLikelihood ? leftKnee : rightKnee;
    final ankle = leftLikelihood > rightLikelihood ? leftAnkle : rightAnkle;

    // Diz açısını hesapla (Kalça -> Diz -> Ayak Bileği üçgeni)
    double kneeAngle = _calculateAngle(
      hip.x, hip.y,
      knee.x, knee.y,
      ankle.x, ankle.y,
    );
    
    // Sırtın zeminle yaptığı mutlak açıyı hesaplar.
    // Omuz ve kalça koordinatları (X,Y) kullanılarak, doğrunun (sırtın) eğimi bulunur.
    // Formül: Eğim (m) = (Y2 - Y1) / (X2 - X1). Bunun Arctanjantı (atan) bize açıyı radyan olarak verir.
    // Çıkan sonucu pi'ye bölüp 180 ile çarparak (radyandan dereceye) çeviriyoruz.
    // 90 derece = Tam dik duruş, 0 derece = Yere tam paralel duruş.
    double dx = shoulder.x - hip.x;
    double dy = shoulder.y - hip.y;
    double backAngleToGround = atan(dy / dx).abs() * (180 / pi);

    // Durum Makinesi (State Machine)
    // Hareketin Hangi Evresinde Olduğumuzu Belirler
    if (kneeAngle > 160) {
      // 160 dereceden büyükse kullanıcı ayağa kalkmış (dik duruyor) demektir.
      if (_isSquatDown) {
        // Öncesinde çömelmiş idiyse (yani hareket tamamlandıysa)
        _score += 10;
        _feedbackText = "HARİKA! +10";
        _feedbackColor = Colors.greenAccent;
        _isSquatDown = false; // Durumu sıfırla, yeni tekrarı bekle
      } else {
        // Zaten ayaktaydıysa bekleme mesajı göster
        _feedbackText = "Aşağı Çömel!";
        _feedbackColor = Colors.yellowAccent;
      }
    } else if (kneeAngle <= 100) {
      // Diz açısı 100'ün altındaysa Çömelme (Paralel) derinliğine inilmiş demektir.
      
      // Form Kontrolü (Good Morning hatası)
      // Sırt yerle 40 dereceden dar bir açı yapıyorsa bel omurları çok fazla yük altında demektir.
      if (backAngleToGround < 40) {
        _feedbackText = "Sırtını Dik Tut! (Çok eğildin)";
        _feedbackColor = Colors.pinkAccent;
        _isSquatDown = false; // Geçersiz say, ayağa kalksa da puan verme
      } else {
        _isSquatDown = true; // Form düzgün, çömelme başarılı
        
        // Derinliğe göre özel geri bildirim (Paralel vs ATG - Ass To Grass)
        // Eğer 70 derecenin de altına (kalça diz kapağının çok altına) inebildiyse ATG sayılır.
        if (kneeAngle <= 70) {
          _feedbackText = "ATG Squat! Kusursuz Derinlik!";
          _feedbackColor = Colors.purpleAccent;
        } else {
          _feedbackText = "Güzel Paralel! Şimdi Kalk!";
          _feedbackColor = Colors.cyanAccent;
        }
      }
    }
  }

  /// 2 Boyutlu uzayda verilen 3 noktanın arasındaki iç açıyı derece cinsinden hesaplar.
  /// (Örn: p1=Kalça, p2=Diz, p3=Ayak Bileği verildiğinde Dizin bükülme açısını bulur)
  double _calculateAngle(double x1, double y1, double x2, double y2, double x3, double y3) {
    // Arctan2 fonksiyonu Y ve X farklarından radyan cinsinden açı bulur.
    double angle = atan2(y3 - y2, x3 - x2) - atan2(y1 - y2, x1 - x2);
    // Radyanı dereceye çevir
    angle = angle * (180 / pi);
    // Negatif açıyı mutlak değere al
    angle = angle.abs();
    // 180'den büyükse iç açıyı bulmak için 360'tan çıkar
    if (angle > 180) {
      angle = 360 - angle;
    }
    return angle;
  }
}

