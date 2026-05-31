import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ActivityItem extends StatelessWidget {
  final Color dotColor;
  final String text;
  final String time;

  const ActivityItem({
    super.key,
    required this.dotColor,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.creamDark),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRichText(text),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        spans.add(TextSpan(
          text: parts[i],
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.textMid,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ));
      }
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
