import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'dart:io';
import '../main.dart'; // AppColors
import '../Services/translation_service.dart'; // Import

class AddSobrietySheet extends StatefulWidget {
  final Function(String type, DateTime date, String customName) onSave;

  const AddSobrietySheet({super.key, required this.onSave});

  @override
  State<AddSobrietySheet> createState() => _AddSobrietySheetState();
}

class _AddSobrietySheetState extends State<AddSobrietySheet> {
  final List<String> _addictions = [
    "Alkohol",
    "Papierosy",
    "Narkotyki",
    "Vaping",
    "Kofeina",
    "Hazard",
    "Social Media",
    "Inne"
  ];
  
  String? _selectedAddiction;
  final TextEditingController _customController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  void _pickDate() async {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 280,
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _selectedDate,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (val) => setState(() => _selectedDate = val),
                  use24hFormat: true,
                ),
              ),
              CupertinoButton(
                child: Text(TranslationService.tr('ready')),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
        ),
      );
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (date != null) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedDate),
        );
        if (time != null) {
          setState(() {
            _selectedDate = DateTime(
              date.year, date.month, date.day, time.hour, time.minute
            );
          });
        }
      }
    }
  }

  void _submit() {
    if (_selectedAddiction == null) return;
    
    String type = _selectedAddiction!;
    String custom = "";
    
    if (type == "Inne") {
      custom = _customController.text.trim();
      if (custom.isEmpty) return; // Wymagamy nazwy dla "Inne"
    }

    widget.onSave(type, _selectedDate, custom);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              TranslationService.tr('new_sobriety_goal'),
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor
              ),
            ),
            const SizedBox(height: 8),
            Text(
              TranslationService.tr('choose_monitor'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8, runSpacing: 8,
              children: _addictions.map((addiction) {
                final isSelected = _selectedAddiction == addiction;
                return Bounceable(
                  onTap: () => setState(() => _selectedAddiction = addiction),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      TranslationService.tr(addiction),
                      style: TextStyle(
                        color: isSelected ? Colors.white : textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_selectedAddiction == "Inne") ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: TranslationService.tr('habit_name'),
                  labelStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              TranslationService.tr('last_occurrence'),
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textColor
              ),
            ),
            const SizedBox(height: 10),
            
            Bounceable(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}   ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    Icon(Icons.calendar_today, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(TranslationService.tr('cancel'), style: const TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Bounceable(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedAddiction == null ? Colors.grey : AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          TranslationService.tr('start'),
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
