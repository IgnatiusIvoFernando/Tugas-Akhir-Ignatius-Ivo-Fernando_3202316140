import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'database_helper.dart';
import 'profil_controller.dart';

/// Utilitas untuk mengelola notifikasi lokal dan tugas latar belakang (Workmanager).
class LocalNotificationUtil {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _lastNotifBody;
  static DateTime? _lastGlobalNotifTime; // Untuk cooldown antar semua jenis notif
  static DateTime? _lastSameBodyNotifTime; // Untuk throttling isi yang sama
  static GlobalKey<NavigatorState>? navigatorKey;

  static const int _notifIdExpiredToday = 10;
  static const int _notifIdExpiredOverdue = 13;
  static const int _notifIdStokHabis = 20;
  static const int _notifIdStokMenipis = 21;

  static Future<void> init({GlobalKey<NavigatorState>? navKey, bool requestPerms = true}) async {
    if (navKey != null) navigatorKey = navKey;

    if (!_isInitialized) {
      tzdata.initializeTimeZones();
      await _setupTimeZone();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onTapNotification,
      );
      _isInitialized = true;
    }

    if (requestPerms) {
      await requestPermissions();
    }
  }

  static Future<void> _setupTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (__) {}
    }
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static void _onTapNotification(NotificationResponse response) {
    if (navigatorKey?.currentState == null) return;
    final payload = response.payload;
    if (payload == null) return;
    
    if (['stok_habis', 'stok_menipis', 'kadaluarsa_hari_ini', 'kadaluarsa_terlewat'].contains(payload)) {
      navigatorKey!.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'default_channel',
    String channelName = 'Peringatan Aplikasi',
    Importance importance = Importance.high,
    bool force = false,
  }) async {
    final profil = await ProfilController().getProfil();
    if (profil == null || !profil.notifikasiAktif) return;

    if (!_isInitialized) await init(requestPerms: false);

    final now = DateTime.now();

    // 1. GLOBAL COOLDOWN: Jangan berisik. Jika ada notifikasi apa pun dalam 1 menit terakhir,
    // abaikan notifikasi baru kecuali dipaksa (force). Ini mencegah double ping (stok & kadaluarsa barengan).
    if (!force && _lastGlobalNotifTime != null && 
        now.difference(_lastGlobalNotifTime!).inMinutes < 1) {
      return;
    }

    // 2. SAME CONTENT THROTTLING: Jangan kirim isi yang sama berkali-kali.
    // Jika isi notifikasi sama persis dengan sebelumnya, tunggu 15 menit sebelum kirim lagi.
    if (!force && _lastNotifBody == body && _lastSameBodyNotifTime != null &&
        now.difference(_lastSameBodyNotifTime!).inMinutes < 15) {
      return;
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );

    // Update state tracker
    if (_lastNotifBody == body) {
      _lastSameBodyNotifTime = now;
    } else {
      _lastNotifBody = body;
      _lastSameBodyNotifTime = now;
    }
    _lastGlobalNotifTime = now;
  }

  static Future<void> cekStokMenipis({bool force = false}) async {
    if (!_isInitialized) await init(requestPerms: false);

    final db = await DatabaseHelper().database;
    final barangList = await db.rawQuery("SELECT nama, stok FROM barang WHERE stok <= 5 AND stok >= 0 AND is_deleted = 0 ORDER BY stok ASC");

    if (barangList.isEmpty) return;

    List<String> habis = [], menipis = [];
    for (var b in barangList) {
      double s = (b['stok'] as num).toDouble();
      if (s <= 0) {
        habis.add(b['nama'] as String);
      } else {
        menipis.add("${b['nama']} (${_formatAngka(s)})");
      }
    }

    if (habis.isNotEmpty) {
      await showNotification(
        id: _notifIdStokHabis,
        title: '⚠️ Stok Habis!',
        body: '${habis.length} barang habis: ${habis.take(3).join(', ')}',
        payload: 'stok_habis',
        force: force,
      );
    } else if (menipis.isNotEmpty) {
      await showNotification(
        id: _notifIdStokMenipis,
        title: '📦 Stok Menipis',
        body: '${menipis.length} barang hampir habis: ${menipis.take(3).join(', ')}',
        payload: 'stok_menipis',
        force: force,
      );
    }
  }

  static Future<void> cekDanNotifikasiKadaluarsa({bool force = false}) async {
    if (!_isInitialized) await init(requestPerms: false);

    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final barangList = await db.rawQuery("SELECT nama, tanggal_kadaluarsa_int FROM barang WHERE tanggal_kadaluarsa_int IS NOT NULL AND is_deleted = 0");

    List<String> expiredToday = [], alreadyExpired = [];
    for (var b in barangList) {
      final timestamp = b['tanggal_kadaluarsa_int'] as int?;
      if (timestamp == null) continue;

      final expDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final expDateOnly = DateTime(expDate.year, expDate.month, expDate.day);
      final diff = expDateOnly.difference(todayOnly).inDays;

      if (diff < 0) {
        alreadyExpired.add(b['nama'] as String);
      } else if (diff == 0) {
        expiredToday.add(b['nama'] as String);
      }
    }

    if (alreadyExpired.isNotEmpty) {
      await showNotification(
        id: _notifIdExpiredOverdue,
        title: '🚫 Barang Kadaluarsa!',
        body: '${alreadyExpired.length} barang kadaluarsa.',
        payload: 'kadaluarsa_terlewat',
        force: force,
      );
    } else if (expiredToday.isNotEmpty) {
      await showNotification(
        id: _notifIdExpiredToday,
        title: '⏰ Kadaluarsa Hari Ini',
        body: '${expiredToday.length} barang kadaluarsa hari ini.',
        payload: 'kadaluarsa_hari_ini',
        force: force,
      );
    }
  }

  static Future<void> cancelNotification({required int id}) async =>
      await _notificationsPlugin.cancel(id: id);

  static Future<void> cancelAllNotifications() async =>
      await _notificationsPlugin.cancelAll();

  static Future<void> initWorkManager() async {
    await Workmanager().registerPeriodicTask(
      "cek-notifikasi-background",
      "cek-notifikasi-background",
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> stopWorkManager() async {
    await Workmanager().cancelByTag("cek-notifikasi-background");
  }

  static String _formatAngka(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  static Future<void> backgroundTask() async {
    WidgetsFlutterBinding.ensureInitialized();
    await init(requestPerms: false);
    await cekDanNotifikasiKadaluarsa(force: false);
    await cekStokMenipis(force: false);
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await LocalNotificationUtil.backgroundTask();
    return Future.value(true);
  });
}
