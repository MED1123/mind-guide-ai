import 'package:flutter/material.dart';
import '../Services/translation_service.dart';

class PasswordRequirementsWidget extends StatelessWidget {
  final String password;
  final bool isDark;

  const PasswordRequirementsWidget({
    Key? key,
    required this.password,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirement(hasMinLength, TranslationService.tr('req_min_len')),
        _buildRequirement(hasUppercase, TranslationService.tr('req_uppercase')),
        _buildRequirement(hasDigit, TranslationService.tr('req_digit')),
        _buildRequirement(hasSpecial, TranslationService.tr('req_special')),
      ],
    );
  }

  Widget _buildRequirement(bool isMet, String text) {
    final color = isMet 
        ? Colors.green 
        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);
    
    final textColor = isMet
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
