import 'package:flutter/material.dart';
import 'main.dart'; // To access HomeScreen
import 'model_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'sheets_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top spacing instead of skip button
            const SizedBox(height: 16.0),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Logo
                      Center(
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colorScheme.primary.withOpacity(0.15),
                                Colors.transparent,
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          children: [
                            const TextSpan(text: 'AI Power.\n'),
                            TextSpan(
                              text: 'Offline. Private. ',
                              style: TextStyle(color: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5)),
                            ),
                            TextSpan(
                              text: 'Yours.',
                              style: TextStyle(color: isDark ? const Color(0xFFEC4899) : const Color(0xFFE11D48)),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        'Run powerful AI models completely offline.\nNo internet. No limits. 100% private.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Feature Cards
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.lock_outline,
                              iconColor: Colors.blueAccent,
                              title: '100% Private',
                              subtitle: 'Your data stays\non your device',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.wifi_off_rounded,
                              iconColor: Colors.blue,
                              title: 'Works Offline',
                              subtitle: 'No internet\nrequired',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.description_outlined,
                              iconColor: Colors.green,
                              title: 'Documents',
                              subtitle: 'PDF, Word, Excel\nSupport',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Section: Google Button & Terms
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        final auth = AuthService();
                        final userCred = await auth.signInWithGoogle();
                        
                        if (!context.mounted) return;
                        Navigator.pop(context); // dismiss loading
                        
                        if (userCred != null && userCred.user != null) {
                          final hasCompleted = await auth.hasCompletedSurvey(userCred.user!.uid);
                          if (!context.mounted) return;
                          
                          if (hasCompleted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
                            );
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const SurveyScreen()),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to sign in with Google')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF111111),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Custom Google Icon
                          Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.g_mobiledata, size: 32),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                        const TextSpan(text: '\nand '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse('https://www.linkedin.com/in/omavchar/');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        debugPrint('Could not launch $url');
                      }
                    },
                    child: Text(
                      'App Developed by Om Avchar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Pagination dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot(isActive: true),
                      const SizedBox(width: 8),
                      _Dot(isActive: false),
                      const SizedBox(width: 8),
                      _Dot(isActive: false),
                      const SizedBox(width: 8),
                      _Dot(isActive: false),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isActive;
  const _Dot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: isActive ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3B82F6) : colorScheme.onSurfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Survey Screen
