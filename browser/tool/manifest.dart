import 'dart:convert';
import 'dart:io';

/// Writes the manifest.json for one browser family:
///
///     dart run tool/manifest.dart chromium|firefox|safari VERSION
///
/// Firefox wants its own id and runs the popup's WebAssembly from 128 on;
/// Chromium needs WasmGC (119). Host access is asked for at sign-in, for
/// the one server only.
///
/// Native messaging reaches the desktop app ("Mit Touch ID entsperren"),
/// whose host manifest names the extension by its ID; in Chromium the
/// public key below fixes it (dgnhcjdoiadiehcdiimmkopdhpkgfbek, also for
/// an unpacked copy). Safari's native messaging only reaches its own
/// wrapper app, so it goes without.
void main(List<String> args) {
  if (args.length != 2 ||
      !{'chromium', 'firefox', 'safari'}.contains(args[0])) {
    stderr.writeln(
      'Aufruf: dart run tool/manifest.dart chromium|firefox|safari <version>',
    );
    exit(64);
  }
  final [target, version] = args;
  const icons = {
    '16': 'icons/icon-16.png',
    '32': 'icons/icon-32.png',
    '48': 'icons/icon-48.png',
    '128': 'icons/icon-128.png',
  };
  final manifest = <String, Object?>{
    'manifest_version': 3,
    'name': 'Sixora',
    'version': version,
    'description': '__MSG_description__',
    'default_locale': 'en',
    'icons': icons,
    'action': {
      'default_popup': 'popup.html',
      'default_title': 'Sixora',
      'default_icon': {'16': icons['16'], '32': icons['32']},
    },
    'permissions': [
      'storage',
      'activeTab',
      'scripting',
      'clipboardWrite',
      if (target != 'safari') 'nativeMessaging',
    ],
    if (target == 'chromium') 'background': {'service_worker': 'background.js'},
    if (target == 'firefox')
      'background': {
        'scripts': ['background.js'],
      },
    'optional_host_permissions': ['https://*/*', 'http://*/*'],
    'content_security_policy': {
      'extension_pages':
          "script-src 'self' 'wasm-unsafe-eval'; object-src 'self'",
    },
    'commands': {
      '_execute_action': {
        'suggested_key': {'default': 'Alt+Shift+O'},
        'description': '__MSG_openPopup__',
      },
    },
    if (target == 'chromium') 'minimum_chrome_version': '119',
    if (target == 'chromium') 'key': _chromiumKey,
    if (target == 'firefox')
      'browser_specific_settings': {
        'gecko': {
          'id': '{8f8c1986-faf4-48a3-a267-a6c28c12f5ec}',
          'strict_min_version': '128.0',
          'data_collection_permissions': {
            'required': ['none'],
          },
        },
      },
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(manifest));
}

const _chromiumKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwsp8WjyZC2ZkXRSN7Ulq4W/EJ0/b8zDqA1SCcjhjT42pgGc11bGRbUtUdsW6NZM+mGdPrmPhiyCU8Juc35HBWa8KUwV1DVUul8UZgZODykpkqlOHS8do1VH8BlhvGfYvfVIIC1Yy94bKbRAbEL8xPQCLYdN85sszyPGiMSiCSRgA5wYZqLIVzuBFb5izaX2V43QosuKMEu4cATXlnAv64QU1EMPIr9SobeOedkUqGdFAPbhxIe6RhHNFOc3ZyLq8NWcu+nTYQWHePHd1GdyEpjrHcFKApodL/cSK6ymgzys/u8Ltxp2vDpzOcY9ctIdOE+vHyW0coueEA65cqRLcHwIDAQAB';
