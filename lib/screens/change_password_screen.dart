import 'package:flutter/material.dart';
import '../Services/api_service.dart';
import '../Services/translation_service.dart';
import '../main.dart';
import '../widgets/password_requirements_widget.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isDark;
  
  const ChangePasswordScreen({Key? key, required this.isDark}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      setState(() {}); // Rebuild to update requirements widget
    });
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationService.tr('enter_email_password'))), // Reusing generic error or create 'fill_all_fields'
      );
      return;
    }

    // Validation
    final hasMinLength = newPass.length >= 8;
    final hasUppercase = newPass.contains(RegExp(r'[A-Z]'));
    final hasDigit = newPass.contains(RegExp(r'[0-9]'));
    final hasSpecial = newPass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    if (!hasMinLength || !hasUppercase || !hasDigit || !hasSpecial) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationService.tr('password_requirements'))),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationService.tr('password_mismatch'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ApiService().updateUserProfile(
      password: newPass,
      oldPassword: oldPass,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.tr('password_changed'))),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.tr('password_change_error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(TranslationService.tr('change_password_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              TranslationService.tr('current_password'),
              _oldPasswordController,
              widget.isDark,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              TranslationService.tr('new_password'),
              _newPasswordController,
              widget.isDark,
            ),
            const SizedBox(height: 12),
            PasswordRequirementsWidget(
              password: _newPasswordController.text,
              isDark: widget.isDark,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              TranslationService.tr('confirm_password'),
              _confirmPasswordController,
              widget.isDark,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        TranslationService.tr('save_changes'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
