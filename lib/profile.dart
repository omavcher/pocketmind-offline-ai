import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'model_manager.dart';
import 'auth_service.dart';
import 'onboarding.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _user?.displayName ?? 'User';
    final String email = _user?.email ?? '';
    final String? photoUrl = _user?.photoURL;
    final String initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings & Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainerHighest.withOpacity(0.5) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primary,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(initials, style: TextStyle(color: colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(email, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Image.network('https://www.google.com/favicon.ico', width: 12, height: 12,
                              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 14)),
                            const SizedBox(width: 4),
                            Text('Google Account', style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Guarantee Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.primary.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security, color: colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '100% Private & Offline',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your chats and data are processed locally on your device. We do not share or store any data on our servers.',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Settings Section
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'General',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'App Theme',
              subtitle: 'System Default',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.sd_storage_outlined,
              title: 'Manage Local Models',
              subtitle: 'View and delete downloaded AI models',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageModelsScreen()),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.notifications_none,
              title: 'Notifications',
              subtitle: 'Manage alerts',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.link_outlined,
              title: 'Created by Om Avchar',
              subtitle: 'Connect on LinkedIn',
              onTap: () async {
                final Uri url = Uri.parse('https://www.linkedin.com/in/omavchar/');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch $url');
                }
              },
            ),
            const SizedBox(height: 24),

            // Legal & About
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'About & Documentation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.policy_outlined,
              title: 'Privacy Policy',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'App Version',
              subtitle: 'v1.0.0 (Build 4)',
              onTap: () {},
              showArrow: false,
            ),
            const SizedBox(height: 32),

            // Sign Out Button
            Center(
              child: TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showArrow;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  ]
                ],
              ),
            ),
            if (showArrow)
              Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class ManageModelsScreen extends StatefulWidget {
  const ManageModelsScreen({super.key});

  @override
  State<ManageModelsScreen> createState() => _ManageModelsScreenState();
}

class _ManageModelsScreenState extends State<ManageModelsScreen> {
  List<File> _installedModels = [];
  bool _isLoading = true;
  String? _activeModelPath;
  double _freeSpaceGB = 0.0;
  double _totalSpaceGB = 0.0;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await ModelManager.getInstalledModels();
    final activePath = await ModelManager.getActiveModelPath();
    final storage = await ModelManager.getStorageInfo();
    setState(() {
      _installedModels = models;
      _activeModelPath = activePath;
      _freeSpaceGB = storage['free']! / (1024 * 1024 * 1024);
      _totalSpaceGB = storage['total']! / (1024 * 1024 * 1024);
      _isLoading = false;
    });
  }

  Future<void> _deleteModel(File file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${file.path.split('/').last}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final filename = file.path.split('/').last;
      await ModelManager.deleteModel(filename);
      _loadModels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Local Models'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Real Storage Info Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary.withOpacity(0.1), colorScheme.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_freeSpaceGB.toStringAsFixed(1)} GB Available',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'of ${_totalSpaceGB.toStringAsFixed(1)} GB Total Storage',
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.storage, color: colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_totalSpaceGB - _freeSpaceGB) / _totalSpaceGB,
                          minHeight: 8,
                          backgroundColor: colorScheme.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _installedModels.isEmpty
                      ? const Center(child: Text('No models downloaded yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _installedModels.length,
                          itemBuilder: (context, index) {
                    final file = _installedModels[index];
                    final filename = file.path.split('/').last;
                    final size = file.lengthSync();
                    final isActive = _activeModelPath == file.path;

                    final knownModel = ModelManager.availableModels.where((m) => m.filename == filename).firstOrNull;
                    final displayName = knownModel?.name ?? filename;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isActive 
                            ? BorderSide(color: colorScheme.primary, width: 2)
                            : BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      elevation: 0,
                      color: isActive ? colorScheme.primaryContainer.withOpacity(0.2) : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.auto_awesome, 
                            color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.sd_storage_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteModel(file),
                        ),
                        onTap: () async {
                          await ModelManager.setActiveModel(filename);
                          _loadModels();
                        },
                      ),
                    );
                  },        // closes itemBuilder
                ),          // closes ListView.builder
                ),          // closes Expanded
              ],            // closes Column children
            ),              // closes Column (body)
    );
  }
}
