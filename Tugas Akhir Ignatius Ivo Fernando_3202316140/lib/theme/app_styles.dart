import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controller/dokumen_controller.dart';
import 'app_colors.dart';

/// Kumpulan gaya dan utilitas UI yang digunakan di seluruh aplikasi dengan kontras tinggi.
class AppStyles {
  // ================= FORMATTERS (INTL) =================
  static final NumberFormat currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  static final NumberFormat currencyFormatDecimal = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 2);
  static final NumberFormat numberFormat = NumberFormat.decimalPattern('id');

  // ================= DATA FORMATTING METHODS =================
  static String formatDateTime(dynamic date) {
    if (date == null) return '-';
    try {
      DateTime dt;
      if (date is String) dt = DateTime.parse(date);
      else if (date is DateTime) dt = date;
      else return '-';
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) { return '-'; }
  }

  static String formatCurrency(dynamic value, {bool showDecimal = false}) {
    if (value == null) return 'Rp 0';
    double numValue = (value is String) ? (double.tryParse(value) ?? 0) : value.toDouble();
    if (numValue.isNaN || numValue.isInfinite) return 'Rp 0';
    if (numValue < 0) {
      final formatter = showDecimal ? currencyFormatDecimal : currencyFormat;
      return '(${formatter.format(numValue.abs())})';
    }
    return (showDecimal ? currencyFormatDecimal : currencyFormat).format(numValue);
  }

  static String formatNumber(dynamic value, {bool forceDecimal = false}) {
    if (value == null) return '0';
    double numValue = (value is String) ? (double.tryParse(value) ?? 0) : value.toDouble();
    if (numValue.isNaN || numValue.isInfinite) return '0';
    if (numValue >= 999999.0) return '∞';
    if (!forceDecimal && numValue == numValue.roundToDouble()) return numberFormat.format(numValue.toInt());
    String formatted = numValue.toString();
    if (formatted.contains('.')) {
      List<String> parts = formatted.split('.');
      if (parts[1].length > 3) formatted = numValue.toStringAsFixed(3);
      formatted = formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  static double parseNumber(String text) {
    if (text.isEmpty) return 0.0;
    if (text.trim() == '∞') return 999999.0;
    String cleaned = text.replaceAll('Rp', '').replaceAll(' ', '').replaceAll('(', '').replaceAll(')', '').trim();
    if (cleaned.isEmpty) return 0.0;
    try {
      if (cleaned.contains('.') && cleaned.contains(',')) cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      else if (cleaned.contains(',') && !cleaned.contains('.')) cleaned = cleaned.replaceAll(',', '.');
      else if (cleaned.contains('.') && !cleaned.contains(',')) {
        List<String> parts = cleaned.split('.');
        if (parts.last.length != 2 && parts.last.length != 1) cleaned = cleaned.replaceAll('.', '');
      }
      return double.tryParse(cleaned) ?? 0.0;
    } catch (_) { return 0.0; }
  }

  // ================= REUSABLE DIALOGS =================
  static void showPelunasanDialog({
    required BuildContext context,
    required DokumenController controller,
    required Map<String, dynamic> doc,
    required VoidCallback onSuccess,
  }) async {
    final double total = (doc['total_akhir'] as num?)?.toDouble() ?? 0.0;
    final double sdhBayar = (doc['nominal_bayar'] as num?)?.toDouble() ?? 0.0;
    final double sisa = total - sdhBayar;
    final inputController = TextEditingController(text: formatNumber(sisa));
    final riwayatCicilan = await controller.getRiwayatPembayaran(doc['id'] as int);

    if (!context.mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: AppColors.primary),
            SizedBox(width: 8),
            Text("Pelunasan", style: h2),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Tagihan:", style: bodySmall),
                          Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Sisa Tagihan:", style: bodySmall),
                          Text(formatCurrency(sisa), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Riwayat Pembayaran", style: labelStyle),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: riwayatCicilan.isEmpty 
                    ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Belum ada riwayat", style: caption)))
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: riwayatCicilan.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (c, i) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatCurrency(riwayatCicilan[i]['nominal']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(riwayatCicilan[i]['tanggal'])), style: caption),
                              ],
                            ),
                            if (riwayatCicilan[i]['keterangan'] != null)
                              Text(riwayatCicilan[i]['keterangan'], style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.disabled)),
                          ],
                        ),
                      ),
                ),
                const SizedBox(height: 24),
                const Text("Nominal Bayar Sekarang", style: labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: inputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: moneyInputDecoration(hintText: '0'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BATAL", style: TextStyle(color: AppColors.disabled, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () async {
              double nominalInput = parseNumber(inputController.text);
              if (nominalInput <= 0) {
                return;
              }
              try {
                await controller.updatePembayaran(doc['id'] as int, nominalInput);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  onSuccess();
                }
              } catch (e) {
                if (ctx.mounted) {
                  showErrorSnackBar(ctx, "Gagal: $e");
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("SIMPAN"),
          ),
        ],
      ),
    );
  }

  // ================= REPORT & BANNER COMPONENTS =================
  static Widget buildHeaderBanner({required String title, required String subtitle, bool isKeuangan = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: gradientBanner(isKeuangan ? [Colors.green, Colors.teal] : [AppColors.accent, AppColors.secondary]),
      child: Column(
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.2)),
          Text(subtitle.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  static Widget buildSummaryCard({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 6),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  // ================= LIST & TILE STYLES =================
  static const EdgeInsets listViewPadding = EdgeInsets.symmetric(vertical: 12);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);
  static const Color tileBackgroundColor = AppColors.white;

  static ShapeBorder selectionShape(bool isSelected) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3), width: isSelected ? 2 : 1),
  );

  static Color get selectedTileColor => AppColors.primary.withValues(alpha: 0.08);

  static PreferredSizeWidget selectionAppBar({required bool isModeSeleksi, required int selectedCount, required String title, required VoidCallback onClose, List<Widget>? actions, PreferredSizeWidget? bottom}) {
    return AppBar(
      leading: isModeSeleksi ? IconButton(icon: const Icon(Icons.close), onPressed: onClose) : null,
      title: Text(isModeSeleksi ? '$selectedCount Terpilih' : title, style: appBarTitle),
      backgroundColor: isModeSeleksi ? Colors.black : AppColors.primary,
      iconTheme: appBarIconTheme,
      actions: actions,
      bottom: bottom,
    );
  }

  // ================= GLOBAL COMPONENT STYLES =================
  static const TextStyle appBarTitle = TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18);
  static const IconThemeData appBarIconTheme = IconThemeData(color: AppColors.white);

  static BoxDecoration cardShadow = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
  );

  static BoxDecoration cardOutline = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.disabledBackground.withValues(alpha: 0.5)),
  );

  static BoxDecoration gradientBanner(List<Color> colors) => BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
    boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
  );

  // ================= INPUT FIELD STYLES =================
  static InputDecoration inputDecoration(String hintText, {IconData? icon}) => InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.disabled), // Menggunakan abu-abu gelap
    prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    filled: true,
    fillColor: Colors.white,
  );

  static InputDecoration moneyInputDecoration({String hintText = '0', IconData? suffixIcon, bool showDecimal = false}) => InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.disabled, fontSize: 16),
    prefixIcon: Container(
      width: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))),
      child: const Center(child: Text('Rp', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))),
    ),
    suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppColors.disabled) : (showDecimal ? null : const SizedBox.shrink()),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    filled: true,
    fillColor: Colors.white,
  );

  // ================= SNACKBAR =================
  static void showSnackBar(BuildContext context, String message, {Color? backgroundColor, IconData? icon, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: AppColors.white, size: 20), const SizedBox(width: 12)],
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: backgroundColor ?? AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        elevation: 6,
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) => showSnackBar(context, message, backgroundColor: AppColors.success, icon: Icons.check_circle_outline);
  static void showErrorSnackBar(BuildContext context, String message) => showSnackBar(context, message, backgroundColor: AppColors.error, icon: Icons.error_outline);
  static void showWarningSnackBar(BuildContext context, String message) => showSnackBar(context, message, backgroundColor: AppColors.warning, icon: Icons.warning_amber_rounded);

  // ================= BUTTON STYLES =================
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    minimumSize: const Size(double.infinity, 55),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  // ================= TEXT STYLES =================
  static const TextStyle labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.black);
  static const TextStyle moneyStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary);
  static const TextStyle h1 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.black87);
  static const TextStyle h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black87);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, color: AppColors.black87);
  static const TextStyle subHeadingStyle = TextStyle(fontSize: 14, color: AppColors.disabled, fontWeight: FontWeight.bold);
  static const TextStyle caption = TextStyle(fontSize: 10, color: AppColors.disabled, fontWeight: FontWeight.w900);
  static const TextStyle chartLabel = TextStyle(fontSize: 8, color: AppColors.black87);
}

