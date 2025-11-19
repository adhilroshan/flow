import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'gemma_service.dart';
import '../../entity/transaction.dart';

/// AI-powered spending insights and analysis service
/// Provides intelligent recommendations and pattern analysis
class SpendingInsightsService {
  static final SpendingInsightsService _instance =
      SpendingInsightsService._internal();
  factory SpendingInsightsService() => _instance;
  SpendingInsightsService._internal();

  final _log = Logger('SpendingInsightsService');
  final _gemmaService = GemmaService();

  /// Generate spending insights for a period
  Future<SpendingInsights?> generateInsights({
    required List<Transaction> transactions,
    required DateTime startDate,
    required DateTime endDate,
    double? budgetLimit,
  }) async {
    try {
      _log.info('Generating spending insights for ${transactions.length} transactions');

      final summary = _summarizeTransactions(transactions);
      final prompt = _buildInsightsPrompt(
        summary: summary,
        startDate: startDate,
        endDate: endDate,
        budgetLimit: budgetLimit,
      );

      final response = await _gemmaService.generateText(prompt);

      return SpendingInsights(
        summary: response,
        period: '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
        totalSpent: summary['totalSpent'] as double,
        totalIncome: summary['totalIncome'] as double,
        transactionCount: transactions.length,
        generatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to generate insights', e, stackTrace);
      return null;
    }
  }

  /// Detect spending anomalies
  Future<List<SpendingAnomaly>> detectAnomalies({
    required List<Transaction> transactions,
    required Map<String, double> averages, // category -> average amount
  }) async {
    try {
      _log.info('Detecting spending anomalies');

      final anomalies = <SpendingAnomaly>[];

      for (final transaction in transactions) {
        // Check if amount is significantly higher than average
        final categoryAvg = averages[transaction.category?.name] ?? 0.0;
        final isHigherThanAverage = categoryAvg > 0 && transaction.amount.abs() > (categoryAvg * 2);

        // Detect anomalies: large transactions or those significantly above average
        if (transaction.amount.abs() > 500 || isHigherThanAverage) {
          final prompt = '''Analyze this transaction for anomalies:
Amount: \$${transaction.amount.toStringAsFixed(2)}
Description: ${transaction.description ?? 'No description'}
Date: ${DateFormat('yyyy-MM-dd').format(transaction.transactionDate)}

Is this transaction unusual or potentially fraudulent?
Respond with: NORMAL or ANOMALY|reason

Response:''';

          final response = await _gemmaService.generateText(prompt);

          if (response.trim().startsWith('ANOMALY')) {
            final parts = response.split('|');
            final reason = parts.length > 1 ? parts[1].trim() : 'Unusual transaction';

            anomalies.add(SpendingAnomaly(
              transaction: transaction,
              reason: reason,
              severity: AnomalySeverity.medium,
              detectedAt: DateTime.now(),
            ));
          }
        }
      }

      _log.info('Detected ${anomalies.length} anomalies');
      return anomalies;
    } catch (e, stackTrace) {
      _log.severe('Failed to detect anomalies', e, stackTrace);
      return [];
    }
  }

  /// Predict future spending
  Future<SpendingPrediction?> predictSpending({
    required List<Transaction> historicalTransactions,
    required String category,
    int daysAhead = 30,
  }) async {
    try {
      _log.info('Predicting spending for category: $category');

      final categoryTransactions = historicalTransactions
          .where((t) => t.category?.name == category)
          .toList();

      if (categoryTransactions.isEmpty) {
        return null;
      }

      final summary = _summarizeTransactions(categoryTransactions);
      final prompt = '''Task: Predict future spending based on historical data.

Historical data for "$category":
- Total transactions: ${categoryTransactions.length}
- Average per transaction: \$${(summary['totalSpent'] as double / categoryTransactions.length).toStringAsFixed(2)}
- Total spent: \$${(summary['totalSpent'] as double).toStringAsFixed(2)}
- Period: ${summary['daysCovered']} days

Predict the likely spending for the next $daysAhead days in this category.
Provide a predicted amount and confidence level (0-100).

Format: AMOUNT|CONFIDENCE|REASONING

Response:''';

      final response = await _gemmaService.generateText(prompt);
      final parts = response.split('|');

      if (parts.length >= 3) {
        final amount = double.tryParse(parts[0].trim()) ?? 0.0;
        final confidence = double.tryParse(parts[1].trim()) ?? 0.0;
        final reasoning = parts[2].trim();

        return SpendingPrediction(
          category: category,
          predictedAmount: amount,
          confidence: confidence / 100.0,
          reasoning: reasoning,
          periodDays: daysAhead,
          basedOnTransactions: categoryTransactions.length,
        );
      }

      return null;
    } catch (e, stackTrace) {
      _log.severe('Failed to predict spending', e, stackTrace);
      return null;
    }
  }

  /// Generate budget recommendations
  Future<List<BudgetRecommendation>> generateBudgetRecommendations({
    required List<Transaction> transactions,
    required double monthlyIncome,
  }) async {
    try {
      _log.info('Generating budget recommendations');

      final summary = _summarizeTransactions(transactions);
      final categoryBreakdown = _getCategoryBreakdown(transactions);

      final prompt = '''Task: Generate budget recommendations based on spending patterns.

Monthly income: \$${monthlyIncome.toStringAsFixed(2)}
Current spending: \$${(summary['totalSpent'] as double).toStringAsFixed(2)}

Category breakdown:
${categoryBreakdown.entries.map((e) => '- ${e.key}: \$${e.value.toStringAsFixed(2)}').join('\n')}

Provide 3-5 specific budget recommendations.
Format each as: CATEGORY|SUGGESTED_AMOUNT|REASON

Response:''';

      final response = await _gemmaService.generateText(prompt);
      final recommendations = <BudgetRecommendation>[];

      for (final line in response.split('\n')) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 3) {
          recommendations.add(BudgetRecommendation(
            category: parts[0].trim(),
            suggestedAmount: double.tryParse(parts[1].trim()) ?? 0.0,
            reason: parts[2].trim(),
          ));
        }
      }

      return recommendations;
    } catch (e, stackTrace) {
      _log.severe('Failed to generate budget recommendations', e, stackTrace);
      return [];
    }
  }

  /// Summarize transactions into key metrics
  Map<String, dynamic> _summarizeTransactions(List<Transaction> transactions) {
    double totalSpent = 0.0;
    double totalIncome = 0.0;
    DateTime? earliest;
    DateTime? latest;

    for (final transaction in transactions) {
      if (transaction.amount < 0) {
        totalSpent += transaction.amount.abs();
      } else {
        totalIncome += transaction.amount;
      }

      if (earliest == null || transaction.transactionDate.isBefore(earliest)) {
        earliest = transaction.transactionDate;
      }
      if (latest == null || transaction.transactionDate.isAfter(latest)) {
        latest = transaction.transactionDate;
      }
    }

    final daysCovered = earliest != null && latest != null
        ? latest.difference(earliest).inDays + 1
        : 0;

    return {
      'totalSpent': totalSpent,
      'totalIncome': totalIncome,
      'daysCovered': daysCovered,
      'transactionCount': transactions.length,
    };
  }

  /// Get category breakdown
  Map<String, double> _getCategoryBreakdown(List<Transaction> transactions) {
    final breakdown = <String, double>{};

    for (final transaction in transactions) {
      final category = transaction.category?.name ?? 'Uncategorized';
      breakdown[category] = (breakdown[category] ?? 0.0) + transaction.amount.abs();
    }

    return breakdown;
  }

  /// Build insights prompt
  String _buildInsightsPrompt({
    required Map<String, dynamic> summary,
    required DateTime startDate,
    required DateTime endDate,
    double? budgetLimit,
  }) {
    final period = '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';

    return '''Task: Provide financial insights and recommendations.

Period: $period
Total spent: \$${(summary['totalSpent'] as double).toStringAsFixed(2)}
Total income: \$${(summary['totalIncome'] as double).toStringAsFixed(2)}
Number of transactions: ${summary['transactionCount']}
${budgetLimit != null ? 'Budget limit: \$${budgetLimit.toStringAsFixed(2)}' : ''}

Provide a concise summary (2-3 sentences) with:
1. Overall spending assessment
2. Key observation or pattern
3. One actionable recommendation

Keep it brief, helpful, and encouraging.

Response:''';
  }
}

