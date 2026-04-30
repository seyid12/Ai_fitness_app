import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pose_detector_view.dart';

void main() {
  // Flutter motorunun (engine) düzgün başlatıldığından emin ol
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiFitnessApp());
}

/// Uygulamanın kök bileşeni (Root Widget). Tema (renkler, fontlar) burada ayarlanır.
class AiFitnessApp extends StatelessWidget {
  const AiFitnessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Squat AI',
      debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" yazısını kaldır
      theme: ThemeData(
        brightness: Brightness.dark, // Karanlık mod
        primaryColor: Colors.cyanAccent, // Ana renk (Neon mavi)
        scaffoldBackgroundColor: const Color(0xFF0A0A1A), // Arka plan (Koyu lacivert/siyah)
        fontFamily: 'Roboto', // Modern bir font
        // Tüm butonların varsayılan görünüm ayarları
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent, // Buton rengi (Neon pembe)
            foregroundColor: Colors.white,      // Yazı rengi
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Yuvarlatılmış köşeler
            ),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomeScreen(), // Açılış sayfası
    );
  }
}

/// Uygulama ilk açıldığında görünen "Ana Ekran". 
/// Kullanıcıdan kamera izni almaktan ve asıl oyun sayfasına yönlendirmekten sorumludur.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  /// Kameraya erişim izni ister. İzin verilirse PoseDetectorView sayfasına geçer.
  Future<void> _checkPermissionAndStart(BuildContext context) async {
    // İşletim sisteminden (Android/iOS) kamera izni penceresi talep et
    final status = await Permission.camera.request();
    
    // Asenkron (await) bir işlemden sonra context'in hala geçerli olup olmadığını kontrol etmeliyiz
    if (!context.mounted) return; 
    
    if (status.isGranted) {
      // İzin verildiyse kamerayı açacak olan asıl sayfaya git
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PoseDetectorView()),
      );
    } else {
      // İzin reddedildiyse alt kısımda uyarı mesajı göster (SnackBar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera izni gereklidir!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold, temel sayfa yapısını (arkaplan, body vb.) sağlar
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dambıl İkonu
            const Icon(
              Icons.fitness_center,
              size: 100,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 20),
            // Başlık Yazısı ve Neon Parlama Efekti (Shadow)
            const Text(
              'NEON SQUAT AI',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.pinkAccent,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Alt Başlık
            const Text(
              'Yapay Zeka ile Formunu Test Et',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 50),
            // Oyuna Başla Butonu
            ElevatedButton(
              onPressed: () => _checkPermissionAndStart(context),
              child: const Text('OYUNA BAŞLA'),
            ),
          ],
        ),
      ),
    );
  }
}
