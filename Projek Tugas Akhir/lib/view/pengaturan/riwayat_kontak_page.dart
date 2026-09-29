import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controller/dokumen_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';

class RiwayatKontakPage extends StatefulWidget {
  final int kontakId;
  final String namaKontak;
  final String tipe; // 'pelanggan' atau 'pemasok'

  const RiwayatKontakPage({
    super.key,
    required this.kontakId,
    required this.namaKontak,
    required this.tipe,
  });

  @override
  State<RiwayatKontakPage> createState() => _RiwayatKontakPageState();
}

class _RiwayatKontakPageState extends State<RiwayatKontakPage> {
  final DokumenController _dokumenController = DokumenController();
  final _formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  late Future<List<Map<String, dynamic>>> _futureDaftarRiwayat;

  @override
  void initState() {
    super.initState();
    _muatDataRiwayat();
  }

  void _muatDataRiwayat() {
    setState(() {
      if (widget.tipe == 'pelanggan') {
        _futureDaftarRiwayat = _dokumenController.getRiwayatByPembeli(widget.kontakId);
      } else {
        _futureDaftarRiwayat = _dokumenController.getRiwayatByPenyuplai(widget.kontakId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat: ${widget.namaKontak}', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureDaftarRiwayat,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final listTransaksi = snapshot.data ?? [];
          if (listTransaksi.isEmpty) {
            return const Center(child: Text('Belum ada riwayat transaksi tercatat'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listTransaksi.length,
            itemBuilder: (context, index) => _buildKartuTransaksi(listTransaksi[index]),
          );
        },
      ),
    );
  }

  Widget _buildKartuTransaksi(Map<String, dynamic> item) {
    final double totalAkhir = (item['total_akhir'] as num?)?.toDouble() ?? 0.0;
    final double sudahBayar = (item['nominal_bayar'] as num?)?.toDouble() ?? 0.0;
    final double sisaTagihan = totalAkhir - sudahBayar;
    
    final bool isHutang = item['status'] == 'HUTANG' || (totalAkhir > 0 && sisaTagihan > 0.01);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isHutang ? Colors.red.shade200 : AppColors.disabledBackground),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item['judul'] ?? 'Transaksi', 
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'])),
              style: AppStyles.caption,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('Total Pembayaran: ${_formatRupiah.format(totalAkhir)}', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (isHutang)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Sisa ${widget.tipe == 'pelanggan' ? 'Piutang' : 'Hutang'}: ${_formatRupiah.format(sisaTagihan)}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            _buildBadgeStatus(isHutang),
          ],
        ),
        onTap: () {
          AppStyles.showPelunasanDialog(
            context: context,
            controller: _dokumenController,
            doc: item,
            onSuccess: () => _muatDataRiwayat(),
          );
        },
      ),
    );
  }

  Widget _buildBadgeStatus(bool isHutang) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isHutang ? Colors.red.shade50 : Colors.green.shade50,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      isHutang ? 'BELUM LUNAS' : 'LUNAS',
      style: TextStyle(
        color: isHutang ? Colors.red : Colors.green.shade700,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
