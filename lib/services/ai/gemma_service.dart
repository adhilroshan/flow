import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:logging/logging.dart';

/// Core service for managing Gemma AI model
/// Handles model initialization, loading, and inference operations
class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  factory GemmaService() => _instance;
  GemmaService._internal();

  final _log = Logger('GemmaService');

  bool _isInitialized = false;
  bool _isModelInstalled = false;
  GemmaModel? _model;
  GemmaChat? _chat;

  final StreamController<double> _downloadProgressController =
      StreamController<double>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<double> get downloadProgress => _downloadProgressController.stream;
  Stream<String> get status => _statusController.stream;

  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _model != null && _chat != null;

  /// Initialize the Gemma service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _updateStatus('Initializing Gemma service...');
      _log.info('Initializing Gemma service');

      // Initialize FlutterGemma with optional settings
      await FlutterGemma.initialize(
        maxDownloadRetries: 3,
        enableWebCache: false, // Not needed for mobile
      );

      _isInitialized = true;
      _updateStatus('Gemma service initialized');
      _log.info('Gemma service initialized successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize Gemma service', e, stackTrace);
      _updateStatus('Failed to initialize: $e');
      rethrow;
    }
  }

  /// Download and install the Gemma model
  /// This is a one-time operation per model variant
  Future<void> installModel({
    ModelType modelType = ModelType.gemma3Nano270M,
    Function(int)? onProgress,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isModelInstalled) {
      _log.info('Model already installed');
      return;
    }

    try {
      _updateStatus('Downloading model...');
      _log.info('Installing Gemma model: $modelType');

      // Install model from Hugging Face
      // Note: For production, you may need to host models yourself
      // or handle the Hugging Face token securely
      await FlutterGemma.installModel(modelType: modelType)
          .fromHuggingFace()
          .withProgress((progress) {
        _log.fine('Download progress: $progress%');
        _updateProgress(progress / 100.0);
        onProgress?.call(progress);
      }).install();

      _isModelInstalled = true;
      _updateStatus('Model installed successfully');
      _log.info('Model installed successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to install model', e, stackTrace);
      _updateStatus('Failed to install model: $e');
      rethrow;
    }
  }

  /// Load the Gemma model for inference
  Future<void> loadModel({
    int maxTokens = 512,
    PreferredBackend backend = PreferredBackend.auto,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isModelInstalled) {
      throw Exception(
        'Model not installed. Call installModel() first.',
      );
    }

    if (_model != null) {
      _log.info('Model already loaded');
      return;
    }

    try {
      _updateStatus('Loading model...');
      _log.info('Loading Gemma model');

      // Get the active model instance
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: backend,
      );

      // Create a chat session
      _chat = await _model!.createChat();

      _updateStatus('Model loaded successfully');
      _log.info('Model loaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to load model', e, stackTrace);
      _updateStatus('Failed to load model: $e');
      rethrow;
    }
  }

  /// Generate text using the Gemma model
  Future<String> generateText(String prompt) async {
    if (_chat == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      _log.info(
        'Generating text for prompt: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...',
      );

      // Add user query to chat
      await _chat!.addQueryChunk(
        Message.text(
          text: prompt,
          isUser: true,
        ),
      );

      // Generate response
      final response = await _chat!.generateChatResponse();

      String result = '';
      if (response is TextResponse) {
        result = response.text ?? '';
      }

      _log.info('Text generated successfully');
      return result;
    } catch (e, stackTrace) {
      _log.severe('Failed to generate text', e, stackTrace);
      rethrow;
    }
  }

  /// Generate text with streaming support
  Stream<String> generateTextStream(String prompt) async* {
    if (_chat == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      _log.info('Generating streamed text for prompt');

      // Add user query to chat
      await _chat!.addQueryChunk(
        Message.text(
          text: prompt,
          isUser: true,
        ),
      );

      // Stream response tokens
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          final token = response.token ?? '';
          if (token.isNotEmpty) {
            yield token;
          }
        }
      }

      _log.info('Stream completed');
    } catch (e, stackTrace) {
      _log.severe('Failed to generate streamed text', e, stackTrace);
      rethrow;
    }
  }

  /// Generate a structured response for specific tasks
  /// This method helps format prompts for better results
  Future<String> generateStructuredResponse({
    required String task,
    required String input,
    String? context,
    List<String>? examples,
  }) async {
    final prompt = _buildStructuredPrompt(
      task: task,
      input: input,
      context: context,
      examples: examples,
    );

    return generateText(prompt);
  }

  /// Build a structured prompt for better inference results
  String _buildStructuredPrompt({
    required String task,
    required String input,
    String? context,
    List<String>? examples,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Task: $task');
    buffer.writeln();

    if (context != null) {
      buffer.writeln('Context: $context');
      buffer.writeln();
    }

    if (examples != null && examples.isNotEmpty) {
      buffer.writeln('Examples:');
      for (final example in examples) {
        buffer.writeln('- $example');
      }
      buffer.writeln();
    }

    buffer.writeln('Input: $input');
    buffer.writeln();
    buffer.writeln('Response:');

    return buffer.toString();
  }

  /// Unload the model to free up memory
  Future<void> unloadModel() async {
    if (_chat == null && _model == null) return;

    try {
      _updateStatus('Unloading model...');
      _log.info('Unloading model');

      // Close chat session
      if (_chat != null) {
        await _chat!.close();
        _chat = null;
      }

      // Close model
      if (_model != null) {
        await _model!.close();
        _model = null;
      }

      _updateStatus('Model unloaded');
      _log.info('Model unloaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to unload model', e, stackTrace);
      _updateStatus('Failed to unload model: $e');
      // Don't rethrow - best effort cleanup
    }
  }

  /// Check if model is installed
  Future<bool> isModelInstalled(ModelType modelType) async {
    try {
      // Note: flutter_gemma doesn't have a direct check method
      // This is a placeholder - you may need to track this in preferences
      return _isModelInstalled;
    } catch (e) {
      return false;
    }
  }

  /// Update status message
  void _updateStatus(String message) {
    if (!_statusController.isClosed) {
      _statusController.add(message);
    }
  }

  /// Update download progress
  void _updateProgress(double progress) {
    if (!_downloadProgressController.isClosed) {
      _downloadProgressController.add(progress);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await unloadModel();
    await _downloadProgressController.close();
    await _statusController.close();
  }
}
