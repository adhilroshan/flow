import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/ai/ai_manager.dart';
import '../../services/ai/natural_language_parser.dart';

/// Bottom sheet for natural language transaction input
/// Allows users to create transactions using plain English
class NaturalLanguageInputSheet extends StatefulWidget {
  const NaturalLanguageInputSheet({super.key});

  @override
  State<NaturalLanguageInputSheet> createState() =>
      _NaturalLanguageInputSheetState();

  /// Show the natural language input sheet
  static Future<ParsedTransaction?> show(BuildContext context) async {
    return showModalBottomSheet<ParsedTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NaturalLanguageInputSheet(),
    );
  }
}

class _NaturalLanguageInputSheetState extends State<NaturalLanguageInputSheet> {
  final TextEditingController _controller = TextEditingController();
  final AIManager _aiManager = AIManager();

  bool _processing = false;
  ParsedTransaction? _parsedResult;
  String? _error;

  final List<String> _examples = [
    'spent \$50 on groceries at Walmart',
    'paid 100 euros for dinner yesterday',
    'received \$1000 salary',
    'coffee this morning \$5.50',
    'gas \$45.20',
    'paid rent \$1500',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
      _parsedResult = null;
    });

    try {
      final result = await _aiManager.parseNaturalLanguage(input);

      if (result != null) {
        setState(() {
          _parsedResult = result;
        });
      } else {
        setState(() {
          _error = 'Could not understand the input. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  void _useExample(String example) {
    _controller.text = example;
    _parse();
  }

  void _confirm() {
    if (_parsedResult != null) {
      Navigator.of(context).pop(_parsedResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Symbols.chat, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Natural Language Entry',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Input field
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'E.g., spent \$50 on groceries',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Symbols.edit),
                  suffixIcon: _processing
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Symbols.send),
                          onPressed: _parse,
                        ),
                ),
                onSubmitted: (_) => _parse(),
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Examples
              if (_parsedResult == null && _error == null) ...[
                Text(
                  'Try these examples:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _examples
                      .map(
                        (example) => ActionChip(
                          label: Text(example),
                          avatar: const Icon(Symbols.lightbulb, size: 16),
                          onPressed: () => _useExample(example),
                        ),
                      )
                      .toList(),
                ),
              ],

              // Error message
              if (_error != null) ...[
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
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Parsed result
              if (_parsedResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Symbols.check_circle,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Parsed Transaction',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow(
                        'Amount',
                        '${_parsedResult!.isExpense ? "-" : "+"}'
                        '${_parsedResult!.currency} ${_parsedResult!.amount.toStringAsFixed(2)}',
                      ),
                      _buildResultRow('Description', _parsedResult!.description),
                      if (_parsedResult!.merchant != null)
                        _buildResultRow('Merchant', _parsedResult!.merchant!),
                      _buildResultRow(
                        'Date',
                        '${_parsedResult!.date.day}/${_parsedResult!.date.month}/${_parsedResult!.date.year}',
                      ),
                      _buildResultRow(
                        'Type',
                        _parsedResult!.type == TransactionType.income
                            ? 'Income'
                            : 'Expense',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Symbols.add),
                          label: const Text('Create Transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
