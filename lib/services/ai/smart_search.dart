import 'package:logging/logging.dart';
import 'gemma_service.dart';
import '../../entity/transaction.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// AI-powered smart search service
/// Provides semantic search and intelligent query understanding
class SmartSearchService {
  static final SmartSearchService _instance = SmartSearchService._internal();
  factory SmartSearchService() => _instance;
  SmartSearchService._internal();

  final _log = Logger('SmartSearchService');
  final _gemmaService = GemmaService();

  /// Search transactions using natural language
  /// Examples:
  /// - "all grocery purchases last month"
  /// - "expensive transactions over $100"
  /// - "coffee spending this week"
  Future<SearchResult> searchTransactions({
    required String query,
    required List<Transaction> allTransactions,
  }) async {
    try {
      _log.info('Searching transactions: $query');

      // Step 1: Parse the query to understand intent
      final searchIntent = await _parseSearchQuery(query);

      if (searchIntent == null) {
        _log.warning('Failed to parse search query');
        return SearchResult(
          query: query,
          matches: [],
          interpretation: 'Could not understand the query',
        );
      }

      _log.info('Search intent: $searchIntent');

      // Step 2: Filter transactions based on intent
      final matches = _filterTransactions(
        allTransactions,
        searchIntent,
      );

      // Step 3: Rank results by relevance
      final rankedMatches = _rankResults(matches, query);

      return SearchResult(
        query: query,
        matches: rankedMatches,
        interpretation: searchIntent.interpretation,
        filters: searchIntent.filters,
      );
    } catch (e, stackTrace) {
      _log.severe('Search failed', e, stackTrace);
      return SearchResult(
        query: query,
        matches: [],
        interpretation: 'Search error: $e',
      );
    }
  }

  /// Parse search query to understand user intent
  Future<SearchIntent?> _parseSearchQuery(String query) async {
    try {
      final prompt = '''Task: Parse a search query for financial transactions.

Query: "$query"

Extract the following filters:
- Keywords (important words to match)
- Amount range (min and max if specified)
- Date range (start and end dates if specified)
- Categories (if mentioned)
- Transaction type (income/expense if specified)

Format your response as:
KEYWORDS|keyword1,keyword2,keyword3
AMOUNT_MIN|value or NONE
AMOUNT_MAX|value or NONE
DATE_START|YYYY-MM-DD or NONE
DATE_END|YYYY-MM-DD or NONE
CATEGORIES|category1,category2 or NONE
TYPE|income or expense or NONE
INTERPRETATION|brief description of what user is looking for

Example:
Query: "grocery purchases over \$50 last month"
KEYWORDS|grocery,purchases
AMOUNT_MIN|50
AMOUNT_MAX|NONE
DATE_START|2025-10-01
DATE_END|2025-10-31
CATEGORIES|groceries
TYPE|expense
INTERPRETATION|Looking for grocery expenses over \$50 in October

Response:''';

      final response = await _gemmaService.generateText(prompt);
      return _parseSearchIntentResponse(response, query);
    } catch (e, stackTrace) {
      _log.severe('Failed to parse search query', e, stackTrace);
      return null;
    }
  }

  /// Parse the AI response into SearchIntent
  SearchIntent? _parseSearchIntentResponse(String response, String originalQuery) {
    try {
      final data = <String, String>{};
      final lines = response.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 2) {
          data[parts[0].trim()] = parts[1].trim();
        }
      }

      final keywords = data['KEYWORDS']?.split(',').map((k) => k.trim()).toList() ?? [];
      final amountMin = data['AMOUNT_MIN'] != 'NONE'
          ? double.tryParse(data['AMOUNT_MIN'] ?? '')
          : null;
      final amountMax = data['AMOUNT_MAX'] != 'NONE'
          ? double.tryParse(data['AMOUNT_MAX'] ?? '')
          : null;
      final categories = data['CATEGORIES'] != 'NONE'
          ? data['CATEGORIES']?.split(',').map((c) => c.trim()).toList() ?? []
          : <String>[];
      final type = data['TYPE'] != 'NONE' ? data['TYPE'] : null;
      final interpretation = data['INTERPRETATION'] ?? originalQuery;

