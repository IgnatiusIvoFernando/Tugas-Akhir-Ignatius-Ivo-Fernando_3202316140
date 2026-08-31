import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../controller/database_helper.dart';
import '../../controller/dokumen_controller.dart';
import '../../controller/barang_controller.dart';
import '../../models/barang.dart';
import '../../models/dokumen_item.dart';
import '../../models/dokumen_stok.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../theme/struk_service.dart';
import '../barang/grid_barang.dart';

class BarangKeluar extends StatefulWidget {
  final List<Barang> items;
  const BarangKeluar({super.key, required this.items});

  factory BarangKeluar.single({required Barang barang}) => BarangKeluar(items: [barang]);

  @override
  State<BarangKeluar> createState() => _BarangKeluarState();
}

class _BarangKeluarState extends State<BarangKeluar> {
  final Map<int, TextEditingController> _mapQtyController = {};
  final Map<int, TextEditingController> _mapSubtotalController = {};

  final _catatanC = TextEditingController();
  final _uangBayarC = TextEditingController();
  final _diskonC = TextEditingController(text: '0');
  final _pajakC = TextEditingController(text: '11');

  int? _idPelangganTerpilih;
  List<Map<String, dynamic>> _daftarPelanggan = [];
  bool _isPajakAktif = false;

  double _nominalDiskon = 0, _nominalPajak = 0, _totalHarusBayar = 0, _kembalian = 0;
  bool _isCalculating = false;

  final _formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    for (var b in widget.items) {
      _mapQtyController[b.id!] = TextEditingController(text: '1');
      _mapSubtotalController[b.id!] = TextEditingController();

      _mapQtyController[b.id!]!.addListener(() => _updateSubtotalPerBarang(b));
      _mapQtyController[b.id!]!.addListener(_hitungSeluruhNota);
      _mapSubtotalController[b.id!]!.addListener(_hitungSeluruhNota);

      _updateSubtotalPerBarang(b);
    }

    _muatDaftarPelanggan();

    _diskonC.addListener(_hitungSeluruhNota);
    _pajakC.addListener(_hitungSeluruhNota);
    _uangBayarC.addListener(_hitungKembalian);

