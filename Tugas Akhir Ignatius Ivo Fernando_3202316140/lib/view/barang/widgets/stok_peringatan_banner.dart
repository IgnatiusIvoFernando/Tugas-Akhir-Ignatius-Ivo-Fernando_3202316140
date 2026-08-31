import 'package:flutter/material.dart';
import '../../../models/barang.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_styles.dart';
import '../edit_barang.dart';
import '../../transaksi/barang_tambah.dart';

class StokPeringatanBanner extends StatelessWidget {
  final List<Barang> dataPeringatan;
  final VoidCallback onRefresh;

  const StokPeringatanBanner({
    super.key,
    required this.dataPeringatan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final listHabis = dataPeringatan.where((b) => b.stok <= 0).toList();
    final listMenipis = dataPeringatan.where((b) => b.stok > 0 && b.stok <= 5).toList();
    final listExpired = dataPeringatan.where(
        (b) => b.tanggalKadaluarsa != null && b.tanggalKadaluarsa!.isBefore(today)
    ).toList();

    if (listHabis.isEmpty && listMenipis.isEmpty && listExpired.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _showDetailPerhatianDialog(context, listHabis, listMenipis, listExpired),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        color: AppColors.warning.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "PERHATIAN STOK & MASA BERLAKU",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFFEF6C00)
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.warning, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (listHabis.isNotEmpty)
                    _buildBadge("Stok Habis: ${listHabis.length}", AppColors.error),
                  if (listMenipis.isNotEmpty)
                    _buildBadge("Stok Menipis: ${listMenipis.length}", AppColors.warning),
                  if (listExpired.isNotEmpty)
                    _buildBadge("Kadaluarsa: ${listExpired.length}", Colors.brown),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12)
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showDetailPerhatianDialog(
      BuildContext context,
      List<Barang> habis,
      List<Barang> menipis,
      List<Barang> expired
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Detail Perhatian", style: AppStyles.h1),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (habis.isNotEmpty) ...[
                  _buildSectionTitle("STOK HABIS (Klik untuk Restok)", AppColors.error),
                  ...habis.map((b) => _buildItemRow(context, b, "0 ${b.satuan}", TambahBarang(items: [b]))),
                  const SizedBox(height: 16),
                ],
                if (menipis.isNotEmpty) ...[
                  _buildSectionTitle("STOK MENIPIS (Klik untuk Restok)", AppColors.warning),
                  ...menipis.map((b) => _buildItemRow(context, b, "${AppStyles.formatNumber(b.stok)} ${b.satuan}", TambahBarang(items: [b]))),
                  const SizedBox(height: 16),
                ],
                if (expired.isNotEmpty) ...[
                  _buildSectionTitle("SUDAH KADALUARSA (Klik untuk Edit)", Colors.brown),
                  ...expired.map((b) => _buildItemRow(context, b, "Expired", EditBarang(barang: b))),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      title,
      style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 11, letterSpacing: 0.5),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _buildItemRow(BuildContext context, Barang b, String info, Widget target) => InkWell(
    onTap: () async {
      Navigator.pop(context);
      if (await Navigator.push(context, MaterialPageRoute(builder: (_) => target)) == true) {
        onRefresh();
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              b.nama.isNotEmpty ? b.nama : 'Tanpa Nama',
              style: AppStyles.bodySmall.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    info,
                    style: AppStyles.bodySmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5A5A5A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  target is EditBarang ? Icons.edit_note : Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
