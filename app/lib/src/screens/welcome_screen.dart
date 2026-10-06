import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'recovery_key_screen.dart';

enum _Mode { login, register, recover }

/// First start: connect to a server, then log in, register or recover.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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
        _mode = info.hasUsers ? _Mode.login : _Mode.register;
      });
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canRegister =>
      _info != null &&
      (!_info!.hasUsers || _info!.registration != RegistrationMode.closed);

  String? _validateNewPassword() {
    if (_username.text.trim().length < 3) {
      return 'Benutzername: mindestens 3 Zeichen';
    }
    if (_password.text.length < 10) {
      return 'Das Master-Passwort braucht mindestens 10 Zeichen';
    }
    if (_password.text != _password2.text) {
      return 'Die Passwörter stimmen nicht überein';
    }
    return null;
  }

  Future<void> _submit() async {
    final c = AppScope.read(context);
    final problem = switch (_mode) {
      _Mode.login
          when _username.text.trim().isEmpty || _password.text.isEmpty =>
        'Benutzername und Master-Passwort eingeben',
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

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
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
              'Deine Einmal-Codes, Ende-zu-Ende-verschlüsselt auf deinem eigenen Server.',
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
      decoration: const InputDecoration(
        labelText: 'Server-Adresse',
        hintText: 'sixora.example.org',
        prefixIcon: Icon(Icons.dns_outlined),
      ),
      onSubmitted: (_) => _connect(),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _busy ? null : _connect,
      child: _busy ? const _Spinner() : const Text('Verbinden'),
    ),
  ];

  List<Widget> _accountStep(ThemeData theme) {
    final strength = passwordStrength(_password.text);
    final newPassword = _mode != _Mode.login;
    return [
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
            '${_url!.host}${_url!.hasPort ? ':${_url!.port}' : ''} · Version ${_info!.version}'
            '${_url!.scheme == 'http' ? '\nOhne HTTPS – nur im eigenen Netz verwenden!' : ''}',
          ),
          trailing: TextButton(
            onPressed: _busy ? null : () => setState(() => _info = null),
            child: const Text('Ändern'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_info!.hasUsers)
        SegmentedButton<_Mode>(
          segments: [
            const ButtonSegment(value: _Mode.login, label: Text('Anmelden')),
            if (_canRegister)
              const ButtonSegment(
                value: _Mode.register,
                label: Text('Registrieren'),
              ),
            const ButtonSegment(value: _Mode.recover, label: Text('Vergessen')),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                  _mode = s.first;
                  _error = null;
                }),
        )
      else
        Text(
          'Dieser Server ist neu. Das erste Konto wird Administrator.',
          style: theme.textTheme.bodyMedium,
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _username,
        autocorrect: false,
        autofillHints: [
          if (_mode == _Mode.register)
            AutofillHints.newUsername
          else
            AutofillHints.username,
        ],
        decoration: const InputDecoration(
          labelText: 'Benutzername',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 12),
      if (_mode == _Mode.recover) ...[
        TextField(
          controller: _recovery,
          autocorrect: false,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: 'Wiederherstellungsschlüssel',
            prefixIcon: Icon(Icons.health_and_safety_outlined),
          ),
        ),
        const SizedBox(height: 12),
      ],
      PasswordField(
        controller: _password,
        label: _mode == _Mode.recover
            ? 'Neues Master-Passwort'
            : 'Master-Passwort',
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
          Text('Stärke: ${strength.label}', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        PasswordField(
          controller: _password2,
          label: 'Master-Passwort wiederholen',
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
          decoration: const InputDecoration(
            labelText: 'Einladungscode',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
      ],
      if (newPassword) ...[
        const SizedBox(height: 12),
        Text(
          'Das Master-Passwort verlässt nie dieses Gerät und kann von niemandem '
          'zurückgesetzt werden – auch nicht vom Administrator. Nur mit dem '
          'Wiederherstellungsschlüssel kommst du ohne Passwort wieder hinein.',
          style: theme.textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const _Spinner()
            : Text(switch (_mode) {
                _Mode.login => 'Anmelden',
                _Mode.register => 'Konto erstellen',
                _Mode.recover => 'Neues Passwort setzen',
              }),
      ),
      if (_busy && _mode != _Mode.login) ...[
        const SizedBox(height: 8),
        Text(
          'Schlüssel werden erzeugt …',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
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
