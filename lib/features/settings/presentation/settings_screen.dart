import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_info.dart';
import '../../../core/network/compozy_api_client.dart';
import '../../../core/network/health_checker.dart';
import '../../../core/presentation/compozy_feedback.dart';
import '../../../core/settings/settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/compozy_theme.dart';
import '../../../core/theme/theme_mode_toggle.dart';
import '../../connection/presentation/connection_banner.dart';

/// Screen allowing the user to view and modify CompozyOS daemon settings,
/// including Base URL, API Token, and active workspace, along with
/// live connection testing, validation, and feedback.
class SettingsScreen extends ConsumerStatefulWidget {
  final bool? isAndroid;

  const SettingsScreen({super.key, this.isAndroid});

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

  bool get _isAndroid => widget.isAndroid ?? (!kIsWeb && Platform.isAndroid);

  static const _loopbackHosts = {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
    '::1',
    '[::1]',
  };

  bool _isLoopbackHost(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    final cleanHost = (host.startsWith('[') && host.endsWith(']'))
        ? host.substring(1, host.length - 1)
        : host;
    return cleanHost == 'localhost' ||
        cleanHost == '127.0.0.1' ||
        cleanHost == '::1';
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _baseUrlController.addListener(_onBaseUrlChanged);
    _apiTokenController = TextEditingController(text: settings.apiToken ?? '');
    _workspaceController =
        TextEditingController(text: settings.activeWorkspaceId ?? '');
    _initialized = true;
  }

  void _onBaseUrlChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _baseUrlController.removeListener(_onBaseUrlChanged);
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
      final normalizedEntered =
          normalizeCompozyBaseUrl(enteredUrl, isAndroid: _isAndroid);

