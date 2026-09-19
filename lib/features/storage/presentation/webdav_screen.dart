import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';

class WebDavScreen extends ConsumerStatefulWidget {
  const WebDavScreen({super.key});

  @override
  ConsumerState<WebDavScreen> createState() => _WebDavScreenState();
}

class _WebDavScreenState extends ConsumerState<WebDavScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final credentials = await ref.read(webDavSettingsStoreProvider).read();
      if (!mounted) return;
      if (credentials != null) {
        _urlController.text = credentials.url;
        _usernameController.text = credentials.username;
        _passwordController.text = credentials.password;
      }
      setState(() {
        _isConnected = credentials != null;
        _isLoading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.cantReadSettings;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final credentials = WebDavCredentials(
      url: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    try {
      await ref.read(webDavConnectionProvider).test(credentials);
      await ref.read(webDavSettingsStoreProvider).write(credentials);
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isSaving = false;
        });
      }
    } on WebDavConnectionException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _isSaving = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.cantSaveSettings;
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(webDavSettingsStoreProvider).clear();
      if (mounted) {
        _urlController.clear();
        _usernameController.clear();
        _passwordController.clear();
        setState(() {
          _isConnected = false;
          _isSaving = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.cantDisconnect;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: AppTheme.stage,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.cloudScores)),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isConnected
                                  ? AppColors.accent.withValues(alpha: 0.16)
                                  : AppColors.stageElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isConnected
                                    ? AppColors.accent.withValues(alpha: 0.4)
                                    : AppColors.stageOutline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isConnected
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_off_outlined,
                                  color: _isConnected
                                      ? AppColors.accent
                                      : AppColors.stageMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isConnected
                                            ? l10n.connectedStatus
                                            : l10n.notConnected,
                                        style: const TextStyle(
                                          color: AppColors.canvas,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isConnected
                                            ? l10n.cloudSyncHint
                                            : l10n.enterServerInfo,
                                        style: const TextStyle(
                                          color: AppColors.stageMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: AppColors.canvas,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.serverAddress,
                              hintText: 'https://example.com/webdav',
                            ),
                            validator: (value) {
                              final uri = Uri.tryParse(value?.trim() ?? '');
                              return uri == null ||
                                      !uri.hasAuthority ||
                                      uri.scheme != 'https'
                                  ? l10n.checkUrl
                                  : null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: AppColors.canvas,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.username,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _connect(),
                            style: const TextStyle(
                              color: AppColors.canvas,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.password,
                            ),
                          ),
                          if (_error case final error?) ...[
                            const SizedBox(height: 14),
                            Text(
                              error,
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _isSaving ? null : _connect,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.canvas,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              _isSaving
                                  ? l10n.checking
                                  : _isConnected
                                  ? l10n.reconnect
                                  : l10n.connect,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_isConnected) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => context.push('/tools/webdav/files'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.canvas,
                                side: const BorderSide(
                                  color: AppColors.stageOutline,
                                ),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              icon: const Icon(Icons.folder_open_rounded),
                              label: Text(l10n.browseFiles),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _isSaving ? null : _disconnect,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.stageMuted,
                              ),
                              child: Text(l10n.disconnect),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
