import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../../entity/ai_preferences.dart';
import '../../entity/transaction.dart';
import '../../entity/category.dart';
import '../../objectbox.g.dart';
import 'gemma_service.dart';
import 'transaction_categorizer.dart';
import 'natural_language_parser.dart';
import 'spending_insights.dart';
import 'receipt_parser.dart';
import 'smart_search.dart';

/// Central AI Manager that coordinates all AI services
/// Singleton that manages initialization, preferences, and feature access
class AIManager {
  static final AIManager _instance = AIManager._internal();
  factory AIManager() => _instance;
  AIManager._internal();

  final _log = Logger('AIManager');

  // AI Services
  final gemmaService = GemmaService();
  final transactionCategorizer = TransactionCategorizerService();
  final naturalLanguageParser = NaturalLanguageParserService();
  final spendingInsights = SpendingInsightsService();
  final receiptParser = ReceiptParserService();
  final smartSearch = SmartSearchService();

  // State
  bool _initialized = false;
  AIPreferences? _preferences;
  Store? _store;

  bool get isInitialized => _initialized;
  AIPreferences? get preferences => _preferences;

  /// Initialize the AI Manager with ObjectBox store
  Future<void> initialize(Store store) async {
    if (_initialized) return;

    try {
      _log.info('Initializing AI Manager');
      _store = store;

      // Load or create AI preferences
      await _loadPreferences();

      // If AI is enabled, initialize the Gemma service
      if (_preferences?.aiEnabled ?? false) {
        await _initializeAIServices();
      }

      _initialized = true;
      _log.info('AI Manager initialized successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize AI Manager', e, stackTrace);
      rethrow;
    }
  }

