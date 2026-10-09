import 'base32.dart';
import 'entry.dart';
import 'otp.dart';

enum CheckIssue {
  /// The same secret more than once: one copy is enough.
  duplicate,

  /// Fewer than 80 bits: guessable with enough tries (RFC 4226 asks for at
  /// least 128). Only the service can issue a better one.
  weakSecret,

  /// Not valid Base32: no code can be computed.
  invalidSecret,

  /// Neither service nor account name: hard to tell apart.
  unnamed,
}

class CheckFinding {
  const CheckFinding(this.issue, this.ids);
  final CheckIssue issue;

  /// The affected entries; for [CheckIssue.duplicate] one group.
  final List<String> ids;
}

/// Looks through the accounts for things worth fixing.
abstract final class AccountCheck {
  static const minSecretBytes = 10;

  static List<CheckFinding> analyze(Map<String, OtpEntry> entries) {
    final findings = <CheckFinding>[];
    final bySecret = <String, List<String>>{};
    for (final MapEntry(key: id, value: e) in entries.entries) {
      if (e.issuer.trim().isEmpty && e.account.trim().isEmpty) {
        findings.add(CheckFinding(CheckIssue.unnamed, [id]));
      }
      final secret = Base32.normalize(e.secret);
      if (!Base32.isValid(secret)) {
        findings.add(CheckFinding(CheckIssue.invalidSecret, [id]));
        continue;
      }
      final bytes = Base32.decode(secret);
      if (bytes.length < minSecretBytes) {
        findings.add(CheckFinding(CheckIssue.weakSecret, [id]));
      }
      // Same secret and type: the same codes, whatever the names say.
      final key =
          '${e.type == OtpType.hotp ? 'h' : 't'}:${Base32.encode(bytes)}';
      (bySecret[key] ??= []).add(id);
    }
    for (final ids in bySecret.values) {
      if (ids.length > 1) findings.add(CheckFinding(CheckIssue.duplicate, ids));
    }
    return findings;
  }

  /// Whether [entry] is already among [existing] (same secret and type).
  static bool contains(Iterable<OtpEntry> existing, OtpEntry entry) {
    String? key(OtpEntry e) {
      final s = Base32.normalize(e.secret);
      if (!Base32.isValid(s)) return null;
      return '${e.type == OtpType.hotp ? 'h' : 't'}:${Base32.encode(Base32.decode(s))}';
    }

    final k = key(entry);
    return k != null && existing.any((e) => key(e) == k);
  }
}
