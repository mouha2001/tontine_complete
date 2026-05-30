import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String value;
  final String label;
  final String change;
  final bool isPositive;
  final bool featured;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.change,
    required this.isPositive,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: featured ? AppTheme.earth : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: featured ? AppTheme.earth : AppTheme.creamDark,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: featured ? AppTheme.gold.withOpacity(0.15) : iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: featured ? AppTheme.gold : AppTheme.textDark,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: featured ? Colors.white60 : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: featured
                  ? AppTheme.gold.withOpacity(0.15)
                  : isPositive
                      ? const Color(0xFFE8F5E8)
                      : const Color(0xFFFDEAEA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              change,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: featured
                    ? AppTheme.gold
                    : isPositive
                        ? const Color(0xFF2D7D2D)
                        : const Color(0xFFC0392B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
