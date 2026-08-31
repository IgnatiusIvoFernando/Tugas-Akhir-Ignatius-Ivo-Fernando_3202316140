import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tugas_akhir/view/laporan/daftar_dokumen_barang.dart';
import 'package:tugas_akhir/view/barang/grid_barang.dart';
import 'package:tugas_akhir/view/pengaturan/pengaturan.dart';
import 'package:tugas_akhir/view/laporan/daftar_struk.dart';
import 'package:tugas_akhir/view/laporan/daftar_transaksi.dart';
import 'package:tugas_akhir/view/laporan/grafik_laporan.dart';

import '../../controller/profil_controller.dart';
import '../../theme/app_colors.dart';

class AppDrawer extends StatefulWidget {
  final String selectedMenu;
  const AppDrawer({super.key, this.selectedMenu = ''});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final ProfilController _profilController = ProfilController();
  String _namaPerusahaan = "Nama Perusahaan";
  String? _fotoPath;
  @override
  void initState() {
    super.initState();
    _loadDataProfil();
  }

  Future<void> _loadDataProfil() async {
    final profil = await _profilController.getProfil();
    if (profil != null) {
      setState(() {
        _namaPerusahaan = profil.namaPerusahaan;
        _fotoPath = profil.fotoPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      backgroundColor: AppColors.backgroundLight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blue100, AppColors.blue200],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),
            _buildLogoHeader(),
            const SizedBox(height: 15),
            _buildNamaPerusahaan(),
            const SizedBox(height: 25),

            // Menu Items
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMenuItem(
                      id: "grid barang",
                      title: "DAFTAR BARANG",
                      icon: Icons.warehouse,
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.selectedMenu != "grid barang") {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const GridBarang()),
                          );
                        }
                      },
                    ),
                    _buildMenuItem(
                      id: "grafik",
                      title: "ANALISIS VISUAL",
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const GrafikLaporanPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      id: "struk",
                      title: "STRUK PENJUALAN",
                      icon: Icons.receipt_long,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DaftarStrukPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      id: "laporan_transaksi",
                      title: "LAPORAN KEUANGAN",
                      icon: Icons.assignment,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DaftarTransaksiPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      id: "dokumen",
                      title: "LAPORAN STOK",
                      icon: Icons.history_edu_sharp,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DokumenStokPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      id: "pengaturan",
                      title: "PENGATURAN",
                      icon: Icons.settings_outlined,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PengaturanPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    final bool hasImage = _fotoPath != null && File(_fotoPath!).existsSync();

    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.tertiary.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: AppColors.tertiary, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: hasImage
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(
                    File(_fotoPath!),
                    fit: BoxFit.scaleDown,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 50,
                      color: AppColors.disabled,
                    ),
                  ),
                )
              : const Icon(
                  Icons.business_center,
                  size: 50,
                  color: AppColors.accent,
                ),
        ),
      ),
    );
  }

  Widget _buildNamaPerusahaan() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.primary),
      ),
      child: Center(
        child: Text(
          _namaPerusahaan.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            letterSpacing: 1.2,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String id,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    bool isActive = widget.selectedMenu == id;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
                ? [AppColors.primary, AppColors.blue200]
                : [AppColors.blue400, AppColors.tertiary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tertiary.withValues(alpha: 0.4),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
          border: Border.all(color: AppColors.white, width: 1.5),
        ),
        child: Stack(
          children: [
            // Efek Glossy
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0.35),
                      AppColors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w900,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
