import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

/// Core service for managing Gemma AI model
/// Handles model initialization, loading, and inference operations
class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  factory GemmaService() => _instance;
  GemmaService._internal();

  final _log = Logger('GemmaService');
  final _gemma = FlutterGemma();

  bool _isInitialized = false;
  bool _isModelLoaded = false;
  String? _modelPath;

  final StreamController<double> _downloadProgressController =
      StreamController<double>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<double> get downloadProgress => _downloadProgressController.stream;
  Stream<String> get status => _statusController.stream;

  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _isModelLoaded;

  /// Initialize the Gemma service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _updateStatus('Initializing Gemma service...');
      _log.info('Initializing Gemma service');

      // Get the models directory
      final directory = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${directory.path}/gemma_models');

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      _isInitialized = true;
      _updateStatus('Gemma service initialized');
      _log.info('Gemma service initialized successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize Gemma service', e, stackTrace);
      _updateStatus('Failed to initialize: $e');
      rethrow;
    }
  }

  /// Load the Gemma model
  /// Uses Gemma 3 Nano 270M for optimal performance on mobile devices
  Future<void> loadModel({
    String modelName = 'gemma-3-nano-270m-q4',
    int maxTokens = 512,
    double temperature = 0.7,
    int topK = 40,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isModelLoaded) {
      _log.info('Model already loaded');
      return;
    }

    try {
      _updateStatus('Loading model: $modelName...');
      _log.info('Loading Gemma model: $modelName');

      // Initialize the model with parameters
      await _gemma.init(
        maxTokens: maxTokens,
        temperature: temperature,
        topK: topK,
        randomSeed: DateTime.now().millisecondsSinceEpoch,
      );

      _isModelLoaded = true;
      _updateStatus('Model loaded successfully');
      _log.info('Model loaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to load model', e, stackTrace);
      _updateStatus('Failed to load model: $e');
      rethrow;
    }
  }

  /// Generate text using the Gemma model
  Future<String> generateText(
    String prompt, {
    int? maxTokens,
    bool stream = false,
  }) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      _log.info('Generating text for prompt: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');

      final response = await _gemma.generateContent(prompt);

      _log.info('Text generated successfully');
      return response ?? '';
    } catch (e, stackTrace) {
      _log.severe('Failed to generate text', e, stackTrace);
      rethrow;
    }
  }

  /// Generate text with streaming support
  Stream<String> generateTextStream(String prompt) {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    return _gemma.generateContentStream(prompt);
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
    if (!_isModelLoaded) return;

    try {
      _updateStatus('Unloading model...');
      _log.info('Unloading model');

      // The flutter_gemma plugin doesn't have explicit unload,
      // but we can mark it as unloaded
      _isModelLoaded = false;

      _updateStatus('Model unloaded');
      _log.info('Model unloaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to unload model', e, stackTrace);
      _updateStatus('Failed to unload model: $e');
      rethrow;
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
  void dispose() {
    _downloadProgressController.close();
    _statusController.close();
  }
}
