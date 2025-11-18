import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/ai/ai_manager.dart';
import '../../services/ai/spending_insights.dart';
import '../../entity/transaction.dart';

/// Card widget that displays AI-powered spending insights
class SpendingInsightsCard extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime startDate;
  final DateTime endDate;
  final double? budgetLimit;

  const SpendingInsightsCard({
    super.key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
    this.budgetLimit,
  });

  @override
  State<SpendingInsightsCard> createState() => _SpendingInsightsCardState();
}

class _SpendingInsightsCardState extends State<SpendingInsightsCard> {
  final AIManager _aiManager = AIManager();

  bool _loading = false;
  SpendingInsights? _insights;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void didUpdateWidget(SpendingInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload if transactions changed
    if (oldWidget.transactions != widget.transactions ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    if (!_aiManager.canUseAI()) {
      return;
    }

    if (widget.transactions.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final insights = await _aiManager.generateInsights(
        transactions: widget.transactions,
        startDate: widget.startDate,
        endDate: widget.endDate,
        budgetLimit: widget.budgetLimit,
      );

      if (mounted) {
        setState(() {
          _insights = insights;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if AI is disabled
    if (!(_aiManager.preferences?.spendingInsightsEnabled ?? false)) {
      return const SizedBox.shrink();
    }

    // Don't show if no transactions
    if (widget.transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Symbols.psychology,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Insights',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_insights != null)
                        Text(
                          _insights!.period,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.refresh),
                  onPressed: _loading ? null : _loadInsights,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content
            if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing your spending...'),
                    ],
                  ),
                ),
              ),
            ] else if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.error,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Failed to generate insights',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_insights != null) ...[
              // Insights content
              Text(
                _insights!.summary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Spent',
                      '\$${_insights!.totalSpent.toStringAsFixed(2)}',
                      Symbols.trending_down,
                      Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Earned',
                      '\$${_insights!.totalIncome.toStringAsFixed(2)}',
                      Symbols.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Symbols.lightbulb,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap refresh to generate AI insights',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
