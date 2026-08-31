import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../controller/profil_controller.dart';
import '../../controller/database_helper.dart';
import '../../controller/notification_util.dart';
import '../../models/profil_perusahaan.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../main.dart'; // Impor untuk mengakses navigatorKey

// Import halaman peta LocationPickerPage
import 'location_picker_page.dart';

class SetupAwalPage extends StatefulWidget {
  const SetupAwalPage({super.key});

  @override
  State<SetupAwalPage> createState() => _SetupAwalPageState();
}

class _SetupAwalPageState extends State<SetupAwalPage> {
  final _keyFormUtama = GlobalKey<FormState>();

  // Variabel penampung hasil Peta / GPS
  String? _negaraTerpilih, _provinsiTerpilih, _kotaTerpilih, _industriTerpilih;
  String? _jalurFotoLogo;
  bool _sedangMenyimpan = false;
  bool _notifikasiAktif = true;

  final _namaTokoC = TextEditingController();
  final _alamatC = TextEditingController();

  final Map<String, List<String>> _kategoriOtomatisMap = {
    'Retail': ['Sembako', 'Rumah Tangga', 'Sabun', 'Snack', 'Bumbu'],
    'Warung': ['Makanan', 'Minuman', 'Gorengan', 'Rokok', 'Lain-lain'],
    'Lainnya': ['Umum', 'Produk', 'Jasa'],
  };

  @override
  void dispose() {
    _namaTokoC.dispose();
    _alamatC.dispose();
    super.dispose();
  }

  // FITUR: Membuka Halaman Peta & Menerima Data Alamat Lengkap
  Future<void> _bukaPetaPilihLokasi() async {
    final hasil = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    // Menerima data kembalian dari LocationPickerPage
    if (hasil != null && hasil is Map<String, dynamic>) {
      final String? alamatFormatted = hasil['alamatFormatted'] as String?;
      final double? lat = hasil['latitude'] as double?;
      final double? lng = hasil['longitude'] as double?;

      if (alamatFormatted != null && alamatFormatted.isNotEmpty) {
        setState(() {
          // 1. Masukkan alamat lengkap dari peta ke TextFormField Alamat
          _alamatC.text = alamatFormatted;

          // 2. Set penanda bahwa peta sudah dipilih
          _kotaTerpilih = "Peta Terpilih";
          _provinsiTerpilih = "${lat?.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}";
        });

        if (mounted) {
          AppStyles.showSuccessSnackBar(context, "Lokasi dari peta berhasil dipilih!");
        }
      }
    }
  }

  Future<void> _ambilFotoLogo() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'logo_init_${DateTime.now().millisecondsSinceEpoch}${path.extension(p.path)}';
    final saved = await File(p.path).copy('${dir.path}/$fileName');

