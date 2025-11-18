import 'dart:io';
import 'package:logging/logging.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'gemma_service.dart';

/// AI-powered receipt parsing service
/// Uses OCR to extract text and AI to parse receipt information
class ReceiptParserService {
  static final ReceiptParserService _instance = ReceiptParserService._internal();
  factory ReceiptParserService() => _instance;
  ReceiptParserService._internal();

  final _log = Logger('ReceiptParserService');
  final _gemmaService = GemmaService();
  final _textRecognizer = TextRecognizer();

  /// Parse a receipt image
  Future<ParsedReceipt?> parseReceipt(String imagePath) async {
    try {
      _log.info('Parsing receipt from: $imagePath');

      // Step 1: Extract text using OCR
      final extractedText = await _extractTextFromImage(imagePath);

      if (extractedText == null || extractedText.isEmpty) {
        _log.warning('No text extracted from receipt');
        return null;
      }

      _log.info('Extracted text (${extractedText.length} chars)');

      // Step 2: Parse the extracted text using AI
      final parsed = await _parseReceiptText(extractedText);

      if (parsed != null) {
        _log.info('Successfully parsed receipt: ${parsed.merchant}');
      }

      return parsed;
    } catch (e, stackTrace) {
      _log.severe('Failed to parse receipt', e, stackTrace);
      return null;
    }
  }

  /// Extract text from an image using OCR
  Future<String?> _extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e, stackTrace) {
      _log.severe('OCR failed', e, stackTrace);
      return null;
    }
  }

  /// Parse extracted receipt text using AI
  Future<ParsedReceipt?> _parseReceiptText(String text) async {
    try {
      final prompt = _buildReceiptParsingPrompt(text);
      final response = await _gemmaService.generateText(prompt);

      return _parseReceiptResponse(response);
    } catch (e, stackTrace) {
      _log.severe('Failed to parse receipt text', e, stackTrace);
      return null;
    }
  }

  /// Build receipt parsing prompt
  String _buildReceiptParsingPrompt(String receiptText) {
    return '''Task: Parse receipt information from OCR text.

Receipt text:
$receiptText

Extract the following information:
1. Merchant name
2. Total amount
3. Date (format: YYYY-MM-DD)
4. Currency
5. Items purchased (if clear)
6. Tax amount (if present)
7. Payment method (if present)

Format your response exactly as:
MERCHANT|merchant_name
TOTAL|amount
DATE|YYYY-MM-DD
CURRENCY|currency_code
TAX|tax_amount
PAYMENT|payment_method
ITEMS|item1;item2;item3

If any field is not found, use UNKNOWN.

Response:''';
  }

  /// Parse AI response into structured receipt data
  ParsedReceipt? _parseReceiptResponse(String response) {
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

      final merchant = data['MERCHANT'];
      final totalStr = data['TOTAL'];
      final dateStr = data['DATE'];
      final currency = data['CURRENCY'] ?? 'USD';
      final taxStr = data['TAX'];
      final paymentMethod = data['PAYMENT'];
      final itemsStr = data['ITEMS'];

      if (merchant == null || merchant == 'UNKNOWN' ||
          totalStr == null || totalStr == 'UNKNOWN') {
        return null;
      }

      final total = double.tryParse(totalStr.replaceAll(RegExp(r'[^\d.]'), ''));
      if (total == null) {
        return null;
      }

      final date = dateStr != null && dateStr != 'UNKNOWN'
          ? DateTime.tryParse(dateStr)
          : null;

      final tax = taxStr != null && taxStr != 'UNKNOWN'
          ? double.tryParse(taxStr.replaceAll(RegExp(r'[^\d.]'), ''))
          : null;

      final items = itemsStr != null && itemsStr != 'UNKNOWN'
          ? itemsStr.split(';').where((i) => i.trim().isNotEmpty).toList()
          : <String>[];

      return ParsedReceipt(
        merchant: merchant,
        total: total,
        date: date ?? DateTime.now(),
        currency: currency,
        tax: tax,
        items: items,
        paymentMethod: paymentMethod != 'UNKNOWN' ? paymentMethod : null,
      );
    } catch (e, stackTrace) {
      _log.severe('Failed to parse receipt response', e, stackTrace);
      return null;
    }
  }

  /// Extract specific items from receipt text
  Future<List<ReceiptItem>> extractItems(String receiptText) async {
    try {
      final prompt = '''Task: Extract individual items from this receipt text.

Receipt text:
$receiptText

List each item with its price.
Format: ITEM_NAME|PRICE

Example:
Coffee|3.50
Sandwich|7.99
Water|1.99

Response:''';

      final response = await _gemmaService.generateText(prompt);
      final items = <ReceiptItem>[];

      for (final line in response.split('\n')) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final priceStr = parts[1].trim();
          final price = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), ''));

          if (price != null) {
            items.add(ReceiptItem(
              name: name,
              price: price,
              quantity: 1,
            ));
          }
        }
      }

      return items;
    } catch (e, stackTrace) {
      _log.severe('Failed to extract items', e, stackTrace);
      return [];
    }
  }

  /// Suggest category for receipt
  Future<String?> suggestCategoryForReceipt(ParsedReceipt receipt) async {
    try {
      final context = [
        'Merchant: ${receipt.merchant}',
        if (receipt.items.isNotEmpty) 'Items: ${receipt.items.join(", ")}',
      ].join('\n');

      final prompt = '''Suggest a category for this purchase.

$context

Common categories: Groceries, Dining, Shopping, Transportation, Entertainment, Health, Utilities, Other

Respond with ONLY the category name.

Category:''';

      final response = await _gemmaService.generateText(prompt);
      return response.trim();
    } catch (e) {
      _log.warning('Failed to suggest category for receipt', e);
      return null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

/// Represents a parsed receipt
class ParsedReceipt {
  final String merchant;
  final double total;
  final DateTime date;
  final String currency;
  final double? tax;
  final List<String> items;
  final String? paymentMethod;

  ParsedReceipt({
    required this.merchant,
    required this.total,
    required this.date,
    required this.currency,
    this.tax,
    required this.items,
    this.paymentMethod,
  });

  @override
  String toString() {
    return 'ParsedReceipt('
        'merchant: $merchant, '
        'total: $total $currency, '
        'date: $date, '
        'items: ${items.length})';
  }
}

/// Represents an item on a receipt
class ReceiptItem {
  final String name;
  final double price;
  final int quantity;

  ReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  @override
  String toString() => '$name x$quantity - \$${totalPrice.toStringAsFixed(2)}';
}
