import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/barang.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_styles.dart';

class BarangListTile extends StatelessWidget {
  final Barang barang;
  final bool isSelected;
  final String namaMerek;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BarangListTile({
    super.key,
    required this.barang,
    required this.isSelected,
    required this.namaMerek,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final initialLetter =
        barang.nama.trim().isNotEmpty ? barang.nama.trim()[0].toUpperCase() : '?';
    final isLaba = barang.untung >= 0;
    
    // FIX BUG: Hitung persentase secara lokal agar tetap akurat saat Rugi
    final double displayPersen = barang.hargaJual > 0 
        ? (barang.untung.abs() / barang.hargaJual) * 100 
        : 0;

    return Padding(
      padding: AppStyles.listItemPadding,
      child: ListTile(
        tileColor: AppStyles.tileBackgroundColor,
        selected: isSelected,
        selectedTileColor: AppStyles.selectedTileColor,
        shape: AppStyles.selectionShape(isSelected),
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : AppColors.blue50,
            shape: BoxShape.circle,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: AppColors.primary)
              : _buildAvatar(barang, initialLetter),
        ),
        title: Text(
          barang.nama.isNotEmpty ? barang.nama : 'Tanpa Nama',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Stok: ${AppStyles.formatNumber(barang.stok)} ${barang.satuan} • $namaMerek",
              style: const TextStyle(fontSize: 11, color: AppColors.disabled),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (barang.hargaJual > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${isLaba ? "Untung" : "Rugi"}: ${AppStyles.formatCurrency(barang.untung.abs())} (${displayPersen.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 12, // Diperbesar sesuai permintaan
                    fontWeight: FontWeight.w900, // Dipertebal
                    color: isLaba ? AppColors.success : AppColors.error,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppStyles.formatCurrency(barang.hargaJual),
              style: AppStyles.moneyStyle.copyWith(fontSize: 13),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Barang b, String initialLetter) {
    if (b.fotoPath != null && b.fotoPath!.isNotEmpty) {
      try {
        final file = File(b.fotoPath!);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _textAvatar(initialLetter),
            ),
          );
        }
      } catch (e) {
        // Fallback
      }
    }
    return _textAvatar(initialLetter);
  }

  Widget _textAvatar(String letter) => Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
}
