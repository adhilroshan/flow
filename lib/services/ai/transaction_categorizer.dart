import 'package:logging/logging.dart';
import 'gemma_service.dart';
import '../../entity/category.dart';

/// AI-powered transaction categorization service
/// Uses Gemma to intelligently categorize transactions based on description
class TransactionCategorizerService {
  static final TransactionCategorizerService _instance =
      TransactionCategorizerService._internal();
  factory TransactionCategorizerService() => _instance;
  TransactionCategorizerService._internal();

  final _log = Logger('TransactionCategorizerService');
  final _gemmaService = GemmaService();

  /// Suggest a category for a transaction based on its description
  Future<CategorySuggestion?> suggestCategory({
    required String description,
    required List<Category> availableCategories,
    String? merchant,
    double? amount,
  }) async {
    try {
      _log.info('Suggesting category for: $description');

      // Build context from available categories
      final categoryList = availableCategories
          .map((cat) => '${cat.name} (${cat.icon})')
          .join(', ');

      final prompt = _buildCategorizationPrompt(
        description: description,
        categories: categoryList,
        merchant: merchant,
        amount: amount,
      );

      final response = await _gemmaService.generateText(prompt);

      // Parse the response
      final suggestion = _parseCategorizationResponse(
        response,
        availableCategories,
      );

      _log.info('Category suggested: ${suggestion?.categoryName}');
      return suggestion;
    } catch (e, stackTrace) {
      _log.severe('Failed to suggest category', e, stackTrace);
      return null;
    }
  }

  /// Suggest multiple categories with confidence scores
  Future<List<CategorySuggestion>> suggestCategoriesWithConfidence({
    required String description,
    required List<Category> availableCategories,
    String? merchant,
    double? amount,
    int topN = 3,
  }) async {
    try {
      _log.info('Suggesting top $topN categories for: $description');

      final categoryList = availableCategories
          .map((cat) => '${cat.name} (${cat.icon})')
          .join(', ');

      final prompt = '''Task: Categorize a financial transaction and provide confidence scores.

Available categories: $categoryList

Transaction details:
- Description: $description
${merchant != null ? '- Merchant: $merchant' : ''}
${amount != null ? '- Amount: \$${amount.toStringAsFixed(2)}' : ''}

Provide the top $topN most likely categories with confidence scores (0-100).

Format your response exactly as:
CATEGORY_NAME|CONFIDENCE_SCORE|REASON
CATEGORY_NAME|CONFIDENCE_SCORE|REASON
CATEGORY_NAME|CONFIDENCE_SCORE|REASON

Example:
Groceries|95|Purchase from a supermarket
Food & Dining|85|Could be dining out
Shopping|60|General retail purchase

Response:''';

      final response = await _gemmaService.generateText(prompt);

      // Parse multiple suggestions
      final suggestions = _parseMultipleSuggestions(
        response,
        availableCategories,
      );

      _log.info('Suggested ${suggestions.length} categories');
      return suggestions;
    } catch (e, stackTrace) {
      _log.severe('Failed to suggest categories with confidence', e, stackTrace);
      return [];
    }
  }

  /// Batch categorize multiple transactions
  Future<Map<String, CategorySuggestion>> batchCategorize({
    required Map<String, String> transactions, // id -> description
    required List<Category> availableCategories,
  }) async {
    final results = <String, CategorySuggestion>{};

    for (final entry in transactions.entries) {
      final suggestion = await suggestCategory(
        description: entry.value,
        availableCategories: availableCategories,
      );

      if (suggestion != null) {
        results[entry.key] = suggestion;
      }
    }

    return results;
  }

  /// Build categorization prompt
  String _buildCategorizationPrompt({
    required String description,
    required String categories,
    String? merchant,
    double? amount,
  }) {
    return '''Task: Categorize a financial transaction.

Available categories: $categories

Transaction details:
- Description: $description
${merchant != null ? '- Merchant: $merchant' : ''}
${amount != null ? '- Amount: \$${amount.toStringAsFixed(2)}' : ''}

Select the MOST appropriate category from the available categories.
Respond with ONLY the category name, nothing else.

Category:''';
  }

  /// Parse categorization response
  CategorySuggestion? _parseCategorizationResponse(
    String response,
    List<Category> availableCategories,
  ) {
    final cleanResponse = response.trim().toLowerCase();

    // Try to find matching category
    for (final category in availableCategories) {
      if (cleanResponse.contains(category.name.toLowerCase())) {
        return CategorySuggestion(
          categoryName: category.name,
          categoryId: category.id,
          confidence: 0.85,
          reason: 'AI categorization',
        );
      }
    }

    // If no exact match, try fuzzy matching
    for (final category in availableCategories) {
      if (category.name.toLowerCase().contains(cleanResponse) ||
          cleanResponse.contains(category.name.toLowerCase())) {
        return CategorySuggestion(
          categoryName: category.name,
          categoryId: category.id,
          confidence: 0.70,
          reason: 'Fuzzy AI match',
        );
      }
    }

    return null;
  }

  /// Parse multiple category suggestions
  List<CategorySuggestion> _parseMultipleSuggestions(
    String response,
    List<Category> availableCategories,
  ) {
    final suggestions = <CategorySuggestion>[];
    final lines = response.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length >= 3) {
        final categoryName = parts[0].trim();
        final confidence = double.tryParse(parts[1].trim()) ?? 0.0;
        final reason = parts[2].trim();

        // Find matching category
        try {
          final category = availableCategories.firstWhere(
            (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
          );

          suggestions.add(CategorySuggestion(
            categoryName: category.name,
            categoryId: category.id,
            confidence: confidence / 100.0,
            reason: reason,
          ));
        } catch (e) {
          // Category not found - skip this suggestion
          _log.fine('Category not found: $categoryName');
        }
      }
    }

    return suggestions;
  }
}

/// Represents a category suggestion from AI
class CategorySuggestion {
  final String categoryName;
  final int categoryId;
  final double confidence;
  final String reason;

  CategorySuggestion({
    required this.categoryName,
    required this.categoryId,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() =>
      'CategorySuggestion($categoryName, confidence: ${(confidence * 100).toStringAsFixed(1)}%, reason: $reason)';
}