      return SearchIntent(
        keywords: keywords,
        amountMin: amountMin,
        amountMax: amountMax,
        categories: categories,
        transactionType: type,
        interpretation: interpretation,
        filters: {
          if (amountMin != null) 'min_amount': '\$${amountMin.toStringAsFixed(2)}',
          if (amountMax != null) 'max_amount': '\$${amountMax.toStringAsFixed(2)}',
          if (categories.isNotEmpty) 'categories': categories.join(', '),
          if (type != null) 'type': type,
        },
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to parse search intent response', e, stackTrace);
      return null;
    }
  }

  /// Filter transactions based on search intent
  List<Transaction> _filterTransactions(
    List<Transaction> transactions,
    SearchIntent intent,
  ) {
    return transactions.where((transaction) {
      // Check amount range
      if (intent.amountMin != null && transaction.amount.abs() < intent.amountMin!) {
        return false;
      }
      if (intent.amountMax != null && transaction.amount.abs() > intent.amountMax!) {
        return false;
      }

      // Check categories
      if (intent.categories.isNotEmpty) {
        final categoryName = transaction.category?.name.toLowerCase() ?? '';
        final matchesCategory = intent.categories.any(
          (cat) => categoryName.contains(cat.toLowerCase()),
        );
        if (!matchesCategory) return false;
      }

      // Check transaction type
      if (intent.transactionType != null) {
        final isExpense = transaction.amount < 0;
        if (intent.transactionType == 'expense' && !isExpense) return false;
        if (intent.transactionType == 'income' && isExpense) return false;
      }

      // Check keywords in description
      if (intent.keywords.isNotEmpty) {
        final description = (transaction.description ?? '').toLowerCase();
        final title = (transaction.title ?? '').toLowerCase();
        final searchText = '$description $title';

        final hasKeyword = intent.keywords.any(
          (keyword) => searchText.contains(keyword.toLowerCase()),
        );
        if (!hasKeyword) return false;
      }

      return true;
    }).toList();
  }

  /// Rank search results by relevance
  List<Transaction> _rankResults(List<Transaction> transactions, String query) {
    // Use fuzzy matching to rank by relevance
    final scored = transactions.map((transaction) {
      final description = transaction.description ?? transaction.title ?? '';
      final score = ratio(query.toLowerCase(), description.toLowerCase());

      return ScoredTransaction(transaction, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((st) => st.transaction).toList();
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSearchSuggestions({
    required String partialQuery,
    required List<Transaction> recentTransactions,
  }) async {
    try {
      // Generate suggestions based on recent activity
      final merchants = <String>{};
      final descriptions = <String>{};

      for (final transaction in recentTransactions.take(50)) {
        if (transaction.description != null) {
          descriptions.add(transaction.description!);
        }
      }

      final suggestions = <String>[
        'transactions over \$100',
        'expenses this month',
        'income last month',
        'groceries this week',
        ...descriptions.take(5),
      ];

      return suggestions
          .where((s) => s.toLowerCase().contains(partialQuery.toLowerCase()))
          .take(5)
          .toList();
    } catch (e) {
      _log.warning('Failed to generate suggestions', e);
      return [];
    }
  }
}

/// Represents search intent parsed from user query
class SearchIntent {
  final List<String> keywords;
  final double? amountMin;
  final double? amountMax;
  final List<String> categories;
  final String? transactionType;
  final String interpretation;
  final Map<String, String> filters;

  SearchIntent({
    required this.keywords,
    this.amountMin,
    this.amountMax,
    required this.categories,
    this.transactionType,
    required this.interpretation,
    required this.filters,
  });

  @override
  String toString() => 'SearchIntent($interpretation)';
}

/// Search result container
class SearchResult {
  final String query;
  final List<Transaction> matches;
  final String interpretation;
  final Map<String, String>? filters;

  SearchResult({
    required this.query,
    required this.matches,
    required this.interpretation,
    this.filters,
  });

  int get count => matches.length;

  @override
  String toString() => 'SearchResult(${matches.length} matches for "$query")';
}

/// Helper class for scoring transactions
class ScoredTransaction {
  final Transaction transaction;
  final int score;

  ScoredTransaction(this.transaction, this.score);
}