  /// Load AI preferences from database
  Future<void> _loadPreferences() async {
    try {
      final box = _store!.box<AIPreferences>();

      // Get the first (and only) preferences object
      final query = box.query().build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        // Create default preferences
        _preferences = AIPreferences.defaults();
        box.put(_preferences!);
        _log.info('Created default AI preferences');
      } else {
        _preferences = results.first;
        _log.info('Loaded existing AI preferences');
      }
    } catch (e, stackTrace) {
      _log.severe('Failed to load AI preferences', e, stackTrace);
      // Create default preferences as fallback
      _preferences = AIPreferences.defaults();
    }
  }

  /// Map model variant string to ModelType enum
  ModelType _getModelType(String variant) {
    switch (variant.toLowerCase()) {
      case 'gemma-3-nano-270m':
      case 'gemma-3-nano-270m-q4':
        return ModelType.gemma3Nano270M;
      case 'gemma-3-nano-1b':
      case 'gemma-3-nano-1b-q4':
        return ModelType.gemma3Nano1B;
      case 'gemma-3-nano-2b':
      case 'gemma-3-nano-2b-q4':
        return ModelType.gemma3Nano2B;
      case 'gemma-2b':
        return ModelType.gemma2B;
      default:
        return ModelType.gemma3Nano270M; // Safe default
    }
  }

  /// Initialize AI services
  Future<void> _initializeAIServices() async {
    try {
      _log.info('Initializing AI services');

      await gemmaService.initialize();

      if (_preferences!.modelDownloaded) {
        await gemmaService.loadModel(
          maxTokens: _preferences!.maxTokens,
        );
      }

      _log.info('AI services initialized');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize AI services', e, stackTrace);
      // Continue anyway - services can be initialized later
    }
  }

  /// Enable AI features
  Future<void> enableAI() async {
    if (_preferences == null) return;

    try {
      _log.info('Enabling AI features');

      // Update preferences
      _preferences = _preferences!.copyWith(
        aiEnabled: true,
        aiEnabledDate: _preferences!.aiEnabledDate ?? DateTime.now(),
      );
      await _savePreferences();

      // Initialize services
      await _initializeAIServices();

      _log.info('AI features enabled');
    } catch (e, stackTrace) {
      _log.severe('Failed to enable AI', e, stackTrace);
      rethrow;
    }
  }

  /// Disable AI features
  Future<void> disableAI() async {
    if (_preferences == null) return;

    try {
      _log.info('Disabling AI features');

      _preferences = _preferences!.copyWith(aiEnabled: false);
      await _savePreferences();

      // Unload model to free memory
      await gemmaService.unloadModel();

      _log.info('AI features disabled');
    } catch (e, stackTrace) {
      _log.severe('Failed to disable AI', e, stackTrace);
      rethrow;
    }
  }

  /// Update AI preferences
  Future<void> updatePreferences(AIPreferences newPreferences) async {
    _preferences = newPreferences;
    await _savePreferences();

    // If model settings changed, reload model
    if (_preferences!.aiEnabled && _preferences!.modelDownloaded) {
      // Unload current model if loaded
      await gemmaService.unloadModel();

      // Load with new settings
      await gemmaService.loadModel(
        maxTokens: _preferences!.maxTokens,
      );
    }
  }

  /// Save preferences to database
  Future<void> _savePreferences() async {
    if (_store == null || _preferences == null) return;

    try {
      final box = _store!.box<AIPreferences>();
      box.put(_preferences!);
      _log.fine('AI preferences saved');
    } catch (e, stackTrace) {
      _log.severe('Failed to save AI preferences', e, stackTrace);
    }
  }

  /// Download and install model
  /// This is a one-time operation that downloads model files
  Future<void> downloadModel({
    String? modelVariant,
    Function(int)? onProgress,
  }) async {
    try {
      final variant = modelVariant ?? _preferences?.modelVariant ?? 'gemma-3-nano-270m-q4';
      final modelType = _getModelType(variant);

      _log.info('Downloading model: $variant (ModelType: $modelType)');

      // Initialize Gemma service if not already done
      if (!gemmaService.isInitialized) {
        await gemmaService.initialize();
      }

      // Install the model (downloads model files)
      await gemmaService.installModel(
        modelType: modelType,
        onProgress: onProgress,
      );

      // Update preferences
      if (_preferences != null) {
        _preferences = _preferences!.copyWith(
          modelDownloaded: true,
          modelVariant: variant,
        );
        await _savePreferences();
      }

      _log.info('Model downloaded successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to download model', e, stackTrace);
      rethrow;
    }
  }

  /// Load model into memory for inference
  /// Call this after downloadModel() or on app startup
  Future<void> loadModelForInference() async {
    if (!_preferences!.modelDownloaded) {
      throw Exception('Model not downloaded. Call downloadModel() first.');
    }

    try {
      _log.info('Loading model for inference');

      await gemmaService.loadModel(
        maxTokens: _preferences!.maxTokens,
      );

      _log.info('Model loaded and ready for inference');
    } catch (e, stackTrace) {
      _log.severe('Failed to load model', e, stackTrace);
      rethrow;
    }
  }

  /// Check if AI features can be used
  bool canUseAI() {
    return _initialized &&
        (_preferences?.aiEnabled ?? false) &&
        (_preferences?.modelDownloaded ?? false) &&
        gemmaService.isModelLoaded;
  }

  /// Categorize a transaction using AI
  Future<CategorySuggestion?> categorizeTransaction({
    required String description,
    required List<Category> availableCategories,
    String? merchant,
    double? amount,
  }) async {
    if (!canUseAI() || !(_preferences?.autoCategorizationEnabled ?? false)) {
      return null;
    }

    try {
      _preferences = _preferences!.copyWith(
        totalAIOperations: _preferences!.totalAIOperations + 1,
        lastModelUsage: DateTime.now(),
      );
      await _savePreferences();

      return await transactionCategorizer.suggestCategory(
        description: description,
        availableCategories: availableCategories,
        merchant: merchant,
        amount: amount,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to categorize transaction', e, stackTrace);
      return null;
    }
  }

  /// Parse natural language transaction
  Future<ParsedTransaction?> parseNaturalLanguage(String input) async {
    if (!canUseAI() || !(_preferences?.naturalLanguageEntryEnabled ?? false)) {
      return null;
    }

    try {
      _preferences = _preferences!.copyWith(
        totalAIOperations: _preferences!.totalAIOperations + 1,
        lastModelUsage: DateTime.now(),
      );
      await _savePreferences();

      return await naturalLanguageParser.parseTransaction(input);
    } catch (e, stackTrace) {
      _log.severe('Failed to parse natural language', e, stackTrace);
      return null;
    }
  }

  /// Generate spending insights
  Future<SpendingInsights?> generateInsights({
    required List<Transaction> transactions,
    required DateTime startDate,
    required DateTime endDate,
    double? budgetLimit,
  }) async {
    if (!canUseAI() || !(_preferences?.spendingInsightsEnabled ?? false)) {
      return null;
    }

    try {
      _preferences = _preferences!.copyWith(
        totalAIOperations: _preferences!.totalAIOperations + 1,
        lastModelUsage: DateTime.now(),
      );
      await _savePreferences();

      return await spendingInsights.generateInsights(
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
        budgetLimit: budgetLimit,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to generate insights', e, stackTrace);
      return null;
    }
  }

  /// Parse receipt image
  Future<ParsedReceipt?> parseReceipt(String imagePath) async {
    if (!canUseAI() || !(_preferences?.receiptScanningEnabled ?? false)) {
      return null;
    }

    try {
      _preferences = _preferences!.copyWith(
        totalAIOperations: _preferences!.totalAIOperations + 1,
        lastModelUsage: DateTime.now(),
      );
      await _savePreferences();

      return await receiptParser.parseReceipt(imagePath);
    } catch (e, stackTrace) {
      _log.severe('Failed to parse receipt', e, stackTrace);
      return null;
    }
  }

  /// Search transactions with AI
  Future<SearchResult> searchTransactions({
    required String query,
    required List<Transaction> allTransactions,
  }) async {
    if (!canUseAI() || !(_preferences?.smartSearchEnabled ?? false)) {
      // Return empty result if AI is disabled
      return SearchResult(
        query: query,
        matches: [],
        interpretation: 'AI search is disabled',
      );
    }

    try {
      _preferences = _preferences!.copyWith(
        totalAIOperations: _preferences!.totalAIOperations + 1,
        lastModelUsage: DateTime.now(),
      );
      await _savePreferences();

      return await smartSearch.searchTransactions(
        query: query,
        allTransactions: allTransactions,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to search transactions', e, stackTrace);
      return SearchResult(
        query: query,
        matches: [],
        interpretation: 'Search error: $e',
      );
    }
  }

  /// Dispose all AI services
  Future<void> dispose() async {
    _log.info('Disposing AI Manager');

    await gemmaService.unloadModel();
    gemmaService.dispose();
    await receiptParser.dispose();

    _initialized = false;
  }
}
