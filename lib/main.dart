import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:flutter/foundation.dart';
import 'onboarding.dart';
import 'profile.dart' as profile;
import 'model_manager.dart';
import 'ai_service.dart';
import 'file_parser.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';
import 'firebase_options.dart';
import 'analytics_service.dart';
import 'sheets_service.dart';


// ─────────────────────────────────────────────
//  Attachment Model
// ─────────────────────────────────────────────

enum _AttachType { image, pdf, word, excel }

class _Attachment {
  final String path;
  final String name;
  final _AttachType type;
  _Attachment({required this.path, required this.name, required this.type});
}

// ─────────────────────────────────────────────
//  Chat Models
// ─────────────────────────────────────────────

class ChatMessage {
  final String role; // 'user' or 'ai'
  final String content;
  final List<_Attachment>? attachments;

  ChatMessage({required this.role, required this.content, this.attachments});

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    // Note: attachments are currently not persisted as files might be large/temporary, 
    // but we store them for the current session UI.
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(role: json['role'], content: json['content']);
  }
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const PocketMindApp());
}

class PocketMindApp extends StatelessWidget {
  const PocketMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Mind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFC),
          onSurface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFFE2E8F0),
          outlineVariant: const Color(0xFFCBD5E1),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
          onSurface: const Color(0xFFF8FAFC),
          surfaceContainerHighest: const Color(0xFF1E293B),
          outlineVariant: const Color(0xFF334155),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────
