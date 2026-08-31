import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/barang.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../transaksi/barang_tambah.dart';

/// Widget Notifikasi Stok
/// Menampilkan ringkasan barang yang memerlukan perhatian (stok habis, menipis, atau kadaluarsa)
class NotifikasiStok extends StatelessWidget {
  final List<Barang> currentBarangList;
  final VoidCallback? onRefresh; // Callback untuk memuat ulang data setelah aksi

  const NotifikasiStok({super.key, required this.currentBarangList, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    // Filter barang berdasarkan kondisi tertentu
    final listHabis = currentBarangList.where((b) => b.stok <= 0).toList();
    final listMenipis = currentBarangList.where((b) => b.stok > 0 && b.stok <= 5).toList();
    
    // Barang yang sudah kadaluarsa
    final listExpired = currentBarangList.where((b) => 
        b.tanggalKadaluarsa != null && b.tanggalKadaluarsa!.isBefore(today)).toList();
    
    // Barang yang akan kadaluarsa dalam 7 hari
    final listAkanExpired = currentBarangList.where((b) => 
        b.tanggalKadaluarsa != null && 
        b.tanggalKadaluarsa!.isAtSameMomentAs(today) || (b.tanggalKadaluarsa!.isAfter(today) && b.tanggalKadaluarsa!.isBefore(nextWeek))).toList();

    if (listHabis.isEmpty && listMenipis.isEmpty && listExpired.isEmpty && listAkanExpired.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _showDetailDialog(context, listHabis, listMenipis, listExpired, listAkanExpired),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFEF6C00)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                  if (listAkanExpired.isNotEmpty && listExpired.isEmpty)
                    _buildBadge("Mendekati Kadaluarsa: ${listAkanExpired.length}", Colors.blueGrey),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, List<Barang> habis, List<Barang> menipis, List<Barang> expired, List<Barang> akanExpired) {
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
                  ...habis.map((b) => _buildItemRow(context, b, "0 ${b.satuan}")),
                  const SizedBox(height: 16),
                ],
                if (menipis.isNotEmpty) ...[
                  _buildSectionTitle("STOK MENIPIS (Klik untuk Restok)", AppColors.warning),
                  ...menipis.map((b) => _buildItemRow(context, b, "${AppStyles.formatNumber(b.stok)} ${b.satuan}")),
                  const SizedBox(height: 16),
                ],
                if (expired.isNotEmpty) ...[
                  _buildSectionTitle("SUDAH KADALUARSA", Colors.brown),
                  ...expired.map((b) => _buildItemRow(context, b, "Exp: ${DateFormat('dd/MM/yy').format(b.tanggalKadaluarsa!)}")),
                  const SizedBox(height: 16),
                ],
                if (akanExpired.isNotEmpty) ...[
                  _buildSectionTitle("MENDEKATI KADALUARSA (< 7 Hari)", Colors.blueGrey),
                  ...akanExpired.map((b) => _buildItemRow(context, b, DateFormat('dd/MM/yy').format(b.tanggalKadaluarsa!))),
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
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: color,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _buildItemRow(BuildContext context, Barang b, String info) => InkWell(
    onTap: () async {
      Navigator.pop(context); // Tutup dialog
      final result = await Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => TambahBarang(items: [b]))
      );
      if (result == true && onRefresh != null) {
        onRefresh!();
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              b.nama,
              style: AppStyles.bodySmall.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info,
                style: AppStyles.bodySmall.copyWith(
                  fontSize: 13, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFF5A5A5A)
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    ),
  );
}