      final bool isHealthy;
      if (enteredUrl.isNotEmpty &&
          enteredUrl != healthChecker.baseUrl &&
          normalizedEntered != healthChecker.baseUrl) {
        final customChecker = HealthChecker(
          baseUrl: enteredUrl,
          isAndroid: _isAndroid,
        );
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

  bool _isBreakingConnectivityChange(String oldUrl, String newUrl) {
    final oldUri = Uri.tryParse(oldUrl.trim());
    final newUri = Uri.tryParse(newUrl.trim());

    if (oldUri == null || newUri == null) return false;
    final oldHost = oldUri.host.toLowerCase();
    final newHost = newUri.host.toLowerCase();

    if (oldHost == newHost) return false;

    // Both are local loopback aliases (e.g. host localhost <-> Android 10.0.2.2)
    if (_loopbackHosts.contains(oldHost) && _loopbackHosts.contains(newHost)) {
      return false;
    }

    // Host changed to a different remote endpoint
    return true;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawBaseUrl = _baseUrlController.text.trim();
    final rawToken = _apiTokenController.text.trim();
    final rawWorkspace = _workspaceController.text.trim();
    final currentSettings = ref.read(settingsProvider);

    // If changing base URL host to an external domain, require confirmation
    if (_isBreakingConnectivityChange(currentSettings.baseUrl, rawBaseUrl)) {
      final palette = context.palette;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('confirm_url_change_dialog'),
          backgroundColor: palette.card,
          shape: const RoundedRectangleBorder(
            borderRadius: CompozyRadius.card,
          ),
          title: Text(
            'Change Daemon URL?',
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Changing the daemon URL from "${currentSettings.baseUrl}" to "$rawBaseUrl" may disrupt active sessions and disconnect from the current daemon.',
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: palette.fgStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('confirm_url_change_button'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.primaryInk,
                shape: const RoundedRectangleBorder(
                  borderRadius: CompozyRadius.pill,
                ),
              ),
              child: const Text('Change URL'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final defaultUrl = defaultCompozyBaseUrl(isAndroid: _isAndroid);
    final updated = currentSettings.copyWith(
      baseUrl: rawBaseUrl.isNotEmpty ? rawBaseUrl : defaultUrl,
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
      showCompozySnack(context, 'Settings saved successfully');
    }
  }

  Future<void> _resetDefaults() async {
    final palette = context.palette;

    // Destructive action confirmation dialog with safe cancel default
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm_reset_defaults_dialog'),
        backgroundColor: palette.card,
        shape: const RoundedRectangleBorder(
          borderRadius: CompozyRadius.card,
        ),
        title: Text(
          'Reset Settings to Defaults?',
          style: TextStyle(
            color: palette.fgStrong,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will reset the daemon Base URL, clear your API token, and active workspace identifier. This action cannot be undone.',
          style: TextStyle(
            color: palette.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancel_reset_defaults_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: palette.fgStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_reset_defaults_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.danger,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: CompozyRadius.pill,
              ),
            ),
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final defaultUrl = defaultCompozyBaseUrl(isAndroid: _isAndroid);
    _baseUrlController.text = defaultUrl;
    _apiTokenController.text = '';
    _workspaceController.text = '';

    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateSettings(Settings(baseUrl: defaultUrl));

    ref.invalidate(healthCheckerProvider);
    ref.invalidate(connectionStatusProvider);

    if (mounted) {
      setState(() {
        _testConnectionSuccess = null;
        _testFeedbackMessage = null;
      });

      showCompozySnack(context, 'Settings reset to defaults');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    ref.listen<Settings>(settingsProvider, (prev, next) {
      _syncFromSettings(next);
    });

    return Scaffold(
      key: const Key('settings_screen'),
      backgroundColor: palette.desk,
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
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildConnectionCard(context),
                      const SizedBox(height: 16),
                      _buildAuthCard(context),
                      const SizedBox(height: 16),
                      _buildWorkspaceCard(context),
                      const SizedBox(height: 16),
                      _buildThemeCard(context),
                      const SizedBox(height: 20),
                      _buildActions(context),
                      const SizedBox(height: 24),
                      _buildAboutSection(context),
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

  Widget _buildHeader(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Icon(
                Icons.tune,
                size: 18,
                color: palette.fgStrong,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Daemon Settings',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.fgStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: palette.elevated,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Text(
                'REST API',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Configure daemon connection, authentication, and active workspace.',
          style: TextStyle(
            color: palette.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 16, color: palette.fgStrong),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text(
                  'Appearance & Theme',
                  style: TextStyle(
                    color: palette.fgStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select theme mode adhering to tokens-light.css and Compozy design tokens.',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const ThemeModeToggle.segmented(key: Key('settings_theme_mode_toggle')),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Daemon Connection',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.fgStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const ConnectionBanner.compact(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Base URL',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_base_url_field'),
            controller: _baseUrlController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'e.g. http://localhost:2123',
              hintStyle: TextStyle(
                color: palette.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: palette.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(
                  color: palette.fg,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.danger),
              ),
              errorStyle: TextStyle(
                color: palette.danger,
                fontSize: 12,
              ),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Daemon Base URL is required';
              }
              final uri = Uri.tryParse(trimmed);
              if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                return 'Enter a valid URL with scheme (e.g. http://localhost:2123)';
              }
              if (uri.scheme != 'http' && uri.scheme != 'https') {
                return 'URL scheme must be http:// or https://';
              }
              if (uri.host.isEmpty) {
                return 'URL must include a valid host';
              }
              return null;
            },
          ),
          if (_isAndroid && _isLoopbackHost(_baseUrlController.text)) ...[
            Builder(
              builder: (context) {
                final typedUrl = _baseUrlController.text.trim();
                final effectiveUrl =
                    normalizeCompozyBaseUrl(typedUrl, isAndroid: true);

                return Container(
                  key: const Key('settings_loopback_helper'),
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: CompozyRadius.input,
                    border: Border.all(
                      color: palette.lineStrong,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: palette.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'On Android, localhost means the phone itself. Use 10.0.2.2 for the emulator or your machine\'s LAN IP for a physical device.',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (effectiveUrl != typedUrl) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.elevated,
                            borderRadius: CompozyRadius.input,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Effective URL: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                              Text(
                                effectiveUrl,
                                key: const Key('settings_effective_url_text'),
                                style: TextStyle(
                                  color: palette.fgStrong,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Default is http://localhost:2123 (use 10.0.2.2 for Android emulator).',
            style: TextStyle(
              color: palette.subtle,
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
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.fg,
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
                  foregroundColor: palette.fg,
                  backgroundColor: palette.elevated,
                  minimumSize: const Size(88, 48),
                  side: BorderSide(color: palette.lineStrong),
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
            _buildTestConnectionFeedback(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTestConnectionFeedback(BuildContext context) {
    final palette = context.palette;

    if (_isTestingConnection) {
      return Container(
        key: const Key('connection_test_loading_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.canvas,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.fg,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Testing daemon connectivity...',
              style: TextStyle(
                color: palette.muted,
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
          isSuccess ? palette.success : palette.danger;
      final statusIcon =
          isSuccess ? Icons.check_circle_outline : Icons.error_outline;

      return Container(
        key: Key(isSuccess
            ? 'connection_test_success_banner'
            : 'connection_test_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.canvas,
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

  Widget _buildAuthCard(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Authentication',
              style: TextStyle(
                color: palette.fgStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'API Token',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_api_token_field'),
            controller: _apiTokenController,
            obscureText: _obscureToken,
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Optional Bearer token',
              hintStyle: TextStyle(
                color: palette.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: palette.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                key: const Key('settings_toggle_token_visibility'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: _obscureToken ? 'Show API token' : 'Hide API token',
                icon: Icon(
                  _obscureToken ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: palette.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscureToken = !_obscureToken;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(
                  color: palette.fg,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Required only when the daemon enforces session or gateway token auth.',
            style: TextStyle(
              color: palette.subtle,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Workspace',
              style: TextStyle(
                color: palette.fgStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Active Workspace Identifier',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('settings_workspace_field'),
            controller: _workspaceController,
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. compozy-app or ws_3e99e4fe517eb344',
              hintStyle: TextStyle(
                color: palette.subtle,
                fontSize: 13,
              ),
              filled: true,
              fillColor: palette.surface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(color: palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: BorderSide(
                  color: palette.fg,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Default workspace context sent with session creation and loop runs.',
            style: TextStyle(
              color: palette.subtle,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final palette = context.palette;

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
            backgroundColor: palette.primary,
            foregroundColor: palette.primaryInk,
            minimumSize: const Size(88, 48),
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
            foregroundColor: palette.muted,
            minimumSize: const Size(88, 48),
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

  Widget _buildAboutSection(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            header: true,
            child: Text(
              'About',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'compozy-app v$kAppVersion · $kAppStage',
              key: const Key('settings_about_version'),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on TextEditingController {
  void disposeNullable() {
    dispose();
  }
}