//  Splash Screen
// ─────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start background tasks
    await ModelManager.migrateModelsToExternal();
    ModelManager.resumeExistingDownloads();
    SheetsService.retryPending(); // Retry any unsent sheet data
    final activeModelTask = ModelManager.getActiveModelPath();
    
    // Enforce a minimum splash duration for the animation to play beautifully
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      activeModelTask,
    ]);

    final activePath = await activeModelTask;

    if (!mounted) return;

    if (activePath != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    // Check auth status
    final auth = AuthService();
    final user = auth.currentUser;
    
    if (user != null) {
      final hasCompleted = await auth.hasCompletedSurvey(user.uid);
      if (!mounted) return;
      
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                isDark
                    ? 'assets/images/dark_splash_screen.png'
                    : 'assets/images/light_splash_screen.png',
                fit: BoxFit.cover,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [Colors.transparent, Colors.black.withOpacity(0.85)]
                          : [Colors.transparent, Colors.white.withOpacity(0.90)],
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
}

// ─────────────────────────────────────────────
//  Chat Screen (Home Screen replacement)
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatSession> _allSessions = [];
  String? _currentSessionId;
  List<ChatMessage> _currentMessages = [];
  bool _isTyping = false;
  bool _isGenerating = false;

  // Attachments
  final List<_Attachment> _attachments = [];
  String? _activeModelFilename;
  List<String> _installedModelFilenames = [];
  String _typingStatus = 'PocketMind is thinking...';
  Timer? _statusTimer;
  final List<String> _statusPhrases = [
    'Exploring the mind...',
    'Analyzing context...',
    'Searching user files...',
    'Structuring thoughts...',
    'Formulating answer...',
    'Finalizing response...',
  ];
  int _statusIdx = 0;

  void _startStatusCycle() {
    _statusIdx = 0;
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _statusIdx = (_statusIdx + 1) % _statusPhrases.length;
          _typingStatus = _statusPhrases[_statusIdx];
        });
      }
    });
  }

  void _stopStatusCycle() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _launchLinkedIn() async {
    final Uri url = Uri.parse('https://www.linkedin.com/in/omavchar/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }


  void _addAttachments(List<_Attachment> newItems) {
    setState(() {
      for (final a in newItems) {
        if (_attachments.length < 5) _attachments.add(a);
      }
    });
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadActiveModel();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveModel() async {
    final prefs = await SharedPreferences.getInstance();
    final filename = prefs.getString('active_model');
    
    // Update installed models list
    final installedFiles = await ModelManager.getInstalledModels();
    final installedNames = installedFiles.map((f) => f.path.split('/').last.split('\\').last).toList();

    setState(() {
      _activeModelFilename = filename;
      _installedModelFilenames = installedNames;
    });

    if (filename != null) {
      final path = await ModelManager.getActiveModelPath();
      if (path != null) {
        try {
          await AiService().loadModel(path);
        } catch (e) {
          debugPrint("Error loading model in background: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load AI model: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString('chat_sessions');
      if (sessionsJson != null) {
        final List decoded = jsonDecode(sessionsJson);
        setState(() {
          _allSessions = decoded.map((s) => ChatSession.fromJson(s)).toList();
          _allSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    } catch (e) {
      debugPrint("Error loading sessions: $e");
    }
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_allSessions.map((s) => s.toJson()).toList());
      await prefs.setString('chat_sessions', encoded);
    } catch (e) {
      debugPrint("Error saving sessions: $e");
    }
  }

  void _createNewChat() {
    setState(() {
      _currentSessionId = null;
      _currentMessages = [];
      _inputController.clear();
      _attachments.clear();
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _loadChat(String sessionId) {
    final session = _allSessions.firstWhere((s) => s.id == sessionId);
    setState(() {
      _currentSessionId = session.id;
      _currentMessages = List.from(session.messages);
    });
    _scaffoldKey.currentState?.closeDrawer();
    _scrollToBottom();
  }

  void _deleteChat(String sessionId) {
    setState(() {
      _allSessions.removeWhere((s) => s.id == sessionId);
      if (_currentSessionId == sessionId) {
        _createNewChat();
      }
    });
    _saveSessions();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    _inputController.clear();
    final currentAttachments = List<_Attachment>.from(_attachments);
    
    // Add User Message
    setState(() {
      _currentMessages.add(ChatMessage(
        role: 'user', 
        content: text,
        attachments: currentAttachments,
      ));
      _isTyping = true;
      _attachments.clear();
    });
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Create session if it doesn't exist
    if (_currentSessionId == null) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final title = text.isNotEmpty ? (text.length > 25 ? '${text.substring(0, 25)}...' : text) : 'New Chat';
      _allSessions.insert(0, ChatSession(
        id: _currentSessionId!,
        title: title,
        createdAt: DateTime.now(),
        messages: [],
      ));
    }

    // Save current state
    _updateCurrentSession();

    await _generateAiResponse(text, currentAttachments);
  }

  void _updateCurrentSession() {
    final index = _allSessions.indexWhere((s) => s.id == _currentSessionId);
    if (index != -1) {
      _allSessions[index].messages = List.from(_currentMessages);
      _saveSessions();
    }
  }

  void _editMessage(int index) {
    // Get text and populate input
    final text = _currentMessages[index].content;
    _inputController.text = text;
    
    // Remove this message and all subsequent messages
    setState(() {
      _currentMessages.removeRange(index, _currentMessages.length);
      _updateCurrentSession();
    });
  }

  void _retryMessage(int index) {
    if (index > 0 && _currentMessages[index - 1].role == 'user') {
      final userText = _currentMessages[index - 1].content;
      final userAttachments = _currentMessages[index - 1].attachments;
      
      setState(() {
        _currentMessages.removeRange(index, _currentMessages.length);
        _isTyping = true;
      });
      _updateCurrentSession();
      _scrollToBottom();
      
      _generateAiResponse(userText, userAttachments ?? []);
    }
  }

  Future<void> _generateAiResponse(String text, List<_Attachment> currentAttachments) async {
    try {
      // 1. Extract text from attachments if any
      setState(() => _typingStatus = 'Scanning files...');
      _startStatusCycle(); // Begin cycling through smart phrases
      
      List<String> contextTexts = [];
      if (currentAttachments.isNotEmpty) {
        final results = await Future.wait(currentAttachments.map((a) async {
          final extracted = await FileParser.extractText(a.path);
          return extracted.isNotEmpty ? "File: ${a.name}\n$extracted" : null;
        }));
        contextTexts = results.whereType<String>().toList();
      }

      // 2. Ensure model is loaded
      if (!AiService().isModelLoaded) {
        setState(() => _typingStatus = 'Loading AI model (Offline)...');
        final path = await ModelManager.getActiveModelPath();
        if (path != null) {
          await AiService().loadModel(path);
        } else {
          throw Exception("No AI model found. Please download a model from the 'Manage Models' screen first.");
        }
      }

      // 3. Generate Real AI Response with Streaming
      setState(() {
        _typingStatus = 'Thinking...';
        _isGenerating = true; // Show stop button
        _isTyping = true;    // SHOW the typing indicator with cycling status
      });

      final aiMsgIndex = _currentMessages.length; // Will be added once first token arrives

      try {
        bool hasStartedStreaming = false;

        await AiService().generateStreamingResponse(
          text, 
          contextTexts: contextTexts,
          onToken: (fullText) {
            if (mounted) {
              setState(() {
                if (!hasStartedStreaming) {
                  // First token arrived! Hide indicator and add the message bubble
                  _isTyping = false;
                  _currentMessages.add(ChatMessage(role: 'ai', content: fullText));
                  hasStartedStreaming = true;
                  _scrollToBottom(animated: true, isStreaming: true);
                } else {
                  // Update existing bubble
                  _currentMessages[_currentMessages.length - 1] = ChatMessage(
                    role: 'ai',
                    content: fullText,
                  );
                  _scrollToBottom(animated: false, isStreaming: true);
                }
              });
            }
          }
        );
      } finally {
        if (mounted) {
          setState(() => _isGenerating = false);
          _stopStatusCycle();
          // Log model usage silently
          AnalyticsService.logModelUsed(_activeModelFilename ?? 'unknown');
        }
      }
    } catch (e) {
      debugPrint("AI Generation Error: $e");
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _stopStatusCycle();
        // If we added an empty message, replace it with error
        if (_currentMessages.isNotEmpty && _currentMessages.last.role == 'ai' && _currentMessages.last.content.isEmpty) {
          _currentMessages.removeLast();
        }
        _currentMessages.add(ChatMessage(
          role: 'ai', 
          content: 'Error: $e\n\nTip: Make sure you have downloaded a model and selected it in the model selection menu.'
        ));
        _isTyping = false;
      });
    }
    _updateCurrentSession();
    _scrollToBottom(animated: true);
  }

  void _scrollToBottom({bool animated = true, bool isStreaming = false}) {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;

    // If it's streaming and the user has manually scrolled up to read earlier messages, don't force scroll down
    if (isStreaming && pos.maxScrollExtent - pos.pixels > 200) {
      return;
    }

    if (animated) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Jump instantly to avoid animation overlaps/glitching during fast token streaming
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colorScheme.onSurface),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'PocketMind',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square, color: colorScheme.onSurface, size: 22),
            onPressed: _createNewChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentMessages.isEmpty 
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      ),
                      child: Center(
                        child: Image.asset('assets/images/logo.png', width: 40, height: 40),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'How can I help you today?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                physics: const BouncingScrollPhysics(),
                itemCount: _currentMessages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _currentMessages.length) {
                    return _TypingIndicator(status: _typingStatus);
                  }
                  final msg = _currentMessages[index];
                  
                  // Wrap in a simple fade-in for new messages
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: msg.role == 'user'
                      ? _UserMessageBubble(
                          text: msg.content,
                          attachments: msg.attachments,
                          onEdit: () => _editMessage(index),
                        )
                      : _AiMessageBubble(
                          text: msg.content,
                          activeModel: _activeModelFilename ?? 'unknown',
                          onRetry: () => _retryMessage(index),
                        ),
                  );
                },
              ),
          ),
          
          // Input Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Suggested prompts
                  if (_currentMessages.isEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SuggestedPrompt(
                            text: 'How does superposition work?',
                            onTap: () {
                              _inputController.text = 'How does superposition work?';
                              _sendMessage();
                            },
                          ),
                          _SuggestedPrompt(
                            text: 'Give real life examples',
                            onTap: () {
                              _inputController.text = 'Give real life examples';
                              _sendMessage();
                            },
                          ),
                        ],
                      ),
                    ),
                  if (_currentMessages.isEmpty) const SizedBox(height: 12),
                  
                  // Advanced Text Input Area
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Attachment preview strip ──
                        if (_attachments.isNotEmpty) ..._buildAttachmentPreviews(colorScheme),
                        TextField(
                          controller: _inputController,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Ask PocketMind anything...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Model Selection Button
                            InkWell(
                              onTap: () async {
                                // Refresh installed models list before showing
                                await _loadActiveModel();
                                if (!mounted) return;
                                
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: colorScheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  builder: (context) {
                                    return SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: colorScheme.outlineVariant.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Select Model',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...ModelManager.availableModels.where((m) => _installedModelFilenames.contains(m.filename)).map((model) {
                                              final isActive = _activeModelFilename == model.filename;
                                              return InkWell(
                                                onTap: () async {
                                                  await ModelManager.setActiveModel(model.filename);
                                                  setState(() {
                                                    _activeModelFilename = model.filename;
                                                  });
                                                  if (mounted) Navigator.pop(context);
                                                  // Reload model in AiService
                                                  await _loadActiveModel();
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.asset(
                                                          model.imageAsset,
                                                          width: 28,
                                                          height: 28,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(model.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isActive ? colorScheme.primary : null)),
                                                          const SizedBox(height: 2),
                                                          Text(model.sizeStr, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                                                        ],
                                                      ),
                                                      const Spacer(),
                                                      if (isActive)
                                                        Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            if (ModelManager.availableModels.where((m) => _installedModelFilenames.contains(m.filename)).isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 20),
                                                child: Text('No models downloaded yet', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                                              ),
                                            Divider(height: 16, color: colorScheme.outlineVariant.withOpacity(0.3)),
                                            InkWell(
                                              onTap: () {
                                                Navigator.pop(context); // Close sheet
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme.surfaceContainerHighest,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(Icons.tune, color: colorScheme.onSurfaceVariant, size: 16),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const Text('Manage Models', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                    const Spacer(),
                                                    Icon(Icons.arrow_forward_ios, size: 12, color: colorScheme.onSurfaceVariant),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final currentModel = ModelManager.availableModels.firstWhere((m) => m.filename == _activeModelFilename, orElse: () => ModelManager.availableModels.first);
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(currentModel.imageAsset, width: 14, height: 14, fit: BoxFit.contain),
                                            const SizedBox(width: 4),
                                            Text(
                                              currentModel.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(Icons.keyboard_arrow_down, size: 14, color: colorScheme.onSurfaceVariant),
                                          ],
                                        );
                                      }
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Local Media Button
                            _LocalMediaButton(onAttach: _addAttachments),
                            // Groble (Web Search) Button
                            _GroblebButton(),
                            const Spacer(),
                            
                            // Send or Stop Button
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: _isGenerating 
                              ? InkWell(
                                  key: const ValueKey('stop_btn'),
                                  onTap: () {
                                    AiService().stopGeneration();
                                    setState(() => _isGenerating = false);
                                    HapticFeedback.mediumImpact();
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorScheme.error.withOpacity(0.2)),
                                    ),
                                    child: Icon(Icons.stop_rounded, color: colorScheme.error, size: 24),
                                  ),
                                )
                              : InkWell(
                                  key: const ValueKey('send_btn'),
                                  onTap: _sendMessage,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [colorScheme.primary, colorScheme.primary.withBlue(255)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.primary.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PocketMind can make mistakes. Consider verifying important information.',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Attachment preview strip builder ──
  List<Widget> _buildAttachmentPreviews(ColorScheme colorScheme) {
    return [
      SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length,
          itemBuilder: (context, i) {
            final att = _attachments[i];
            return Padding(
              padding: EdgeInsets.only(right: 8, bottom: 4, top: 2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Card
                  att.type == _AttachType.image
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(att.path),
                            width: 66,
                            height: 66,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: _fileColor(att.type).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _fileColor(att.type).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_fileIcon(att.type),
                                  color: _fileColor(att.type), size: 26),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  att.name.length > 8
                                      ? '${att.name.substring(0, 7)}…'
                                      : att.name,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _fileColor(att.type),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                  // Remove button
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _removeAttachment(i),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  IconData _fileIcon(_AttachType t) {
    switch (t) {
      case _AttachType.pdf:   return Icons.picture_as_pdf_rounded;
      case _AttachType.word:  return Icons.description_rounded;
      case _AttachType.excel: return Icons.table_chart_rounded;
      default:                return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(_AttachType t) {
    switch (t) {
      case _AttachType.pdf:   return const Color(0xFFEF4444);
      case _AttachType.word:  return const Color(0xFF2563EB);
      case _AttachType.excel: return const Color(0xFF16A34A);
      default:                return const Color(0xFF6366F1);
    }
  }

  // Helper method for drawer
  Widget _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Drawer(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Top Section: Logo & New Chat
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 32, height: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'PocketMind',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _createNewChat,
                    icon: Icon(Icons.edit_square, color: colorScheme.onSurfaceVariant),
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            
            // Divider
            Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
            
            // Chat History
            Expanded(
              child: _allSessions.isEmpty
                  ? Center(child: Text('No recent chats', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _buildGroupedSessions(context, colorScheme),
                    ),
            ),
            
            // Divider
            Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
            
            // Bottom Section: Manage Models & User Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: colorScheme.onSurfaceVariant, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Manage Models',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const profile.ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Builder(builder: (context) {
                        final user = AuthService().currentUser;
                        final name = user?.displayName ?? 'User';
                        final photoUrl = user?.photoURL;
                        final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary,
                              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null
                                  ? Text(initials, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 13))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Connect with Om Avchar
                  InkWell(
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      _launchLinkedIn();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0077B5).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.link, color: Color(0xFF0077B5), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Developer LinkedIn',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Connect with Om Avchar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 16, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Debug Info Toggle
                  if (kDebugMode)
                    TextButton.icon(
                      onPressed: () async {
                        final path = await ModelManager.getActiveModelPath();
                        final installed = await ModelManager.getInstalledModels();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Debug Info'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Active: ${_activeModelFilename ?? "None"}'),
                                    const SizedBox(height: 8),
                                    Text('Path: ${path ?? "Invalid"}'),
                                    const SizedBox(height: 8),
                                    Text('Installed Files: ${installed.length}'),
                                    ...installed.map((f) => Text('- ${f.path.split('/').last.split('\\').last}', style: const TextStyle(fontSize: 10))),
                                    const SizedBox(height: 8),
                                    Text('AI Loaded: ${AiService().isModelLoaded}'),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    await AiService().dispose();
                                    await _loadActiveModel();
                                    if (context.mounted) Navigator.pop(c);
                                  },
                                  child: const Text('Reset Engine', style: TextStyle(color: Colors.red)),
                                ),
                                TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bug_report_outlined, size: 14),
                      label: const Text('Debug Models', style: TextStyle(fontSize: 10)),
                    ),
                    
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Generated by Om Avchar',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSessions(BuildContext context, ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    Map<String, List<ChatSession>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (var session in _allSessions) {
      final sessionDate = DateTime(session.createdAt.year, session.createdAt.month, session.createdAt.day);
      if (sessionDate == today) {
        groups['Today']!.add(session);
      } else if (sessionDate == yesterday) {
        groups['Yesterday']!.add(session);
      } else if (sessionDate.isAfter(sevenDaysAgo)) {
        groups['Previous 7 Days']!.add(session);
      } else {
        groups['Older']!.add(session);
      }
    }

    List<Widget> widgets = [];
    groups.forEach((title, sessions) {
      if (sessions.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
        ));
        for (var session in sessions) {
          final isSelected = session.id == _currentSessionId;
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
            child: ListTile(
              onTap: () => _loadChat(session.id),
              selected: isSelected,
              selectedTileColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              trailing: isSelected ? GestureDetector(
                onTap: () => _deleteChat(session.id),
                child: Icon(Icons.delete_outline, size: 16, color: colorScheme.error.withOpacity(0.7)),
              ) : null,
            ),
          ));
        }
      }
    });
    return widgets;
  }
}

class _TypingIndicator extends StatefulWidget {
  final String status;
  const _TypingIndicator({required this.status});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0, right: 48.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pulsing Avatar
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2 * _pulseAnim.value),
                      blurRadius: 15 * _pulseAnim.value,
                      spreadRadius: 2 * _pulseAnim.value,
                    )
                  ],
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.1 + (0.2 * _pulseAnim.value)),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome, 
                    size: 18, 
                    color: colorScheme.primary.withOpacity(0.5 + (0.5 * _pulseAnim.value)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shimmering Status Bubble
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.25),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.1 * _pulseAnim.value),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Small modern indicator (shimmering bar)
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.3 + (0.7 * _pulseAnim.value)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withOpacity(0.6 + (0.4 * _pulseAnim.value)),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestedPrompt extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestedPrompt({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  final String text;
  final List<_Attachment>? attachments;
  final VoidCallback onEdit;

  const _UserMessageBubble({required this.text, this.attachments, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 48.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (attachments != null && attachments!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: attachments!.map((a) => _buildAttachmentBadge(context, a)).toList(),
                ),
              ),
            GestureDetector(
              onLongPress: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withBlue(220)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 12, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentBadge(BuildContext context, _Attachment a) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color color;

    switch (a.type) {
      case _AttachType.image:
        icon = Icons.image_outlined;
        color = Colors.orange;
        break;
      case _AttachType.pdf:
        icon = Icons.picture_as_pdf_outlined;
        color = Colors.red;
        break;
      case _AttachType.word:
        icon = Icons.description_outlined;
        color = Colors.blue;
        break;
      case _AttachType.excel:
        icon = Icons.table_chart_outlined;
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            a.name.length > 15 ? '${a.name.substring(0, 12)}...' : a.name,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _AiMessageBubble extends StatefulWidget {
  final String text;
  final String activeModel;
  final VoidCallback? onRetry;

  const _AiMessageBubble({required this.text, required this.activeModel, this.onRetry});

  @override
  State<_AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<_AiMessageBubble> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  @override
  void dispose() {
    // Fire-and-forget stop; ignore any plugin-not-ready errors during dispose
    _flutterTts.stop().catchError((_) {});
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    try {
      if (_isPlaying) {
        await _flutterTts.stop();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        if (mounted) setState(() => _isPlaying = true);
        await _flutterTts.setLanguage("en-US");
        await _flutterTts.setSpeechRate(0.5);

        _flutterTts.setCompletionHandler(() {
          if (mounted) setState(() => _isPlaying = false);
        });

        await _flutterTts.speak(widget.text);
      }
    } catch (e) {
      // Plugin not yet compiled into the running build — reset state silently
      if (mounted) setState(() => _isPlaying = false);
      debugPrint('TTS unavailable (needs full restart): $e');
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0, right: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary.withOpacity(0.2), colorScheme.primary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                  ),
                  child: MarkdownBody(
                    data: widget.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 15.5, color: colorScheme.onSurface.withOpacity(0.9), height: 1.6),
                      code: TextStyle(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        color: colorScheme.primary,
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ActionButton(
                      icon: _isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                      onTap: _toggleAudio,
                      isActive: _isPlaying,
                    ),
                    _ActionButton(
                      icon: Icons.copy_outlined,
                      onTap: _copyToClipboard,
                    ),
                    if (widget.onRetry != null)
                      _ActionButton(
                        icon: Icons.refresh_outlined,
                        onTap: widget.onRetry!,
                      ),
                    const Spacer(),
                    _ActionButton(
                      icon: Icons.thumb_up_outlined,
                      onTap: () {
                        AnalyticsService.logLike(widget.activeModel);
                      },
                    ),
                    _ActionButton(
                      icon: Icons.thumb_down_outlined,
                      onTap: () {
                        AnalyticsService.logDislike(widget.activeModel);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({required this.icon, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          icon,
          size: 16,
          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Local Media Button (popup: Files, Camera, Photos)
// ─────────────────────────────────────────────

class _LocalMediaButton extends StatefulWidget {
  final void Function(List<_Attachment>) onAttach;
  const _LocalMediaButton({required this.onAttach});

  @override
  State<_LocalMediaButton> createState() => _LocalMediaButtonState();
}

class _LocalMediaButtonState extends State<_LocalMediaButton> {
  final GlobalKey _buttonKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  // ── Gallery: pick up to 5 images ──
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(limit: 5);
      if (files.isEmpty) return;
      final attachments = files.map((f) => _Attachment(
        path: f.path,
        name: f.name,
        type: _AttachType.image,
      )).toList();
      widget.onAttach(attachments);
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  // ── Camera: take one photo ──
  Future<void> _pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;
      widget.onAttach([_Attachment(
        path: file.path,
        name: file.name,
        type: _AttachType.image,
      )]);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  // ── Files: pick PDF / Word / Excel ──
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
        allowMultiple: true,
      );
      if (result == null) return;
      final attachments = result.files.map((f) {
        final ext = f.extension?.toLowerCase() ?? '';
        _AttachType type;
        if (ext == 'pdf') {
          type = _AttachType.pdf;
        } else if (ext == 'xls' || ext == 'xlsx') {
          type = _AttachType.excel;
        } else {
          type = _AttachType.word;
        }
        return _Attachment(
          path: f.path ?? '',
          name: f.name,
          type: type,
        );
      }).toList();
      widget.onAttach(attachments);
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _showMediaPopup() {
    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 195,
        offset.dx + size.width,
        offset.dy,
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'ADD MEDIA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        _mediaMenuItem(
          context: context,
          icon: Icons.insert_drive_file_outlined,
          label: 'Files',
          subtitle: 'PDF, Word, Excel',
          color: const Color(0xFF6366F1),
          onTap: _pickFiles,
        ),
        _mediaMenuItem(
          context: context,
          icon: Icons.camera_alt_outlined,
          label: 'Camera',
          subtitle: 'Take a photo',
          color: const Color(0xFF0EA5E9),
          onTap: _pickFromCamera,
        ),
        _mediaMenuItem(
          context: context,
          icon: Icons.photo_library_outlined,
          label: 'Photos',
          subtitle: 'Choose from gallery (max 5)',
          color: const Color(0xFF10B981),
          onTap: _pickFromGallery,
        ),
      ],
    );
  }

  PopupMenuItem _mediaMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      key: _buttonKey,
      onPressed: _showMediaPopup,
      icon: Icon(
        Icons.attach_file_rounded,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Local Media',
    );
  }
}



// ─────────────────────────────────────────────
//  Groble (Web Search) Button
// ─────────────────────────────────────────────

class _GroblebButton extends StatefulWidget {
  const _GroblebButton();

  @override
  State<_GroblebButton> createState() => _GroblebButtonState();
}

class _GroblebButtonState extends State<_GroblebButton> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;

    return IconButton(
      onPressed: () => setState(() => _active = !_active),
      icon: Icon(
        Icons.language,
        size: 20,
        color: _active ? activeColor : colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Groble — Web Search',
    );
  }
}
