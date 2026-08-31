import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tugas_akhir/view/barang/grid_barang.dart';
import 'package:tugas_akhir/view/pengaturan/setup_awal.dart';
import 'package:tugas_akhir/view/laporan/daftar_transaksi.dart';
import 'package:tugas_akhir/controller/profil_controller.dart';
import 'package:tugas_akhir/controller/notification_util.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import 'models/profil_perusahaan.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await initializeDateFormatting('id', null);
  await LocalNotificationUtil.init(navKey: navigatorKey, requestPerms: false);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  ProfilPerusahaan? profil;
  try {
    profil = await ProfilController().getProfil();
  } catch (e) {
    debugPrint('Error loading profil: $e');
  }

  runApp(MyApp(isFirstTime: profil == null));

  if (profil != null && profil.notifikasiAktif) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocalNotificationUtil.requestPermissions();
        LocalNotificationUtil.cekDanNotifikasiKadaluarsa();
        LocalNotificationUtil.cekStokMenipis();
        await LocalNotificationUtil.initWorkManager();
      } catch (e) {
        debugPrint('Notification Init Error: $e');
      }
    });
  }
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Stok Barang Jualan',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => isFirstTime ? const SetupAwalPage() : const GridBarang(),
        '/home': (context) => const GridBarang(), // Rute langsung ke Home
        '/laporan_keuangan': (context) => const DaftarTransaksiPage(),
      },
    );
  }
}
