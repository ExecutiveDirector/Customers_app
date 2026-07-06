// lib/screens/profile_screen.dart
//
// Customer profile screen. Palette matches the live-tracking screen
// (lib/screens/track_order_screen.dart) for visual consistency across
// the app: AquaGas green (0xFF10B981 / 0xFF064E3B).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aquagas/screens/update_password_screen.dart';
import 'package:aquagas/screens/nearby_vendors_screen.dart';
import 'package:aquagas/screens/change_location_screen.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aquagas/screens/account_screen.dart';
import 'package:aquagas/screens/notifications_screen.dart';
import 'package:aquagas/services/notification_service.dart';
import 'package:aquagas/services/push_notification_manager.dart';

// ─── Palette (mirrors track_order_screen.dart) ───────────────────────────────
const Color _kGreen500 = Color(0xFF10B981);
const Color _kGreen700 = Color(0xFF047857);
const Color _kGreen900 = Color(0xFF064E3B);
const Color _kGreen100 = Color(0xFFD1FAE5);
const Color _kSlate800 = Color(0xFF1E293B);
const Color _kSlate500 = Color(0xFF64748B);
const Color _kSlate100 = Color(0xFFF1F5F9);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final AuthService authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;

  bool isLoading = true;
  bool isEditing = false;
  bool isUploadingAvatar = false;
  Map<String, dynamic>? userProfile;
  String? errorMessage;

  // Locally-picked image shown optimistically while it uploads.
  File? _pendingAvatarFile;

  // Controllers for editing
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _notificationService.getUnreadCount().then((int count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final profileData = await authService.getProfile();
      final data = profileData;
      final profile = data['profile'] as Map<String, dynamic>?;

      if (profile != null) {
        setState(() {
          userProfile = profile;
          _populateControllers();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load profile data.';
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading profile: $e');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        errorMessage = authService.getAuthErrorMessage(e);
        isLoading = false;
      });
    }
  }

  void _populateControllers() {
    if (userProfile != null) {
      final profile = userProfile!;

      firstNameController.text = (profile['first_name'] as String?) ?? '';
      lastNameController.text = (profile['last_name'] as String?) ?? '';
      phoneController.text = (profile['phone_number'] as String?) ?? '';
      emailController.text = (profile['email'] as String?) ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!isEditing) return;

    setState(() => isLoading = true);

    try {
      final updates = {
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
      };

      final result = await authService.updateProfile(updates);

      if (result['profile'] != null) {
        setState(() {
          userProfile = result['profile'] as Map<String, dynamic>?;
          isEditing = false;
          isLoading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: _kGreen700,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.getAuthErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Picks an image, shows it immediately (optimistic UI), then uploads it
  /// to the backend (POST /auth/profile/avatar) and persists the returned
  /// avatar_url into the in-memory profile. Reverts on failure.
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    setState(() {
      _pendingAvatarFile = file;
      isUploadingAvatar = true;
    });

    try {
      final String avatarUrl = await authService.uploadAvatar(file);

      if (!mounted) return;
      setState(() {
        userProfile = <String, dynamic>{
          ...?userProfile,
          'avatar_url': avatarUrl,
        };
        isUploadingAvatar = false;
        // Keep showing the local file (looks identical, avoids a network
        // round-trip flash) — it'll be replaced by the network image next
        // time the profile is reloaded.
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: _kGreen700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingAvatarFile = null;
        isUploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.getAuthErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kSlate800,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: _kGreen500),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _kGreen500),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: _kSlate500)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await PushNotificationManager.instance.unregister();
      await authService.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Logged out successfully'),
          backgroundColor: _kGreen900,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveLocation(LatLng? location) async {
    try {
      if (location != null) {
        await storage.write(
          key: 'user_location',
          value: '${location.latitude},${location.longitude}',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved successfully'),
            backgroundColor: _kGreen700,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  String _getDisplayName() {
    final profile = userProfile;

    if (profile == null) return 'User';

    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';
    final email = profile['email'] as String? ?? 'User';

    if (firstName.isEmpty && lastName.isEmpty) {
      return email;
    }

    return '$firstName $lastName'.trim();
  }

  String _getDisplayInfo() {
    final profile = userProfile;

    if (profile == null) return '';

    final phone = profile['phone_number'] as String?;
    final email = profile['email'] as String?;

    return phone?.isNotEmpty == true
        ? phone!
        : (email?.isNotEmpty == true ? email! : '');
  }

  String _getInitials() {
    final name = _getDisplayName();
    if (name.isEmpty || name == 'User') return 'U';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Resolves which avatar image to display, in priority order:
  /// freshly-picked local file > server-stored avatar_url > none (initials).
  ImageProvider? _resolveAvatarImage() {
    if (_pendingAvatarFile != null) {
      return FileImage(_pendingAvatarFile!);
    }
    final String? avatarUrl =
        AuthService.resolveMediaUrl(userProfile?['avatar_url'] as String?);
    if (avatarUrl != null) {
      return NetworkImage(avatarUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && userProfile == null) {
      return const Scaffold(
        backgroundColor: _kSlate100,
        body: Center(
          child: CircularProgressIndicator(color: _kGreen500),
        ),
      );
    }

    if (errorMessage != null && userProfile == null) {
      return Scaffold(
        backgroundColor: _kSlate100,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(fontSize: 16, color: _kSlate800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadUserProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen500,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kSlate100,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: _kGreen900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  isEditing = false;
                  _populateControllers();
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: _kGreen500,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kGreen900, _kGreen500],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: isEditing && !isUploadingAvatar
                          ? _showImageSourceDialog
                          : null,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: _resolveAvatarImage(),
                            child: _resolveAvatarImage() == null
                                ? Text(
                                    _getInitials(),
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: _kGreen700,
                                    ),
                                  )
                                : null,
                          ),
                          if (isUploadingAvatar)
                            const Positioned.fill(
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.black38,
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          if (isEditing && !isUploadingAvatar)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _kGreen500, width: 2),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: _kGreen700,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isEditing) ...[
                      Text(
                        _getDisplayName(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDisplayInfo(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      if (userProfile?['referral_code'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.card_giftcard,
                                size: 18,
                                color: _kGreen700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Referral: ${userProfile!['referral_code']}',
                                style: const TextStyle(
                                  color: _kGreen700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Edit Form or Profile Options
              if (isEditing) _buildEditForm() else _buildProfileOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kSlate800,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: firstNameController,
            label: 'First Name',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: lastNameController,
            label: 'Last Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: phoneController,
            label: 'Phone Number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email,
            enabled: false,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kGreen500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGreen500, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildProfileOptions() {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildProfileOption(
          icon: Icons.notifications,
          text: 'Notifications',
          trailing: _unreadCount > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              : null,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            final int count = await _notificationService.getUnreadCount();
            if (mounted) setState(() => _unreadCount = count);
          },
        ),
        _buildProfileOption(
          icon: Icons.lock,
          text: 'Update Password',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const UpdatePasswordScreen(),
              ),
            );
          },
        ),
        _buildSectionHeader('Geography'),
        _buildProfileOption(
          icon: Icons.location_on,
          text: 'Change Location',
          onTap: () async {
            final location = await Navigator.push<LatLng?>(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangeLocationScreen(),
              ),
            );
            if (location != null) {
              await _saveLocation(location);
            }
          },
        ),
        _buildProfileOption(
          icon: Icons.language,
          text: 'Change Language',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Language settings coming soon')),
            );
          },
        ),
        _buildSectionHeader('Membership'),
        _buildProfileOption(
          icon: Icons.card_membership,
          text: 'Loyalty Cards',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Loyalty cards feature coming soon')),
            );
          },
        ),
        _buildProfileOption(
          icon: Icons.group,
          text: 'Membership',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Membership feature coming soon')),
            );
          },
        ),
        _buildProfileOption(
          icon: Icons.school,
          text: 'Certificates',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Certificates feature coming soon')),
            );
          },
        ),
        _buildSectionHeader('More Options'),
        _buildProfileOption(
          icon: Icons.info,
          text: 'About Us',
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('About AquaGas'),
                content: const Text(
                  'AquaGas is your trusted platform for gas and water delivery services.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK',
                        style: TextStyle(color: _kGreen700)),
                  ),
                ],
              ),
            );
          },
        ),
        _buildProfileOption(
          icon: Icons.store,
          text: 'Nearby Vendors',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const NearbyVendorsScreen(),
              ),
            );
          },
        ),
        _buildProfileOption(
          icon: Icons.account_box,
          text: 'My Account',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const AccountPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _logout(context),
              child: const Text(
                'Log out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String text,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _kGreen500),
      title: Text(text, style: const TextStyle(color: _kSlate800)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: _kSlate500),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: _kSlate500,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}