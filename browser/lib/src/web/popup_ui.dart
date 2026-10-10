import 'dart:async';
import 'dart:js_interop';

import 'package:sixora_core/sixora_core.dart';
import 'package:web/web.dart' as web;

import '../extension.dart';
import '../format.dart';
import '../stored_account.dart';
import '../texts.dart';
import 'bridge.dart';

const _icons = {
  'lock':
      '<svg viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0 1 10 0v3"/><rect x="5" y="10" width="14" height="10" rx="2"/></svg>',
  'settings':
      '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>',
  'back': '<svg viewBox="0 0 24 24"><path d="M15 18l-6-6 6-6"/></svg>',
  'insert':
      '<svg viewBox="0 0 24 24"><path d="M9 10l-5 5 5 5"/><path d="M20 4v7a4 4 0 0 1-4 4H4"/></svg>',
};

/// The popup (and the setup tab): plain DOM, rebuilt per screen.
class PopupUi {
  PopupUi(this.x, this.t, {required this.inTab});

  final SixoraExtension x;
  final Texts t;

  /// Opened as a tab for the first sign-in: Firefox closes a popup while
  /// it asks for the server permission.
  final bool inTab;

  final _root = web.document.getElementById('app')! as web.HTMLElement;
  Timer? _ticker;
  ServiceMatch? _match;
  String? _site;
  bool _settings = false;
  bool _setupDone = false;
  String _query = '';
  web.HTMLElement? _list;
  web.HTMLElement? _status;
  web.HTMLElement? _toast;
  final _rows = <({Code code, web.HTMLElement value, web.HTMLElement bar})>[];

  Future<void> start() async {
    if (inTab) web.document.body?.classList.add('tab');
    await x.load();
    _site = siteOf((await bridge.activeTabUrl().toDart)?.toDart);
    if (_site != null) _match = ServiceMatch(domain: _site);
    _render();
    if (x.stage == Stage.unlocked) unawaited(_sync());
  }

  // --- DOM helpers ---------------------------------------------------------

  web.HTMLElement _el(
    String tag, {
    String? cls,
    String? text,
    List<web.Node> children = const [],
    Map<String, String> attrs = const {},
  }) {
    final e = web.document.createElement(tag) as web.HTMLElement;
    if (cls != null) e.className = cls;
    if (text != null) e.textContent = text;
    attrs.forEach((name, value) => e.setAttribute(name, value));
    for (final c in children) {
      e.appendChild(c);
    }
    return e;
  }

  web.HTMLElement _iconButton(
    String icon,
    String label,
    void Function() onTap,
  ) {
    final b = _el(
      'button',
      cls: 'icon',
      attrs: {'title': label, 'aria-label': label},
    );
    b.innerHTML = _icons[icon]!.toJS;
    _onClick(b, onTap);
    return b;
  }

  void _onClick(web.HTMLElement e, void Function() action) =>
      e.addEventListener('click', ((web.Event _) => action()).toJS);

  web.HTMLInputElement _input(
    String label, {
    String type = 'text',
    String autocomplete = 'off',
    String value = '',
  }) {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = type
      ..value = value
      ..autocomplete = autocomplete
      ..placeholder = label
      ..setAttribute('aria-label', label)
      ..spellcheck = false;
    return input;
  }

  /// Replaces the screen; [list] and [status] belong to the main screen.
  void _show(
    List<web.Node> children, {
    web.HTMLElement? list,
    web.HTMLElement? status,
  }) {
    _ticker?.cancel();
    _rows.clear();
    _list = list;
    _status = status;
    _root.textContent = '';
    for (final c in children) {
      _root.appendChild(c);
    }
    _toast = _el('div', cls: 'toast', attrs: {'role': 'status'});
    _root.appendChild(_toast!);
  }

  void _say(String text) {
    final toast = _toast;
    if (toast == null) return;
    toast
      ..textContent = text
      ..classList.add('visible');
    Timer(const Duration(seconds: 2), () => toast.classList.remove('visible'));
  }

