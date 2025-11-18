## AI Features Integration Examples

This document provides code examples for integrating AI features into different parts of the Flow app.

## Table of Contents

1. [App Initialization](#app-initialization)
2. [Transaction Creation](#transaction-creation)
3. [Category Suggestions](#category-suggestions)
4. [Receipt Scanning](#receipt-scanning)
5. [Search Integration](#search-integration)
6. [Insights Display](#insights-display)
7. [Settings Integration](#settings-integration)

---

## App Initialization

### Initialize AI Manager on App Start

```dart
// In lib/main.dart or your app initialization file

import 'package:flow/services/ai/ai_manager.dart';

class FlowApp extends StatefulWidget {
  @override
  State<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<FlowApp> {
  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      final aiManager = AIManager();
      final store = ObjectBox.instance.store; // Your ObjectBox store
      await aiManager.initialize(store);
      print('AI Manager initialized successfully');
    } catch (e) {
      print('Failed to initialize AI: $e');
      // Continue without AI - features will be disabled
    }
  }

  @override
  Widget build(BuildContext context) {
    // Your app widget tree
  }
}
```

---

## Transaction Creation

### Add Natural Language Input Option

```dart
// In lib/routes/transaction_page.dart or transaction creation UI

import 'package:flow/widgets/ai/natural_language_input_sheet.dart';
import 'package:flow/services/ai/ai_manager.dart';

class TransactionCreationPage extends StatefulWidget {
  // ... existing code ...
}

class _TransactionCreationPageState extends State<TransactionCreationPage> {
  final AIManager _aiManager = AIManager();

  // Add a button to show NL input
  Widget _buildNLInputButton() {
    // Only show if NL entry is enabled
    if (!(_aiManager.preferences?.naturalLanguageEntryEnabled ?? false)) {
      return SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: _showNLInput,
      icon: Icon(Symbols.chat),
      label: Text('Quick Add'),
      heroTag: 'nl_input',
    );
  }

  Future<void> _showNLInput() async {
    final result = await NaturalLanguageInputSheet.show(context);

    if (result != null) {
      // Create transaction from parsed result
      _createTransactionFromParsedData(result);
    }
  }

  void _createTransactionFromParsedData(ParsedTransaction parsed) {
    // Populate form fields
    setState(() {
      amountController.text = parsed.amount.toString();
      descriptionController.text = parsed.description;
      if (parsed.merchant != null) {
        merchantController.text = parsed.merchant!;
      }
      selectedDate = parsed.date;
      isExpense = parsed.isExpense;
    });

    // Or directly save without form:
    // _saveTransaction(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing code ...
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNLInputButton(),
          SizedBox(height: 8),
          // ... other FABs ...
        ],
      ),
    );
  }
}
```

---

## Category Suggestions

### Add AI Category Suggestions to Transaction Form

```dart
// In transaction creation form

import 'package:flow/services/ai/ai_manager.dart';
import 'package:flow/services/ai/transaction_categorizer.dart';

class TransactionForm extends StatefulWidget {
  // ... existing code ...
}

class _TransactionFormState extends State<TransactionForm> {
  final AIManager _aiManager = AIManager();
  List<CategorySuggestion> _suggestions = [];
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();

    // Listen to description changes
    descriptionController.addListener(_onDescriptionChanged);
  }

  Future<void> _onDescriptionChanged() async {
    final description = descriptionController.text;

    if (description.length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    // Don't suggest if AI is disabled or user manually selected category
    if (!(_aiManager.preferences?.showCategorySuggestions ?? false)) {
      return;
    }

    setState(() => _loadingSuggestions = true);

    try {
      final categorizer = _aiManager.transactionCategorizer;
      final allCategories = await _loadCategories(); // Your method to get categories

      final suggestions = await categorizer.suggestCategoriesWithConfidence(
        description: description,
        availableCategories: allCategories,
        merchant: merchantController.text.isEmpty ? null : merchantController.text,
        amount: double.tryParse(amountController.text),
        topN: 3,
      );

      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Failed to get suggestions: $e');
    } finally {
      setState(() => _loadingSuggestions = false);
    }
  }

  Widget _buildCategorySuggestions() {
    if (_suggestions.isEmpty || selectedCategory != null) {
      return SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Symbols.psychology, size: 16),
                SizedBox(width: 8),
                Text('AI Suggestions', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Divider(height: 1),
          ...suggestions.map((suggestion) => ListTile(
            dense: true,
            leading: Text(getCategoryIcon(suggestion.categoryId)),
            title: Text(suggestion.categoryName),
            subtitle: Text(
              '${(suggestion.confidence * 100).toStringAsFixed(0)}% confident',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => _selectSuggestion(suggestion),
          )),
        ],
      ),
    );
  }

  void _selectSuggestion(CategorySuggestion suggestion) {
    setState(() {
      selectedCategory = categories.firstWhere(
        (cat) => cat.id == suggestion.categoryId,
      );
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: [
          // ... existing form fields ...

          _buildCategorySuggestions(),

          // ... rest of form ...
        ],
      ),
    );
  }
}
```

---

## Receipt Scanning

### Add Receipt Scanner to Transaction Creation

```dart
// In transaction creation page

import 'package:flow/services/ai/ai_manager.dart';
import 'package:image_picker/image_picker.dart';

class TransactionCreationPage extends StatefulWidget {
  // ... existing code ...
}

class _TransactionCreationPageState extends State<TransactionCreationPage> {
  final AIManager _aiManager = AIManager();
  final ImagePicker _picker = ImagePicker();

  Future<void> _scanReceipt() async {
    if (!(_aiManager.preferences?.receiptScanningEnabled ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt scanning is disabled')),
      );
      return;
    }

    // Pick image from camera or gallery
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning receipt...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final parsedReceipt = await _aiManager.parseReceipt(image.path);

      Navigator.pop(context); // Close loading dialog

      if (parsedReceipt != null) {
        _populateFromReceipt(parsedReceipt);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt scanned successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse receipt')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _populateFromReceipt(ParsedReceipt receipt) {
    setState(() {
      merchantController.text = receipt.merchant;
      amountController.text = receipt.total.toString();
      selectedDate = receipt.date;

      // Optionally set description from items
      if (receipt.items.isNotEmpty) {
        descriptionController.text = receipt.items.take(3).join(', ');
      }
    });

    // Auto-suggest category
    _suggestCategoryForReceipt(receipt);
  }

  Future<void> _suggestCategoryForReceipt(ParsedReceipt receipt) async {
    final category = await _aiManager.receiptParser.suggestCategoryForReceipt(receipt);
    if (category != null) {
      // Find and select the category
      final matchingCategory = categories.firstWhere(
        (cat) => cat.name.toLowerCase() == category.toLowerCase(),
        orElse: () => categories.first,
      );

      setState(() {
        selectedCategory = matchingCategory;
      });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Symbols.camera_alt),
              title: Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Symbols.photo_library),
              title: Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptScanButton() {
    if (!(_aiManager.preferences?.receiptScanningEnabled ?? false)) {
      return SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(Symbols.receipt_long),
      tooltip: 'Scan Receipt',
      onPressed: _scanReceipt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Transaction'),
        actions: [
          _buildReceiptScanButton(),
          // ... other actions ...
        ],
      ),
      // ... rest of UI ...
    );
  }
}
```

---

## Search Integration

### Add Smart Search to Transaction List

```dart
// In transaction list or search page

import 'package:flow/services/ai/ai_manager.dart';
import 'package:flow/services/ai/smart_search.dart';

class TransactionSearchPage extends StatefulWidget {
  final List<Transaction> allTransactions;

  const TransactionSearchPage({required this.allTransactions});

  @override
  State<TransactionSearchPage> createState() => _TransactionSearchPageState();
}

class _TransactionSearchPageState extends State<TransactionSearchPage> {
  final AIManager _aiManager = AIManager();
  final TextEditingController _searchController = TextEditingController();

  bool _searching = false;
  SearchResult? _searchResult;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    if (query.length >= 3) {
      _loadSuggestions(query);
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (!(_aiManager.preferences?.smartSearchEnabled ?? false)) return;

    try {
      final suggestions = await _aiManager.smartSearch.getSearchSuggestions(
        partialQuery: query,
        recentTransactions: widget.allTransactions.take(50).toList(),
      );

      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Failed to load suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResult = null);
      return;
    }

    setState(() => _searching = true);

    try {
      final result = await _aiManager.searchTransactions(
        query: query,
        allTransactions: widget.allTransactions,
      );

      setState(() {
        _searchResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    } finally {
      setState(() => _searching = false);
    }
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search transactions...',
        prefixIcon: Icon(Symbols.search),
        suffixIcon: _searching
            ? Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Symbols.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResult = null);
                    },
                  )
                : null,
      ),
      onSubmitted: _performSearch,
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty) return SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text('Suggestions', style: TextStyle(fontSize: 12)),
          ),
          ..._suggestions.map((suggestion) => ListTile(
            dense: true,
            title: Text(suggestion),
            leading: Icon(Symbols.lightbulb, size: 16),
            onTap: () {
              _searchController.text = suggestion;
              _performSearch(suggestion);
            },
          )),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchResult == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _searchResult!.interpretation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 8),
              Text(
                '${_searchResult!.count} results',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (_searchResult!.matches.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No transactions found'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _searchResult!.matches.length,
            itemBuilder: (context, index) {
              final transaction = _searchResult!.matches[index];
              return TransactionListItem(transaction: transaction);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildSearchBar(),
          ),
          if (_searchResult == null) _buildSuggestions(),
          Expanded(
            child: SingleChildScrollView(
              child: _buildResults(),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Insights Display

### Add AI Insights to Home Page

```dart
// In lib/routes/home_page.dart

import 'package:flow/widgets/ai/spending_insights_card.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get transactions for current period
    final transactions = _getRecentTransactions();
    final startDate = DateTime.now().subtract(Duration(days: 30));
    final endDate = DateTime.now();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... existing home page widgets ...

            // Add AI Insights Card
            SpendingInsightsCard(
              transactions: transactions,
              startDate: startDate,
              endDate: endDate,
              budgetLimit: userBudget, // optional
            ),

            // ... rest of home page ...
          ],
        ),
      ),
    );
  }
}
```

---

## Settings Integration

### Add AI Preferences to Main Settings

```dart
// In lib/routes/preferences_page.dart

import 'package:flow/routes/preferences/ai_preferences_page.dart';
import 'package:flow/services/ai/ai_manager.dart';

class PreferencesPage extends StatelessWidget {
  final AIManager _aiManager = AIManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // ... existing preference sections ...

          // Add AI Preferences Section
          ListHeader(text: 'AI Features'),
          ListTile(
            leading: Icon(Symbols.psychology),
            title: Text('AI Features'),
            subtitle: Text(
              _aiManager.preferences?.aiEnabled ?? false
                  ? 'AI features are active'
                  : 'Configure AI-powered features',
            ),
            trailing: _aiManager.preferences?.aiEnabled ?? false
                ? Icon(Symbols.check_circle, color: Colors.green)
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AIPreferencesPage(),
                ),
              );
            },
          ),

          // ... rest of settings ...
        ],
      ),
    );
  }
}
```

---

## Additional Integration Points

### 1. Transaction Detail Page

Add "Re-categorize with AI" button to transaction detail page.

### 2. Budget Page

Show AI predictions for expected spending in each category.

### 3. Statistics Page

Add AI insights card showing spending patterns and recommendations.

### 4. Onboarding

Add optional step to introduce AI features during first-time setup.

### 5. Notifications

Use anomaly detection to send alerts for unusual transactions (if user enables).

---

## Best Practices

1. **Always check if AI is enabled** before showing AI features
2. **Handle errors gracefully** - AI should enhance UX, not break it
3. **Show loading states** during AI operations
4. **Respect user preferences** - don't force AI on users
5. **Provide fallbacks** - app should work without AI
6. **Test performance** on actual devices before release
7. **Monitor resource usage** especially on lower-end devices

---

## Performance Tips

1. Cache AI results when appropriate
2. Debounce real-time suggestions
3. Batch AI operations when possible
4. Unload model when app goes to background
5. Use smaller model for better performance

---

This completes the integration examples. Refer to AI_FEATURES_README.md for feature documentation and AI_SETUP_INSTRUCTIONS.md for setup steps.
