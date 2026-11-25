import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/network/compozy_api_client.dart';
import '../../../core/presentation/app_shell.dart';
import '../../../core/presentation/compozy_feedback.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/compozy_theme.dart';

/// Screen displayed when no confirmed connection exists to the CompozyOS daemon.
///
/// Prompts the user to configure and verify connectivity with their local daemon,
/// offering candidate shortcuts (Android emulator loopback, localhost), inline validation,
/// test-connection verification, and an offline continuation bypass.
class DaemonSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onContinueOffline;
  final VoidCallback? onConnected;
  final bool? isAndroid;
  final Future<Map<String, dynamic>?> Function(String url)? testConnectionOverride;

  const DaemonSetupScreen({
    super.key,
    this.onContinueOffline,
    this.onConnected,
    this.isAndroid,
    this.testConnectionOverride,
  });

  @override
  ConsumerState<DaemonSetupScreen> createState() => _DaemonSetupScreenState();
}

class _DaemonSetupScreenState extends ConsumerState<DaemonSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;

  bool _isTesting = false;
  bool _isConnected = false;
  String? _daemonInfo;
  String? _errorMessage;

  bool get _isAndroid => widget.isAndroid ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final effectiveUrl = normalizeCompozyBaseUrl(
      settings.baseUrl,
      isAndroid: _isAndroid,
    );
    _urlController = TextEditingController(text: effectiveUrl);
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    if (_isConnected || _errorMessage != null) {
      setState(() {
        _isConnected = false;
        _daemonInfo = null;
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _selectCandidate(String url) {
    compozyHaptic();
    _urlController.text = url;
    _formKey.currentState?.validate();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o endereço do daemon';
    }
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'URL inválida. Formato esperado: http://host:porta';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'O esquema deve ser http ou https';
    }
    if (uri.host.isEmpty) {
      return 'Host não pode ser vazio';
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _daemonInfo = null;
      _isConnected = false;
    });

    final rawUrl = _urlController.text.trim();
    final normalizedUrl = normalizeCompozyBaseUrl(rawUrl, isAndroid: _isAndroid);

    try {
      if (widget.testConnectionOverride != null) {
        final result = await widget.testConnectionOverride!(normalizedUrl);
        if (result != null) {
          final title =
              result['info']?['title'] ?? result['title'] ?? 'CompozyOS Daemon';
          final version = result['info']?['version'] ?? result['version'];
          final infoText = version != null ? '$title · v$version' : '$title';
          if (mounted) {
            setState(() {
              _isTesting = false;
              _isConnected = true;
              _daemonInfo = infoText;
            });
            compozyHaptic();
          }
          return;
        } else {
          throw CompozyNetworkException(
            message: 'Conexão recusada em $normalizedUrl',
          );
        }
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: normalizedUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final response = await dio.get<dynamic>('/api/openapi.json');
      if (response.statusCode == 200) {
        String daemonTitle = 'CompozyOS Daemon';
        String? daemonVersion;
        if (response.data is Map<String, dynamic>) {
          final info = response.data['info'];
          if (info is Map<String, dynamic>) {
            daemonTitle = info['title']?.toString() ?? daemonTitle;
            daemonVersion = info['version']?.toString();
          }
        }
        final infoText = daemonVersion != null
            ? '$daemonTitle · v$daemonVersion'
            : daemonTitle;
        if (mounted) {
          setState(() {
            _isTesting = false;
            _isConnected = true;
            _daemonInfo = infoText;
          });
          compozyHaptic();
        }
      } else {
        if (mounted) {
          setState(() {
            _isTesting = false;
            _errorMessage =
                'Resposta inesperada do daemon (HTTP ${response.statusCode})';
          });
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String message;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = 'Tempo limite esgotado ao conectar ao daemon ($normalizedUrl)';
      } else if (e.type == DioExceptionType.connectionError) {
        message =
            'Conexão recusada em $normalizedUrl. Verifique se o daemon está em execução.';
      } else if (e.response?.statusCode == 404) {
        message =
            'Endpoint /api/openapi.json não encontrado (HTTP 404). Verifique o host e a porta.';
      } else {
        message = e.message ?? 'Falha de rede ao conectar ao daemon';
      }
      setState(() {
        _isTesting = false;
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _errorMessage = 'Falha ao testar conexão: $e';
      });
    }
  }

  Future<void> _handleContinue() async {
    final rawUrl = _urlController.text.trim();
    final normalized = normalizeCompozyBaseUrl(rawUrl, isAndroid: _isAndroid);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    await notifier.updateBaseUrl(normalized);
    await notifier.setConfirmedConnection(true);
    compozyHaptic();

    if (!mounted) return;

    if (widget.onConnected != null) {
      widget.onConnected!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleContinueOffline() {
    compozyHaptic();
    if (widget.onContinueOffline != null) {
      widget.onContinueOffline!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppNavigationShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Glyph
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: CompozyRadius.card,
                          border: Border.all(color: palette.line, width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.hub_outlined,
                            size: 28,
                            color: palette.fgStrong,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Conectar ao daemon',
                      style: TextStyle(
                        color: palette.fgStrong,
                        fontSize: textScaler.scale(24),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle / short line
                    Text(
                      'O aplicativo comunica-se com um daemon CompozyOS local para orquestrar agentes e sessões.',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: textScaler.scale(14),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // URL Input Label
                    Text(
                      'Endereço do daemon',
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: textScaler.scale(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // URL Input Field
                    TextFormField(
                      key: const Key('daemon_setup_url_field'),
                      controller: _urlController,
                      validator: _validateUrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        color: palette.fgStrong,
                        fontFamily: 'monospace',
                        fontSize: textScaler.scale(14),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: palette.surface2,
                        hintText: 'http://10.0.2.2:2123',
                        hintStyle: TextStyle(
                          color: palette.subtle,
                          fontFamily: 'monospace',
                          fontSize: textScaler.scale(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: CompozyRadius.input,
                          borderSide: BorderSide(color: palette.line, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: CompozyRadius.input,
                          borderSide: BorderSide(color: palette.line, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: CompozyRadius.input,
                          borderSide: BorderSide(color: palette.lineStrong, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: CompozyRadius.input,
                          borderSide: BorderSide(color: palette.danger, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: CompozyRadius.input,
                          borderSide: BorderSide(color: palette.danger, width: 1.5),
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _urlController,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Semantics(
                              label: 'Limpar endereço do daemon',
                              button: true,
                              child: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: palette.muted,
                                ),
                                onPressed: () {
                                  _urlController.clear();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Candidate Shortcuts Header
                    Text(
                      'Atalhos de conexão',
                      style: TextStyle(
                        color: palette.subtle,
                        fontSize: textScaler.scale(12),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Candidate 1: Android Emulator
                    _buildCandidateTile(
                      key: const Key('candidate_emulator'),
                      icon: Icons.phone_android_outlined,
                      label: 'Emulador Android · 10.0.2.2:2123',
                      targetUrl: 'http://10.0.2.2:2123',
                      palette: palette,
                      textScaler: textScaler,
                    ),
                    const SizedBox(height: 8),

                    // Candidate 2: Localhost
                    _buildCandidateTile(
                      key: const Key('candidate_localhost'),
                      icon: Icons.computer_outlined,
                      label: 'Este computador · localhost:2123',
                      targetUrl: 'http://localhost:2123',
                      palette: palette,
                      textScaler: textScaler,
                    ),

                    // Android-only helper text
                    if (_isAndroid) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: CompozyRadius.card,
                          border: Border.all(color: palette.line, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: palette.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No Android, localhost refere-se ao próprio dispositivo. Em emuladores use 10.0.2.2; em aparelhos físicos na rede local, use o IP da sua máquina.',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: textScaler.scale(12),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Connection Test Feedback (Success / Error / Progress)
                    if (_isTesting) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface2,
                          borderRadius: CompozyRadius.input,
                          border: Border.all(color: palette.line, width: 1),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Testando conexão...',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: textScaler.scale(13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_isConnected) ...[
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('daemon_setup_success_banner'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: CompozyRadius.card,
                          border: Border.all(color: palette.success, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: palette.success,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Conectado',
                                    style: TextStyle(
                                      color: palette.success,
                                      fontSize: textScaler.scale(14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_daemonInfo != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _daemonInfo!,
                                      style: TextStyle(
                                        color: palette.muted,
                                        fontSize: textScaler.scale(12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('daemon_setup_error_banner'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: CompozyRadius.card,
                          border: Border.all(color: palette.danger, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: palette.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Falha na conexão',
                                    style: TextStyle(
                                      color: palette.danger,
                                      fontSize: textScaler.scale(13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: palette.fg,
                                      fontSize: textScaler.scale(12),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Primary Button (Continuar when connected, Testar conexão otherwise)
                    if (_isConnected)
                      ElevatedButton(
                        key: const Key('daemon_setup_continue_button'),
                        onPressed: _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.primaryInk,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: CompozyRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: textScaler.scale(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        key: const Key('daemon_setup_test_button'),
                        onPressed: _isTesting ? null : _testConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.primaryInk,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: CompozyRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isTesting) ...[
                              const Icon(Icons.bolt_outlined, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isTesting ? 'Testando conexão...' : 'Testar conexão',
                              style: TextStyle(
                                fontSize: textScaler.scale(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Secondary Button: Continuar offline
                    TextButton(
                      key: const Key('daemon_setup_offline_button'),
                      onPressed: _handleContinueOffline,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.muted,
                        minimumSize: const Size(double.infinity, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: CompozyRadius.pill,
                        ),
                      ),
                      child: Text(
                        'Continuar offline',
                        style: TextStyle(
                          fontSize: textScaler.scale(13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateTile({
    required Key key,
    required IconData icon,
    required String label,
    required String targetUrl,
    required CompozyPalette palette,
    required TextScaler textScaler,
  }) {
    final isSelected = _urlController.text.trim() == targetUrl;

    return Semantics(
      button: true,
      label: 'Preencher $label',
      child: Material(
        color: isSelected ? palette.surface2 : palette.card,
        borderRadius: CompozyRadius.input,
        child: InkWell(
          key: key,
          onTap: () => _selectCandidate(targetUrl),
          borderRadius: CompozyRadius.input,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: CompozyRadius.input,
              border: Border.all(
                color: isSelected ? palette.lineStrong : palette.line,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? palette.fgStrong : palette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? palette.fgStrong : palette.fg,
                      fontSize: textScaler.scale(13),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: palette.fgStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