  web.HTMLElement _header({List<web.Node> actions = const []}) => _el(
    'header',
    children: [
      _el('img', attrs: {'src': 'icons/icon-32.png', 'alt': ''}),
      _el('h1', text: 'Sixora'),
      _el('div', cls: 'actions', children: actions),
    ],
  );

  // --- Screens ---------------------------------------------------------------

  void _render() => switch (x.stage) {
    Stage.loading => null,
    Stage.setup => inTab ? _setupForm() : _setupIntro(),
    Stage.locked => _lockScreen(),
    Stage.unlocked =>
      _setupDone ? _done() : (_settings ? _settingsScreen() : _main()),
  };

  void _setupIntro() => _show([
    _header(),
    _el(
      'main',
      cls: 'center',
      children: [
        if (x.signedOutRemotely)
          _el('p', cls: 'notice', text: t['signedOutRemotely']),
        _el('p', text: t['setupNeeded']),
        _button(t['setupStart'], () async {
          await bridge.openTab('popup.html#setup').toDart;
          web.window.close();
        }),
      ],
    ),
  ]);

  web.HTMLElement _button(
    String label,
    void Function() onTap, {
    String cls = 'primary',
  }) {
    final b = _el('button', cls: cls, text: label);
    _onClick(b, onTap);
    return b;
  }

  void _setupForm() {
    final server = _input(t['serverAddress'], autocomplete: 'url');
    final user = _input(t['username'], autocomplete: 'username');
    final password = _input(
      t['masterPassword'],
      type: 'password',
      autocomplete: 'current-password',
    );
    final error = _el('p', cls: 'error', attrs: {'role': 'alert'});
    final submit = _el(
      'button',
      cls: 'primary',
      text: t['signIn'],
      attrs: {'type': 'submit'},
    );
    final form = _el(
      'form',
      children: [
        server,
        user,
        password,
        submit,
        error,
        _el('p', cls: 'hint', text: t['permissionHint']),
      ],
    );
    form.addEventListener(
      'submit',
      ((web.Event e) {
        e.preventDefault();
        error.textContent = '';
        final Uri url;
        try {
          url = SixoraExtension.parseAddress(server.value);
        } on Object catch (err) {
          error.textContent = t.error(err);
          return;
        }
        // Still inside the click: the browser only asks during a gesture.
        final allowed = bridge.requestHost(hostPattern(url));
        submit
          ..setAttribute('disabled', '')
          ..textContent = '…';
        unawaited(() async {
          try {
            if (!(await allowed.toDart).toDart) {
              throw const ExtensionError('permissionDenied');
            }
            await x.signIn(url, user.value, password.value);
            password.value = '';
            _setupDone = true;
            _render();
          } on Object catch (err) {
            error.textContent = t.error(err);
            submit
              ..removeAttribute('disabled')
              ..textContent = t['signIn'];
          }
        }());
      }).toJS,
    );
    _show([
      _header(),
      _el(
        'main',
        cls: 'setup',
        children: [
          _el('h2', text: t['setupTitle']),
          if (x.signedOutRemotely)
            _el('p', cls: 'notice', text: t['signedOutRemotely']),
          _el('p', text: t['setupIntro']),
          form,
        ],
      ),
    ]);
    server.focus();
  }

  void _done() => _show([
    _header(),
    _el(
      'main',
      cls: 'setup',
      children: [_el('p', cls: 'done', text: t['setupDone'])],
    ),
  ]);

