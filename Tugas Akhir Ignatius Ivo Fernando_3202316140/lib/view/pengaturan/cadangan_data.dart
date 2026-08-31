import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_styles.dart';
import '../../controller/database_helper.dart';
import '../../theme/app_colors.dart';

/// Halaman Cadangan dan Pulihkan Data (Backup & Restore)
class CadanganDataPage extends StatefulWidget {
  const CadanganDataPage({super.key});

  @override
  State<CadanganDataPage> createState() => _CadanganDataPageState();
}

class _CadanganDataPageState extends State<CadanganDataPage> {
  bool _sedangDiproses = false;

  /// Logika Backup: Mengirim file database (.db) ke aplikasi lain
  Future<void> _prosesBagikanCadangan() async {
    setState(() => _sedangDiproses = true);
    try {
      final pathDB = await DatabaseHelper().getDatabasePath();
      final fileDB = File(pathDB);

      if (await fileDB.exists()) {
        // PERBAIKAN: Menggunakan SharePlus.instance.share sesuai rekomendasi terbaru
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(pathDB, name: 'stok_barang_backup.db')],
            text: 'File Cadangan Database Stok Barang - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
          ),
        );
      } else {
        throw 'File database tidak ditemukan di sistem.';
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _sedangDiproses = false);
    }
  }

  /// Download cadangan ke penyimpanan lokal
  Future<void> _prosesDownloadCadangan() async {
    setState(() => _sedangDiproses = true);
    try {
      final pathDB = await DatabaseHelper().getDatabasePath();
      final fileDB = File(pathDB);

      if (await fileDB.exists()) {
        Directory? downloadDir;
        if (Platform.isAndroid) {
          downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            downloadDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadDir = await getApplicationDocumentsDirectory();
        } else {
          downloadDir = await getDownloadsDirectory();
        }

        if (downloadDir == null) throw 'Tidak dapat mengakses direktori download';

        final tanggal = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'stok_barang_backup_$tanggal.db';
        final savePath = '${downloadDir.path}/$fileName';

        await fileDB.copy(savePath);

        if (mounted) AppStyles.showSuccessSnackBar(context, 'Cadangan disimpan di: $savePath');
        if (mounted) _showDownloadSuccessDialog(savePath);
      } else {
        throw 'File database tidak ditemukan di sistem.';
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal download: $e');
    } finally {
      if (mounted) setState(() => _sedangDiproses = false);
    }
  }

  void _showDownloadSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Berhasil!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File cadangan telah disimpan di:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Logika Restore: Mengganti file database yang aktif dengan file cadangan
  Future<void> _prosesPulihkanData() async {
    try {
      // Menggunakan FilePicker.pickFiles() (tanpa .platform untuk versi terbaru)
      FilePickerResult? hasilPilihan = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (hasilPilihan != null && hasilPilihan.files.single.path != null) {
        File fileCadangan = File(hasilPilihan.files.single.path!);

        if (await fileCadangan.length() == 0) throw 'File cadangan tidak valid atau kosong.';

        if (!mounted) return;

        bool? konfirmasi = await _dialogKonfirmasi();

        if (konfirmasi == true) {
          setState(() => _sedangDiproses = true);

          final pathDBAktif = await DatabaseHelper().getDatabasePath();

          // Menutup koneksi database sebelum melakukan replace file
          await DatabaseHelper().close();

          await Future.delayed(const Duration(milliseconds: 500));

          await fileCadangan.copy(pathDBAktif);

          if (!mounted) return;
          _showDialogSukses();
        }
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal Pulihkan: $e');
    } finally {
      if (mounted) setState(() => _sedangDiproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangkan & Pulihkan Data', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: _sedangDiproses
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
        child: ListView(
          children: [
            _buildCardMenu(
              judul: 'Bagikan Cadangan (Cloud)',
              deskripsi: 'Kirim file database ke Google Drive, WhatsApp, atau email.',
              ikon: Icons.cloud_upload_rounded,
              warna: Colors.blue,
              onTap: _prosesBagikanCadangan,
            ),
            const SizedBox(height: 20),
            _buildCardMenu(
              judul: 'Download Cadangan',
              deskripsi: 'Simpan file database ke folder Download perangkat.',
              ikon: Icons.download_rounded,
              warna: Colors.green,
              onTap: _prosesDownloadCadangan,
            ),
            const SizedBox(height: 20),
            _buildCardMenu(
              judul: 'Pulihkan Data (Restore)',
              deskripsi: 'Ganti data saat ini dengan data dari file cadangan.',
              ikon: Icons.settings_backup_restore_rounded,
              warna: Colors.orange,
              onTap: _prosesPulihkanData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMenu({
    required String judul,
    required String deskripsi,
    required IconData ikon,
    required Color warna,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(ikon, color: warna, size: 30),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(deskripsi, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _dialogKonfirmasi() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pulihkan Data?'),
      content: const Text('Data saat ini akan dihapus dan diganti dengan data cadangan. Lanjutkan?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('PULIHKAN', style: TextStyle(color: Colors.red))),
      ],
    ),
  );

  void _showDialogSukses() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Berhasil!'),
        content: const Text('Data dipulihkan. Aplikasi akan ditutup untuk menerapkan perubahan.'),
        actions: [
          TextButton(onPressed: () => exit(0), child: const Text('TUTUP')),
        ],
      ),
    );
  }
}
