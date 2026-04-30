import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Bu bileşen, cihazın kamerasını açıp saniyede ~30 kere canlı görüntü kareleri (frame) yakalar.
/// Yakalanan her kare, ML Kit'in anlayacağı bir "InputImage" nesnesine dönüştürülüp üst katmana iletilir.
class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.customPaint, // İskelet çizgilerini çizdiğimiz katman
    required this.onImage,     // Yakalanan görüntüyü yapay zekaya göndereceğimiz fonksiyon
    this.initialDirection = CameraLensDirection.front, // Varsayılan olarak ön kamera
  }) : super(key: key);

  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  int _cameraIndex = -1;
  List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Mevcut kameraları bulur ve istenen yön (ön/arka) kamerayı seçer.
  void _initialize() async {
    if (cameras.isEmpty) {
      cameras = await availableCameras();
    }
    for (var i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == widget.initialDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed(); // Sayfa kapanırken kamerayı kapatarak batarya sızıntısını önler
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kamera henüz açılmadıysa siyah ekranda yükleniyor simgesi göster
    if (_controller?.value.isInitialized == false) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Arkada kameranın canlı önizlemesi (kullanıcı kendini görür)
          if (_controller != null)
            CameraPreview(_controller!),
          
          // Kameranın üzerine bindirilen (overlay) iskelet çizimleri
          if (widget.customPaint != null) widget.customPaint!,
        ],
      ),
    );
  }

  /// Kamera donanımını başlatır ve sürekli görüntü akışını (stream) açar
  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Performans için orta çözünürlük yeterlidir
      enableAudio: false,      // Ses gerekmediği için mikrofonu kapalı tutuyoruz
      // İşletim sistemine (Android/iOS) göre kameranın doğal görüntü formatı seçilir
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      // Görüntü akışı başladığında her yeni kare "_processCameraImage" fonksiyonuna gönderilir
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  /// Kameradan gelen raw (ham) kareyi (CameraImage) ML Kit formatına çevirir
  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage); // Çevrilen görüntüyü analize (PoseDetector'a) gönder
  }

  /// CameraImage nesnesini, Google ML Kit'in beklediği InputImage formatına çevirme algoritması
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    // Resmin rotasyonunu ayarlama (Kullanıcı telefonu yan tutarsa açıların düzgün kalması için)
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // Ön kamera için ayna etkisi (mirroring) dengelemesi
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // Resim formatını doğrulama
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.isEmpty) return null;

    // ML Kit için nihai InputImage nesnesi oluşturuluyor
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()), // Çözünürlük bilgisi
        rotation: rotation, // Dönüş bilgisi
        format: format,     // Renk formatı (nv21 veya bgra8888)
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // Cihazın tutuluş yönüne göre eklenecek dönüş dereceleri (Kamera açısı düzeltmesi)
  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