  void _lockScreen() {
    final password = _input(
      t['masterPassword'],
      type: 'password',
      autocomplete: 'current-password',
    );
    final error = _el('p', cls: 'error', attrs: {'role': 'alert'});
    final submit = _el(
      'button',
      cls: 'primary',
      text: t['unlock'],
      attrs: {'type': 'submit'},
    );
    final form = _el('form', children: [password, submit, error]);
    form.addEventListener(
      'submit',
      ((web.Event e) {
        e.preventDefault();
        submit
          ..setAttribute('disabled', '')
          ..textContent = '…';
        unawaited(() async {
          try {
            await x.unlock(password.value);
            _render();
            unawaited(_sync());
          } on Object catch (err) {
            if (x.stage == Stage.setup) {
              _render();
              return;
            }
            error.textContent = t.error(err);
            password.value = '';
            password.focus();
            submit
              ..removeAttribute('disabled')
              ..textContent = t['unlock'];
          }
        }());
      }).toJS,
    );
    final s = x.stored!;
    _show([
      _header(),
      _el(
        'main',
        cls: 'center',
        children: [
          _el('h2', text: t['locked']),
          _el(
            'p',
            cls: 'muted',
            text: '${s.account.username} · ${s.server.host}',
          ),
          form,
        ],
      ),
    ]);
    password.focus();
  }

