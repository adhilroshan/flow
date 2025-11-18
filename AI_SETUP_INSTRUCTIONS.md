# AI Features Setup Instructions

This guide will help you complete the setup of AI features in Flow.

## Prerequisites

- Flutter SDK installed and in PATH
- Sufficient disk space (500 MB+)
- Internet connection for initial dependency download

## Setup Steps

### 1. Install Dependencies

```bash
flutter pub get
```

This will install:
- `flutter_gemma` - Gemma model integration
- `google_mlkit_text_recognition` - OCR for receipts

### 2. Generate ObjectBox Entity Files

The `AIPreferences` entity needs to be registered with ObjectBox:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate:
- `lib/entity/ai_preferences.g.dart` - JSON serialization
- Updated `lib/objectbox.g.dart` - ObjectBox schema

### 3. Verify Integration

Check that the following files were generated:
- `lib/entity/ai_preferences.g.dart`
- ObjectBox schema updated in `lib/objectbox.g.dart`

### 4. Initialize AI Manager in App

The AI Manager needs to be initialized when the app starts. Add this to your app initialization:

```dart
import 'package:flow/services/ai/ai_manager.dart';

// In your app initialization (e.g., main.dart or app setup)
Future<void> initializeApp() async {
  // ... existing initialization code ...

  // Initialize AI Manager
  final aiManager = AIManager();
  await aiManager.initialize(store); // pass your ObjectBox store

  // ... rest of initialization ...
}
```

### 5. Add AI Preferences Route

Add the AI preferences page to your routing configuration.

In your routes file (e.g., `lib/routes.dart` or router configuration):

```dart
import 'package:flow/routes/preferences/ai_preferences_page.dart';

// Add route for AI preferences
// The exact implementation depends on your routing setup
```

### 6. Add AI Preferences Link

Add a link to the AI preferences page in your main preferences page.

In `lib/routes/preferences_page.dart` or similar:

```dart
import 'package:flow/routes/preferences/ai_preferences_page.dart';

// Add a ListTile or button to navigate to AI preferences
ListTile(
  leading: const Icon(Symbols.psychology),
  title: const Text('AI Features'),
  subtitle: const Text('Configure AI-powered features'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AIPreferencesPage()),
  ),
),
```

## Testing AI Features

### Test 1: AI Preferences Page

1. Run the app
2. Navigate to Settings → AI Features
3. Verify the page loads without errors
4. Try toggling AI features (should prompt for model download)

### Test 2: Model Download

1. Enable AI features
2. Confirm the model download
3. Wait for download to complete
4. Verify model status shows as "Downloaded"

### Test 3: Natural Language Input

1. Enable "Natural Language Entry" in AI settings
2. Create a new transaction
3. Test with: "spent $50 on groceries"
4. Verify it parses correctly

### Test 4: Smart Categorization

1. Enable "Smart Categorization"
2. Create a transaction with description "Starbucks coffee"
3. Verify category suggestion appears
4. Check confidence score

### Test 5: Spending Insights

1. Enable "Spending Insights"
2. Add several transactions
3. View home page or stats
4. Verify AI insights card appears with analysis

## Platform-Specific Setup

### Android

Minimum SDK version should be 21 or higher. Update `android/app/build.gradle` if needed:

```gradle
minSdkVersion 21
```

### iOS

Minimum iOS version should be 12.0 or higher. Update `ios/Podfile` if needed:

```ruby
platform :ios, '12.0'
```

For ML Kit text recognition, add camera permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan receipts</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select receipt images</string>
```

### Web

Web support for Gemma is available but may have performance limitations. Test thoroughly.

## Troubleshooting

### Build Runner Errors

If you get errors running build_runner:

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### ObjectBox Schema Conflicts

If you get ObjectBox schema conflicts:

1. The `AIPreferences` entity has been added
2. ObjectBox will automatically migrate the schema
3. If issues persist, you may need to clear app data (development only)

### Import Errors

If you get import errors for AI services:

```dart
// Use the barrel export
import 'package:flow/services/ai/ai_services.dart';

// Or import individual services
import 'package:flow/services/ai/ai_manager.dart';
import 'package:flow/services/ai/gemma_service.dart';
// etc.
```

### Model Download Fails

If model download fails:

1. Check internet connection
2. Verify sufficient storage space
3. Try a smaller model variant (270m instead of 1b/2b)
4. Check device compatibility

## Performance Optimization

### Reduce App Size

If app size is a concern:

1. Use the smallest model (gemma-3-nano-270m-q4)
2. Download model on-demand (default behavior)
3. Allow users to delete model when not in use

### Improve Inference Speed

1. Lower max_tokens (default: 512)
2. Use lower temperature (0.3-0.5)
3. Reduce confidence threshold
4. Use the 270M model variant

### Battery Optimization

1. Unload model when not in use (automatic)
2. Batch AI operations when possible
3. Disable features not in use
4. Use conservative temperature settings

## Development Tips

### Debugging AI Features

Enable logging to see AI operations:

```dart
import 'package:logging/logging.dart';

// In main.dart or initialization
Logger.root.level = Level.FINE;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.time}: ${record.message}');
});
```

### Testing Without Model

For development without downloading the large model:

```dart
// Mock AI responses for testing
class MockGemmaService extends GemmaService {
  @override
  Future<String> generateText(String prompt) async {
    // Return mock responses based on prompt
    return 'Mock AI response';
  }
}
```

### Custom Prompts

Modify prompts in service files to customize AI behavior:

- `transaction_categorizer.dart` - categorization prompts
- `natural_language_parser.dart` - parsing prompts
- `spending_insights.dart` - insights prompts

## Next Steps

1. Complete the setup steps above
2. Test each AI feature
3. Customize prompts for your use case
4. Monitor performance and resource usage
5. Gather user feedback
6. Iterate and improve

## Additional Resources

- [Gemma Model Documentation](https://ai.google.dev/gemma)
- [flutter_gemma Package](https://pub.dev/packages/flutter_gemma)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [ObjectBox Flutter](https://docs.objectbox.io/getting-started)

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review the AI_FEATURES_README.md
3. Check Flutter and package versions
4. File an issue on GitHub with detailed logs

---

**Important**: After completing setup, test thoroughly on actual devices to ensure performance is acceptable for your target audience.
