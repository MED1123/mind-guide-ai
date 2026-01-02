import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../Services/api_service.dart';
import '../models/sobriety_clock.dart';
import '../widgets/add_sobriety_sheet.dart';
import '../Services/translation_service.dart'; // Import
import '../main.dart'; // AppColors

class SobrietyScreen extends StatefulWidget {
  const SobrietyScreen({super.key});

  @override
  State<SobrietyScreen> createState() => _SobrietyScreenState();
}

class _SobrietyScreenState extends State<SobrietyScreen> {
  List<SobrietyClock> _clocks = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchClocks();
    // Odświeżamy UI co sekundę, żeby licznik "tykał"
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchClocks() async {
    setState(() => _isLoading = true);
    final clocks = await ApiService().getSobrietyClocks();
    if (mounted) {
      setState(() {
        _clocks = clocks;
        _isLoading = false;
      });
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSobrietySheet(
        onSave: (type, date, customName) async {
          final success = await ApiService()
              .createSobrietyClock(type, date, customName: customName);
          if (success) {
            _fetchClocks();
          }
        },
      ),
    );
  }

  void _deleteClock(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationService.tr('delete_clock')),
        content: Text(TranslationService.tr('operation_irreversible')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(TranslationService.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(TranslationService.tr('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().deleteSobrietyClock(id);
      _fetchClocks();
    }
  }

  void _resetClock(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationService.tr('reset_clock')),
        content: Text(TranslationService.tr('reset_desc')),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(TranslationService.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: Text(TranslationService.tr('reset'), style: const TextStyle(color: Colors.red))
            ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().resetSobrietyClock(id, DateTime.now());
      _fetchClocks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(TranslationService.tr('sobriety_title'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: textColor),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Bounceable(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: AppColors.primaryBlue),
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clocks.isEmpty
              ? _buildEmptyState(textColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clocks.length,
                  itemBuilder: (context, index) {
                    return _buildClockCard(_clocks[index], isDark, textColor);
                  },
                ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            TranslationService.tr('start_journey'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 10),
          Text(
            TranslationService.tr('add_new_goal'),
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add),
            label: Text(TranslationService.tr('add_goal')),
          )
        ],
      ),
    );
  }

  Widget _buildClockCard(SobrietyClock clock, bool isDark, Color textColor) {
    final duration = DateTime.now().difference(clock.startDate); // Czas "trzeźwości"
    
    // Obliczamy Dni, Godziny, Minuty, Sekundy
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    String iconText = "🎯";
    if (clock.addictionType == "Alkohol") iconText = "🍺";
    else if (clock.addictionType == "Papierosy") iconText = "🚬";
    else if (clock.addictionType == "Narkotyki") iconText = "💊";
    else if (clock.addictionType == "Kofeina") iconText = "☕";
    else if (clock.addictionType == "Hazard") iconText = "🎲";
    else if (clock.addictionType == "Social Media") iconText = "📱";

    final displayTitle = clock.addictionType == "Inne" && clock.customName.isNotEmpty 
        ? clock.customName 
        : TranslationService.tr(clock.addictionType);

    return Dismissible(
      key: Key(clock.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        _deleteClock(clock.id);
        return false; // Usuwamy ręcznie w _deleteClock
      },
      child: Bounceable(
        onTap: () => _resetClock(clock.id), // Prosty tap to reset (na razie)
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(iconText, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      TranslationService.tr('ongoing'),
                      style: TextStyle(
                          color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeItem(days, TranslationService.tr('days'), isDark, textColor),
                  _buildSeparator(textColor),
                  _buildTimeItem(hours, TranslationService.tr('hours'), isDark, textColor),
                  _buildSeparator(textColor),
                  _buildTimeItem(minutes, TranslationService.tr('minutes'), isDark, textColor),
                  _buildSeparator(textColor),
                  _buildTimeItem(seconds, TranslationService.tr('seconds'), isDark, textColor, isSeconds: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeItem(int value, String label, bool isDark, Color textColor, {bool isSeconds = false}) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: Platform.isIOS ? "SF Pro Rounded" : null,
            color: isSeconds ? AppColors.primaryBlue : textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        ":",
        style: TextStyle(fontSize: 20, color: color.withOpacity(0.3), fontWeight: FontWeight.bold),
      ),
    );
  }
}