  void _main() {
    final search = _input(t['search'], type: 'search', value: _query);
    search.addEventListener(
      'input',
      ((web.Event _) {
        _query = search.value.trim().toLowerCase();
        _fillList();
      }).toJS,
    );
    // Enter puts the first code into the page.
    search.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        if (e.key == 'Enter' && _rows.isNotEmpty) _insert(_rows.first.code);
      }).toJS,
    );
    final list = _el('div', cls: 'list');
    final status = _el('p', cls: 'status');
    _show(list: list, status: status, [
      _header(
        actions: [
          _iconButton('lock', t['lock'], () async {
            await x.lock();
            _render();
          }),
          _iconButton('settings', t['settings'], () {
            _settings = true;
            _render();
          }),
        ],
      ),
      _el('div', cls: 'search', children: [search]),
      status,
      list,
    ]);
    _fillList();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    search.focus();
  }

  void _fillList() {
    final list = _list;
    if (list == null) return;
    list.textContent = '';
    _rows.clear();
    _updateStatus();
    bool shown(Code c) =>
        _query.isEmpty ||
        c.entry.issuer.toLowerCase().contains(_query) ||
        c.entry.account.toLowerCase().contains(_query);
    final codes = x.codes.where(shown).toList();
    final match = _match;
    final matching = [
      if (match != null)
        for (final c in codes)
          if (match.matches(c.entry)) c,
    ];
    final others = [
      for (final c in codes)
        if (!matching.contains(c)) c,
    ];
    if (x.codes.isEmpty) {
      list.appendChild(_el('p', cls: 'empty', text: t['noAccounts']));
      return;
    }
    if (codes.isEmpty) {
      list.appendChild(_el('p', cls: 'empty', text: t['noMatches']));
      return;
    }
    if (matching.isNotEmpty) {
      list.appendChild(_el('h3', text: t.fill('matching', {'site': _site!})));
      matching.forEach(_row);
      list.appendChild(_el('h3', text: t['allAccounts']));
    }
    others.forEach(_row);
  }

  void _row(Code c) {
    final now = DateTime.now();
    final e = c.entry;
    final value = _el('div', cls: 'code', text: groupCode(e.code(now)));
    final bar = _el('div', cls: 'bar');
    final avatar = _el(
      'div',
      cls: 'avatar',
      text: e.displayName.isEmpty ? '?' : e.displayName.characters1,
    );
    avatar.style.setProperty('background', avatarColor(e));
    final insert = _iconButton('insert', t['insert'], () => _insert(c));
    final row = _el(
      'div',
      cls: 'row',
      attrs: {'tabindex': '0', 'title': t['copy']},
      children: [
        avatar,
        _el(
          'div',
          cls: 'names',
          children: [
            _el('div', cls: 'issuer', text: e.displayName),
            if (e.account.isNotEmpty && e.issuer.isNotEmpty)
              _el('div', cls: 'account', text: e.account),
          ],
        ),
        _el(
          'div',
          cls: 'value',
          children: [
            value,
            _el('div', cls: 'track', children: [bar]),
          ],
        ),
        insert,
      ],
    );
    row.addEventListener(
      'click',
      ((web.MouseEvent ev) {
        if (insert.contains(ev.target as web.Node?)) return;
        _copy(c);
      }).toJS,
    );
    row.addEventListener(
      'keydown',
      ((web.KeyboardEvent ev) {
        if (ev.key == 'Enter') _insert(c);
      }).toJS,
    );
    _list!.appendChild(row);
    _rows.add((code: c, value: value, bar: bar));
    _paint(_rows.last, now);
  }

  void _paint(
    ({Code code, web.HTMLElement value, web.HTMLElement bar}) r,
    DateTime now,
  ) {
    final e = r.code.entry;
    final left = secondsLeft(e, now);
    r.value.textContent = groupCode(e.code(now));
    r.bar.style.setProperty(
      'width',
      '${(left * 100 / e.period).toStringAsFixed(1)}%',
    );
    r.bar.classList.toggle('low', left <= 5);
    r.value.parentElement?.setAttribute(
      'title',
      t.fill('secondsLeft', {'n': left}),
    );
  }

  void _tick() {
    final now = DateTime.now();
    for (final r in _rows) {
      _paint(r, now);
    }
  }

  void _updateStatus() {
    final status = _status;
    if (status == null) return;
    final parts = <String>[
      if (x.syncError != null) t['offline'],
      if (x.unreadable > 0) t.fill('unreadable', {'n': x.unreadable}),
    ];
    status.textContent = parts.join(' ');
    status.classList.toggle('visible', parts.isNotEmpty);
  }

  Future<void> _copy(Code c) async {
    await web.window.navigator.clipboard.writeText(c.entry.code()).toDart;
    unawaited(x.touch());
    _say(t['copied']);
  }

  Future<void> _insert(Code c) async {
    final code = c.entry.code();
    unawaited(x.touch());
    if ((await bridge.fill(code).toDart).toDart) {
      _say(t['inserted']);
      Timer(const Duration(milliseconds: 500), () => web.window.close());
      return;
    }
    await web.window.navigator.clipboard.writeText(code).toDart;
    _say(t['noField']);
  }

  Future<void> _sync() async {
    await x.sync();
    if (x.stage != Stage.unlocked) {
      _render();
      return;
    }
    if (_list != null) _fillList();
  }

  void _settingsScreen() {
    final s = x.stored!;
    final select =
        web.document.createElement('select') as web.HTMLSelectElement;
    for (final minutes in ExtensionSettings.choices) {
      final option =
          web.document.createElement('option') as web.HTMLOptionElement
            ..value = '$minutes'
            ..textContent = minutes == 0
                ? t['onBrowserClose']
                : t.fill('afterMinutes', {'n': minutes})
            ..selected = minutes == x.settings.autoLockMinutes;
      select.appendChild(option);
    }
    select.addEventListener(
      'change',
      ((web.Event _) {
        x.settings.autoLockMinutes = int.parse(select.value);
        unawaited(x.saveSettings());
      }).toJS,
    );
    final last = s.lastSync;
    _show([
      _header(
        actions: [
          _iconButton('back', t['back'], () {
            _settings = false;
            _render();
          }),
        ],
      ),
      _el(
        'main',
        cls: 'settings',
        children: [
          _el('h3', text: t['account']),
          _el(
            'p',
            text: '${s.account.username} · ${s.serverName} (${s.server.host})',
          ),
          if (last != null)
            _el(
              'p',
              cls: 'muted',
              text: t.fill('lastSync', {'time': _time(last)}),
            ),
          _el('h3', text: t['autoLock']),
          select,
          _el('p', cls: 'muted', text: t['readOnlyHint']),
          _button(t['signOut'], () async {
            await x.signOut();
            _settings = false;
            _render();
          }, cls: 'danger'),
          _el('p', cls: 'muted', text: t['signOutHint']),
          _el(
            'p',
            cls: 'muted',
            text: t.fill('version', {'v': bridge.version()}),
          ),
        ],
      ),
    ]);
  }

  String _time(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}. ${two(d.hour)}:${two(d.minute)}';
  }
}

extension on String {
  /// The first character (a whole code point) in upper case.
  String get characters1 => String.fromCharCode(runes.first).toUpperCase();
}
