import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/barang.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_styles.dart';

class BarangCard extends StatelessWidget {
  final Barang barang;
  final bool isSelected;
  final String namaMerek;
  final String namaKategori;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BarangCard({
    super.key,
    required this.barang,
    required this.isSelected,
    required this.namaMerek,
    required this.namaKategori,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLowStock = barang.stok <= 5;
    final bool isExp = barang.isExpired;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: (isSelected
                ? AppStyles.cardOutline.copyWith(color: AppStyles.selectedTileColor)
                : AppStyles.cardShadow)
            .copyWith(
          borderRadius: BorderRadius.circular(3),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(
                  color: isExp
                      ? AppColors.error
                      : (isLowStock
                          ? AppColors.warning
                          : AppColors.secondary.withValues(alpha: 0.3)),
                  width: 1.5,
                ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: _buildCardImage(barang),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  barang.nama.isNotEmpty ? barang.nama : 'Tanpa Nama',
                  style: AppStyles.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$namaMerek | $namaKategori',
                  style: AppStyles.caption.copyWith(color: Colors.black, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (barang.deskripsi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      barang.deskripsi,
                      style: AppStyles.caption.copyWith(
                        fontSize: 12,
                        color: Colors.black,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                _buildHargaStokRow(barang, isLowStock),
                _buildProfitLabel(barang),
                if (barang.tanggalKadaluarsa != null) _buildLabelExp(barang, isExp),
                if (isLowStock && !isExp) _buildLabelLowStock(),
              ],
            ),
            if (isSelected)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(Barang b) {
    if (b.fotoPath == null || b.fotoPath!.isEmpty) {
      return const Icon(
        Icons.image_outlined,
        color: AppColors.secondary,
        size: 40,
      );
    }

    try {
      final file = File(b.fotoPath!);
      if (!file.existsSync()) {
        return const Icon(
          Icons.image_outlined,
          color: AppColors.secondary,
          size: 40,
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_outlined,
            color: AppColors.secondary,
            size: 40,
          ),
        ),
      );
    } catch (e) {
      return const Icon(
        Icons.image_outlined,
        color: AppColors.secondary,
        size: 40,
      );
    }
  }

  Widget _buildLabelLowStock() => Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(
          '⚠️ STOK MENIPIS',
          style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
        ),
      );

  Widget _buildHargaStokRow(Barang b, bool isLowStock) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jual: ${AppStyles.formatCurrency(b.hargaJual)}',
                  style: AppStyles.moneyStyle.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Beli: ${AppStyles.formatCurrency(b.hargaBeli)}',
                  style: AppStyles.caption.copyWith(fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${AppStyles.formatNumber(b.stok)} ${b.satuan}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isLowStock ? AppColors.warning : AppColors.black87,
            ),
          ),
        ],
      );

  Widget _buildProfitLabel(Barang b) {
    if (b.hargaJual <= 0) return const SizedBox.shrink();
    
    final untung = b.untung;
    final isLaba = untung >= 0;
    final double displayPersen = b.hargaJual > 0 ? (untung.abs() / b.hargaJual) * 100 : 0;
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLaba ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLaba ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isLaba ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${isLaba ? "Untung" : "Rugi"}: ${AppStyles.formatCurrency(untung.abs())} (${displayPersen.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isLaba ? AppColors.success : AppColors.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelExp(Barang b, bool isExp) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isExp ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isExp ? "EXPIRED" : "Exp: ${DateFormat('dd/MM/yy').format(b.tanggalKadaluarsa!)}",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isExp ? AppColors.error : AppColors.success,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
