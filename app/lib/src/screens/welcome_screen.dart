import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../data/local_server.dart';
import '../l10n.dart';
import '../platform/link_inbox.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'recovery_key_screen.dart';
import 'scan_screen.dart';

enum _Mode { login, register, recover }

/// First start: connect to a server (or use none), then log in, register
/// or recover.
///
/// With [move] it moves the local mode to a server instead: sign in there
/// or create an account, then carry the codes over. Pops with the number
/// of codes moved.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.move = false});

  final bool move;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _invite = TextEditingController();
  final _recovery = TextEditingController();
  Uri? _url;
  ServerInfo? _info;
  _Mode _mode = _Mode.login;
  bool _busy = false;
  String? _error;

  /// Local mode chosen ("Ohne Server nutzen").
  bool _local = false;

  /// A move to the server stopped half way and can go on.
  bool _moveStopped = false;
  String? _progress;

  /// Set by an invitation link or QR code: register with this code.
  bool _invited = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    LinkInbox.instance.addListener(_takeInvite);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeInvite());
  }

  void _takeInvite() {
    if (!mounted || _busy) return;
    final link = LinkInbox.instance.take((l) => InviteLink.parse(l) != null);
    if (link != null) _applyInvite(InviteLink.parse(link)!);
  }

  /// Fills in server and invite code and connects; the address is shown
  /// before anything is sent, so a forged invitation stands out.
  Future<void> _applyInvite(InviteLink invite) async {
    setState(() {
      _info = null;
      _server.text = invite.server.toString();
      _invite.text = invite.code;
      _invited = true;
    });
    await _connect();
  }

  Future<void> _scanInvite() async {
    final text = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (text == null || !mounted) return;
    final invite = InviteLink.parse(text);
    if (invite == null) {
      setState(() => _error = t.notAnInviteCode);
      return;
    }
    await _applyInvite(invite);
  }

  @override
  void dispose() {
    LinkInbox.instance.removeListener(_takeInvite);
    for (final c in [
      _server,
      _username,
      _password,
      _password2,
      _invite,
      _recovery,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (url, info) = await AppController.probe(_server.text);
      setState(() {
        _url = url;
        _info = info;
        _mode = info.hasUsers && !_invited ? _Mode.login : _Mode.register;
      });
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useLocal() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (url, info) = await AppController.openLocal();
      setState(() {
        _local = true;
        _url = url;
        _info = info;
        _username.text = LocalServer.username;
        _mode = info.hasUsers ? _Mode.login : _Mode.register;
      });
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteLocalData() async {
    final ok = await confirm(
      context,
      title: '${t.deleteLocalData}?',
      message: t.deleteLocalDataMessage,
      action: t.deleteLocalData,
      destructive: true,
    );
    if (!ok || !mounted) return;
    AppController.deleteLocalData();
    await _useLocal();
  }

  void _changeServer() => setState(() {
    _info = null;
    if (_local) {
      _local = false;
      _username.clear();
    }
  });

  bool get _canRegister =>
      _info != null &&
      (!_info!.hasUsers || _info!.registration != RegistrationMode.closed);

  String? _validateNewPassword() {
    if (_username.text.trim().length < 3) {
      return t.usernameTooShort;
    }
    if (_password.text.length < 10) {
      return t.masterPasswordTooShort;
    }
    if (_password.text != _password2.text) {
      return t.passwordsDoNotMatch;
    }
    return null;
  }

  Future<void> _submit() async {
    final c = AppScope.read(context);
    final problem = switch (_mode) {
      _Mode.login
          when _username.text.trim().isEmpty || _password.text.isEmpty =>
        t.enterUsernameAndPassword,
      _Mode.register || _Mode.recover => _validateNewPassword(),
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    if (widget.move) {
      await _move(c, navigator);
      return;
    }
    try {
      switch (_mode) {
        case _Mode.login:
          await c.login(
            server: _url!,
            serverName: _info!.name,
            username: _username.text,
            password: _password.text,
          );
        case _Mode.register:
          final key = await c.register(
            server: _url!,
            serverName: _info!.name,
            username: _username.text.trim(),
            password: _password.text,
            inviteCode: _invite.text,
          );
          await navigator.push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => RecoveryKeyScreen(
                recoveryKey: key,
                username: _username.text.trim(),
              ),
            ),
          );
          await c.enter();
        case _Mode.recover:
          final key = await c.recover(
            server: _url!,
            serverName: _info!.name,
            username: _username.text,
            recoveryKey: _recovery.text,
            newPassword: _password.text,
          );
          await navigator.push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => RecoveryKeyScreen(
                recoveryKey: key,
                username: _username.text.trim(),
                renewed: true,
              ),
            ),
          );
          await c.enter();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signs in at the server (or creates the account), shows a new recovery
  /// key and carries the codes over; after an interruption it goes on.
  Future<void> _move(AppController c, NavigatorState navigator) async {
    void progress(int done, int total) {
      if (mounted) setState(() => _progress = t.moveProgress(done, total));
    }

    int? moved;
    String? recoveryKey;
    String? stopped;
    try {
      if (_moveStopped) {
        if (!c.moving) throw UserError(t.moveLost);
        moved = await c.finishMove(progress: progress);
      } else {
        final r = await c.moveToServer(
          server: _url!,
          serverName: _info!.name,
          username: _username.text.trim(),
          password: _password.text,
          create: _mode == _Mode.register,
          inviteCode: _invite.text,
          progress: progress,
        );
        moved = r.moved;
        recoveryKey = r.recoveryKey;
      }
    } on MoveIncomplete catch (e) {
      recoveryKey = e.recoveryKey;
      stopped = e.message;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _busy = false;
          _progress = null;
        });
      }
      return;
    }
    if (recoveryKey != null) {
      await navigator.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => RecoveryKeyScreen(
            recoveryKey: recoveryKey!,
            username: _username.text.trim(),
          ),
        ),
      );
    }
    if (!mounted) return;
    if (stopped != null) {
      setState(() {
        _moveStopped = true;
        _error = stopped;
        _busy = false;
        _progress = null;
      });
      return;
    }
    navigator.pop(moved);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    if (widget.move) {
      return Scaffold(
        appBar: AppBar(title: Text(t.connectServer)),
        body: SafeArea(
          child: FormPage(
            children: [
              Text(t.moveIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              if (_info == null) ..._serverStep() else ..._accountStep(theme),
              if (_progress != null) ...[
                const SizedBox(height: 12),
                Text(_progress!, textAlign: TextAlign.center),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: FormPage(
          children: [
            const SizedBox(height: 16),
            const Center(child: BrandMark(size: 88)),
            const SizedBox(height: 16),
            Text(
              'Sixora',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              t.tagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            if (c.notice != null) ...[
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(c.notice!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_info == null) ..._serverStep() else ..._accountStep(theme),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _serverStep() => [
    TextField(
      controller: _server,
      autofocus: true,
      keyboardType: TextInputType.url,
      autocorrect: false,
      autofillHints: const [AutofillHints.url],
      decoration: InputDecoration(
        labelText: t.serverAddressOrInvite,
        hintText: 'sixora.example.org',
        prefixIcon: const Icon(Icons.dns_outlined),
        suffixIcon: PasteButton(controller: _server),
      ),
      // A pasted invitation link fills in everything.
      onChanged: (text) {
        final invite = InviteLink.parse(text);
        if (invite != null) _applyInvite(invite);
      },
      onSubmitted: (_) => _connect(),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _busy ? null : _connect,
      child: _busy ? const _Spinner() : Text(t.connect),
    ),
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) ...[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _scanInvite,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(t.scanInviteQr),
      ),
    ],
    if (!widget.move) ...[
      const SizedBox(height: 28),
      const Divider(),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _busy ? null : _useLocal,
        icon: const Icon(Icons.smartphone_outlined),
        label: Text(t.useWithoutServer),
      ),
      Text(
        t.useWithoutServerHint,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  ];

  /// Which way in: sign in, create an account, or recover. The local mode
  /// has a single account; the move only signs in or creates.
  List<_Mode> get _modes => [
    if (_info!.hasUsers) _Mode.login,
    if (!_local && _canRegister) _Mode.register,
    if (_info!.hasUsers && !widget.move) _Mode.recover,
  ];

  List<Widget> _accountStep(ThemeData theme) {
    final strength = passwordStrength(_password.text);
    final newPassword = _mode != _Mode.login;
    final modes = _modes;
    return [
      if (_local)
        Card(
          child: ListTile(
            leading: const Icon(Icons.smartphone_outlined),
            title: Text(t.thisDeviceOnly),
            subtitle: Text(t.localModeHint),
            trailing: TextButton(
              onPressed: _busy ? null : _changeServer,
              child: Text(t.change),
            ),
          ),
        )
      else
        Card(
          child: ListTile(
            leading: Icon(
              _url!.scheme == 'https'
                  ? Icons.lock_outline
                  : Icons.lock_open_outlined,
              color: _url!.scheme == 'https'
                  ? Colors.green
                  : theme.colorScheme.error,
            ),
            title: Text(_info!.name),
            subtitle: Text(
              '${_url!.host}${_url!.hasPort ? ':${_url!.port}' : ''} · '
              '${t.serverVersion(_info!.version)}'
              '${_url!.scheme == 'http' ? '\n${t.noHttpsWarning}' : ''}',
            ),
            trailing: TextButton(
              onPressed: _busy || _moveStopped ? null : _changeServer,
              child: Text(t.change),
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (_moveStopped)
        const SizedBox.shrink()
      else if (modes.length > 1)
        SegmentedButton<_Mode>(
          segments: [
            for (final m in modes)
              ButtonSegment(
                value: m,
                label: Text(switch (m) {
                  _Mode.login => t.signIn,
                  _Mode.register => t.register,
                  _Mode.recover => t.forgotten,
                }),
              ),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                  _mode = s.first;
                  _error = null;
                }),
        )
      else if (_local)
        Text(t.localModeNew, style: theme.textTheme.bodyMedium)
      else if (!_info!.hasUsers)
        Text(t.newServerFirstAdmin, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      if (!_moveStopped) ..._credentials(theme, newPassword, strength),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const _Spinner()
            : Text(
                _moveStopped
                    ? t.moveContinue
                    : widget.move
                    ? t.moveButton
                    : switch (_mode) {
                        _Mode.login => t.signIn,
                        _Mode.register => t.createAccount,
                        _Mode.recover => t.setNewPassword,
                      },
              ),
      ),
      if (_busy && _mode != _Mode.login && _progress == null) ...[
        const SizedBox(height: 8),
        Text(
          t.generatingKeys,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
      if (_local && _mode == _Mode.login) ...[
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy ? null : _deleteLocalData,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(t.deleteLocalData),
        ),
      ],
    ];
  }

  List<Widget> _credentials(
    ThemeData theme,
    bool newPassword,
    ({double score, String label}) strength,
  ) {
    return [
      // The local mode has one account; its name is fixed.
      if (!_local) ...[
        TextField(
          controller: _username,
          autocorrect: false,
          autofillHints: [
            if (_mode == _Mode.register)
              AutofillHints.newUsername
            else
              AutofillHints.username,
          ],
          decoration: InputDecoration(
            labelText: t.username,
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_mode == _Mode.recover) ...[
        TextField(
          controller: _recovery,
          autocorrect: false,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: t.recoveryKey,
            prefixIcon: const Icon(Icons.health_and_safety_outlined),
            suffixIcon: PasteButton(controller: _recovery),
          ),
        ),
        const SizedBox(height: 12),
      ],
      PasswordField(
        controller: _password,
        label: _mode == _Mode.recover ? t.newMasterPassword : t.masterPassword,
        autofillHints: [
          if (newPassword)
            AutofillHints.newPassword
          else
            AutofillHints.password,
        ],
        onSubmitted: newPassword ? null : (_) => _submit(),
      ),
      if (newPassword) ...[
        if (_password.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: strength.score,
            color: strength.score < 0.5 ? theme.colorScheme.error : null,
          ),
          const SizedBox(height: 4),
          Text(
            t.strengthLabel(strength.label),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        PasswordField(
          controller: _password2,
          label: t.repeatMasterPassword,
          autofillHints: const [AutofillHints.newPassword],
        ),
      ],
      if (_mode == _Mode.register &&
          _info!.hasUsers &&
          _info!.registration == RegistrationMode.invite) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _invite,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: t.inviteCode,
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            suffixIcon: PasteButton(controller: _invite),
          ),
        ),
      ],
      if (newPassword) ...[
        const SizedBox(height: 12),
        Text(t.masterPasswordNeverLeaves, style: theme.textTheme.bodySmall),
      ],
    ];
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
