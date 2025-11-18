import "package:flow/l10n/extensions.dart";
import "package:flow/entity/ai_preferences.dart";
import "package:flow/services/ai/ai_manager.dart";
import "package:flow/widgets/general/frame.dart";
import "package:flow/widgets/general/list_header.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";

class AIPreferencesPage extends StatefulWidget {
  const AIPreferencesPage({super.key});

  @override
  State<AIPreferencesPage> createState() => _AIPreferencesPageState();
}

class _AIPreferencesPageState extends State<AIPreferencesPage> {
  final AIManager _aiManager = AIManager();

  bool _busy = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;

  AIPreferences? get _prefs => _aiManager.preferences;

  @override
  void initState() {
    super.initState();

    // Listen to download progress
    _aiManager.gemmaService.downloadProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });
  }

  Future<void> _updatePreference(AIPreferences Function(AIPreferences) update) async {
    if (_prefs == null) return;

    setState(() => _busy = true);

    try {
      final updated = update(_prefs!);
      await _aiManager.updatePreferences(updated);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleAI(bool value) async {
    if (value) {
      // Enabling AI
      if (_prefs?.modelDownloaded ?? false) {
        await _aiManager.enableAI();
      } else {
        // Need to download model first
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download AI Model'),
            content: const Text(
              'To use AI features, you need to download the Gemma model (approximately 150-500 MB depending on variant). '
              'This is a one-time download and the model runs entirely on your device.\n\n'
              'Continue?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Download'),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          await _downloadModel();
        }
      }
    } else {
      // Disabling AI
      await _aiManager.disableAI();
    }

    if (mounted) setState(() {});
  }

  Future<void> _downloadModel() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _aiManager.downloadModel(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      await _aiManager.enableAI();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI model downloaded and activated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Features')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Features'),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Frame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Symbols.psychology),
                      title: const Text('Enable AI Features'),
                      subtitle: Text(
                        _prefs!.aiEnabled
                            ? 'AI features are active'
                            : 'Activate on-device AI capabilities',
                      ),
                      trailing: Switch(
                        value: _prefs!.aiEnabled,
                        onChanged: _busy || _downloading ? null : _toggleAI,
                      ),
                    ),
                    if (_downloading)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            LinearProgressIndicator(value: _downloadProgress),
                            const SizedBox(height: 8),
                            Text(
                              'Downloading model... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Model Information
              if (_prefs!.modelDownloaded) ...[
                const ListHeader(text: 'Model Information'),
                Frame(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Symbols.check_circle),
                        title: const Text('Model Status'),
                        subtitle: Text('${_prefs!.modelVariant} • Downloaded'),
                        trailing: const Icon(
                          Symbols.cloud_done,
                          color: Colors.green,
                        ),
                      ),
                      if (_prefs!.lastModelUsage != null)
                        ListTile(
                          leading: const Icon(Symbols.schedule),
                          title: const Text('Last Used'),
                          subtitle: Text(
                            _formatDate(_prefs!.lastModelUsage!),
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Symbols.analytics),
                        title: const Text('Total Operations'),
                        subtitle: Text('${_prefs!.totalAIOperations} AI operations'),
                      ),
                    ],
                  ),
                ),
              ],

              // AI Features
              const ListHeader(text: 'AI Features'),
              Frame(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.category),
                      title: const Text('Smart Categorization'),
                      subtitle: const Text(
                        'Automatically suggest categories for new transactions',
                      ),
                      value: _prefs!.autoCategorizationEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(autoCategorizationEnabled: value),
                              ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.chat),
                      title: const Text('Natural Language Entry'),
                      subtitle: const Text(
                        'Create transactions using plain English (e.g., "spent \$50 on groceries")',
                      ),
                      value: _prefs!.naturalLanguageEntryEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(naturalLanguageEntryEnabled: value),
                              ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.insights),
                      title: const Text('Spending Insights'),
                      subtitle: const Text(
                        'AI-powered analysis and recommendations',
                      ),
                      value: _prefs!.spendingInsightsEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(spendingInsightsEnabled: value),
                              ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.receipt_long),
                      title: const Text('Receipt Scanning'),
                      subtitle: const Text(
                        'Extract transaction details from receipt photos',
                      ),
                      value: _prefs!.receiptScanningEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(receiptScanningEnabled: value),
                              ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.search),
                      title: const Text('Smart Search'),
                      subtitle: const Text(
                        'Search with natural language queries',
                      ),
                      value: _prefs!.smartSearchEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(smartSearchEnabled: value),
                              ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.warning),
                      title: const Text('Anomaly Detection'),
                      subtitle: const Text(
                        'Alert for unusual spending patterns',
                      ),
                      value: _prefs!.anomalyDetectionEnabled,
                      onChanged: !_prefs!.aiEnabled || _busy
                          ? null
                          : (value) => _updatePreference(
                                (p) => p.copyWith(anomalyDetectionEnabled: value),
                              ),
                    ),
                  ],
                ),
              ),

              // Advanced Settings
              const ListHeader(text: 'Advanced Settings'),
              Frame(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Symbols.tune),
                      title: const Text('Confidence Threshold'),
                      subtitle: Text(
                        '${(_prefs!.confidenceThreshold * 100).toStringAsFixed(0)}% - Only show high confidence suggestions',
                      ),
                      trailing: SizedBox(
                        width: 200,
                        child: Slider(
                          value: _prefs!.confidenceThreshold,
                          min: 0.5,
                          max: 0.95,
                          divisions: 9,
                          label: '${(_prefs!.confidenceThreshold * 100).toStringAsFixed(0)}%',
                          onChanged: !_prefs!.aiEnabled || _busy
                              ? null
                              : (value) => _updatePreference(
                                    (p) => p.copyWith(confidenceThreshold: value),
                                  ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.thermostat),
                      title: const Text('Model Temperature'),
                      subtitle: Text(
                        '${_prefs!.temperature.toStringAsFixed(2)} - ${_prefs!.temperature < 0.5 ? "More precise" : "More creative"}',
                      ),
                      trailing: SizedBox(
                        width: 200,
                        child: Slider(
                          value: _prefs!.temperature,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: _prefs!.temperature.toStringAsFixed(1),
                          onChanged: !_prefs!.aiEnabled || _busy
                              ? null
                              : (value) => _updatePreference(
                                    (p) => p.copyWith(temperature: value),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Privacy Notice
              const ListHeader(text: 'Privacy'),
              Frame(
                child: ListTile(
                  leading: const Icon(Symbols.privacy_tip),
                  title: const Text('100% On-Device Processing'),
                  subtitle: const Text(
                    'All AI processing happens locally on your device. '
                    'No data is sent to external servers. Your financial data remains completely private.',
                  ),
                  iconColor: Colors.green,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
