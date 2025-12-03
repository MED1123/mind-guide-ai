import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Do wibracji
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../main.dart';

class MoodCard extends StatefulWidget {
  final MoodEntry entry;

  const MoodCard({super.key, required this.entry});

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard>
    with SingleTickerProviderStateMixin {
  // Zmienne do obsługi obrotu 3D
  double _rotationX = 0;
  double _rotationY = 0;

  // Kontroler do płynnego powrotu karty do pozycji zero po puszczeniu
  late AnimationController _controller;
  late Animation<double> _animRotationX;
  late Animation<double> _animRotationY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final size = context.size;
    if (size == null) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Pozycja palca względem środka
    final touchX = event.localPosition.dx - centerX;
    final touchY = event.localPosition.dy - centerY;

    setState(() {
      // Czułość efektu 3D
      _rotationY = (touchX / centerX) * 0.10;
      _rotationX = -(touchY / centerY) * 0.10;
    });
  }

  void _resetCard() {
    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _animRotationX = Tween<double>(
      begin: _rotationX,
      end: 0.0,
    ).animate(curvedAnimation);
    _animRotationY = Tween<double>(
      begin: _rotationY,
      end: 0.0,
    ).animate(curvedAnimation);

    _controller.reset();
    _controller.forward();

    _controller.addListener(() {
      setState(() {
        _rotationX = _animRotationX.value;
        _rotationY = _animRotationY.value;
      });
    });
  }

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
    if (category.contains("Radość")) return Icons.sentiment_very_satisfied;
    if (category.contains("Stres")) return Icons.bolt;
    if (category.contains("Smutek")) return Icons.cloud;
    if (category.contains("Zmęczenie")) return Icons.bedtime;
    if (category.contains("Złość")) return Icons.whatshot;
    return Icons.self_improvement;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(widget.entry.category);
    final icon = _getCategoryIcon(widget.entry.category);
    final hasImage = widget.entry.imagePaths.isNotEmpty;

    return Listener(
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _resetCard(),
      onPointerCancel: (_) => _resetCard(),

      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspektywa
          ..rotateX(_rotationX)
          ..rotateY(_rotationY),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            // Usunięto 'image: ...' - wracamy do koloru
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
                  // Data i ikonka zdjęcia
                  Row(
                    children: [
                      if (hasImage)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Icon(
                            Icons.photo_library,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                        ),
                      Text(
                        DateFormat(
                          'dd MMM, HH:mm',
                          'pl_PL',
                        ).format(widget.entry.date),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.entry.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
