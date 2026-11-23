import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/health_checker.dart';
import '../../../core/settings/settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';

/// Screen allowing the user to view and modify CompozyOS daemon settings,
/// including Base URL, API Token, and active workspace, along with
/// live connection testing and feedback.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _baseUrlController;
  late TextEditingController _apiTokenController;
  late TextEditingController _workspaceController;

  bool _obscureToken = true;
  bool _isTestingConnection = false;
  bool? _testConnectionSuccess;
  String? _testFeedbackMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _apiTokenController = TextEditingController(text: settings.apiToken ?? '');
    _workspaceController =
        TextEditingController(text: settings.activeWorkspaceId ?? '');
    _initialized = true;
  }

  @override
  void dispose() {
    _baseUrlController.disposeNullable();
    _apiTokenController.disposeNullable();
    _workspaceController.disposeNullable();
    super.dispose();
  }

  void _syncFromSettings(Settings settings) {
    if (!_initialized) return;
    if (_baseUrlController.text != settings.baseUrl) {
      _baseUrlController.text = settings.baseUrl;
    }
    if (_apiTokenController.text != (settings.apiToken ?? '')) {
      _apiTokenController.text = settings.apiToken ?? '';
    }
    if (_workspaceController.text != (settings.activeWorkspaceId ?? '')) {
      _workspaceController.text = settings.activeWorkspaceId ?? '';
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _testConnectionSuccess = null;
      _testFeedbackMessage = null;
    });

    try {
      final healthChecker = ref.read(healthCheckerProvider);
      final enteredUrl = _baseUrlController.text.trim();

      final bool isHealthy;
      if (enteredUrl.isNotEmpty && enteredUrl != healthChecker.baseUrl) {
        final customChecker = HealthChecker(baseUrl: enteredUrl);
        isHealthy = await customChecker.checkHealth();
      } else {
        isHealthy = await healthChecker.checkHealth();
      }

      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testConnectionSuccess = isHealthy;
          _testFeedbackMessage = isHealthy
              ? 'Daemon is reachable (HTTP 200 OK)'
              : 'Connection failed: unable to reach daemon';
        });

        // Invalidate global connection status so app bar reflects the check
        ref.invalidate(connectionStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testConnectionSuccess = false;
          _testFeedbackMessage = 'Connection failed: $e';
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final rawBaseUrl = _baseUrlController.text.trim();
    final rawToken = _apiTokenController.text.trim();
    final rawWorkspace = _workspaceController.text.trim();

    final currentSettings = ref.read(settingsProvider);
    final updated = currentSettings.copyWith(
      baseUrl: rawBaseUrl.isNotEmpty ? rawBaseUrl : 'http://localhost:2123',
      apiToken: rawToken,
      clearApiToken: rawToken.isEmpty,
      activeWorkspaceId: rawWorkspace,
      clearActiveWorkspaceId: rawWorkspace.isEmpty,
    );

    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateSettings(updated);

    // Invalidate health checker and connection status
    ref.invalidate(healthCheckerProvider);
    ref.invalidate(connectionStatusProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('settings_saved_snackbar'),
          content: const Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: CompozyColors.success),
              SizedBox(width: 8),
              Text(
                'Settings saved successfully',
                style: TextStyle(
                  color: CompozyColors.fgStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: CompozyColors.elevated,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: CompozyRadius.input,
            side: BorderSide(color: CompozyColors.line, width: 1),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetDefaults() async {
    _baseUrlController.text = 'http://localhost:2123';
    _apiTokenController.text = '';
    _workspaceController.text = '';

    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateSettings(const Settings());

    ref.invalidate(healthCheckerProvider);
    ref.invalidate(connectionStatusProvider);

    if (mounted) {
      setState(() {
        _testConnectionSuccess = null;
        _testFeedbackMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Settings reset to defaults',
            style: TextStyle(color: CompozyColors.fgStrong, fontSize: 13),
          ),
          backgroundColor: CompozyColors.elevated,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: CompozyRadius.input,
            side: BorderSide(color: CompozyColors.line, width: 1),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes from repository / external updates
    ref.listen<Settings>(settingsProvider, (prev, next) {
      _syncFromSettings(next);
    });

    return Scaffold(
      key: const Key('settings_screen'),
      backgroundColor: CompozyColors.desk,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 680 : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 24 : 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildConnectionCard(),
                      const SizedBox(height: 16),
                      _buildAuthCard(),
                      const SizedBox(height: 16),
                      _buildWorkspaceCard(),
                      const SizedBox(height: 20),
                      _buildActions(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: CompozyColors.card,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: const Icon(
                Icons.tune,
                size: 16,
                color: CompozyColors.fgStrong,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Daemon Settings',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CompozyColors.fgStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CompozyColors.elevated,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: const Text(
                'REST API',
                style: TextStyle(
                  color: CompozyColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure daemon connection, authentication, and active workspace.',
          style: TextStyle(
            color: CompozyColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CompozyColors.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Daemon Connection',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CompozyColors.fgStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ConnectionBanner.compact(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Base URL',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_base_url_field'),
            controller: _baseUrlController,
            style: const TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'e.g. http://localhost:2123',
              hintStyle: const TextStyle(
                color: CompozyColors.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: CompozyColors.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(
                  color: CompozyColors.fg,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Default is http://localhost:2123 (use 10.0.2.2 for Android emulator).',
            style: TextStyle(
              color: CompozyColors.subtle,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('settings_test_connection_button'),
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CompozyColors.fg,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering, size: 15),
                label: Text(
                  _isTestingConnection ? 'Testing...' : 'Test Connection',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CompozyColors.fg,
                  backgroundColor: CompozyColors.elevated,
                  side: const BorderSide(color: CompozyColors.lineStrong),
                  shape: const RoundedRectangleBorder(
                    borderRadius: CompozyRadius.pill,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          if (_isTestingConnection || _testFeedbackMessage != null) ...[
            const SizedBox(height: 12),
            _buildTestConnectionFeedback(),
          ],
        ],
      ),
    );
  }

  Widget _buildTestConnectionFeedback() {
    if (_isTestingConnection) {
      return Container(
        key: const Key('connection_test_loading_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CompozyColors.canvas,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: CompozyColors.line, width: 1),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CompozyColors.fg,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Testing daemon connectivity...',
              style: TextStyle(
                color: CompozyColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_testFeedbackMessage != null) {
      final isSuccess = _testConnectionSuccess == true;
      final statusColor =
          isSuccess ? CompozyColors.success : CompozyColors.danger;
      final statusIcon =
          isSuccess ? Icons.check_circle_outline : Icons.error_outline;

      return Container(
        key: Key(isSuccess
            ? 'connection_test_success_banner'
            : 'connection_test_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CompozyColors.canvas,
          borderRadius: CompozyRadius.input,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 15, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _testFeedbackMessage!,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CompozyColors.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Authentication',
            style: TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'API Token',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_api_token_field'),
            controller: _apiTokenController,
            obscureText: _obscureToken,
            style: const TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Optional Bearer token',
              hintStyle: const TextStyle(
                color: CompozyColors.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: CompozyColors.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                key: const Key('settings_toggle_token_visibility'),
                icon: Icon(
                  _obscureToken ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: CompozyColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscureToken = !_obscureToken;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(
                  color: CompozyColors.fg,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Required only when the daemon enforces session or gateway token auth.',
            style: TextStyle(
              color: CompozyColors.subtle,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CompozyColors.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workspace',
            style: TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Active Workspace Identifier',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_workspace_field'),
            controller: _workspaceController,
            style: const TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. compozy-app or ws_3e99e4fe517eb344',
              hintStyle: const TextStyle(
                color: CompozyColors.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: CompozyColors.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(
                  color: CompozyColors.fg,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Default workspace context sent with session creation and loop runs.',
            style: TextStyle(
              color: CompozyColors.subtle,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Primary monochrome pill action
        ElevatedButton(
          key: const Key('settings_save_button'),
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: CompozyColors.primary,
            foregroundColor: CompozyColors.primaryInk,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: CompozyRadius.pill,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ),
        // Secondary action
        TextButton(
          key: const Key('settings_reset_button'),
          onPressed: _resetDefaults,
          style: TextButton.styleFrom(
            foregroundColor: CompozyColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text(
            'Reset Defaults',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

extension on TextEditingController {
  void disposeNullable() {
    dispose();
  }
}
