import 'dart:async';
import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  bool _isModelLoaded = false;
  String? _loadedModelPath;
  int? _currentRequestId;

  bool get isModelLoaded => _isModelLoaded;

  // Strong System Prompt to guide the AI persona
  static const String systemPrompt = """
You are PocketMind, a smart, helpful, and premium offline AI assistant.

Your goal is to provide high-quality, structured, and accurate responses.

Rules:
* ALWAYS use Markdown for structure (Headings, Bold text, Bullet points, Code blocks).
* Be concise but COMPLETE. Never cut off mid-sentence.
* If a detailed explanation is needed, provide it in a structured way.
* Avoid unnecessary filler words or fluff.
* Never invent fake facts. If you don't know, say "I don't know".
* Stay professional and modern.
""";

  Future<void> loadModel(String path) async {
    if (_loadedModelPath == path && _isModelLoaded) return;

    try {
      debugPrint('Preparing model: $path');
      _loadedModelPath = path;
      _isModelLoaded = true; 
      debugPrint('Model ready for inference at: $path');
    } catch (e) {
      debugPrint('Error preparing model: $e');
      _isModelLoaded = false;
      _loadedModelPath = null;
      rethrow;
    }
  }

  Future<String> generateStreamingResponse(
    String prompt, {
    List<String> contextTexts = const [],
    required Function(String) onToken,
  }) async {
    if (!_isModelLoaded || _loadedModelPath == null) {
      throw Exception('AI Model not loaded.');
    }

    try {
      final messages = <Message>[];
      
      // 1. Add System Prompt
      messages.add(Message(Role.system, systemPrompt));

      // 2. Add Context from files if available
      if (contextTexts.isNotEmpty) {
        messages.add(Message(
          Role.system,
          "Additional Context from user files:\n${contextTexts.join('\n---\n')}",
        ));
      }

      // 3. Add User Question
      messages.add(Message(Role.user, prompt));

      // 4. Use Optimized Settings for quality and complete answers
      final request = OpenAiRequest(
        modelPath: _loadedModelPath!,
        messages: messages,
        temperature: 0.4,    // Slightly lower for even more stability
        topP: 0.9,          // Allows for slightly more creative but high-probability tokens
        presencePenalty: 1.1,
        frequencyPenalty: 1.1, // Added to prevent looping
        maxTokens: 1024,      // Increased to prevent cutting off answers
        contextSize: 4096,    // Increased context for better coherence
        numGpuLayers: 0,     
      );

      StringBuffer fullResponse = StringBuffer();
      Completer<String> completer = Completer<String>();

      debugPrint('Starting PocketMind inference for: $prompt');

      _currentRequestId = await fllamaChat(request, (String responseText, String json, bool done) {
        if (responseText.isNotEmpty) {
          onToken(responseText);
        }
        if (done && !completer.isCompleted) {
          completer.complete(responseText);
        }
      });

      // Timeout safety
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.complete(fullResponse.toString());
          }
          return fullResponse.toString();
        },
      );

      _currentRequestId = null;
      return result;
    } catch (e) {
      debugPrint('Error in PocketMind Chat: $e');
      _currentRequestId = null;
      return 'Error: $e';
    }
  }

  /// Immediately stops the current AI generation
  Future<void> stopGeneration() async {
    if (_currentRequestId != null) {
      debugPrint('Stopping AI generation for request: $_currentRequestId');
      fllamaCancelInference(_currentRequestId!);
      _currentRequestId = null;
    }
  }

  Future<void> dispose() async {
    await stopGeneration();
    _isModelLoaded = false;
    _loadedModelPath = null;
  }
}
