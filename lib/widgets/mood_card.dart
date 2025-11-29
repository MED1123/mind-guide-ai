import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Do wibracji
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../main.dart';

class MoodCard extends StatefulWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;

  const MoodCard({super.key, required this.entry, this.onTap});

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard>
    with SingleTickerProviderStateMixin {
  // Zmienne do obsługi obrotu 3D
  double _rotationX = 0;
  double _rotationY = 0;
  double _scale = 1.0;

  // Kontroler do płynnego powrotu karty do pozycji zero po puszczeniu
  late AnimationController _controller;
  late Animation<double> _animRotationX;
  late Animation<double> _animRotationY;
  late Animation<double> _animScale;

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
    // Pobieramy rozmiar karty
    final size = context.size;
    if (size == null) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Pozycja palca względem środka
    final touchX = event.localPosition.dx - centerX;
    final touchY = event.localPosition.dy - centerY;

    setState(() {
      // Obliczamy kąty obrotu (czułość)
      _rotationY = (touchX / centerX) * 0.15;
      _rotationX = -(touchY / centerY) * 0.15;
      // Utrzymujemy lekkie zmniejszenie podczas ruchu
      _scale = 0.95;
    });
  }

  void _resetCard() {
    // Definiujemy krzywą animacji powrotu
    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Animacja powrotu do stanu płaskiego (0 rotacji, skala 1.0)
    _animRotationX = Tween<double>(
      begin: _rotationX,
      end: 0.0,
    ).animate(curvedAnimation);
    _animRotationY = Tween<double>(
      begin: _rotationY,
      end: 0.0,
    ).animate(curvedAnimation);
    _animScale = Tween<double>(
      begin: _scale,
      end: 1.0,
    ).animate(curvedAnimation);

    _controller.reset();
    _controller.forward();

    _controller.addListener(() {
      setState(() {
        _rotationX = _animRotationX.value;
        _rotationY = _animRotationY.value;
        _scale = _animScale.value;
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
    final color = _getCategoryColor(widget.entry.category);
    final icon = _getCategoryIcon(widget.entry.category);

    // Używamy Listenera na najwyższym poziomie, aby łapać surowe zdarzenia
    // To naprawia problem z przewijaniem listy
    return Listener(
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _scale = 0.95);
      },
      onPointerMove: _handlePointerMove,
      // Gdy użytkownik puści palec
      onPointerUp: (_) => _resetCard(),
      // KLUCZOWE: Gdy ScrollView przejmie gest (anulowanie dotyku)
      onPointerCancel: (_) => _resetCard(),

      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onTap != null) widget.onTap!();
        },
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspektywa 3D
            ..rotateX(_rotationX)
            ..rotateY(_rotationY)
            ..scale(_scale),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  // Dynamiczny cień - większy gdy karta jest "płaska", mniejszy gdy wciśnięta
                  blurRadius: _scale < 1.0 ? 5 : 15,
                  offset: Offset(0, _scale < 1.0 ? 2 : 8),
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
                      DateFormat('dd MMM, HH:mm').format(widget.entry.date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
