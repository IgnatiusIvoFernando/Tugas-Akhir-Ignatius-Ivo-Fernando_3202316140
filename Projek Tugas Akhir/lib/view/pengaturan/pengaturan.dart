import 'package:flutter/material.dart';
import 'package:tugas_akhir/theme/app_styles.dart';
import 'package:tugas_akhir/view/pengaturan/profil_perusahaan.dart';
import 'package:tugas_akhir/view/pengaturan/daftar_kategori.dart';
import 'package:tugas_akhir/view/pengaturan/daftar_merek.dart';
import 'package:tugas_akhir/view/pengaturan/pemasok_pelanggan.dart';
import 'package:tugas_akhir/view/pengaturan/cadangan_data.dart';
import '../widgets/app_drawer.dart';
import '../../theme/app_colors.dart';

/// Halaman Pusat Pengaturan Aplikasi

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Daftar menu pengaturan menggunakan List of Maps untuk kemudahan pengelolaan (Dynamic List)
    final List<Map<String, dynamic>> daftarMenu = [
      {
        'judul': 'Profil Perusahaan',
        'subjudul': 'Nama, alamat, dan logo toko',
        'ikon': Icons.business_rounded,
        'halamanTujuan': const ProfilPerusahaanPage(),
      },
      {
        'judul': 'Daftar Kategori',
        'subjudul': 'Pengelompokan jenis barang',
        'ikon': Icons.category_rounded,
        'halamanTujuan': const DaftarKategori(),
      },
      {
        'judul': 'Daftar Merek',
        'subjudul': 'Manajemen brand produk',
        'ikon': Icons.branding_watermark_rounded,
        'halamanTujuan': const DaftarMerek(),
      },
      {
        'judul': 'Pemasok & Pelanggan',
        'subjudul': 'Buku kontak dan riwayat hutang',
        'ikon': Icons.contact_phone_rounded,
        'halamanTujuan': const PemasokPelangganPage(),
      },
      {
        'judul': 'Cadangkan & Pulihkan Data',
        'subjudul': 'Ekspor/Impor database sistem',
        'ikon': Icons.cloud_sync_rounded,
        'halamanTujuan': const CadanganDataPage(),
      },
    ];

    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      appBar: AppBar(
        title: const Text('Pengaturan Sistem', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GridView.builder(
                itemCount: daftarMenu.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Menampilkan 2 kolom grid
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1, // Rasio lebar:tinggi kartu
                ),
                itemBuilder: (context, index) {
                  final menu = daftarMenu[index];
                  return _buildKartuMenu(
                    context,
                    judul: menu['judul'] as String,
                    ikon: menu['ikon'] as IconData,
                    tujuan: menu['halamanTujuan'] as Widget,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun widget kartu menu yang interaktif.
  Widget _buildKartuMenu(
    BuildContext context, {
    required String judul,
    required IconData ikon,
    required Widget tujuan,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => tujuan));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5), width: 1.5),
          color: AppColors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon menu dengan warna sekunder aplikasi
            Flexible(child: Icon(ikon, size: 42, color: AppColors.secondary)),
            const SizedBox(height: 12),
            // Judul menu dengan teks yang tebal
            Text(
              judul,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
