import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // Aby uzyskać dostęp do AppColors

// --- 6. WIDGET KARTY NASTROJU ---
class MoodCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;

  const MoodCard({super.key, required this.entry, this.onTap});

  Color _getCategoryColor(String category) {
    if (category.contains("Radość") || category.contains("radosny"))
      return Colors.orange;
    if (category.contains("Stres") || category.contains("zestresowany"))
      return AppColors.cardRed;
    if (category.contains("Smutek") || category.contains("smutny"))
      return Colors.blueGrey;
    if (category.contains("Zmęczenie") || category.contains("zmęczony"))
      return Colors.purple;
    if (category.contains("Złość") || category.contains("zły"))
      return AppColors.angerRed;
    return AppColors.cardBlue;
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains("Radość") || category.contains("radosny"))
      return Icons.sentiment_very_satisfied;
    if (category.contains("Stres") || category.contains("zestresowany"))
      return Icons.bolt;
    if (category.contains("Smutek") || category.contains("smutny"))
      return Icons.cloud;
    if (category.contains("Zmęczenie") || category.contains("zmęczony"))
      return Icons.bedtime;
    if (category.contains("Złość") || category.contains("zły"))
      return Icons.whatshot;
    return Icons.self_improvement;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(entry.category);
    final icon = _getCategoryIcon(entry.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Text(
                  DateFormat('dd MMM, HH:mm').format(entry.date),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
