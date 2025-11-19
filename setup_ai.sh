#!/bin/bash

# AI Integration - Build and Test Script
# Run this script to complete the AI integration setup

set -e  # Exit on error

echo "🚀 Flow AI Integration - Setup Script"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not in Flutter project root directory"
    echo "Please cd to /home/user/flow first"
    exit 1
fi

echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Install dependencies
echo "📦 Step 1/3: Installing dependencies..."
echo "Running: flutter pub get"
echo ""
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"
echo ""

# Step 2: Generate ObjectBox files
echo "🔨 Step 2/3: Generating ObjectBox entity files..."
echo "Running: flutter pub run build_runner build --delete-conflicting-outputs"
echo ""
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate ObjectBox files"
    exit 1
fi

echo "✅ ObjectBox files generated successfully"
echo ""

# Step 3: Analyze code
echo "🔍 Step 3/3: Analyzing code for errors..."
echo "Running: flutter analyze"
echo ""
flutter analyze

if [ $? -ne 0 ]; then
    echo "⚠️  Code analysis found issues"
    echo "Please review the errors above"
    exit 1
fi

echo "✅ Code analysis passed - no issues found!"
echo ""

# Success summary
echo "🎉 SUCCESS! AI Integration is ready!"
echo "======================================"
echo ""
echo "✅ All dependencies installed"
echo "✅ ObjectBox files generated:"
echo "   - lib/entity/ai_preferences.g.dart"
echo "   - lib/objectbox.g.dart (updated)"
echo "✅ Code analysis passed"
echo ""
echo "📱 Next Steps:"
echo "1. Run the app: flutter run"
echo "2. Navigate to: Settings → AI Features"
echo "3. Enable AI and download model"
echo "4. Test features:"
echo "   - Natural language: 'spent \$50 on groceries'"
echo "   - Category suggestions"
echo "   - Spending insights"
echo ""
echo "📚 Documentation:"
echo "   - FIXES_COMPLETE.md - Setup complete!"
echo "   - AI_FEATURES_README.md - Feature guide"
echo "   - AI_INTEGRATION_EXAMPLES.md - Code examples"
echo ""
echo "Happy coding! 🚀"
