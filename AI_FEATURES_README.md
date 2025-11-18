# AI Features Integration - Gemma Local Inference

This document describes the AI features integrated into Flow using Google's Gemma model for on-device inference.

## Overview

Flow now includes advanced AI capabilities powered by the Gemma language model, running entirely on-device for complete privacy. All AI processing happens locally on your device - no data is sent to external servers.

## Features

### 🤖 Smart Transaction Categorization
- **Auto-categorization**: Automatically suggests categories for new transactions based on description and merchant
- **Confidence scores**: Shows how confident the AI is about each suggestion
- **Learning from context**: Uses transaction amount and merchant information to improve accuracy

### 💬 Natural Language Transaction Entry
- **Plain English input**: Create transactions using natural language
  - Example: "spent $50 on groceries at Walmart"
  - Example: "paid 100 euros for dinner yesterday"
  - Example: "received $1000 salary"
- **Smart parsing**: Extracts amount, description, merchant, date, and transaction type automatically
- **Date understanding**: Recognizes relative dates like "yesterday", "last week", "this morning"

### 📊 AI-Powered Spending Insights
- **Pattern analysis**: Identifies spending trends and patterns
- **Smart recommendations**: Provides actionable advice based on your spending habits
- **Budget insights**: Analyzes spending against budget limits
- **Anomaly detection**: Flags unusual transactions that might need attention

### 📄 Receipt Scanning & Parsing
- **OCR extraction**: Uses Google ML Kit to extract text from receipt photos
- **Intelligent parsing**: AI parses receipt data to extract:
  - Merchant name
  - Total amount
  - Individual items
  - Tax amount
  - Date
  - Payment method
- **Auto-categorization**: Suggests categories based on merchant and items purchased

### 🔍 Smart Search
- **Natural language queries**: Search transactions using plain English
  - Example: "all grocery purchases last month"
  - Example: "expensive transactions over $100"
  - Example: "coffee spending this week"
- **Semantic understanding**: Understands intent behind search queries
- **Intelligent filtering**: Automatically applies filters based on query

### ⚠️ Spending Anomaly Detection
- **Pattern recognition**: Learns normal spending patterns
- **Unusual transaction alerts**: Flags transactions that deviate from normal behavior
- **Fraud detection**: Helps identify potentially fraudulent charges

## Technical Architecture

### Core Components

#### 1. AI Services (`lib/services/ai/`)
- **`gemma_service.dart`**: Core Gemma model management and inference
- **`ai_manager.dart`**: Central coordinator for all AI features
- **`transaction_categorizer.dart`**: Smart categorization service
- **`natural_language_parser.dart`**: NL parsing service
- **`spending_insights.dart`**: Analysis and insights generation
- **`receipt_parser.dart`**: OCR and receipt parsing
- **`smart_search.dart`**: Semantic search service

#### 2. Data Layer
- **`ai_preferences.dart`**: ObjectBox entity for AI settings
- Stores user preferences, model configuration, and usage statistics

#### 3. UI Components
- **`ai_preferences_page.dart`**: Settings page for AI features
- **`natural_language_input_sheet.dart`**: Bottom sheet for NL transaction entry
- **`spending_insights_card.dart`**: Widget displaying AI insights

### Dependencies

```yaml
dependencies:
  flutter_gemma: ^0.3.2  # Gemma model integration
  google_mlkit_text_recognition: ^0.14.0  # OCR for receipts
  fuzzywuzzy: ^1.2.0  # Fuzzy string matching (already present)
```

## Model Information

### Gemma 3 Nano Variants

Flow supports multiple Gemma model variants:

1. **gemma-3-nano-270m-q4** (Default)
   - Size: ~150 MB
   - Speed: Fastest
   - Best for: General use, quick responses
   - Recommended for most users

2. **gemma-3-nano-1b-q4**
   - Size: ~300 MB
   - Speed: Fast
   - Best for: Better accuracy

3. **gemma-3-nano-2b-q4**
   - Size: ~500 MB
   - Speed: Moderate
   - Best for: Highest accuracy, complex queries

### Model Capabilities

- **Context window**: Up to 512 tokens (configurable)
- **Languages**: Optimized for English, supports multiple languages
- **Inference speed**: 10-30 tokens/second on modern mobile devices
- **Platform support**: Android, iOS, Web

## Privacy & Security

### Complete On-Device Processing
- ✅ All AI inference runs locally on your device
- ✅ No data sent to external servers
- ✅ No internet required after model download
- ✅ Model stored in app's local directory
- ✅ Fully compliant with GDPR and privacy regulations

