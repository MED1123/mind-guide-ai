import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:image_picker/image_picker.dart';
import '../Services/api_service.dart';
import '../models/mood_analysis.dart';
import '../main.dart'; // AppColors, AppSettings
import 'analysis_detail_screen.dart'; // Import

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ... (Kod stanu i logiki bez zmian) ...
  MoodAnalysis? _analysis;
  bool _isLoadingAnalysis = false;
  bool _isLoadingProfile = false;

  String _displayName = "Użytkownik";
  String _displayUsername = "";
  String _profileImagePath = "";

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() async {
    setState(() {
      _isLoadingAnalysis = true;
      _isLoadingProfile = true;
    });

    final profileData = await ApiService().getUserProfile();
    if (profileData != null) {
      final name = profileData['name'] ?? "";
      final surname = profileData['surname'] ?? "";
      final username = profileData['username'] ?? "";

      if (mounted) {
        setState(() {
          _displayName = (name.isNotEmpty || surname.isNotEmpty)
              ? "$name $surname"
              : "Użytkownik";
          _displayUsername = username;
          _profileImagePath = profileData['profile_image_path'] ?? "";

          _nameController.text = name;
          _surnameController.text = surname;
          _usernameController.text = username;
          _dobController.text = profileData['birth_date'] ?? "";
          _emailController.text = profileData['email'] ?? "";
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }

    final analysisResult = await ApiService().getMoodAnalysis('Tydzień');
    if (mounted) {
      setState(() {
        _analysis = analysisResult;
        _isLoadingAnalysis = false;
      });
    }
  }

  void _pickProfileImage() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        await ApiService().updateUserProfile(profileImagePath: image.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Zdjęcie profilowe zaktualizowane")),
          );
        }
      }
    } catch (e) {
      print("Błąd wyboru zdjęcia: $e");
    }
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('.');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {}
    }

    if (Platform.isIOS) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 280,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900),
                  onDateTimeChanged: (val) {
                    setState(() {
                      _dobController.text =
                          "${val.day.toString().padLeft(2, '0')}.${val.month.toString().padLeft(2, '0')}.${val.year}";
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('Zatwierdź'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primaryBlue,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _dobController.text =
              "${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}";
        });
      }
    }
  }

  void _openAnalysisDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AnalysisDetailScreen(initialRange: 'Tydzień', initialAnalysis: _analysis),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    String greetingText = "Witaj 👋";
    if (_displayUsername.isNotEmpty) {
      greetingText = "Witaj, $_displayUsername 👋";
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      greetingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  Bounceable(
                    onTap: () => _showSettingsBottomSheet(isDark),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.settings, color: textColor, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              _buildUserProfileCard(isDark, textColor),
              const SizedBox(height: 30),

              Text(
                "Twoje Centrum",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildGridCard(
                      isDark: isDark,
                      title: "Analiza AI",
                      subtitle: "Twoje emocje",
                      icon: Icons.auto_awesome,
                      iconColor: AppColors.primaryBlue,
                      onTap: _openAnalysisDetail,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGridCard(
                      isDark: isDark,
                      title: "Sobriety",
                      subtitle: "Liczniki",
                      icon: Icons.access_time_filled,
                      iconColor: Colors.teal,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Moduł Sobriety w budowie..."),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.timer,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Czas w aplikacji",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "0 sesji dzisiaj",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Bounceable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ApiService().currentUserId = null;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 10),
                      const Text(
                        "Wyloguj się",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETY POMOCNICZE ---

  Widget _buildUserProfileCard(bool isDark, Color textColor) {
    ImageProvider? imageProvider;
    if (_profileImagePath.isNotEmpty) {
      imageProvider = FileImage(File(_profileImagePath));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Bounceable(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                    image: imageProvider != null
                        ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageProvider == null
                      ? const Icon(Icons.person, size: 35, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingProfile)
                  const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    _displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showEditProfileSheet,
                  child: Text(
                    "Ustawienia profilu >",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final cardTextColor = isDark ? Colors.white : Colors.black87;
    return Bounceable(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cardTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(bool initialIsDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // ODŚWIEŻAMY STAN MOTYWU Z appSettings
            final isCurrentDark = appSettings.isDarkMode;

            final sheetBgColor = isCurrentDark
                ? const Color(0xFF1E1E1E)
                : Colors.white;
            final sheetTextColor = isCurrentDark ? Colors.white : Colors.black87;

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SwitchListTile(
                    title: Text(
                      "Tryb ciemny",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: sheetTextColor,
                      ),
                    ),
                    value: isCurrentDark,
                    activeColor: AppColors.primaryBlue,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dark_mode,
                        size: 20,
                        color: isCurrentDark ? Colors.white : Colors.indigo,
                      ),
                    ),
                    onChanged: (bool value) {
                      appSettings.toggleTheme(value);
                      setModalState(() {});
                      // Odświeżamy też ekran pod spodem
                      setState(() {});
                    },
                  ),

                  const Divider(),

                  _buildSettingsItem(
                    icon: Icons.lock_outline,
                    title: "Zmień hasło",
                    onTap: () {},
                    isDark: isCurrentDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.language,
                    title: "Zmień język",
                    trailing: const Text("🇵🇱"),
                    onTap: () {},
                    isDark: isCurrentDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    title: "Polityka prywatności",
                    onTap: () {},
                    isDark: isCurrentDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.help_outline,
                    title: "Pomoc / Kontakt",
                    onTap: () {},
                    isDark: isCurrentDark,
                  ),

                  const Spacer(),

                  _buildSettingsItem(
                    icon: Icons.delete_outline,
                    title: "Usuń konto",
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Funkcja w budowie")),
                      );
                    },
                    isDark: isCurrentDark,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
  }) {
    final defaultColor = isDark ? Colors.white : Colors.black87;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? defaultColor).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor ?? defaultColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? defaultColor,
        ),
      ),
      trailing:
          trailing ??
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _showEditProfileSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edytuj Dane",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                "Imię",
                _nameController,
                isDark,
                Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                "Nazwisko",
                _surnameController,
                isDark,
                Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                "Nazwa użytkownika",
                _usernameController,
                isDark,
                Icons.alternate_email,
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: _buildTextField(
                    "Data urodzenia",
                    _dobController,
                    isDark,
                    Icons.cake_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              _buildTextField(
                "Email",
                _emailController,
                isDark,
                Icons.email_outlined,
              ),
              const SizedBox(height: 24),
              Bounceable(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final success = await ApiService().updateUserProfile(
                    name: _nameController.text,
                    surname: _surnameController.text,
                    username: _usernameController.text,
                    birthDate: _dobController.text,
                    email: _emailController.text,
                  );

                  if (success) {
                    _fetchData();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Zapisano zmiany!")),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Błąd zapisu.")),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Zapisz zmiany",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool isDark,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
