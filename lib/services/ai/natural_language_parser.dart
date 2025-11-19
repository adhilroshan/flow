import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'gemma_service.dart';
import '../../entity/transaction/type.dart';

/// AI-powered natural language transaction parser
/// Converts natural language input into structured transaction data
class NaturalLanguageParserService {
  static final NaturalLanguageParserService _instance =
      NaturalLanguageParserService._internal();
  factory NaturalLanguageParserService() => _instance;
  NaturalLanguageParserService._internal();

  final _log = Logger('NaturalLanguageParserService');
  final _gemmaService = GemmaService();

  /// Parse natural language transaction input
  /// Examples:
  /// - "spent $50 on groceries at Walmart"
  /// - "paid 100 euros for dinner yesterday"
  /// - "received $1000 salary"
  /// - "coffee this morning $5.50"
  Future<ParsedTransaction?> parseTransaction(String input) async {
    try {
      _log.info('Parsing transaction: $input');

      final prompt = _buildParsingPrompt(input);
      final response = await _gemmaService.generateText(prompt);

      final parsed = _parseResponse(response);

      if (parsed != null) {
        _log.info('Successfully parsed transaction: $parsed');
      } else {
        _log.warning('Failed to parse transaction from input: $input');
      }

      return parsed;
    } catch (e, stackTrace) {
      _log.severe('Error parsing transaction', e, stackTrace);
      return null;
    }
  }

  /// Parse multiple transactions at once
  Future<List<ParsedTransaction>> parseMultipleTransactions(
    List<String> inputs,
  ) async {
    final results = <ParsedTransaction>[];

    for (final input in inputs) {
      final parsed = await parseTransaction(input);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  /// Build parsing prompt
  String _buildParsingPrompt(String input) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    return '''Task: Parse a natural language transaction description into structured data.

Current date: $today

Examples:
Input: "spent \$50 on groceries at Walmart"
Output: AMOUNT:-50.00|CURRENCY:USD|DESCRIPTION:groceries|MERCHANT:Walmart|DATE:$today|TYPE:EXPENSE

Input: "paid 100 euros for dinner yesterday"
Output: AMOUNT:-100.00|CURRENCY:EUR|DESCRIPTION:dinner|MERCHANT:|DATE:${DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)))}|TYPE:EXPENSE

Input: "received \$1000 salary"
Output: AMOUNT:1000.00|CURRENCY:USD|DESCRIPTION:salary|MERCHANT:|DATE:$today|TYPE:INCOME

Input: "coffee this morning \$5.50"
Output: AMOUNT:-5.50|CURRENCY:USD|DESCRIPTION:coffee|MERCHANT:|DATE:$today|TYPE:EXPENSE

Now parse this transaction:
Input: "$input"
Output:''';
  }

  /// Parse the AI response into structured data
  ParsedTransaction? _parseResponse(String response) {
    try {
      final cleanResponse = response.trim();
      final parts = <String, String>{};

      // Parse the key-value pairs
      final segments = cleanResponse.split('|');
      for (final segment in segments) {
        final keyValue = segment.split(':');
        if (keyValue.length == 2) {
          parts[keyValue[0].trim()] = keyValue[1].trim();
        }
      }

      // Extract values
      final amountStr = parts['AMOUNT'];
      final currency = parts['CURRENCY'] ?? 'USD';
      final description = parts['DESCRIPTION'] ?? '';
      final merchant = parts['MERCHANT'];
      final dateStr = parts['DATE'];
      final typeStr = parts['TYPE'];

      if (amountStr == null || description.isEmpty) {
        return null;
      }

      final amount = double.tryParse(amountStr);
      if (amount == null) {
        return null;
      }

      final date = dateStr != null
          ? DateTime.tryParse(dateStr) ?? DateTime.now()
          : DateTime.now();

      final type = typeStr == 'INCOME'
          ? TransactionType.income
          : TransactionType.expense;

      return ParsedTransaction(
        amount: amount.abs(),
        currency: currency,
        description: description,
        merchant: merchant?.isEmpty ?? true ? null : merchant,
        date: date,
        type: type,
        isExpense: amount < 0,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to parse response: $response', e, stackTrace);
      return null;
    }
  }

  /// Extract amount from text using AI
  Future<double?> extractAmount(String text) async {
    try {
      final prompt = '''Extract the monetary amount from this text.
Return ONLY the number, nothing else.

Examples:
Input: "spent \$50 on groceries"
Output: 50

Input: "paid 100 euros"
Output: 100

Input: "$text"
Output:''';

      final response = await _gemmaService.generateText(prompt);
      return double.tryParse(response.trim());
    } catch (e) {
      _log.warning('Failed to extract amount from: $text', e);
      return null;
    }
  }

  /// Extract date from text using AI
  Future<DateTime?> extractDate(String text) async {
    try {
      final prompt = '''Extract the date from this text and format it as YYYY-MM-DD.
If the text says "yesterday", use yesterday's date.
If the text says "today" or has no date, use today's date.

Current date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

Examples:
Input: "spent \$50 yesterday"
Output: ${DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)))}

Input: "coffee this morning"
Output: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

Input: "$text"
Output:''';

      final response = await _gemmaService.generateText(prompt);
      return DateTime.tryParse(response.trim());
    } catch (e) {
      _log.warning('Failed to extract date from: $text', e);
      return null;
    }
  }
}

/// Represents a parsed transaction from natural language
class ParsedTransaction {
  final double amount;
  final String currency;
  final String description;
  final String? merchant;
  final DateTime date;
  final TransactionType type;
  final bool isExpense;

  ParsedTransaction({
    required this.amount,
    required this.currency,
    required this.description,
    this.merchant,
    required this.date,
    required this.type,
    required this.isExpense,
  });

  @override
  String toString() {
    return 'ParsedTransaction('
        'amount: $amount $currency, '
        'description: $description, '
        'merchant: $merchant, '
        'date: ${DateFormat('yyyy-MM-dd').format(date)}, '
        'type: $type)';
  }
}