/// Represents spending insights generated by AI
class SpendingInsights {
  final String summary;
  final String period;
  final double totalSpent;
  final double totalIncome;
  final int transactionCount;
  final DateTime generatedAt;

  SpendingInsights({
    required this.summary,
    required this.period,
    required this.totalSpent,
    required this.totalIncome,
    required this.transactionCount,
    required this.generatedAt,
  });
}

/// Represents a spending anomaly
class SpendingAnomaly {
  final Transaction transaction;
  final String reason;
  final AnomalySeverity severity;
  final DateTime detectedAt;

  SpendingAnomaly({
    required this.transaction,
    required this.reason,
    required this.severity,
    required this.detectedAt,
  });
}

enum AnomalySeverity {
  low,
  medium,
  high,
}

/// Represents a spending prediction
class SpendingPrediction {
  final String category;
  final double predictedAmount;
  final double confidence;
  final String reasoning;
  final int periodDays;
  final int basedOnTransactions;

  SpendingPrediction({
    required this.category,
    required this.predictedAmount,
    required this.confidence,
    required this.reasoning,
    required this.periodDays,
    required this.basedOnTransactions,
  });
}

/// Represents a budget recommendation
class BudgetRecommendation {
  final String category;
  final double suggestedAmount;
  final String reason;

  BudgetRecommendation({
    required this.category,
    required this.suggestedAmount,
    required this.reason,
  });
}