class CurrencyInputFormatter extends TextInputFormatter {
  final bool allowDecimal;
  CurrencyInputFormatter({this.allowDecimal = false});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String numberText = cleanText.replaceAll('.', '');
    if (allowDecimal) {
      final parts = numberText.split(',');
      if (parts.length > 2) {
        numberText = '${parts[0]},${parts[1]}';
      }
      if (parts.length == 2 && parts[1].length > 2) {
        numberText = '${parts[0]},${parts[1].substring(0, 2)}';
      }
    } else {
      numberText = numberText.replaceAll(',', '');
    }
    try {
      final parseText = numberText.replaceAll(',', '.');
      final value = double.parse(parseText);
      if (value.isNaN || value.isInfinite) {
        return oldValue;
      }
      final formatter = NumberFormat.decimalPattern('id');
      String formatted;
      if (allowDecimal && numberText.contains(',')) {
        final parts = numberText.split(',');
        final intPart = int.tryParse(parts[0]) ?? 0;
        final decPart = parts.length > 1 ? parts[1] : '';
        formatted = '${formatter.format(intPart)}${decPart.isNotEmpty ? ',$decPart' : ''}';
      } else {
        formatted = formatter.format(value.toInt());
      }
      return newValue.copyWith(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    } catch (_) {
      return oldValue;
    }
  }
}
