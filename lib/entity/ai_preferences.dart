import "package:flow/entity/_base.dart";
import "package:flow/utils/json/utc_datetime_converter.dart";
import "package:json_annotation/json_annotation.dart";
import "package:objectbox/objectbox.dart";
import "package:uuid/uuid.dart";

part "ai_preferences.g.dart";

@Entity()
@JsonSerializable(explicitToJson: true, converters: [UTCDateTimeConverter()])
class AIPreferences implements EntityBase {
  @JsonKey(includeFromJson: false, includeToJson: false)
  int id;

  @override
  @Unique()
  String uuid;

  /// Whether AI features are enabled
  bool aiEnabled;

  /// Whether to use AI for automatic transaction categorization
  bool autoCategorizationEnabled;

  /// Whether to show AI category suggestions when creating transactions
  bool showCategorySuggestions;

  /// Whether natural language transaction entry is enabled
  bool naturalLanguageEntryEnabled;

  /// Whether to show AI-powered spending insights
  bool spendingInsightsEnabled;

  /// Whether to enable receipt scanning and parsing
  bool receiptScanningEnabled;

  /// Whether to enable smart search with AI
  bool smartSearchEnabled;

  /// Whether to detect spending anomalies
  bool anomalyDetectionEnabled;

  /// Minimum confidence threshold for AI suggestions (0.0 to 1.0)
  /// Suggestions below this threshold won't be shown
  double confidenceThreshold;

  /// Gemma model variant to use
  /// Options: 'gemma-3-nano-270m', 'gemma-3-nano-1b', 'gemma-3-nano-2b'
  String modelVariant;

  /// Maximum tokens for AI generation
  int maxTokens;

  /// Temperature for AI generation (0.0 to 1.0)
  /// Lower = more deterministic, Higher = more creative
  double temperature;

  /// Whether model is currently downloaded and ready
  bool modelDownloaded;

  /// Last time model was used
  DateTime? lastModelUsage;

  /// Total number of AI operations performed
  int totalAIOperations;

  /// Whether to send usage analytics (anonymized)
  /// Always false by default for privacy
  bool sendAnalytics;

  /// Date when AI features were first enabled
  DateTime? aiEnabledDate;

  /// User's preferred language for AI interactions
  String? preferredLanguage;

  AIPreferences({
    this.id = 0,
    String? uuid,
    this.aiEnabled = false,
    this.autoCategorizationEnabled = false,
    this.showCategorySuggestions = true,
    this.naturalLanguageEntryEnabled = false,
    this.spendingInsightsEnabled = false,
    this.receiptScanningEnabled = false,
    this.smartSearchEnabled = false,
    this.anomalyDetectionEnabled = false,
    this.confidenceThreshold = 0.70,
    this.modelVariant = 'gemma-3-nano-270m-q4',
    this.maxTokens = 512,
    this.temperature = 0.7,
    this.modelDownloaded = false,
    this.lastModelUsage,
    this.totalAIOperations = 0,
    this.sendAnalytics = false,
    this.aiEnabledDate,
    this.preferredLanguage,
  }) : uuid = uuid ?? const Uuid().v4();

  factory AIPreferences.fromJson(Map<String, dynamic> json) =>
      _$AIPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$AIPreferencesToJson(this);

  /// Create default AI preferences with conservative settings
  factory AIPreferences.defaults() => AIPreferences(
        aiEnabled: false,
        autoCategorizationEnabled: false,
        showCategorySuggestions: true,
        naturalLanguageEntryEnabled: false,
        spendingInsightsEnabled: false,
        receiptScanningEnabled: false,
        smartSearchEnabled: false,
        anomalyDetectionEnabled: false,
        confidenceThreshold: 0.70,
        modelVariant: 'gemma-3-nano-270m-q4',
        maxTokens: 512,
        temperature: 0.7,
        sendAnalytics: false,
      );

  /// Copy with modifications
  AIPreferences copyWith({
    int? id,
    String? uuid,
    bool? aiEnabled,
    bool? autoCategorizationEnabled,
    bool? showCategorySuggestions,
    bool? naturalLanguageEntryEnabled,
    bool? spendingInsightsEnabled,
    bool? receiptScanningEnabled,
    bool? smartSearchEnabled,
    bool? anomalyDetectionEnabled,
    double? confidenceThreshold,
    String? modelVariant,
    int? maxTokens,
    double? temperature,
    bool? modelDownloaded,
    DateTime? lastModelUsage,
    int? totalAIOperations,
    bool? sendAnalytics,
    DateTime? aiEnabledDate,
    String? preferredLanguage,
  }) {
    return AIPreferences(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      autoCategorizationEnabled:
          autoCategorizationEnabled ?? this.autoCategorizationEnabled,
      showCategorySuggestions:
          showCategorySuggestions ?? this.showCategorySuggestions,
      naturalLanguageEntryEnabled:
          naturalLanguageEntryEnabled ?? this.naturalLanguageEntryEnabled,
      spendingInsightsEnabled:
          spendingInsightsEnabled ?? this.spendingInsightsEnabled,
      receiptScanningEnabled:
          receiptScanningEnabled ?? this.receiptScanningEnabled,
      smartSearchEnabled: smartSearchEnabled ?? this.smartSearchEnabled,
      anomalyDetectionEnabled:
          anomalyDetectionEnabled ?? this.anomalyDetectionEnabled,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      modelVariant: modelVariant ?? this.modelVariant,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      modelDownloaded: modelDownloaded ?? this.modelDownloaded,
      lastModelUsage: lastModelUsage ?? this.lastModelUsage,
      totalAIOperations: totalAIOperations ?? this.totalAIOperations,
      sendAnalytics: sendAnalytics ?? this.sendAnalytics,
      aiEnabledDate: aiEnabledDate ?? this.aiEnabledDate,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  /// Check if any AI features are enabled
  bool get hasAnyFeatureEnabled =>
      aiEnabled &&
      (autoCategorizationEnabled ||
          showCategorySuggestions ||
          naturalLanguageEntryEnabled ||
          spendingInsightsEnabled ||
          receiptScanningEnabled ||
          smartSearchEnabled ||
          anomalyDetectionEnabled);

  /// Increment AI operations counter
  void incrementOperations() {
    totalAIOperations++;
    lastModelUsage = DateTime.now();
  }

  @override
  String toString() => 'AIPreferences(aiEnabled: $aiEnabled, model: $modelVariant)';
}
