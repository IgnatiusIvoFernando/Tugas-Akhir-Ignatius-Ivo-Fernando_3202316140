import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../controller/profil_controller.dart';
import '../../controller/notification_util.dart';
import '../../models/profil_perusahaan.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../main.dart'; // Impor untuk mengakses navigatorKey

// Import halaman peta LocationPickerPage
import 'location_picker_page.dart';

class ProfilPerusahaanPage extends StatefulWidget {
  const ProfilPerusahaanPage({super.key});

  @override
  State<ProfilPerusahaanPage> createState() => _ProfilPerusahaanPageState();
}

class _ProfilPerusahaanPageState extends State<ProfilPerusahaanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _keyFormProfil = GlobalKey<FormState>();
  final _keyFormStruk = GlobalKey<FormState>();

  // Variabel penampung hasil Peta / GPS
  String? _negaraTerpilih, _provinsiTerpilih, _kotaTerpilih, _industriTerpilih;
  String? _jalurFotoLogo;
  bool _sedangMemuat = true;
  bool _sedangMenyimpan = false;
  bool _notifikasiAktif = true;

  final _namaTokoC = TextEditingController();
  final _alamatC = TextEditingController();
  final _headerStrukC = TextEditingController();
  final _footerStrukC = TextEditingController();

  final Map<String, List<String>> _kategoriOtomatisMap = {
    'Retail': ['Sembako', 'Rumah Tangga', 'Sabun', 'Snack', 'Bumbu'],
    'Warung': ['Makanan', 'Minuman', 'Gorengan', 'Rokok', 'Lain-lain'],
    'Lainnya': ['Umum', 'Produk', 'Jasa'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _muatDataAwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _namaTokoC.dispose();
    _alamatC.dispose();
    _headerStrukC.dispose();
    _footerStrukC.dispose();
    super.dispose();
  }

  Future<void> _muatDataAwal() async {
    try {
      final profilData = await ProfilController().getProfil();
      if (mounted) {
        setState(() {
          if (profilData != null) {
            _namaTokoC.text = profilData.namaPerusahaan;
            _alamatC.text = profilData.alamat;
            _jalurFotoLogo = profilData.fotoPath;
            _headerStrukC.text = profilData.headerStruk ?? '';
            _footerStrukC.text = profilData.footerStruk ?? '';
            _notifikasiAktif = profilData.notifikasiAktif;
            _industriTerpilih = profilData.jenisIndustri;
            
            // Lokasi (Koordinat disimpan di kolom negara/provinsi/kota oleh setup_awal)
            _negaraTerpilih = profilData.negara;
            _provinsiTerpilih = profilData.provinsi;
            _kotaTerpilih = profilData.kota;
          }
          _sedangMemuat = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sedangMemuat = false);
    }
  }

  Future<void> _bukaPetaPilihLokasi() async {
    final hasil = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    if (hasil != null && hasil is Map<String, dynamic>) {
      final String? alamatFormatted = hasil['alamatFormatted'] as String?;
      final double? lat = hasil['latitude'] as double?;
      final double? lng = hasil['longitude'] as double?;

      if (alamatFormatted != null && alamatFormatted.isNotEmpty) {
        setState(() {
          _alamatC.text = alamatFormatted;
          _kotaTerpilih = "Peta Terpilih";
          _provinsiTerpilih = "${lat?.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}";
        });
      }
    }
  }

  Future<void> _ambilFotoLogo() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
    final saved = await File(image.path).copy('${directory.path}/$fileName');
    
    setState(() => _jalurFotoLogo = saved.path);
  }

  Future<void> _prosesSimpan() async {
    if (_sedangMenyimpan) return;
    
    final profilValid = _keyFormProfil.currentState?.validate() ?? true;
    final strukValid = _keyFormStruk.currentState?.validate() ?? true;

    if (!profilValid || !strukValid) {
      _tabController.animateTo(!profilValid ? 0 : 1);
      AppStyles.showWarningSnackBar(context, 'Mohon lengkapi seluruh data wajib!');
      return;
    }

    setState(() => _sedangMenyimpan = true);
    
    final profil = ProfilPerusahaan(
      namaPerusahaan: _namaTokoC.text.trim(),
      jenisIndustri: _industriTerpilih ?? 'Lainnya',
      negara: _negaraTerpilih ?? '',
      provinsi: _provinsiTerpilih ?? '',
      kota: _kotaTerpilih ?? '',
      alamat: _alamatC.text.trim(),
      fotoPath: _jalurFotoLogo,
      headerStruk: _headerStrukC.text.trim(),
      footerStruk: _footerStrukC.text.trim(),
      notifikasiAktif: _notifikasiAktif,
    );

    try {
      await ProfilController().simpanProfil(profil);

      if (_notifikasiAktif) {
        await LocalNotificationUtil.init(navKey: navigatorKey);
        await Future.wait([
          LocalNotificationUtil.cekStokMenipis(force: true),
          LocalNotificationUtil.cekDanNotifikasiKadaluarsa(force: true),
        ]);
        await LocalNotificationUtil.initWorkManager();
      } else {
        await LocalNotificationUtil.cancelAllNotifications();
        await LocalNotificationUtil.stopWorkManager();
      }

      if (mounted) {
        AppStyles.showSuccessSnackBar(context, 'Berhasil disimpan!');
        _muatDataAwal();
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sedangMemuat) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Profil & Struk', style: AppStyles.appBarTitle),
        iconTheme: AppStyles.appBarIconTheme,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.warning,
          tabs: const [
            Tab(text: 'IDENTITAS', icon: Icon(Icons.store_rounded)),
            Tab(text: 'NOTA / STRUK', icon: Icon(Icons.receipt_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormIdentitas(),
          _buildFormStruk(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFormIdentitas() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _keyFormProfil,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildSelectorFoto()),
              const SizedBox(height: 30),
              _buildInputField("Nama Perusahaan / Toko", _namaTokoC, wajib: true),
              _buildDropdown("Jenis Industri / Usaha", _industriTerpilih, _kategoriOtomatisMap.keys.toList(), (val) {
                setState(() => _industriTerpilih = val);
              }),
              const Divider(height: 40),
              Text("Lokasi Toko", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              
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
                  ),
                ),
              const SizedBox(height: 16),

              _buildInputField("Alamat Lengkap", _alamatC, baris: 3, wajib: true),
              const Divider(height: 40),
              _buildToggleNotifikasi(),
            ],
          ),
        ),
      );

  Widget _buildFormStruk() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _keyFormStruk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PENGATURAN TAMPILAN NOTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              const SizedBox(height: 8),
              const Text("Teks di bawah ini akan tercetak secara otomatis pada setiap struk belanja.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              _buildInputField("Header Struk", _headerStrukC, hint: "Contoh: Toko Makmur - Telp. 08123456789"),
              _buildInputField("Footer Struk", _footerStrukC, hint: "Contoh: Terima Kasih Telah Berbelanja", baris: 3),
            ],
          ),
        ),
      );

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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: (value != null && items.contains(value)) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(hintText: "Pilih $label", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(12), filled: true, fillColor: Colors.white),
          items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _sedangMenyimpan ? null : onChanged,
          validator: (val) => (val == null || val.isEmpty) ? 'Pilih $label' : null,
        ),
      ],
    ),
  );

  Widget _buildToggleNotifikasi() {
    return Material(
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: const Text("Aktifkan Notifikasi Sistem", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text("Pengingat stok dan kadaluarsa.", style: TextStyle(fontSize: 12)),
        value: _notifikasiAktif,
        activeThumbColor: AppColors.primary,
        onChanged: _sedangMenyimpan ? null : (val) => setState(() => _notifikasiAktif = val),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: ElevatedButton(
        onPressed: _sedangMenyimpan ? null : _prosesSimpan,
        style: AppStyles.primaryButton,
        child: _sedangMenyimpan
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const FittedBox(fit: BoxFit.scaleDown, child: Text("SIMPAN SELURUH DATA")),
      ),
    );
  }
}