    setState(() => _jalurFotoLogo = saved.path);
  }

  Future<void> _selesaikanSetup() async {
    if (!_keyFormUtama.currentState!.validate()) return;
    if (_industriTerpilih == null) {
      AppStyles.showWarningSnackBar(context, "Pilih jenis usaha Anda");
      return;
    }

    setState(() => _sedangMenyimpan = true);

    try {
      final profil = ProfilPerusahaan(
        namaPerusahaan: _namaTokoC.text.trim(),
        jenisIndustri: _industriTerpilih!,
        negara: _negaraTerpilih ?? '',
        provinsi: _provinsiTerpilih ?? '',
        kota: _kotaTerpilih ?? '',
        alamat: _alamatC.text.trim(),
        fotoPath: _jalurFotoLogo,
        headerStruk: "Selamat Datang di ${_namaTokoC.text}",
        footerStruk: "Terima Kasih Telah Berbelanja",
        notifikasiAktif: _notifikasiAktif,
      );

      final int profilId = await ProfilController().simpanProfil(profil);

      final db = await DatabaseHelper().database;
      await db.transaction((txn) async {
        List<String> listKat = _kategoriOtomatisMap[_industriTerpilih] ?? ["Umum"];
        for (var kat in listKat) {
          await txn.insert('kategori', {
            'profil_id': profilId,
            'nama': kat,
            'keterangan': 'Dibuat otomatis'
          });
        }
        await txn.insert('merek', {
          'profil_id': profilId,
          'nama': 'Tanpa Merek',
          'keterangan': 'Default'
        });
      });

      if (_notifikasiAktif) {
        // PERBAIKAN: Inisialisasi notifikasi dengan navigatorKey agar navigasi berfungsi
        await LocalNotificationUtil.init(navKey: navigatorKey);
        await Future.wait([
          LocalNotificationUtil.cekStokMenipis(force: true),
          LocalNotificationUtil.cekDanNotifikasiKadaluarsa(force: true),
        ]);
        await LocalNotificationUtil.initWorkManager();
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Setup Profil Perusahaan', style: AppStyles.appBarTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
        child: Form(
          key: _keyFormUtama,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildSelectorFoto()),
              const SizedBox(height: 30),
              _buildInputField("Nama Perusahaan / Toko", _namaTokoC, wajib: true, hint: "Contoh: Toko Berkah"),
              _buildDropdown("Jenis Industri / Usaha", _industriTerpilih, _kategoriOtomatisMap.keys.toList(), (val) {
                setState(() => _industriTerpilih = val);
              }),
              if (_industriTerpilih != null) ...[
                const Text("Kategori barang otomatis yang akan dibuat:", style: TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                _buildInfoKategoriOtomatis(),
                const SizedBox(height: 16),
              ],
              const Divider(height: 40),
              Text("Lokasi Toko", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),

              // TOMBOL BUKA PETA LOKASI
              OutlinedButton.icon(
                onPressed: _sedangMenyimpan ? null : _bukaPetaPilihLokasi,
                icon: Icon(_kotaTerpilih != null ? Icons.map : Icons.my_location),
                label: Text(
                  _kotaTerpilih != null ? "UBAH LOKASI DI PETA" : "PILIH LOKASI DI PETA",
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              if (_kotaTerpilih != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Koordinat: ${_provinsiTerpilih ?? ''}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 16),

              _buildInputField("Alamat Lengkap", _alamatC, baris: 3, wajib: true, hint: "Jl. Merdeka No. 123..."),
              const Divider(height: 40),
              _buildToggleNotifikasi(),
              const SizedBox(height: 40),
              _buildTombolSimpan(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Helpers ---
  Widget _buildSelectorFoto() {
    final hasImage = _jalurFotoLogo != null && File(_jalurFotoLogo!).existsSync();
    return GestureDetector(
      onTap: _sedangMenyimpan ? null : _ambilFotoLogo,
      child: Stack(
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              image: hasImage ? DecorationImage(image: FileImage(File(_jalurFotoLogo!)), fit: BoxFit.contain) : null,
            ),
            child: hasImage ? null : const Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primary),
          ),
          if (hasImage)
            const Positioned(
              bottom: 0, right: 0,
              child: CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.edit, color: Colors.white, size: 16)),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool wajib = false, int baris = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: baris,
          decoration: InputDecoration(hintText: hint ?? "Masukkan $label", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(12), filled: true, fillColor: Colors.white),
          validator: (v) => wajib && (v == null || v.trim().isEmpty) ? 'Harap isi $label' : null,
        ),
      ],
    ),
  );

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: (value != null && items.contains(value)) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(hintText: "Pilih $label", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(12), filled: true, fillColor: Colors.white),
          items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _sedangMenyimpan ? null : onChanged,
          validator: (val) => (val == null || val.isEmpty) ? 'Pilih $label' : null,
        ),
      ],
    ),
  );

  Widget _buildInfoKategoriOtomatis() {
    return Wrap(
      spacing: 6,
      children: (_kategoriOtomatisMap[_industriTerpilih] ?? []).map((k) => Chip(
        label: Text(k, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.blue50,
        side: BorderSide.none,
      )).toList(),
    );
  }

  Widget _buildToggleNotifikasi() {
    return Material(
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: const Text("Aktifkan Notifikasi Sistem", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
        subtitle: const Text("Pengingat stok dan kadaluarsa.", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        value: _notifikasiAktif,
        activeThumbColor: AppColors.primary,
        onChanged: _sedangMenyimpan ? null : (val) => setState(() => _notifikasiAktif = val),
      ),
    );
  }

  Widget _buildTombolSimpan() {
    return ElevatedButton(
      onPressed: _sedangMenyimpan ? null : _selesaikanSetup,
      style: AppStyles.primaryButton,
      child: _sedangMenyimpan
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const FittedBox(fit: BoxFit.scaleDown, child: Text("SIMPAN & MULAI")),
    );
  }
}