// ─────────────────────────────────────────────

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<String, String> _responses = {};

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'What best describes you?',
      'options': [
        'Student',
        'Developer',
        'Corporate Professional',
        'Government Employee',
        'Teacher',
        'Homemaker',
        'Business Owner',
      ]
    },
    {
      'question': 'What will you mostly use AI for?',
      'options': [
        'Study',
        'Coding',
        'Writing',
        'Research',
        'Daily Tasks',
        'Business',
      ]
    },
    {
      'question': 'Where did you hear about us?',
      'options': [
        'YouTube',
        'Instagram',
        'Friend',
        'Twitter/X',
        'Google',
      ]
    },
  ];

  void _nextPage(String selectedOption) async {
    final question = _questions[_currentIndex]['question'] as String;
    _responses[question] = selectedOption;

    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // End of survey - save to Firestore
      final auth = AuthService();
      final user = auth.currentUser;
      
      if (user != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        
        await auth.saveSurvey(user.uid, _responses);
        
        // Sync to Google Sheet silently
        SheetsService.syncUser(surveyAnswers: Map<String, String>.from(_responses));
        
        if (!context.mounted) return;
        Navigator.pop(context); // dismiss loading
      }

      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _currentIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: List.generate(_questions.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentIndex
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final options = q['options'] as List<String>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q['question'],
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Expanded(
                          child: ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (context, optIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () => _nextPage(options[optIndex]),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle_outlined,
                                          color: colorScheme.outline,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          options[optIndex],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
//  Model Selection Screen
// ─────────────────────────────────────────────

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  int _selectedIndex = 0; // 0 for TinyLlama, 1 for Gemma
  double _freeSpaceGB = 0.0;
  Map<String, bool> _installedModels = {};
  
  // Download stats
  String _downloadSpeed = '-- MB/s';
  String _timeRemaining = 'Calculating...';
  DateTime? _lastProgressTime;
  double _lastProgress = 0.0;
  


  @override
  void initState() {
    super.initState();
    _updateStorageInfo();
    _checkInstalledModels();
    ModelManager.downloadProgress.addListener(_updateDownloadStats);
  }

  @override
  void dispose() {
    ModelManager.downloadProgress.removeListener(_updateDownloadStats);
    super.dispose();
  }

  Future<void> _checkInstalledModels() async {
    Map<String, bool> installed = {};
    for (var model in ModelManager.availableModels) {
      installed[model.filename] = await ModelManager.isModelInstalled(model.filename);
    }
    if (mounted) setState(() => _installedModels = installed);
  }

  Future<void> _updateStorageInfo() async {
    final info = await ModelManager.getStorageInfo();
    if (mounted) {
      setState(() {
        _freeSpaceGB = info['free']! / (1024 * 1024 * 1024);
      });
    }
  }

  void _updateDownloadStats() {
    final progress = ModelManager.downloadProgress.value;
    if (progress == 0.0 || progress == 1.0) {
      _lastProgressTime = null;
      _lastProgress = progress;
      return;
    }

    final now = DateTime.now();
    if (_lastProgressTime != null) {
      final timeDelta = now.difference(_lastProgressTime!).inMilliseconds / 1000.0; // seconds
      if (timeDelta > 0.5) { // update every half second to avoid flicker
        final progressDelta = progress - _lastProgress;
        
        // Estimate total size based on selected model (rough estimation since sizeStr is string)
        final selectedModel = ModelManager.availableModels[_selectedIndex];
        double totalSizeMB = selectedModel.sizeStr.contains('GB') 
            ? double.parse(selectedModel.sizeStr.replaceAll(' GB', '')) * 1024 
            : double.parse(selectedModel.sizeStr.replaceAll(' MB', ''));

        final bytesPerSec = (progressDelta * totalSizeMB) / timeDelta;
        
        final remainingProgress = 1.0 - progress;
        final remainingSeconds = bytesPerSec > 0 ? (remainingProgress * totalSizeMB) / bytesPerSec : 0;

        if (mounted) {
          setState(() {
            _downloadSpeed = '${bytesPerSec.toStringAsFixed(1)} MB/s';
            if (remainingSeconds > 60) {
              _timeRemaining = '${(remainingSeconds / 60).toStringAsFixed(0)} min left';
            } else {
              _timeRemaining = '${remainingSeconds.toStringAsFixed(0)} sec left';
            }
          });
        }
        
        _lastProgressTime = now;
        _lastProgress = progress;
      }
    } else {
      _lastProgressTime = now;
      _lastProgress = progress;
    }
  }

  void _startDownload(int index) async {
    setState(() => _selectedIndex = index);
    final selectedModel = ModelManager.availableModels[index];
    
    _lastProgressTime = null;
    _lastProgress = 0.0;
    _downloadSpeed = 'Preparing...';
    _timeRemaining = '';

    ModelManager.downloadModel(
      model: selectedModel,
      onProgress: (progress) {},
      onSuccess: () {
        if (mounted) {
          _checkInstalledModels();
          _updateStorageInfo();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${selectedModel.name} downloaded successfully!')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $error')),
          );
        }
      },
    );
  }

  void _uninstallModel(int index) async {
    final selectedModel = ModelManager.availableModels[index];
    await ModelManager.deleteModel(selectedModel.filename);
    if (mounted) {
      _checkInstalledModels();
      _updateStorageInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedModel.name} uninstalled.')),
      );
    }
  }

  void _continueToApp() async {
    final selectedModel = ModelManager.availableModels[_selectedIndex];
    final isInstalled = _installedModels[selectedModel.filename] ?? false;
    
    if (isInstalled) {
      await ModelManager.setActiveModel(selectedModel.filename);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please install the selected model first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 16, color: colorScheme.onSurface),
                onPressed: ModelManager.isDownloading.value ? null : () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.sd_storage_outlined, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  const Text('Storage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${_freeSpaceGB.toStringAsFixed(1)} GB Free', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              const Text(
                'Choose Your AI Model',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select the model that best fits your needs.\nYou can change or download others later.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                      ),
                      child: Icon(Icons.shield_outlined, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'All models run completely offline on your device.\nNo internet required after download.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Recommended Models',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Cards
              ValueListenableBuilder<bool>(
                valueListenable: ModelManager.isDownloading,
                builder: (context, isDownloading, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: ModelManager.isPaused,
                    builder: (context, isPaused, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: ModelManager.downloadProgress,
                        builder: (context, progress, _) {
                          return Column(
                            children: ModelManager.availableModels.asMap().entries.map((entry) {
                              final index = entry.key;
                              final model = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _ModelDetailCard(
                                  title: model.name,
                                  subtitle: model.subtitle,
                                  imageAsset: model.imageAsset,
                                  iconBgColor: model.iconBgColor,
                                  iconColor: model.iconColor,
                                  chips: model.chips,
                                  radioText: model.radioText,
                                  size: model.sizeStr,
                                  ram: model.ram,
                                  speedStars: model.speedStars,
                                  qualityStars: model.qualityStars,
                                  isRecommended: model.isRecommended,
                                  isSelected: _selectedIndex == index,
                                  isInstalled: _installedModels[model.filename] ?? false,
                                  isDownloading: isDownloading && _selectedIndex == index,
                                  isPaused: isPaused,
                                  downloadProgress: progress,
                                  downloadSpeed: _downloadSpeed,
                                  timeRemaining: _timeRemaining,
                                  onTap: isDownloading ? () {} : () => setState(() => _selectedIndex = index),
                                  onInstall: () => _startDownload(index),
                                  onUninstall: () => _uninstallModel(index),
                                  onPause: () => ModelManager.pauseDownload(model),
                                  onResume: () => ModelManager.resumeDownload(model),
                                ),
                              );
                            }).toList(),
                          );
                        }
                      );
                    }
                  );
                }
              ),

              // Native Ad during download
              const SizedBox.shrink(),

              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Not sure which to choose?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Gemma 2 2B Q8 is optimized for high-quality offline chats.', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ValueListenableBuilder<bool>(
            valueListenable: ModelManager.isDownloading,
            builder: (context, isDownloading, _) {
              return ElevatedButton(
                onPressed: isDownloading ? null : _continueToApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Indigo shade
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}

class _ModelDetailCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageAsset;
  final Color iconBgColor;
  final Color iconColor;
  final List<String> chips;
  final String radioText;
  final String size;
  final String ram;
  final int speedStars;
  final int qualityStars;
  final bool isRecommended;
  final bool isSelected;
  final bool isInstalled;
  final bool isDownloading;
  final bool isPaused;
  final double downloadProgress;
  final String downloadSpeed;
  final String timeRemaining;
  final VoidCallback onTap;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const _ModelDetailCard({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.iconBgColor,
    required this.iconColor,
    required this.chips,
    required this.radioText,
    required this.size,
    required this.ram,
    required this.speedStars,
    required this.qualityStars,
    required this.isRecommended,
    required this.isSelected,
    required this.isInstalled,
    required this.isDownloading,
    required this.isPaused,
    required this.downloadProgress,
    required this.downloadSpeed,
    required this.timeRemaining,
    required this.onTap,
    required this.onInstall,
    required this.onUninstall,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest.withOpacity(isSelected ? 0.8 : 0.3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark || !isSelected ? [] : [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Content
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            imageAsset,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (isRecommended) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.star, size: 10, color: Color(0xFF6366F1)),
                                          SizedBox(width: 2),
                                          Text('Recommended', style: TextStyle(color: Color(0xFF6366F1), fontSize: 8, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chips.map((chip) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? colorScheme.onSurface : Colors.grey.shade700,
                          ),
                        ),
                      )).toList(),
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? const Color(0xFF6366F1) : colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          radioText,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Actions & Progress Area
                    if (isDownloading)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isPaused ? 'Paused' : 'Downloading: ${(downloadProgress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold, 
                                        color: isPaused ? Colors.orange : const Color(0xFF6366F1),
                                      ),
                                    ),
                                    Text(
                                      isPaused ? '-- MB/s' : downloadSpeed,
                                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: downloadProgress,
                                    minHeight: 6,
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isPaused ? Colors.orange : const Color(0xFF6366F1)
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isPaused ? 'Tap resume to continue' : timeRemaining,
                                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Pause / Resume Button
                          InkWell(
                            onTap: isPaused ? onResume : onPause,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isPaused ? Colors.orange.withOpacity(0.1) : const Color(0xFF6366F1).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                color: isPaused ? Colors.orange : const Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (isInstalled)
                            ElevatedButton.icon(
                              onPressed: onUninstall,
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text('Uninstall', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.error,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(0, 32),
                                elevation: 0,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: onInstall,
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text('Install', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                                foregroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(0, 32),
                                elevation: 0,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Container(
                  width: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),

              // Right Content (Stats)
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatRow(icon: Icons.download_outlined, label: 'Size', value: size),
                    _StatRow(icon: Icons.memory_outlined, label: 'RAM', value: ram),
                    _StatStars(icon: Icons.bolt_outlined, label: 'Speed', stars: speedStars),
                    _StatStars(icon: Icons.auto_awesome_outlined, label: 'Quality', stars: qualityStars),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatStars extends StatelessWidget {
  final IconData icon;
  final String label;
  final int stars;

  const _StatStars({required this.icon, required this.label, required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              Icons.star,
              size: 8,
              color: index < stars ? const Color(0xFF6366F1) : Colors.grey.shade300,
            );
          }),
        ),
      ],
    );
  }
}