### Data Handling
- Transaction data never leaves your device
- Model files stored in app's documents directory
- No analytics or telemetry (unless explicitly enabled by user)
- All processing respects Flow's existing privacy guarantees

## Performance Considerations

### Resource Usage
- **Storage**: 150-500 MB depending on model variant
- **RAM**: 200-400 MB during active inference
- **Battery**: Minimal impact; model automatically unloads when not in use
- **Network**: Only required for initial model download

### Optimization Tips
1. Use the default 270M model for best performance
2. Disable features you don't use to save resources
3. Lower confidence threshold for more suggestions
4. Adjust temperature for faster/more precise responses

## Usage Guide

### Enabling AI Features

1. Go to **Settings** → **AI Features**
2. Toggle **Enable AI Features**
3. Download the model (one-time, ~150-500 MB)
4. Enable specific features you want to use

### Natural Language Transaction Entry

1. Enable "Natural Language Entry" in AI settings
2. When creating a transaction, use the AI input option
3. Type naturally: "spent $50 on groceries"
4. Review parsed result and confirm

### Smart Categorization

1. Enable "Smart Categorization" in AI settings
2. When creating transactions, AI will suggest categories
3. Accept or modify suggestions as needed
4. Suggestions improve over time

### Receipt Scanning

1. Enable "Receipt Scanning" in AI settings
2. Take a photo of your receipt
3. AI extracts merchant, amount, items, and date
4. Review and create transaction

### Spending Insights

1. Enable "Spending Insights" in AI settings
2. View AI-generated insights on home or stats pages
3. Get recommendations and pattern analysis
4. Use insights to improve financial habits

### Smart Search

1. Enable "Smart Search" in AI settings
2. Search transactions using natural language
3. Examples:
   - "groceries last month"
   - "expensive purchases"
   - "coffee this week"

## Configuration Options

### AI Preferences

- **Confidence Threshold** (50-95%): Minimum confidence for showing suggestions
- **Model Temperature** (0.1-1.0): Controls randomness in responses
  - Lower (0.1-0.5): More precise, deterministic
  - Higher (0.6-1.0): More creative, varied
- **Max Tokens** (128-1024): Maximum length of AI responses
- **Model Variant**: Choose model size based on device capabilities

## Development

### Adding New AI Features

1. Create a new service in `lib/services/ai/`
2. Add methods to `AIManager` for feature access
3. Update `AIPreferences` entity with new settings
4. Create UI components in `lib/widgets/ai/`
5. Add preference toggle in `ai_preferences_page.dart`

### Testing

```dart
// Example: Test transaction categorization
final aiManager = AIManager();
await aiManager.initialize(store);

final suggestion = await aiManager.categorizeTransaction(
  description: 'Starbucks coffee',
  availableCategories: categories,
);

print(suggestion?.categoryName); // "Food & Dining"
```

## Troubleshooting

### Model won't download
- Check internet connection
- Ensure sufficient storage space (500 MB+)
- Try a smaller model variant

### AI features not working
- Verify AI is enabled in settings
- Check if model is downloaded
- Ensure sufficient RAM available
- Restart the app

### Poor categorization accuracy
- Increase confidence threshold
- Provide more context in descriptions
- Use merchant information when available

### Slow performance
- Use smaller model variant (270M)
- Reduce max tokens
- Close other apps to free RAM
- Lower temperature for faster responses

## Future Enhancements

Potential improvements for future versions:

- [ ] Multi-language support for non-English transactions
- [ ] Budget forecasting and prediction
- [ ] Bill detection and recurring payment suggestions
- [ ] Financial goal recommendations
- [ ] Spending habit coaching
- [ ] Integration with financial advice
- [ ] Custom model fine-tuning on user's data
- [ ] Voice input for transaction entry
- [ ] Smart notifications based on spending patterns

## Credits

- **Gemma Model**: Google DeepMind
- **flutter_gemma**: DenisovAV
- **ML Kit**: Google
- **Integration**: Claude AI Code Assistant

## License

This AI integration maintains Flow's GPL-3.0 license. The Gemma model is subject to Google's Gemma Terms of Use.

## Support

For issues or questions about AI features:
1. Check the troubleshooting section above
2. Review AI preferences settings
3. File an issue on GitHub with "AI:" prefix
4. Include model variant and device specs

---

**Note**: AI features are experimental and may produce incorrect results. Always review AI suggestions before accepting them. The AI does not have access to external data sources and bases suggestions solely on local transaction patterns and general knowledge.