    WidgetsBinding.instance.addPostFrameCallback((_) => _hitungSeluruhNota());
  }

  @override
  void dispose() {
    for (var c in _mapQtyController.values) {
      c.dispose();
    }
    for (var c in _mapSubtotalController.values) {
      c.dispose();
    }
    for (var c in [_catatanC, _uangBayarC, _diskonC, _pajakC]) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateSubtotalPerBarang(Barang b) {
    final qty = AppStyles.parseNumber(_mapQtyController[b.id!]!.text);
    final subtotal = qty * b.hargaJual;
    final formatted = AppStyles.formatNumber(subtotal);

    if (_mapSubtotalController[b.id!]!.text != formatted) {
      _mapSubtotalController[b.id!]!.text = formatted;
    }
  }

  Future<void> _muatDaftarPelanggan() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('kontak', where: 'tipe = ?', whereArgs: ['pelanggan']);
    if (mounted) setState(() => _daftarPelanggan = data);
  }

  void _hitungSeluruhNota() {
    if (_isCalculating || !mounted) return;
    _isCalculating = true;

    double totalKotor = 0;
    for (var b in widget.items) {
      final subText = _mapSubtotalController[b.id!]?.text ?? '0';
      totalKotor += AppStyles.parseNumber(subText);
    }

    final persenDiskon = AppStyles.parseNumber(_diskonC.text);
    final persenPajak = _isPajakAktif ? AppStyles.parseNumber(_pajakC.text) : 0;

    setState(() {
      _nominalDiskon = totalKotor * (persenDiskon / 100);
      double setelahDiskon = totalKotor - _nominalDiskon;
      _nominalPajak = setelahDiskon * (persenPajak / 100);
      _totalHarusBayar = setelahDiskon + _nominalPajak;
      _kembalian = AppStyles.parseNumber(_uangBayarC.text) - _totalHarusBayar;
      _isCalculating = false;
    });
  }

  void _hitungKembalian() {
    setState(() {
      _kembalian = AppStyles.parseNumber(_uangBayarC.text) - _totalHarusBayar;
    });
  }

  void _tampilkanRingkasanTransaksi({
    required double totalBayar,required double uangDiterima,
    required double kembalian,
    required String status,
    required String namaPelanggan,
    required Map<String, dynamic> dataTransaksi,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: status == 'DIBAYAR' ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Icon(
                status == 'DIBAYAR' ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: status == 'DIBAYAR' ? Colors.green : Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 12),
              Text(
                status == 'DIBAYAR' ? 'Transaksi Berhasil' : 'Transaksi Disimpan',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (namaPelanggan != "Pelanggan Umum")
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Pelanggan: $namaPelanggan',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRingkasanRow('Total Belanja', _formatRupiah.format(totalBayar)),
                    _buildRingkasanRow('Uang Diterima', _formatRupiah.format(uangDiterima)),
                    const Divider(height: 20),
                    if (status == 'DIBAYAR' && kembalian > 0.01)
                      _buildRingkasanRow(
                        'Kembalian',
                        _formatRupiah.format(kembalian),
                        isBold: true,
                        color: Colors.green,
                      ),
                    if (status == 'HUTANG')
                      _buildRingkasanRow(
                        'Sisa Hutang',
                        _formatRupiah.format(totalBayar - uangDiterima),
                        isBold: true,
                        color: Colors.red,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (status == 'DIBAYAR' && kembalian > 0.01)
                _buildInfoBox(
                  icon: Icons.money_off,
                  color: Colors.green,
                  text: 'Kembalian: ${_formatRupiah.format(kembalian)}\nHarap dikembalikan ke pelanggan!',
                ),
              if (status == 'DIBAYAR' && kembalian <= 0.01 && uangDiterima > 0)
                _buildInfoBox(
                  icon: Icons.verified,
                  color: Colors.blue,
                  text: 'Pembayaran LUNAS',
                  isCenter: true,
                ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            children: [
              if (status == 'DIBAYAR')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          try {
                            // Menggunakan cetakLagi agar konsisten dengan riwayat
                            await StrukService.cetakLagi(dataTransaksi['id']);
                          } catch (e) {
                            debugPrint("Cetak gagal: $e");
                          }
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const GridBarang()),
                                  (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('CETAK STRUK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const GridBarang()),
                                (route) => false,
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        status == 'DIBAYAR' ? 'SELESAI' : 'TUTUP',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.disabled),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({required IconData icon, required Color color, required String text, bool isCenter = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: isCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            flex: isCenter ? 0 : 1,
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingkasanRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null, fontSize: 14), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : null,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prosesSimpanTransaksi() async {
    final bayarVal = AppStyles.parseNumber(_uangBayarC.text);

    double totalKotor = 0;
    List<DokumenItem> itemsToSave = [];
    for (var b in widget.items) {
      final qty = AppStyles.parseNumber(_mapQtyController[b.id!]?.text ?? '0');
      final subtotal = AppStyles.parseNumber(_mapSubtotalController[b.id!]!.text);

      if (qty > 0.0001) {
        if (b.stok < BarangController.UNLIMITED_STOCK && qty > b.stok) {
          return AppStyles.showWarningSnackBar(context, 'Stok ${b.nama} tidak mencukupi!');
        }
        itemsToSave.add(DokumenItem(
          dokumenId: 0,
          barangId: b.id!,
          qty: qty,
          harga: qty > 0 ? (subtotal / qty) : b.hargaJual,
        ));
        totalKotor += subtotal;
      }
    }

    if (itemsToSave.isEmpty) return AppStyles.showWarningSnackBar(context, 'Masukkan jumlah barang!');

    if (bayarVal < (_totalHarusBayar - 0.01) && _idPelangganTerpilih == null) {
      return AppStyles.showWarningSnackBar(context, 'Pilih pelanggan untuk mencatat transaksi piutang!');
    }

    try {
      final DokumenController controller = DokumenController();
      String status = bayarVal < (_totalHarusBayar - 0.01) ? 'HUTANG' : 'DIBAYAR';

      final double kasBersih = status == 'DIBAYAR'
          ? (bayarVal > _totalHarusBayar ? _totalHarusBayar : bayarVal)
          : bayarVal;

      final namaPelanggan = _idPelangganTerpilih != null
          ? _daftarPelanggan.firstWhere((e) => e['id'] == _idPelangganTerpilih)['nama']
          : "Pelanggan Umum";

      final header = DokumenStok(
        jenis: JenisDokumen.keluar,
        judul: itemsToSave.length == 1
            ? "Penjualan: ${widget.items.firstWhere((b) => b.id == itemsToSave.first.barangId).nama}"
            : "Penjualan Campur (${itemsToSave.length} item)",
        tanggal: DateTime.now(),
        pembeliId: _idPelangganTerpilih,
        totalAkhir: _totalHarusBayar,
        nominalBayar: bayarVal,
        pajakPersen: _isPajakAktif ? AppStyles.parseNumber(_pajakC.text) : 0,
        diskonPersen: AppStyles.parseNumber(_diskonC.text),
        status: status,
        keterangan: _catatanC.text,
      );

      final int idDokumen = await controller.simpanTransaksiLengkap(
        dokumen: header,
        items: itemsToSave,
        nominalAwal: kasBersih > 0.01 ? kasBersih : null,
      );

      final dataTransaksi = {
        'id': idDokumen,
        'tanggal': DateTime.now().toIso8601String(),
        'pembeli': namaPelanggan,
        'status': status,
        'total_kotor': totalKotor,
        'nominal_diskon': _nominalDiskon,
        'nominal_pajak': _nominalPajak,
        'total_akhir': _totalHarusBayar,
        'nominal_bayar': bayarVal,
        'kembalian': _kembalian > 0.01 ? _kembalian : 0,
        'diskon_persen': AppStyles.parseNumber(_diskonC.text),
        'pajak_persen': _isPajakAktif ? AppStyles.parseNumber(_pajakC.text) : 0,
        'items': itemsToSave.map((item) {
          final barang = widget.items.firstWhere((b) => b.id == item.barangId);
          return {
            'nama': barang.nama,
            'qty': item.qty,
            'harga': item.harga,
            'subtotal': item.qty * item.harga,
          };
        }).toList(),
      };

      if (mounted) {
        _tampilkanRingkasanTransaksi(
          totalBayar: _totalHarusBayar,
          uangDiterima: bayarVal,
          kembalian: _kembalian > 0.01 ? _kembalian : 0,
          status: status,
          namaPelanggan: namaPelanggan,
          dataTransaksi: dataTransaksi,
        );
      }
    } catch (e) {
      if (mounted) AppStyles.showErrorSnackBar(context, 'Gagal: $e');
    }
  }


  String _formatStok(double stok, String satuan) {
    return '${AppStyles.formatNumber(stok)} $satuan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Penjualan Barang', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: AppStyles.appBarIconTheme,
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...widget.items.map((b) => _buildBarisInputBarang(b)),

          const Divider(height: 32),
          _buildLabelHeader("Informasi Transaksi"),
          _buildLabelInput("Pilih Pelanggan"),
          _buildDropdownPelanggan(),

          const SizedBox(height: 16),
          _buildLabelInput("Catatan Penjualan"),
          TextFormField(controller: _catatanC, decoration: AppStyles.inputDecoration('Contoh: Pesanan via WA', icon: Icons.notes)),

          const SizedBox(height: 24),
          _buildBarisDiskonPajak(),

          const SizedBox(height: 24),
          _buildKotakRingkasan(),

          const SizedBox(height: 24),
          _buildLabelInput("Uang yang Diterima (Rp)"),
          TextFormField(
            controller: _uangBayarC,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: AppStyles.moneyInputDecoration(hintText: '0'),
          ),

          const SizedBox(height: 16),
          _buildStatusBayarBanner(),
          const SizedBox(height: 20),
        ]))),
        _buildTombolSimpan(),
      ]),
    );
  }

  Widget _buildBarisInputBarang(Barang b) {
    final qty = AppStyles.parseNumber(_mapQtyController[b.id!]?.text ?? '0');
    final isStokCukup = b.stok >= BarangController.UNLIMITED_STOCK || qty <= (b.stok + 0.0001);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.nama, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (b.deskripsi.isNotEmpty)
          Text(b.deskripsi, style: AppStyles.caption.copyWith(fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _mapQtyController[b.id],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+[.,]?[0-9]*$')),
              ],
              decoration: InputDecoration(
                labelText: 'Qty',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: isStokCukup ? null : 'Melebihi stok!',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _mapSubtotalController[b.id],
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: AppStyles.moneyInputDecoration(hintText: '0'),
            ),
          ),
        ]),
        Text(
          'Tersedia: ${_formatStok(b.stok, b.satuan)} | Harga: @${AppStyles.formatCurrency(b.hargaJual)}',
          style: AppStyles.caption.copyWith(
            color: isStokCukup ? null : Colors.red,
            fontWeight: isStokCukup ? null : FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }

  Widget _buildDropdownPelanggan() => DropdownButtonFormField<int>(
    initialValue: _idPelangganTerpilih,
    isExpanded: true,
    items: _daftarPelanggan.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['nama'] as String, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: (v) => setState(() => _idPelangganTerpilih = v),
    decoration: AppStyles.inputDecoration('Pilih Pelanggan', icon: Icons.person_search_rounded),
  );

  Widget _buildBarisDiskonPajak() => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabelInput("Diskon (%)"),
      TextFormField(controller: _diskonC, keyboardType: TextInputType.number, decoration: AppStyles.inputDecoration('0', icon: Icons.discount_rounded)),
    ])),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabelInput("Pajak (%)"),
      TextFormField(controller: _pajakC, keyboardType: TextInputType.number, enabled: _isPajakAktif, decoration: AppStyles.inputDecoration('11', icon: Icons.gavel_rounded)),
    ])),
    Padding(padding: const EdgeInsets.only(top: 25), child: Switch(
      value: _isPajakAktif,
      onChanged: (v) => setState(() { _isPajakAktif = v; _hitungSeluruhNota(); }),
      activeThumbColor: AppColors.primary,
    )),
  ]);

  Widget _buildKotakRingkasan() => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppStyles.cardOutline.copyWith(color: AppColors.blue50),
    child: Column(children: [
      _buildRowSummary('Potongan Diskon', '- ${AppStyles.formatCurrency(_nominalDiskon, showDecimal: true)}', neg: true),
      _buildRowSummary('Pertambahan Pajak', '+ ${AppStyles.formatCurrency(_nominalPajak, showDecimal: true)}'),
      const Divider(),
      _buildRowSummary('TOTAL AKHIR', AppStyles.formatCurrency(_totalHarusBayar), bold: true),
    ]),
  );

  Widget _buildStatusBayarBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kembalian < -0.01 ? Colors.red.shade50 : (_kembalian > 0.01 ? Colors.green.shade50 : Colors.blue.shade50),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _kembalian < -0.01
              ? 'HUTANG'
              : (_kembalian > 0.01 ? 'KEMBALI' : 'PAS'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _kembalian < -0.01 ? Colors.red : (_kembalian > 0.01 ? Colors.green : Colors.blue),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _kembalian < -0.01
                ? AppStyles.formatCurrency(_kembalian.abs())
                : (_kembalian > 0.01
                ? AppStyles.formatCurrency(_kembalian)
                : ''),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _kembalian < -0.01 ? Colors.red : (_kembalian > 0.01 ? Colors.green : Colors.blue),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _buildTombolSimpan() {
    bool adaMasalahStok = false;
    for (var b in widget.items) {
      final qty = AppStyles.parseNumber(_mapQtyController[b.id!]?.text ?? '0');
      if (b.stok < BarangController.UNLIMITED_STOCK && qty > (b.stok + 0.0001)) {
        adaMasalahStok = true;
        break;
      }
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      child: ElevatedButton.icon(
        onPressed: adaMasalahStok ? null : _prosesSimpanTransaksi,
        icon: const Icon(Icons.check_circle_rounded),
        label: Flexible(child: Text(adaMasalahStok ? 'STOK TIDAK CUKUP!' : 'PROSES & SIMPAN PENJUALAN', overflow: TextOverflow.ellipsis)),
        style: AppStyles.primaryButton,
      ),
    );
  }

  Widget _buildLabelHeader(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(s.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1), overflow: TextOverflow.ellipsis),
  );

  Widget _buildLabelInput(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(s, style: AppStyles.labelStyle, overflow: TextOverflow.ellipsis),
  );

  Widget _buildRowSummary(String l, String v, {bool neg = false, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : null), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text(
        v,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : null,
          color: neg ? Colors.red : (bold ? AppColors.primary : null),
          fontSize: bold ? 16 : 14,
        ),
      ),
    ]),
  );
}
